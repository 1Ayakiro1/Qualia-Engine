import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'workspace_project.dart';
import 'workspace_document_schema.dart';
import 'workspace_isolate_codec.dart';

class WorkspaceArchiveContents {
  const WorkspaceArchiveContents({
    required this.project,
    this.hiddenNodeIds = const {},
    this.hiddenModuleIds = const {},
    this.moduleActiveOverrides = const {},
    this.removedModuleIds = const {},
    this.showLogicBlocks = true,
    this.showModuleBlocks = true,
  });

  final WorkspaceProject project;
  final Set<String> hiddenNodeIds;
  final Set<String> hiddenModuleIds;
  final Map<String, bool> moduleActiveOverrides;
  final Set<String> removedModuleIds;
  final bool showLogicBlocks;
  final bool showModuleBlocks;
}

/// Portable workspace document.
///
/// A workspace folder contains a manifest and readable JSON documents. The ZIP
/// representation uses exactly the same paths, so a workspace can either be
/// inspected as a directory or moved as one archive file.
class WorkspaceArchive {
  const WorkspaceArchive._();

  static const format = 'qualia-workspace-folder';
  static const version = 1;

  /// Public single-file representation (.qwork); identical to the directory
  /// contract below. Encoding/validation runs off the main isolate.
  static Future<List<int>> encodeAsync(
    WorkspaceProject project, {
    Set<String> hiddenNodeIds = const {},
    Set<String> hiddenModuleIds = const {},
    Map<String, bool> moduleActiveOverrides = const {},
    Set<String> removedModuleIds = const {},
    bool showLogicBlocks = true,
    bool showModuleBlocks = true,
  }) {
    // Build only transfer-safe JSON on the UI isolate. ZIP compression and
    // pretty-printing stay in the worker; rebuilding WorkspaceProject there
    // would pull dart:ui geometry across an isolate boundary.
    final files = _files(
      project,
      hiddenNodeIds: hiddenNodeIds,
      hiddenModuleIds: hiddenModuleIds,
      moduleActiveOverrides: moduleActiveOverrides,
      removedModuleIds: removedModuleIds,
      showLogicBlocks: showLogicBlocks,
      showModuleBlocks: showModuleBlocks,
    );
    return Isolate.run(() => _encodeFiles(files));
  }

  static Future<WorkspaceArchiveContents> decodeAsync(List<int> bytes) async {
    // ZIP decompression and JSON parsing happen away from the UI isolate;
    // model validation stays here because WorkspaceProject owns Flutter
    // geometry values and host module objects.
    final files = await Isolate.run(() => _decodeFileMaps(bytes));
    return _decodeFiles(files);
  }

  static List<int> encode(
    WorkspaceProject project, {
    Set<String> hiddenNodeIds = const {},
    Set<String> hiddenModuleIds = const {},
    Map<String, bool> moduleActiveOverrides = const {},
    Set<String> removedModuleIds = const {},
    bool showLogicBlocks = true,
    bool showModuleBlocks = true,
  }) {
    return _encodeFiles(_files(
      project,
      hiddenNodeIds: hiddenNodeIds,
      hiddenModuleIds: hiddenModuleIds,
      moduleActiveOverrides: moduleActiveOverrides,
      removedModuleIds: removedModuleIds,
      showLogicBlocks: showLogicBlocks,
      showModuleBlocks: showModuleBlocks,
    ));
  }

