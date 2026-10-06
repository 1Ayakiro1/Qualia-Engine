import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/modules/module_registry.dart';
import '../core/modules/module_runtime.dart';
import '../core/workspace/workspace_model.dart';
import '../core/workspace/workspace_project.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_entry.dart';

class WorkspaceState {
  const WorkspaceState({
    this.nodes = const [],
    this.links = const [],
    this.library = const [],
    this.presets = const [],
    this.presetModuleIds,
    this.authorMetadata = const {},
    this.loaded = false,
    this.projects = const [],
    this.activeProjectId = 'default',
  });
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final List<SystemModule> library;
  final List<WorkspacePreset> presets;
  final List<String>? presetModuleIds;
  final bool loaded;
  final List<WorkspaceProject> projects;
  final String activeProjectId;
  WorkspaceProject get activeProject =>
      projects.where((p) => p.id == activeProjectId).firstOrNull ??
      WorkspaceProject(
        id: activeProjectId,
        name: 'Workspace',
        nodes: nodes,
        links: links,
        presetModuleIds: presetModuleIds,
      );
  final Map<String, Map<String, dynamic>> authorMetadata;
  WorkspaceState copyWith({
    List<WorkspaceNode>? nodes,
    List<WorkspaceLink>? links,
    List<SystemModule>? library,
    List<WorkspacePreset>? presets,
    List<String>? presetModuleIds,
    Map<String, Map<String, dynamic>>? authorMetadata,
    bool clearPreset = false,
    bool? loaded,
    List<WorkspaceProject>? projects,
    String? activeProjectId,
  }) => WorkspaceState(
    nodes: nodes ?? this.nodes,
    links: links ?? this.links,
    library: library ?? this.library,
    presets: presets ?? this.presets,
    authorMetadata: authorMetadata ?? this.authorMetadata,
    presetModuleIds: clearPreset
        ? null
        : presetModuleIds ?? this.presetModuleIds,
    loaded: loaded ?? this.loaded,
    projects: projects ?? this.projects,
    activeProjectId: activeProjectId ?? this.activeProjectId,
  );
}

class WorkspaceController extends Notifier<WorkspaceState> {
  Timer? _saveTimer;
  bool _disposed = false;
  late final ModuleRuntime _runtime;
  static const storageKey = 'qualia.workspace.v1';
  @override
  WorkspaceState build() {
    _runtime = ModuleRuntime(
      onUpdate: (id, status, values) {
        if (_disposed) return;
        final node = state.nodes.where((n) => n.id == id).firstOrNull;
        if (node == null) return;
        if (status == 'starting') node.runtimeValues.clear();
        node.runtimeStatus = status;
        node.runtimeValues.addAll(values);
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
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
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
      state = WorkspaceState(
        nodes: nodes,
        links: links,
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
        loaded: true,
        authorMetadata: {
          for (final entry in (json['authorMetadata'] as Map? ?? {}).entries)
            entry.key as String: Map<String, dynamic>.from(entry.value as Map),
        },
      );
      final projects = (json['projects'] as List? ?? [])
          .map(
            (p) =>
                WorkspaceProject.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
      if (projects.isEmpty) {
        projects.add(state.activeProject);
      }
      final active =
          projects.where((p) => p.id == json['activeProjectId']).firstOrNull ??
          projects.first;
      state = state.copyWith(
        projects: projects,
        activeProjectId: active.id,
        nodes: active.nodes,
        links: active.links,
        presetModuleIds: active.presetModuleIds,
        clearPreset: active.presetModuleIds == null,
      );
      _syncRuntime();
    } catch (error) {
      if (!_disposed) state = state.copyWith(loaded: true);
      logW(LogSource.modules, 'Workspace could not be restored: $error');
    }
  }

  void _changed() {
    final project = state.activeProject.copyWith(
      nodes: state.nodes,
      links: state.links,
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
    _syncRuntime();
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_save()),
    );
  }

  void _syncRuntime() {
    for (final node in state.nodes.where((n) => n.module.isLocal)) {
      if (node.settings['enabled'] == false) {
        node.runtimeStatus = 'stopped';
        node.runtimeValues.clear();
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
      state.nodes,
      state.links,
      state.library,
    );
  }

  Future<void> _save() async {
    final json = jsonEncode({
      'nodes': state.nodes.map((node) => node.toJson()).toList(),
      'links': state.links.map((link) => link.toJson()).toList(),
      'library': state.library
          .map((module) => module.toWorkspaceJson())
          .toList(),
      'presets': state.presets.map((preset) => preset.toJson()).toList(),
      'presetModuleIds': state.presetModuleIds,
      'authorMetadata': state.authorMetadata,
      'projects': state.projects.map((p) => p.toJson()).toList(),
      'activeProjectId': state.activeProjectId,
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json);
    } catch (error) {
      logW(LogSource.modules, 'Workspace could not be saved: $error');
    }
  }

  String createProject(String name, {String description = ''}) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 80) {
      throw const FormatException('Invalid workspace name.');
    }
    final project = WorkspaceProject(
      id: 'workspace-${DateTime.now().microsecondsSinceEpoch}',
      name: cleaned,
      description: description.trim(),
    );
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

  void deleteProject(String id) {
    final remaining = state.projects.where((p) => p.id != id).toList();
    if (remaining.length == state.projects.length) return;
    if (remaining.isEmpty) {
      remaining.add(
        WorkspaceProject(
          id: 'workspace-${DateTime.now().microsecondsSinceEpoch}',
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
        presetModuleIds: project.presetModuleIds,
        clearPreset: project.presetModuleIds == null,
      );
    }
    _changed();
  }

  String importProject(WorkspaceProject source, List<SystemModule> resolved) {
    final id = 'workspace-${DateTime.now().microsecondsSinceEpoch}';
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
    });
    for (final node in project.nodes) {
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
      id: 'node-${DateTime.now().microsecondsSinceEpoch}',
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
    if (node == null) return;
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

  void addPort(String id, bool output) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null) return;
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
    if (node == null) return;
    final field = (node.module.manifest['ui'] as List? ?? const [])
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
