import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'module_registry.dart';
import 'port_schema.dart';
import 'module_platform.dart';

class ModuleLaunchCommand {
  const ModuleLaunchCommand(this.executable, this.arguments, this.directory);
  final String executable, directory;
  final List<String> arguments;
}

/// Immutable content-addressed installations; executable paths never come from
/// workspace documents or catalog manifests.
class LocalModuleStore {
  LocalModuleStore({this.root});
  final Directory? root;
  static const maxBytes = 256 * 1024 * 1024;

  static bool safePath(dynamic path) =>
      path is String &&
      path.isNotEmpty &&
      path.length <= 240 &&
      !path.startsWith('/') &&
      !path.startsWith('.') &&
      !path.contains('\\') &&
      !path.contains(':') &&
      !path.contains('\u0000') &&
      !RegExp(r'[<>"|?*\x00-\x1f]').hasMatch(path) &&
      !path
          .split('/')
          .any(
            (s) =>
                s.endsWith('.') ||
                s.endsWith(' ') ||
                RegExp(
                  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
                  caseSensitive: false,
                ).hasMatch(s),
          ) &&
      !path.split('/').any((s) => s == '..' || s == '.' || s.isEmpty);

  static String entrypoint(Map<String, dynamic> manifest) =>
      ModulePlatform.select(manifest)['executable'] as String;
  Future<Directory> get directory async =>
      root ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'qmod'));

  static Map<String, dynamic> validateManifest(dynamic value) {
    if (value is! Map) throw const FormatException('Missing module manifest.');
    final m = Map<String, dynamic>.from(value);
    if (m['format'] != 'qualia-module' ||
        m['schemaVersion'] != 1 ||
        !['native-process-v1', 'process-v1'].contains(m['runtime']) ||
        (m['runtime'] == 'native-process-v1' &&
            (m['entrypoint'] != 'bin/module' ||
                m['platform'] != 'linux-x64' ||
                m.containsKey('targets'))) ||
        m['id'] is! String ||
        !RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(m['id'] as String) ||
        m['version'] is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(m['version'] as String) ||
        m['name'] is! String ||
        (m['name'] as String).trim().isEmpty ||
        (m['name'] as String).length > 80) {
      throw const FormatException(
        'Unsupported or invalid process module manifest.',
      );
    }
    if (m['runtime'] == 'process-v1') {
      if (m.containsKey('targets')) {
        if (m['targets'] is! Map ||
            (m['targets'] as Map).isEmpty ||
            (m['targets'] as Map).length > ModulePlatform.supported.length ||
            m.containsKey('platform') ||
            m.containsKey('launch') ||
            m.containsKey('entrypoint') ||
            (m['targets'] as Map).keys.any(
              (key) => !ModulePlatform.supported.contains(key),
            )) {
          throw const FormatException('Invalid or ambiguous platform targets.');
        }
      } else if (!ModulePlatform.supported.contains(m['platform'])) {
        throw const FormatException('Unsupported module platform.');
      }
      final launches = m['targets'] is Map
          ? (m['targets'] as Map).values
          : [m['launch']];
      for (final launch in launches) {
        if (launch is! Map ||
            launch.keys.any(
              (key) => !['executable', 'arguments'].contains(key),
            ) ||
            !safePath(launch['executable']) ||
            launch['arguments'] is! List ||
            (launch['arguments'] as List).length > 32 ||
            (launch['arguments'] as List).any(
              (a) => a is! String || a.length > 4096 || a.contains('\u0000'),
            )) {
          throw const FormatException('Invalid packaged launch command.');
        }
      }
    }
    if (m.containsKey('ui') && m['ui'] is! List) {
      throw const FormatException('Invalid UI.');
    }
    final ui = m['ui'] is List ? m['ui'] as List : const <dynamic>[];
    if (ui.length > 64) {
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
    if (m.containsKey('uiLayout') && m['uiLayout'] is! Map) {
      throw const FormatException('Invalid custom UI layout.');
    }
    if (m['uiLayout'] is Map) {
      _validateCustomLayout(
        Map<String, dynamic>.from(m['uiLayout'] as Map),
        ids,
      );
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
    PortSchema.validateManifest(m);
    return m;
  }

  static void _validateCustomLayout(
    Map<String, dynamic> node,
    Set<String> fieldIds, {
    int depth = 0,
    Set<String>? seen,
    List<int>? nodeCount,
  }) {
    final visited = seen ?? <String>{};
    final count = nodeCount ?? [0];
    count[0]++;
    if (depth > 12 || count[0] > 512) {
      throw const FormatException('Custom UI layout is too deep or too large.');
    }
    final type = node['type'];
    const containers = ['column', 'row', 'card'];
    const leaves = [
      'text',
      'value',
      'button',
      'input',
      'chart',
      'divider',
      'spacer',
    ];
    if (![...containers, ...leaves].contains(type)) {
      throw const FormatException('Unsupported custom UI element.');
    }
    const interactive = ['input', 'button'];
    const stateElements = ['value', 'chart'];
    if (node['id'] != null) {
      if (node['id'] is! String ||
          !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$')
              .hasMatch(node['id'] as String) ||
          (interactive.contains(type) && !fieldIds.contains(node['id']))) {
        throw const FormatException('Custom UI references an unknown field.');
      }
      visited.add(node['id'] as String);
    }
    if ((interactive.contains(type) || stateElements.contains(type)) &&
        node['id'] is! String) {
      throw const FormatException('Custom UI element needs an ID.');
    }
    for (final key in ['label', 'title', 'text']) {
      if (node[key] != null &&
          (node[key] is! String || (node[key] as String).length > 1000)) {
        throw const FormatException('Custom UI text is invalid.');
      }
    }
    if (node['gap'] != null &&
        (node['gap'] is! num ||
            (node['gap'] as num) < 0 ||
            (node['gap'] as num) > 96)) {
      throw const FormatException('Custom UI gap is invalid.');
    }
    if (type == 'input' &&
        !const ['number', 'text'].contains(node['inputType'])) {
      throw const FormatException('Custom UI input type is invalid.');
    }
    if (type == 'input') {
      final field = fieldIds.contains(node['id']) ? node['id'] : null;
      if (field == null) {
        throw const FormatException('Custom UI input needs a UI field.');
      }
    }
    if (type == 'spacer' &&
        (node['height'] is! num ||
            (node['height'] as num) < 0 ||
            (node['height'] as num) > 240)) {
      throw const FormatException('Custom UI spacer height is invalid.');
    }
    if (node['children'] != null) {
      if (!containers.contains(type) ||
          node['children'] is! List ||
          (node['children'] as List).length > 64) {
        throw const FormatException('Custom UI children are invalid.');
      }
      for (final child in node['children'] as List) {
        if (child is! Map) {
          throw const FormatException('Custom UI child is invalid.');
        }
        _validateCustomLayout(
          Map<String, dynamic>.from(child),
          fieldIds,
          depth: depth + 1,
          seen: visited,
          nodeCount: count,
        );
      }
    } else if (containers.contains(type)) {
      throw const FormatException('Custom UI container needs children.');
    }
  }

  /// v1 deliberately accepts ZIP STORE only: no unbounded decompression, links,
  /// encryption, traversal or archive-provided executable permissions.
  static Archive validateArchive(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Package is too large.');
    }
    final dir = ZipDirectory.read(InputStream(bytes));
    if (dir.fileHeaders.length > 4096) {
      throw const FormatException('Too many files.');
    }
    final names = <String>{};
    var total = 0;
    for (final h in dir.fileHeaders) {
      final name = h.filename;
      final mode = (h.externalFileAttributes ?? 0) >> 16;
      total += h.uncompressedSize ?? 0;
      if (!safePath(name) ||
          name.startsWith('.') ||
          name.isEmpty ||
          name.length > 240 ||
          name.startsWith('/') ||
          name.contains('\\') ||
          name.contains(':') ||
          name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
          !names.add(name.toLowerCase()) ||
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
    if (archive.findFile('manifest.json') == null) {
      throw const FormatException('Package needs manifest.json.');
    }
    for (final entry in archive.files) {
      if (entry.name.startsWith('lib/') &&
          !RegExp(
            r'(\.so(?:\.\d+)*|\.dll|\.dylib)$',
            caseSensitive: false,
          ).hasMatch(entry.name)) {
        throw const FormatException(
          'Only shared libraries are allowed in lib/.',
        );
      }
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
    final selected = ModulePlatform.select(m);
    for (final variant in ModulePlatform.launches(m).entries) {
      final entry = archive.findFile(variant.value['executable'] as String);
      if (entry == null ||
          !ModulePlatform.matches(entry.content as List<int>, variant.key)) {
        throw FormatException(
          'Missing or wrong executable for ${variant.key}.',
        );
      }
    }
    final executableEntry = archive.findFile(selected['executable'] as String);
    if (executableEntry == null) {
      throw const FormatException('Packaged executable is missing.');
    }
    final binary = executableEntry.content as List<int>;
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
        final executables = archive.files
            .where((entry) {
              final bytes = entry.content as List<int>;
              return ModulePlatform.needsExecutePermission(bytes);
            })
            .map((entry) => p.join(staging.path, entry.name))
            .toList();
        if (!Platform.isWindows) {
          for (var i = 0; i < executables.length; i += 64) {
            final chmod = await Process.run('/bin/chmod', [
              '700',
              ...executables.skip(i).take(64),
            ]);
            if (chmod.exitCode != 0) {
              throw const FileSystemException(
                'Cannot set executable permission.',
              );
            }
          }
        }
        await File(p.join(staging.path, '.package.sha256')).writeAsString(hash);
        await File(p.join(staging.path, '.executable.sha256'))
            .writeAsString(sha256.convert(binary).toString());
        await File(p.join(staging.path, '.files.sha256')).writeAsString(
          jsonEncode({
            for (final entry in archive.files)
              entry.name: sha256.convert(entry.content as List<int>).toString(),
          }),
        );
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
    return (await command(installed)).executable;
  }

  Future<ModuleLaunchCommand> command(SystemModule installed) async {
    final hash = installed.localPackage;
    if (hash == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Module is not installed locally.');
    }
    final base = p.join((await directory).path, hash);
    final manifest = validateManifest(
      jsonDecode(await File(p.join(base, 'manifest.json')).readAsString()),
    );
    // The host library identity must match the immutable package's manifest.
    if (manifest['id'] != installed.id ||
        manifest['version'] != installed.version ||
        _canonicalJson(manifest) != _canonicalJson(installed.manifest)) {
      throw const FormatException(
        'Installed module metadata does not match the package.',
      );
    }
    final selected = ModulePlatform.select(manifest);
    final path = p.join(base, selected['executable'] as String);
    if (!await File(path).exists()) {
      throw const FileSystemException('Module executable is missing.');
    }
    final digest = File(p.join(base, '.executable.sha256'));
    if (!manifest.containsKey('targets') &&
        (!await digest.exists() ||
            await digest.readAsString() !=
                (await sha256.bind(File(path).openRead()).first).toString())) {
      throw const FileSystemException(
        'Installed executable is damaged. Install a new package version.',
      );
    }
    final files = File(p.join(base, '.files.sha256'));
    if (await files.exists()) {
      final hashes = jsonDecode(await files.readAsString()) as Map;
      for (final entry in hashes.entries) {
        if (!safePath(entry.key)) {
          throw const FormatException('Invalid installed file index.');
        }
        final file = File(p.join(base, entry.key as String));
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
                FileSystemEntityType.file ||
            (await sha256.bind(file.openRead()).first).toString() !=
                entry.value) {
          throw const FileSystemException(
            'Installed package is damaged. Reinstall it.',
          );
        }
      }
    } else if (manifest['runtime'] == 'process-v1') {
      throw const FileSystemException(
        'Packaged runtime integrity index is missing.',
      );
    }
    if (!ModulePlatform.matches(await File(path).readAsBytes(), ModulePlatform.current)) {
      throw const FormatException('Installed executable does not match the host ABI.');
    }
    return ModuleLaunchCommand(
      path,
      List<String>.from(selected['arguments'] as List),
      base,
    );
  }

  static String _canonicalJson(dynamic value) {
    dynamic sorted(dynamic item) {
      if (item is Map) {
        final keys = item.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: sorted(item[key])};
      }
      return item is List ? item.map(sorted).toList() : item;
    }

    return jsonEncode(sorted(value));
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
