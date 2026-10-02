import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/modules/module_registry.dart';
import '../core/workspace/workspace_model.dart';
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
  });
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final List<SystemModule> library;
  final List<WorkspacePreset> presets;
  final List<String>? presetModuleIds;
  final bool loaded;
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
  );
}

class WorkspaceController extends Notifier<WorkspaceState> {
  Timer? _saveTimer;
  bool _disposed = false;
  static const storageKey = 'qualia.workspace.v1';
  @override
  WorkspaceState build() {
    ref.onDispose(() {
      _disposed = true;
      _saveTimer?.cancel();
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
        state = state.copyWith(loaded: true);
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
    } catch (error) {
      if (!_disposed) state = state.copyWith(loaded: true);
      logW(LogSource.modules, 'Workspace could not be restored: $error');
    }
  }

  void _changed() {
    state = state.copyWith(nodes: [...state.nodes], links: [...state.links]);
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_save()),
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
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json);
    } catch (error) {
      logW(LogSource.modules, 'Workspace could not be saved: $error');
    }
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

  void replaceNode(String id, SystemModule module) {
    final node = state.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null) return;
    node.module = module;
    node.settings.clear();
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
    node.settings[key] = value;
    _changed();
  }

  void addToLibrary(SystemModule module) {
    state = state.copyWith(
      library: [...state.library.where((old) => old.id != module.id), module],
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
