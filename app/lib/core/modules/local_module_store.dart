import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'module_registry.dart';

/// Immutable content-addressed installations; executable paths never come from
/// workspace documents or catalog manifests.
class LocalModuleStore {
  LocalModuleStore({this.root});
  final Directory? root;
  static const maxBytes = 64 * 1024 * 1024;
  Future<Directory> get directory async =>
      root ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'qmod'));

  static Map<String, dynamic> validateManifest(dynamic value) {
    if (value is! Map) throw const FormatException('Missing module manifest.');
    final m = Map<String, dynamic>.from(value);
    if (m['format'] != 'qualia-module' ||
        m['schemaVersion'] != 1 ||
        m['runtime'] != 'native-process-v1' ||
        m['platform'] != 'linux-x64' ||
        m['entrypoint'] != 'bin/module' ||
        m['id'] is! String ||
        !RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(m['id'] as String) ||
        m['version'] is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(m['version'] as String) ||
        m['name'] is! String ||
        (m['name'] as String).trim().isEmpty ||
        (m['name'] as String).length > 80) {
      throw const FormatException(
        'Unsupported or invalid native module manifest.',
      );
    }
    final ui = m['ui'];
    if (ui is! List || ui.length > 64) {
      throw const FormatException('Invalid UI.');
    }
    final ids = <String>{};
    for (final field in ui) {
      if (field is! Map ||
          field['id'] is! String ||
          !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$')
              .hasMatch(field['id'] as String) ||
          !ids.add(field['id'] as String) ||
          const ['enabled', 'label'].contains(field['id']) ||
          !const [
            'slider',
            'toggle',
            'select',
            'text',
            'number',
            'button',
            'label',
          ].contains(field['type'])) {
        throw const FormatException('Invalid or duplicate UI field.');
      }
      if (field['label'] is! String ||
          (field['label'] as String).length > 240) {
        throw const FormatException('Invalid UI label.');
      }
      if (field['type'] == 'slider' &&
          (field['min'] is! num ||
              field['max'] is! num ||
              (field['max'] as num) <= (field['min'] as num))) {
        throw const FormatException('Invalid slider range.');
      }
      if (field['type'] == 'select' &&
          (field['options'] is! List ||
              (field['options'] as List).isEmpty ||
              (field['options'] as List).length > 64 ||
              (field['options'] as List).any(
                (o) => o is! String || o.length > 240,
              ))) {
        throw const FormatException('Invalid select options.');
      }
    }
    if (m['ports'] is! Map) throw const FormatException('Invalid ports.');
    for (final direction in ['inputs', 'outputs']) {
      final ports = (m['ports'] as Map)[direction];
      if (ports is! List ||
          ports.length > 16 ||
          ports.toSet().length != ports.length ||
          ports.any(
            (id) =>
                id is! String ||
                !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(id),
          )) {
        throw const FormatException('Invalid port IDs.');
      }
    }
    return m;
  }

  /// v1 deliberately accepts ZIP STORE only: no unbounded decompression, links,
  /// encryption, traversal or archive-provided executable permissions.
  static Archive validateArchive(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Package is too large.');
    }
    final dir = ZipDirectory.read(InputStream(bytes));
    if (dir.fileHeaders.length > 256) {
      throw const FormatException('Too many files.');
    }
    final names = <String>{};
    var total = 0;
    for (final h in dir.fileHeaders) {
      final name = h.filename;
      final mode = (h.externalFileAttributes ?? 0) >> 16;
      total += h.uncompressedSize ?? 0;
      if (name.isEmpty ||
          name.length > 240 ||
          name.startsWith('/') ||
          name.contains('\\') ||
          name.contains(':') ||
          name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
          !names.add(name) ||
          h.compressionMethod != 0 ||
          h.file?.compressionMethod != 0 ||
          (h.generalPurposeBitFlag & 1) != 0 ||
          ((h.file?.flags ?? 0) & 1) != 0 ||
          (mode & 0xF000 != 0 && mode & 0xF000 != 0x8000) ||
          total > maxBytes ||
          h.uncompressedSize != h.compressedSize) {
        throw const FormatException('Unsafe or unsupported package entry.');
      }
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.findFile('manifest.json') == null ||
        archive.findFile('bin/module') == null) {
      throw const FormatException(
        'Package needs manifest.json and bin/module.',
      );
    }
    return archive;
  }

  Future<SystemModule> install(List<int> bytes) async {
    final archive = validateArchive(bytes);
    final manifestFile = archive.findFile('manifest.json')!;
    if (manifestFile.size > 65536) {
      throw const FormatException('Manifest is too large.');
    }
    final m = validateManifest(
      jsonDecode(utf8.decode(manifestFile.content as List<int>)),
    );
    final binary = archive.findFile('bin/module')!.content as List<int>;
    if (binary.length < 20 ||
        binary[0] != 127 ||
        binary[1] != 69 ||
        binary[2] != 76 ||
        binary[3] != 70 ||
        binary[4] != 2 ||
        binary[5] != 1 ||
        binary[18] != 62 ||
        binary[19] != 0) {
      throw const FormatException('Expected a Linux x64 ELF executable.');
    }
    final hash = sha256.convert(bytes).toString();
    final base = await directory;
    await base.create(recursive: true);
    final target = Directory(p.join(base.path, hash));
    if (!await target.exists()) {
      final staging = await base.createTemp('.install-');
      try {
        for (final entry in archive) {
          final file = File(p.join(staging.path, entry.name));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.content as List<int>, flush: true);
        }
        final chmod = await Process.run('chmod', [
          '700',
          p.join(staging.path, 'bin/module'),
        ]);
        if (chmod.exitCode != 0) {
          throw const FileSystemException('Cannot set executable permission.');
        }
        await File(p.join(staging.path, '.package.sha256')).writeAsString(hash);
        await File(p.join(staging.path, '.executable.sha256'))
            .writeAsString(sha256.convert(binary).toString());
        await staging.rename(target.path);
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    }
    return SystemModule(
      id: m['id'] as String,
      name: m['name'] as String,
      category: 'Local',
      description: m['description'] as String? ?? '',
      version: m['version'] as String,
      active: true,
      reviewState: 'local',
      localPackage: hash,
      manifest: m,
    );
  }

  Future<String> executable(SystemModule installed) async {
    final hash = installed.localPackage;
    if (hash == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Module is not installed locally.');
    }
    final path = p.join((await directory).path, hash, 'bin/module');
    if (!await File(path).exists()) {
      throw const FileSystemException('Module executable is missing.');
    }
    final digest = File(
      p.join(File(path).parent.parent.path, '.executable.sha256'),
    );
    if (!await digest.exists() ||
        await digest.readAsString() !=
            (await sha256.bind(File(path).openRead()).first).toString()) {
      throw const FileSystemException(
        'Installed executable is damaged. Install a new package version.',
      );
    }
    return path;
  }

  Future<void> createProject(String path) async {
    final target = Directory(path);
    if (await target.exists() && !await target.list().isEmpty) {
      throw const FileSystemException('Choose an empty project directory.');
    }
    for (final name in [
      'qmod.py',
      'include/qualia.hpp',
      'include/json.hpp',
      'template/CMakeLists.txt',
      'template/main.cpp',
      'template/manifest.json',
    ]) {
      final data = await rootBundle.load('assets/module_sdk/$name');
      final relative = name.startsWith('template/') ? name.substring(9) : name;
      final file = File(p.join(path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
  }
}
