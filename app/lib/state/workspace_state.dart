import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/modules/module_registry.dart';
import '../core/modules/module_runtime.dart';
import '../core/workspace/workspace_model.dart';
import '../core/workspace/workspace_project.dart';
import '../core/workspace/workspace_id.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_entry.dart';
import '../core/logic/logic_blocks.dart';

class WorkspaceState {
  const WorkspaceState({
    this.nodes = const [],
    this.links = const [],
    this.annotations = const [],
    this.library = const [],
    this.presets = const [],
    this.presetModuleIds,
    this.moduleActiveOverrides = const {},
    this.hiddenModuleIds = const {},
    this.removedModuleIds = const {},
    this.showLogicBlocks = true,
    this.showModuleBlocks = true,
    this.authorMetadata = const {},
    this.loaded = false,
    this.projects = const [],
    this.activeProjectId = 'default',
    this.canvasWidth = WorkspaceProject.defaultCanvasWidth,
    this.canvasHeight = WorkspaceProject.defaultCanvasHeight,
  });
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final List<WorkspaceAnnotation> annotations;
  final List<SystemModule> library;
  final List<WorkspacePreset> presets;
  final List<String>? presetModuleIds;
  final bool loaded;
  final List<WorkspaceProject> projects;
  final String activeProjectId;
  final double canvasWidth, canvasHeight;

  /// Host-owned module state. A missing entry follows the catalog's default.
  final Map<String, bool> moduleActiveOverrides;
  final Set<String> hiddenModuleIds;
  final Set<String> removedModuleIds;
  final bool showLogicBlocks, showModuleBlocks;
  WorkspaceProject get activeProject =>
      projects.where((p) => p.id == activeProjectId).firstOrNull ??
      WorkspaceProject(
        id: activeProjectId,
        name: 'Workspace',
        nodes: nodes,
        links: links,
        annotations: annotations,
        presetModuleIds: presetModuleIds,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );
  final Map<String, Map<String, dynamic>> authorMetadata;
  WorkspaceState copyWith({
    List<WorkspaceNode>? nodes,
    List<WorkspaceLink>? links,
    List<WorkspaceAnnotation>? annotations,
    List<SystemModule>? library,
    List<WorkspacePreset>? presets,
    List<String>? presetModuleIds,
    Map<String, Map<String, dynamic>>? authorMetadata,
    bool clearPreset = false,
    bool? loaded,
    List<WorkspaceProject>? projects,
    String? activeProjectId,
    double? canvasWidth,
    double? canvasHeight,
    Map<String, bool>? moduleActiveOverrides,
    Set<String>? hiddenModuleIds,
    Set<String>? removedModuleIds,
    bool? showLogicBlocks,
    bool? showModuleBlocks,
  }) => WorkspaceState(
    nodes: nodes ?? this.nodes,
    links: links ?? this.links,
    annotations: annotations ?? this.annotations,
    library: library ?? this.library,
    presets: presets ?? this.presets,
    authorMetadata: authorMetadata ?? this.authorMetadata,
    presetModuleIds: clearPreset
        ? null
        : presetModuleIds ?? this.presetModuleIds,
    loaded: loaded ?? this.loaded,
    projects: projects ?? this.projects,
    activeProjectId: activeProjectId ?? this.activeProjectId,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
    moduleActiveOverrides: moduleActiveOverrides ?? this.moduleActiveOverrides,
    hiddenModuleIds: hiddenModuleIds ?? this.hiddenModuleIds,
    removedModuleIds: removedModuleIds ?? this.removedModuleIds,
    showLogicBlocks: showLogicBlocks ?? this.showLogicBlocks,
    showModuleBlocks: showModuleBlocks ?? this.showModuleBlocks,
  );
}

class WorkspaceController extends Notifier<WorkspaceState> {
  Timer? _saveTimer;
  bool _disposed = false;
  late final ModuleRuntime _runtime;
  static const storageKey = 'qualia.workspace.v1';
  final List<String> _undo = [];
  final List<String> _redo = [];
  String? _lastDocument;
  String? _savedDocument;
  final Set<String> _namedProjects = {};
  int historyNotice = 0;
  bool lastHistoryWasRedo = false;
  static const savedStorageKey = 'qualia.workspace.saved.v1';
  Future<void> _persistence = Future.value();