  static List<int> _encodeFiles(Map<String, dynamic> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      _addJson(archive, entry.key, entry.value);
    }
    return ZipEncoder().encode(archive)!;
  }

  /*
   * Kept as a single helper so the synchronous compatibility API and the
   * isolate-backed API use exactly the same archive contract.
   */
  static Map<String, dynamic> _decodeFileMaps(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, dynamic>{};
    for (final path in _paths) {
      final file = archive.findFile(path);
      if (file == null) {
        if (path == 'workspace/state.json') continue;
        throw FormatException('Workspace archive lacks $path.');
      }
      files[path] = _readJson(archive, path);
    }
    return files;
  }

  /// Writes the same format as an ordinary directory using a staging folder,
  /// so a partially written workspace is never presented as complete.
  static Future<void> writeDirectory(
    Directory directory,
    WorkspaceProject project, {
    Set<String> hiddenNodeIds = const {},
    Set<String> hiddenModuleIds = const {},
    Map<String, bool> moduleActiveOverrides = const {},
    Set<String> removedModuleIds = const {},
    bool showLogicBlocks = true,
    bool showModuleBlocks = true,
  }) async {
    final staging = Directory(
      p.join(
        directory.parent.path,
        '.${p.basename(directory.path)}.staging-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await staging.create(recursive: true);
    try {
      for (final entry in _files(
        project,
        hiddenNodeIds: hiddenNodeIds,
        hiddenModuleIds: hiddenModuleIds,
        moduleActiveOverrides: moduleActiveOverrides,
        removedModuleIds: removedModuleIds,
        showLogicBlocks: showLogicBlocks,
        showModuleBlocks: showModuleBlocks,
      ).entries) {
        await _writeJsonFile(
          File(p.join(staging.path, entry.key)),
          entry.value,
        );
      }
      if (await directory.exists()) await directory.delete(recursive: true);
      await staging.rename(directory.path);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  static Future<WorkspaceProject> decodeDirectory(Directory directory) async =>
      (await decodeDirectoryContents(directory)).project;

  static Future<WorkspaceArchiveContents> decodeDirectoryContents(
    Directory directory, {
    bool parseOffMainIsolate = true,
  }
  ) async {
    if (!await directory.exists()) {
      throw const FormatException('Workspace directory does not exist.');
    }
    final files = <String, dynamic>{};
    for (final path in _paths) {
      final file = File(p.join(directory.path, path));
      if (path == 'workspace/state.json' && !await file.exists()) continue;
      files[path] = await _readJsonFile(
        file,
        path,
        parseOffMainIsolate: parseOffMainIsolate,
      );
    }
    return _decodeFiles(files);
  }

  static bool looksLikeArchive(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
      (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);

  static WorkspaceProject decode(List<int> bytes) =>
      decodeContents(bytes).project;

  static WorkspaceArchiveContents decodeContents(List<int> bytes) {
    return _decodeFiles(_decodeFileMaps(bytes));
  }

  static const _paths = [
    'manifest.json',
    'workspace/project.json',
    'workspace/entities.json',
    'workspace/variables.json',
    'workspace/state.json',
  ];

  static Map<String, dynamic> _files(
    WorkspaceProject project, {
    required Set<String> hiddenNodeIds,
    required Set<String> hiddenModuleIds,
    required Map<String, bool> moduleActiveOverrides,
    required Set<String> removedModuleIds,
    required bool showLogicBlocks,
    required bool showModuleBlocks,
  }) => {
    'manifest.json': {
      'format': format,
      'version': version,
      'schemaVersion': WorkspaceDocumentSchema.currentVersion,
      'workspaceId': project.id,
      'name': project.name,
      'files': {
        'project': 'workspace/project.json',
        'entities': 'workspace/entities.json',
        'variables': 'workspace/variables.json',
        'state': 'workspace/state.json',
      },
    },
    'workspace/project.json': project.toPackage(),
    'workspace/entities.json': [
      for (final node in project.nodes)
        {
          'id': node.id,
          'kind': node.kind.name,
          if (node.isLogic) 'logicType': node.logicType.name,
          'name': node.module.name,
          'module': {
            'slug': node.module.id,
            'version': node.module.version,
            'releaseId': node.module.releaseId,
          },
        },
    ],
    'workspace/variables.json': [
      for (final node in project.nodes)
        {'entityId': node.id, 'values': node.settings},
    ],
    'workspace/state.json': {
      'hiddenNodeIds': hiddenNodeIds.toList(),
      'hiddenModuleIds': hiddenModuleIds.toList(),
      'moduleActiveOverrides': moduleActiveOverrides,
      'removedModuleIds': removedModuleIds.toList(),
      'showLogicBlocks': showLogicBlocks,
      'showModuleBlocks': showModuleBlocks,
    },
  };

  static WorkspaceArchiveContents _decodeFiles(Map<String, dynamic> files) {
    final manifest = files['manifest.json'];
    if (manifest is! Map ||
        manifest['format'] != format ||
        manifest['version'] != version) {
      throw const FormatException('Unsupported workspace archive.');
    }
    final entities = files['workspace/entities.json'];
    final variables = files['workspace/variables.json'];
    if (entities is! List || variables is! List) {
      throw const FormatException('Invalid workspace entity files.');
    }
    final state = files['workspace/state.json'];
    final stateMap = state is Map ? state : const <String, dynamic>{};
    return WorkspaceArchiveContents(
      project: WorkspaceProject.fromPackage(
        Map<String, dynamic>.from(files['workspace/project.json'] as Map),
      ),
      hiddenNodeIds: (stateMap['hiddenNodeIds'] as List? ?? [])
          .whereType<String>()
          .toSet(),
      hiddenModuleIds: (stateMap['hiddenModuleIds'] as List? ?? [])
          .whereType<String>()
          .toSet(),
      moduleActiveOverrides: {
        for (final entry
            in (stateMap['moduleActiveOverrides'] as Map? ?? {}).entries)
          if (entry.key is String && entry.value is bool)
            entry.key as String: entry.value as bool,
      },
      removedModuleIds: (stateMap['removedModuleIds'] as List? ?? [])
          .whereType<String>()
          .toSet(),
      showLogicBlocks: stateMap['showLogicBlocks'] != false,
      showModuleBlocks: stateMap['showModuleBlocks'] != false,
    );
  }

  static void _addJson(Archive archive, String path, Object value) {
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(value),
    );
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static Future<void> _writeJsonFile(File file, Object value) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      await WorkspaceIsolateCodec.encodeJson(value),
      flush: true,
    );
  }

  static Future<dynamic> _readJsonFile(
    File file,
    String path, {
    bool parseOffMainIsolate = true,
  }) async {
    if (!await file.exists()) {
      throw FormatException('Workspace directory lacks $path.');
    }
    try {
      final source = await file.readAsString();
      return parseOffMainIsolate
          ? await WorkspaceIsolateCodec.decodeJson(source)
          : jsonDecode(source);
    } catch (_) {
      throw FormatException('Invalid JSON in $path.');
    }
  }

  static dynamic _readJson(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) throw FormatException('Workspace archive lacks $path.');
    try {
      return jsonDecode(utf8.decode(file.content as List<int>));
    } catch (_) {
      throw FormatException('Invalid JSON in $path.');
    }
  }
}