  Future<void> _persist(Future<void> Function() write) {
    final next = _persistence.then((_) => write());
    // A failed disk write must not poison later save attempts.
    _persistence = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  // Recovery is automatic; an explicit save is a separate user checkpoint.
  String _progress(String document) {
    final json = jsonDecode(document) as Map<String, dynamic>;
    return jsonEncode(json['projects']);
  }

  bool get hasUnsavedChanges =>
      _lastDocument != null &&
      _savedDocument != null &&
      _progress(_lastDocument!) != _progress(_savedDocument!);

  bool needsProjectName(String id) => !_namedProjects.contains(id);

  Future<void> saveProgress() async {
    _saveTimer?.cancel();
    final document = _document();
    await _persist(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, document) ||
          !await prefs.setString(savedStorageKey, document)) {
        throw StateError('Workspace could not be saved.');
      }
      _savedDocument = document;
    });
    if (!_disposed) state = state.copyWith();
  }

  Future<void> discardProgress() async {
    final saved = _savedDocument;
    if (saved == null) return;
    _saveTimer?.cancel();
    final draft = _document();
    final current = jsonDecode(draft) as Map<String, dynamic>;
    final baseline = jsonDecode(saved) as Map<String, dynamic>;
    current['projects'] = baseline['projects'];
    current['activeProjectId'] = baseline['activeProjectId'];
    current['namedProjects'] = baseline['namedProjects'];
    // Removing an Explorer package also removes its host library reference.
    // Restoring saved nodes must restore those references, but not erase newly
    // installed packages or unrelated catalog preferences.
    final requiredModules = <String>{
      for (final project in baseline['projects'] as List? ?? [])
        for (final node in (project as Map)['nodes'] as List? ?? [])
          ((node as Map)['module'] as Map)['slug'] as String,
    };
    final library = (current['library'] as List).cast<Map>();
    String identity(Map module) =>
        '${module['slug']}@${module['version']}:${module['local_package'] ?? module['release_id'] ?? ''}';
    final installed = library.map(identity).toSet();
    current['library'] = [
      ...library,
      for (final module in (baseline['library'] as List? ?? []).cast<Map>())
        if (requiredModules.contains(module['slug']) &&
            !installed.contains(identity(module)))
          module,
    ];
    current['removedModuleIds'] = (current['removedModuleIds'] as List)
        .where((id) => !requiredModules.contains(id))
        .toList();
    _restoreDocument(current);
    _changed(recordHistory: false);
    _saveTimer?.cancel();
    try {
      await _save(reportFailure: true);
      _undo.clear();
      _redo.clear();
    } catch (_) {
      _restoreDocument(jsonDecode(draft) as Map<String, dynamic>);
      _lastDocument = draft;
      _syncRuntime();
      rethrow;
    }
  }

  Future<void> flushRecovery() async {
    _saveTimer?.cancel();
    await _save(reportFailure: true);
  }

  bool _historyGroup = false;
  bool _groupRecorded = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Pointer-driven edits are one undo step, rather than one per frame.
  void beginHistoryGroup() {
    _historyGroup = true;
    _groupRecorded = false;
  }

  void endHistoryGroup() {
    _historyGroup = false;
    _groupRecorded = false;
  }

  void undo() => _restoreHistory(_undo, _redo);
  void redo() => _restoreHistory(_redo, _undo);

  void _restoreHistory(List<String> source, List<String> destination) {
    if (source.isEmpty || _lastDocument == null) return;
    lastHistoryWasRedo = identical(source, _redo);
    historyNotice++;
    endHistoryGroup();
    destination.add(_lastDocument!);
    _restoreDocument(jsonDecode(source.removeLast()) as Map<String, dynamic>);
    _changed(recordHistory: false);
  }

  @override
  WorkspaceState build() {
    _runtime = ModuleRuntime(
      onUpdate: (id, status, values) {
        if (_disposed) return;
        final node = state.nodes.where((n) => n.id == id).firstOrNull;
        if (node == null ||
            node.settings['enabled'] == false ||
            state.moduleActiveOverrides[node.module.id] == false) {
          return;
        }
        if (status == 'starting') {
          node.runtimeValues.clear();
          node.runtimeHistory.clear();
        }
        node.runtimeStatus = status;
        node.runtimeValues.addAll(values);
        for (final entry in values.entries) {
          if (entry.value is num && (entry.value as num).isFinite) {
            final series = node.runtimeHistory.putIfAbsent(entry.key, () => []);
            series.add((entry.value as num).toDouble());
            if (series.length > 240) {
              series.removeRange(0, series.length - 240);
            }
          }
        }
        state = state.copyWith(nodes: [...state.nodes]);
      },
    );
    ref.onDispose(() {
      _disposed = true;
      _saveTimer?.cancel();
      _runtime.dispose();
    });
    unawaited(_load());
    return const WorkspaceState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (_disposed) return;
      if (raw == null) {
        state = state.copyWith(
          loaded: true,
          projects: [WorkspaceProject(id: 'default', name: 'Workspace')],
        );
        _syncRuntime();
        _lastDocument = _document();
        _savedDocument = _lastDocument;
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _restoreDocument(json);
      _syncRuntime();
      _lastDocument = _document();
      _savedDocument = prefs.getString(savedStorageKey) ?? _lastDocument;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(loaded: true);
        _lastDocument = _document();
        _savedDocument = _lastDocument;
      }
      logW(LogSource.modules, 'Workspace could not be restored: $error');
    }
  }

  /// JSON snapshots deliberately omit volatile runtime values and processes.
  void _restoreDocument(Map<String, dynamic> json) {
    final nodes = (json['nodes'] as List? ?? [])
        .map(
          (item) =>
              WorkspaceNode.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final links = <WorkspaceLink>[];
    for (final item in json['links'] as List? ?? []) {
      final link = WorkspaceLink.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
      if (validateWorkspaceLink(nodes, links, link) == null) links.add(link);
    }
    final annotations = (json['annotations'] as List? ?? [])
        .map(
          (item) => WorkspaceAnnotation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final restored = WorkspaceState(
      nodes: nodes,
      links: links,
      annotations: annotations,
      canvasWidth: WorkspaceProject.parseCanvasSize(json['canvasWidth']),
      canvasHeight: WorkspaceProject.parseCanvasSize(
        json['canvasHeight'],
        fallback: WorkspaceProject.defaultCanvasHeight,
      ),
      library: (json['library'] as List? ?? [])
          .map(
            (item) =>
                SystemModule.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      presets: (json['presets'] as List? ?? [])
          .map(
            (item) => WorkspacePreset.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      presetModuleIds: json['presetModuleIds'] == null
          ? null
          : List<String>.from(json['presetModuleIds'] as List),
      moduleActiveOverrides: {
        for (final entry
            in (json['moduleActiveOverrides'] as Map? ?? {}).entries)
          if (entry.key is String && entry.value is bool)
            entry.key as String: entry.value as bool,
      },
      hiddenModuleIds: (json['hiddenModuleIds'] as List? ?? [])
          .whereType<String>()
          .toSet(),
      removedModuleIds: (json['removedModuleIds'] as List? ?? [])
          .whereType<String>()
          .toSet(),
      showLogicBlocks: json['showLogicBlocks'] != false,
      showModuleBlocks: json['showModuleBlocks'] != false,
      loaded: true,
      authorMetadata: {
        for (final entry in (json['authorMetadata'] as Map? ?? {}).entries)
          entry.key as String: Map<String, dynamic>.from(entry.value as Map),
      },
    );
    final projects = (json['projects'] as List? ?? [])
        .map(
          (p) => WorkspaceProject.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList();
    if (projects.isEmpty) {
      projects.add(restored.activeProject);
    }
    final active =
        projects.where((p) => p.id == json['activeProjectId']).firstOrNull ??
        projects.first;
    _namedProjects
      ..clear()
      ..addAll(
        (json['namedProjects'] as List?)?.whereType<String>() ??
            projects
                .where((p) => p.id != 'default' || p.name != 'Workspace')
                .map((p) => p.id),
      );
    state = restored.copyWith(
      projects: projects,
      activeProjectId: active.id,
      nodes: active.nodes,
      links: active.links,
      annotations: active.annotations,
      canvasWidth: active.canvasWidth,
      canvasHeight: active.canvasHeight,
      presetModuleIds: active.presetModuleIds,
      clearPreset: active.presetModuleIds == null,
    );
  }

  void _changed({bool recordHistory = true}) {
    final project = state.activeProject.copyWith(
      nodes: state.nodes,
      links: state.links,
      annotations: state.annotations,
      canvasWidth: state.canvasWidth,
      canvasHeight: state.canvasHeight,
      presetModuleIds: state.presetModuleIds,
      clearPreset: state.presetModuleIds == null,
    );
    state = state.copyWith(
      nodes: [...state.nodes],
      links: [...state.links],
      projects: state.projects.any((p) => p.id == project.id)
          ? [for (final p in state.projects) p.id == project.id ? project : p]
          : [...state.projects, project],
    );
    final document = _document();
    if (recordHistory && _lastDocument != null && document != _lastDocument) {
      if (!_historyGroup || !_groupRecorded) {
        _undo.add(_lastDocument!);
        if (_undo.length > 50) _undo.removeAt(0);
        _groupRecorded = true;
      }
      _redo.clear();
    }
    _lastDocument = document;
    _syncRuntime();
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_save()),
    );
  }

  void _syncRuntime() {
    for (final node in state.nodes.where(
      (n) => n.module.isLocal || n.isLogic,
    )) {
      if (node.settings['enabled'] == false ||
          state.moduleActiveOverrides[node.module.id] == false) {
        node.runtimeStatus = 'stopped';
        node.runtimeValues.clear();
        node.runtimeHistory.clear();
      } else if (node.isLogic) {
        if (node.runtimeStatus == null ||
            node.runtimeStatus == 'stopped' ||
            node.runtimeStatus == 'not installed') {
          node.runtimeStatus = 'idle';
        }
      } else if (!state.library.any(
        (m) =>
            m.localPackage == node.module.localPackage &&
            m.id == node.module.id &&
            m.version == node.module.version,
      )) {
        node.runtimeStatus = 'not installed';
        node.runtimeValues.clear();
      }
    }
    _runtime.sync(
      state.activeProjectId,
      state.nodes
          .where((node) => state.moduleActiveOverrides[node.module.id] != false)
          .toList(),
      state.links,
      state.library,
    );
  }

  String _document() => jsonEncode({
    'nodes': state.nodes.map((node) => node.toJson()).toList(),
    'links': state.links.map((link) => link.toJson()).toList(),
    'annotations': state.annotations
        .map((annotation) => annotation.toJson())
        .toList(),
    'canvasWidth': state.canvasWidth,
    'canvasHeight': state.canvasHeight,
    'library': state.library.map((module) => module.toWorkspaceJson()).toList(),
    'presets': state.presets.map((preset) => preset.toJson()).toList(),
    'presetModuleIds': state.presetModuleIds,
    'authorMetadata': state.authorMetadata,
    'projects': state.projects.map((p) => p.toJson()).toList(),
    'activeProjectId': state.activeProjectId,
    'moduleActiveOverrides': state.moduleActiveOverrides,
    'hiddenModuleIds': state.hiddenModuleIds.toList(),
    'removedModuleIds': state.removedModuleIds.toList(),
    'showLogicBlocks': state.showLogicBlocks,
    'showModuleBlocks': state.showModuleBlocks,
    'namedProjects': _namedProjects.toList(),
  });

  Future<void> _save({bool reportFailure = false}) async {
    final json = _document();
    try {
      await _persist(() async {
        final prefs = await SharedPreferences.getInstance();
        if (_savedDocument != null && !prefs.containsKey(savedStorageKey)) {
          if (!await prefs.setString(savedStorageKey, _savedDocument!)) {
            throw StateError('Workspace checkpoint could not be saved.');
          }
        }
        if (!await prefs.setString(storageKey, json)) {
          throw StateError('Workspace could not be saved.');
        }
      });
    } catch (error) {
      logW(LogSource.modules, 'Workspace could not be saved: $error');
      if (reportFailure) rethrow;
    }
  }

  String createProject(String name, {String description = ''}) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 80) {
      throw const FormatException('Invalid workspace name.');
    }
    final project = WorkspaceProject(
      id: WorkspaceId.create('workspace'),
      name: cleaned,
      description: description.trim(),
    );
    _namedProjects.add(project.id);
    state = state.copyWith(projects: [...state.projects, project]);
    switchProject(project.id);
    return project.id;
  }

  void switchProject(String id) {
    final project = state.projects.where((p) => p.id == id).firstOrNull;
    if (project == null) return;
    state = state.copyWith(
      activeProjectId: id,
      nodes: project.nodes,
      links: project.links,
      annotations: project.annotations,
      canvasWidth: project.canvasWidth,
      canvasHeight: project.canvasHeight,
      presetModuleIds: project.presetModuleIds,
      clearPreset: project.presetModuleIds == null,
    );
    _changed();
  }

  void editProject(String id, String name, String description) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 80) {
      throw const FormatException('Invalid workspace name.');
    }
    _namedProjects.add(id);
    state = state.copyWith(
      projects: [
        for (final project in state.projects)
          project.id == id
              ? project.copyWith(name: cleaned, description: description.trim())
              : project,
      ],
    );
    _changed();
  }

  void setCanvasSize({double? width, double? height}) {
    final nextWidth = width ?? state.canvasWidth;
    final nextHeight = height ?? state.canvasHeight;
    if (!nextWidth.isFinite || !nextHeight.isFinite) return;
    if (nextWidth < WorkspaceProject.minCanvasSize ||
        nextHeight < WorkspaceProject.minCanvasSize ||
        nextWidth > WorkspaceProject.maxCanvasSize ||
        nextHeight > WorkspaceProject.maxCanvasSize) {
      return;
    }
    if (nextWidth == state.canvasWidth && nextHeight == state.canvasHeight) {
      return;
    }
    state = state.copyWith(canvasWidth: nextWidth, canvasHeight: nextHeight);
    _changed();
  }

  void deleteProject(String id) {
    final remaining = state.projects.where((p) => p.id != id).toList();
    if (remaining.length == state.projects.length) return;
    if (remaining.isEmpty) {
      remaining.add(
        WorkspaceProject(
          id: WorkspaceId.create('workspace'),
          name: 'Workspace',
        ),
      );
    }
    state = state.copyWith(projects: remaining);
    if (id == state.activeProjectId) {
      final project = remaining.first;
      state = state.copyWith(
        activeProjectId: project.id,
        nodes: project.nodes,
        links: project.links,
        annotations: project.annotations,
        canvasWidth: project.canvasWidth,
        canvasHeight: project.canvasHeight,
        presetModuleIds: project.presetModuleIds,
        clearPreset: project.presetModuleIds == null,
      );
    }
    _changed();
  }

  String importProject(WorkspaceProject source, List<SystemModule> resolved) {
    final id = WorkspaceId.create('workspace');
    final ids = {
      for (var index = 0; index < source.nodes.length; index++)
        source.nodes[index].id: '$id-node-$index',
    };
    final project = WorkspaceProject.fromJson({
      ...source.toJson(),
      'id': id,
      'nodes': [
        for (final node in source.nodes) {...node.toJson(), 'id': ids[node.id]},
      ],
      'links': [
        for (final link in source.links)
          {
            ...link.toJson(),
            'source': ids[link.source],
            'target': ids[link.target],
          },
      ],
      'annotations': source.annotations
          .map((annotation) => annotation.toJson())
          .toList(),
    });
    for (final node in project.nodes) {
      if (node.isLogic) continue;
      final module = resolved
          .where(
            (m) =>
                m.id == node.module.id &&
                m.version == node.module.version &&
                (!node.module.isLocal ||
                    m.localPackage == node.module.localPackage) &&
                (node.module.releaseId == null ||
                    node.module.releaseId == m.releaseId),
          )
          .firstOrNull;
      if (module == null) {
        throw FormatException(
          'Unavailable module: ${node.module.id}@${node.module.version}',
        );
      }
      node.module = module;
    }
    final dependencies = {
      for (final module in [...state.library, ...resolved])
        '${module.id}@${module.version}:${module.localPackage ?? module.releaseId ?? ''}':
            module,
    };
    _namedProjects.add(id);
    state = state.copyWith(
      projects: [...state.projects, project],
      library: dependencies.values.toList(),
    );
    switchProject(id);
    return id;
  }

  WorkspaceNode addNode(SystemModule module, Offset position) {
    final ports = module.manifest['ports'] is Map
        ? module.manifest['ports'] as Map
        : const {};
    final node = WorkspaceNode(
      id: WorkspaceId.create('node'),
      module: module,
      position: position,
      inputs: ports['inputs'] is List
          ? (ports['inputs'] as List)
                .whereType<String>()
                .where((port) => port.trim().isNotEmpty)
                .toSet()
                .take(16)
                .toList()
          : null,
      outputs: ports['outputs'] is List
          ? (ports['outputs'] as List)
                .whereType<String>()
                .where((port) => port.trim().isNotEmpty)
                .toSet()
                .take(16)
                .toList()
          : null,
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
    _changed();
    return node;
  }

  WorkspaceNode addLogicBlock(LogicBlockType type, Offset position) {
    final node = WorkspaceNode(
      id: WorkspaceId.create('logic'),
      module: LogicBlocks.module(type),
      kind: WorkspaceNodeKind.logic,
      logicType: type,
      position: position,
      inputs: ['input'],
      outputs: LogicBlocks.outputs(type),
      settings: LogicBlocks.defaults(type),
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
    _changed();
    return node;
  }

  /// View filters never stop execution or mutate graph connections.
  void setBlockVisibility({bool? logic, bool? modules}) {
    state = state.copyWith(showLogicBlocks: logic, showModuleBlocks: modules);
    _changed();
  }

  void moveNode(String id, Offset position) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null) return;
    node.position = position;
    _changed();
  }

  /// A group drag publishes one graph update per pointer event, not per node.
  void moveNodes(Set<String> ids, Offset delta) {
    if (ids.isEmpty ||
        delta == Offset.zero ||
        !delta.dx.isFinite ||
        !delta.dy.isFinite) {
      return;
    }
    for (final node in state.nodes.where((node) => ids.contains(node.id))) {
      node.position += delta;
    }
    _changed();
  }

  void removeNode(String id) {
    removeNodes({id});
  }

  void resizeNode(String id, Size size) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null) return;
    node.resize(size);
    _changed();
  }

  void removeNodes(Set<String> ids) {
    state = state.copyWith(
      nodes: state.nodes.where((node) => !ids.contains(node.id)).toList(),
      links: state.links
          .where(
            (link) => !ids.contains(link.source) && !ids.contains(link.target),
          )
          .toList(),
    );
    _changed();
  }

  void setNodeColors(Set<String> ids, WorkspaceNodeColor color) {
    for (final node in state.nodes.where((node) => ids.contains(node.id))) {
      node.headerColor = color;
    }
    _changed();
  }

  void replaceNode(String id, SystemModule module) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || node.isLogic) return;
    node.module = module;
    node.settings.clear();
    _changed();
  }

  void setPortColor(
    String id,
    String port,
    bool output,
    WorkspaceNodeColor color,
  ) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || !(output ? node.outputs : node.inputs).contains(port)) {
      return;
    }
    final colors = output ? node.outputColors : node.inputColors;
    if (color == WorkspaceNodeColor.none) {
      colors.remove(port);
    } else {
      colors[port] = color;
    }
    _changed();
  }

  String? connect(WorkspaceLink link) {
    final error = validateWorkspaceLink(state.nodes, state.links, link);
    if (error != null) return error;
    state = state.copyWith(
      links: [
        ...state.links.where(
          (old) => !(old.target == link.target && old.input == link.input),
        ),
        link,
      ],
    );
    _changed();
    return null;
  }

  /// Rename the display label only; connections keep stable manifest port IDs.
  void setPortLabel(String id, String port, bool output, String label) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || !(output ? node.outputs : node.inputs).contains(port)) {
      return;
    }
    final labels = output ? node.outputLabels : node.inputLabels;
    final cleaned = label.trim();
    if (cleaned.isEmpty || cleaned == port) {
      labels.remove(port);
    } else {
      labels[port] = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
    }
    _changed();
  }

  void setPortType(
    String id,
    String port,
    bool output,
    WorkspacePortType type,
  ) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || !(output ? node.outputs : node.inputs).contains(port)) {
      return;
    }
    final types = output ? node.outputTypes : node.inputTypes;
    if (type == WorkspacePortType.any) {
      types.remove(port);
    } else {
      types[port] = type;
    }
    _changed();
  }

  void disconnect(WorkspaceLink link) {
    state = state.copyWith(
      links: state.links.where((old) => old != link).toList(),
    );
    _changed();
  }

  void addAnnotation(WorkspaceAnnotation annotation) {
    if (annotation.points.length < 2 || state.annotations.length >= 200) return;
    state = state.copyWith(annotations: [...state.annotations, annotation]);
    _changed();
  }

  void removeAnnotation(String id) {
    final next = state.annotations
        .where((annotation) => annotation.id != id)
        .toList();
    if (next.length == state.annotations.length) return;
    state = state.copyWith(annotations: next);
    _changed();
  }

  void clearAnnotations() {
    if (state.annotations.isEmpty) return;
    state = state.copyWith(annotations: const []);
    _changed();
  }

  void addPort(String id, bool output) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || node.isLogic) return;
    final ports = output ? node.outputs : node.inputs;
    if (ports.length >= 16) return;
    var index = ports.length + 1;
    while (ports.contains('${output ? 'output' : 'input'} $index')) {
      index++;
    }
    ports.add('${output ? 'output' : 'input'} $index');
    _changed();
  }

  void setParameter(String id, String key, dynamic value) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null || state.hiddenModuleIds.contains(node.module.id)) return;
    final fields = [
      if (node.module.manifest['parameters'] is List)
        ...node.module.manifest['parameters'] as List,
      if (node.module.manifest['ui'] is List)
        ...node.module.manifest['ui'] as List,
    ];
    final field = fields
        .whereType<Map>()
        .where((f) => f['id'] == key)
        .firstOrNull;
    if (node.module.isLocal && field?['type'] == 'button') {
      _runtime.event(id, key, value);
      return;
    }
    node.settings[key] = value;
    _changed();
  }

  void addToLibrary(SystemModule module) {
    if (module.isLocal &&
        state.library.any(
          (old) =>
              old.id == module.id &&
              (!old.isLocal ||
                  (old.version == module.version &&
                      old.localPackage != module.localPackage)),
        )) {
      throw const FormatException(
        'This ID/version already belongs to another module package. Use a new ID or version.',
      );
    }
    state = state.copyWith(
      removedModuleIds: {...state.removedModuleIds}..remove(module.id),
      library: [
        ...state.library.where(
          (old) =>
              old.id != module.id ||
              (old.isLocal && module.isLocal && old.version != module.version),
        ),
        module,
      ],
    );
    _changed();
  }

  void removeLocalModule(String id) {
    state = state.copyWith(
      library: state.library.where((m) => m.id != id).toList(),
    );
    _changed();
  }

  void setModuleActive(String id, bool active) {
    state = state.copyWith(
      moduleActiveOverrides: {...state.moduleActiveOverrides, id: active},
    );
    _changed();
  }

  /// Remove host references only; never delete an author's remote package.
  void removeWorkspaceModule(String id) {
    WorkspaceProject removeFrom(WorkspaceProject project) {
      final ids = project.nodes
          .where((n) => n.module.id == id)
          .map((n) => n.id)
          .toSet();
      return project.copyWith(
        nodes: project.nodes.where((n) => !ids.contains(n.id)).toList(),
        links: project.links
            .where((l) => !ids.contains(l.source) && !ids.contains(l.target))
            .toList(),
      );
    }

    final current = removeFrom(
      state.activeProject.copyWith(nodes: state.nodes, links: state.links),
    );
    state = state.copyWith(
      nodes: current.nodes,
      links: current.links,
      library: state.library.where((m) => m.id != id).toList(),
      projects: state.projects.map(removeFrom).toList(),
      removedModuleIds: {...state.removedModuleIds, id},
    );
    _changed();
  }

  void setModuleHidden(String id, bool hidden) {
    final ids = {...state.hiddenModuleIds};
    if (hidden) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    state = state.copyWith(hiddenModuleIds: ids);
    _changed();
  }

  void moveNodesToProject(Set<String> nodeIds, String projectId) {
    if (projectId == state.activeProjectId) return;
    final moved = state.nodes
        .where((item) => nodeIds.contains(item.id))
        .toList();
    final target = state.projects
        .where((item) => item.id == projectId)
        .firstOrNull;
    if (moved.isEmpty || target == null) return;
    if (target.nodes.length + moved.length > 500 ||
        target.nodes.any((n) => moved.any((m) => m.id == n.id))) {
      throw const FormatException(
        'Target workspace cannot accept these nodes.',
      );
    }
    final ids = moved.map((n) => n.id).toSet();
    final movedLinks = state.links
        .where((link) => ids.contains(link.source) && ids.contains(link.target))
        .toList();
    if (target.links.length + movedLinks.length > 8000) {
      throw const FormatException('Target workspace has too many connections.');
    }
    final currentNodes = state.nodes
        .where((item) => !ids.contains(item.id))
        .toList();
    final currentLinks = state.links
        .where(
          (link) => !ids.contains(link.source) && !ids.contains(link.target),
        )
        .toList();
    for (final node in moved) {
      node.runtimeValues.clear();
      node.runtimeHistory.clear();
      node.runtimeStatus = null;
    }
    final targetProject = target.copyWith(
      nodes: [...target.nodes, ...moved],
      links: [...target.links, ...movedLinks],
    );
    state = state.copyWith(
      nodes: currentNodes,
      links: currentLinks,
      projects: [
        for (final project in state.projects)
          if (project.id == state.activeProjectId)
            project.copyWith(nodes: currentNodes, links: currentLinks)
          else if (project.id == projectId)
            targetProject
          else
            project,
      ],
    );
    _changed();
  }

  void addPreset(WorkspacePreset preset) {
    state = state.copyWith(
      presets: [...state.presets.where((old) => old.id != preset.id), preset],
    );
    _changed();
  }

  List<String> loadPreset(
    WorkspacePreset preset,
    List<SystemModule> available,
  ) {
    state = state.copyWith(presetModuleIds: preset.moduleIds);
    _changed();
    return preset.moduleIds
        .where((id) => !available.any((module) => module.id == id))
        .toList();
  }

  void clearPreset() {
    state = state.copyWith(clearPreset: true);
    _changed();
  }

  void saveAuthorMetadata(String id, Map<String, dynamic> metadata) {
    state = state.copyWith(
      authorMetadata: {...state.authorMetadata, id: metadata},
    );
    for (final node in state.nodes.where(
      (node) => node.module.databaseId == id,
    )) {
      node.module = node.module.withManifest(metadata);
    }
    _changed();
  }
}

final workspaceProvider = NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);
