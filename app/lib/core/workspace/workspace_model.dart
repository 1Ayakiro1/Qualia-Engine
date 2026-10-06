import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../modules/module_registry.dart';

/// Stable host-owned color groups; never stored in author parameters.
enum WorkspaceNodeColor {
  none,
  red,
  orange,
  yellow,
  green,
  blue,
  purple;

  static WorkspaceNodeColor fromJson(dynamic value) =>
      values.where((color) => color.name == value).firstOrNull ?? none;
}

/// Host-owned port annotations; independent of manifest IDs and parameters.
enum WorkspacePortType {
  any,
  string,
  number,
  boolean,
  list,
  object;

  static WorkspacePortType fromJson(dynamic value) =>
      values.where((type) => type.name == value).firstOrNull ?? any;
}

/// Host-owned graph. Module instances are distinct from catalog entries.
class WorkspaceNode {
  WorkspaceNode({
    required this.id,
    required this.module,
    this.position = const Offset(80, 80),
    double width = defaultWidth,
    double? height,
    List<String>? inputs,
    List<String>? outputs,
    Map<String, dynamic>? settings,
    this.headerColor = WorkspaceNodeColor.none,
    Map<String, WorkspaceNodeColor>? inputColors,
    Map<String, WorkspaceNodeColor>? outputColors,
    Map<String, String>? inputLabels,
    Map<String, String>? outputLabels,
    Map<String, WorkspacePortType>? inputTypes,
    Map<String, WorkspacePortType>? outputTypes,
  }) : inputs = inputs ?? ['input'],
       outputs = outputs ?? ['output'],
       inputColors = inputColors ?? {},
       outputColors = outputColors ?? {},
       inputLabels = inputLabels ?? {},
       outputLabels = outputLabels ?? {},
       inputTypes = inputTypes ?? {},
       outputTypes = outputTypes ?? {},
       settings = settings ?? {},
       width = width.isFinite ? width.clamp(minWidth, maxSize) : defaultWidth,
       preferredHeight = height != null && height.isFinite
           ? height.clamp(0, maxSize)
           : 0;
  final String id;
  SystemModule module;
  Offset position;
  WorkspaceNodeColor headerColor;
  final Map<String, WorkspaceNodeColor> inputColors;
  final Map<String, WorkspaceNodeColor> outputColors;
  final Map<String, String> inputLabels;
  final Map<String, String> outputLabels;
  final Map<String, WorkspacePortType> inputTypes;
  final Map<String, WorkspacePortType> outputTypes;
  String portLabel(String port, bool output) =>
      (output ? outputLabels : inputLabels)[port] ?? port;
  WorkspacePortType portType(String port, bool output) =>
      (output ? outputTypes : inputTypes)[port] ?? WorkspacePortType.any;
  WorkspaceNodeColor portColor(String port, bool output) =>
      (output ? outputColors : inputColors)[port] ?? WorkspaceNodeColor.none;
  static const defaultWidth = 300.0;
  static const minWidth = 280.0;
  static const maxSize = 2000.0;
  static const headerHeight = 44.0;
  static const portsTopPadding = 8.0;
  static const portRowHeight = 32.0;
  double width;
  double preferredHeight;
  final List<String> inputs;
  final List<String> outputs;
  final Map<String, dynamic> settings;

  /// Volatile runtime output, never saved into a workspace or author settings.
  final Map<String, dynamic> runtimeValues = {};
  String? runtimeStatus;
  // Minimum size follows the port count; manual height never clips new ports.
  double get minHeight =>
      144 + math.max(inputs.length, outputs.length) * portRowHeight;
  double get height => math.max(minHeight, preferredHeight);
  void resize(Size size) {
    if (!size.width.isFinite || !size.height.isFinite) return;
    width = size.width.clamp(minWidth, maxSize);
    preferredHeight = size.height.clamp(minHeight, maxSize);
  }

  Offset portPosition(String port, bool output) =>
      position +
      Offset(
        output ? width - 6 : 6,
        1 +
            headerHeight +
            portsTopPadding +
            portRowHeight / 2 +
            (output ? outputs : inputs).indexOf(port) * portRowHeight,
      );
  Map<String, dynamic> toJson({bool includeRuntime = false}) => {
    'id': id,
    'module': module.toWorkspaceJson(),
    'x': position.dx,
    'y': position.dy,
    'width': width,
    'height': preferredHeight,
    'inputs': inputs,
    'outputs': outputs,
    'settings': settings,
    if (includeRuntime) 'runtimeValues': runtimeValues,
    if (includeRuntime) 'runtimeStatus': runtimeStatus,
    'headerColor': headerColor.name,
    'inputColors': inputColors.map((port, color) => MapEntry(port, color.name)),
    'outputColors': outputColors.map(
      (port, color) => MapEntry(port, color.name),
    ),
    'inputLabels': inputLabels,
    'outputLabels': outputLabels,
    'inputTypes': inputTypes.map((port, type) => MapEntry(port, type.name)),
    'outputTypes': outputTypes.map((port, type) => MapEntry(port, type.name)),
  };
  factory WorkspaceNode.fromJson(Map<String, dynamic> json) {
    final node = WorkspaceNode(
      id: json['id'] as String,
      module: SystemModule.fromJson(
        Map<String, dynamic>.from(json['module'] as Map),
      ),
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      width: (json['width'] as num?)?.toDouble() ?? defaultWidth,
      height: (json['height'] as num?)?.toDouble(),
      inputs: List<String>.from(json['inputs'] as List),
      outputs: List<String>.from(json['outputs'] as List),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      headerColor: WorkspaceNodeColor.fromJson(json['headerColor']),
      inputColors: _portColorsFromJson(json['inputColors']),
      outputColors: _portColorsFromJson(json['outputColors']),
      inputLabels: _portLabelsFromJson(json['inputLabels']),
      outputLabels: _portLabelsFromJson(json['outputLabels']),
      inputTypes: _portTypesFromJson(json['inputTypes']),
      outputTypes: _portTypesFromJson(json['outputTypes']),
    );
    if (json['runtimeValues'] is Map) {
      node.runtimeValues.addAll(
        Map<String, dynamic>.from(json['runtimeValues'] as Map),
      );
    }
    node.runtimeStatus = json['runtimeStatus'] as String?;
    return node;
  }

  static Map<String, WorkspaceNodeColor> _portColorsFromJson(dynamic json) =>
      json is Map
      ? {
          for (final entry in json.entries)
            if (entry.key is String)
              entry.key as String: WorkspaceNodeColor.fromJson(entry.value),
        }
      : {};

  static Map<String, String> _portLabelsFromJson(dynamic json) => json is Map
      ? {
          for (final entry in json.entries)
            if (entry.key is String &&
                entry.value is String &&
                (entry.value as String).trim().isNotEmpty)
              entry.key as String: (entry.value as String).trim(),
        }
      : {};

  static Map<String, WorkspacePortType> _portTypesFromJson(dynamic json) =>
      json is Map
      ? {
          for (final entry in json.entries)
            if (entry.key is String)
              entry.key as String: WorkspacePortType.fromJson(entry.value),
        }
      : {};
}

class WorkspaceLink {
  const WorkspaceLink({
    required this.source,
    required this.output,
    required this.target,
    required this.input,
  });
  final String source;
  final String output;
  final String target;
  final String input;
  Map<String, dynamic> toJson() => {
    'source': source,
    'output': output,
    'target': target,
    'input': input,
  };
  factory WorkspaceLink.fromJson(Map<String, dynamic> json) => WorkspaceLink(
    source: json['source'] as String,
    output: json['output'] as String,
    target: json['target'] as String,
    input: json['input'] as String,
  );
}

class WorkspacePreset {
  const WorkspacePreset({
    required this.id,
    required this.name,
    required this.moduleIds,
  });
  final String id;
  final String name;
  final List<String> moduleIds;
  Map<String, dynamic> toJson() => {
    'format': 'qualia-workspace-preset',
    'version': 1,
    'id': id,
    'name': name,
    'modules': moduleIds,
  };
  factory WorkspacePreset.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'qualia-workspace-preset' || json['version'] != 1) {
      throw const FormatException('Unsupported workspace preset format.');
    }
    final name = (json['name'] as String? ?? '').trim();
    if (name.isEmpty || json['modules'] is! List) {
      throw const FormatException(
        'A preset needs a name and a list of module IDs.',
      );
    }
    final ids = List<String>.from(json['modules'] as List)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.length > 500) {
      throw const FormatException('A preset supports up to 500 modules.');
    }
    return WorkspacePreset(
      id:
          (json['id'] as String?) ??
          'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      moduleIds: ids,
    );
  }
}

/// Validates structural edges before they can enter the graph.
String? validateWorkspaceLink(
  List<WorkspaceNode> nodes,
  List<WorkspaceLink> links,
  WorkspaceLink next,
) {
  final source = nodes.where((node) => node.id == next.source).firstOrNull;
  final target = nodes.where((node) => node.id == next.target).firstOrNull;
  if (source == null || target == null) return 'A module is missing.';
  if (source.id == target.id) return 'A module cannot connect to itself.';
  if (!source.outputs.contains(next.output) ||
      !target.inputs.contains(next.input)) {
    return 'A port is missing.';
  }
  final visited = <String>{};
  bool reachesSource(String id) {
    if (id == next.source) return true;
    if (!visited.add(id)) return false;
    return links
        .where(
          (link) =>
              link.source == id &&
              !(link.target == next.target && link.input == next.input),
        )
        .any((link) => reachesSource(link.target));
  }

  if (reachesSource(next.target)) {
    return 'This connection would create a processing cycle.';
  }
  return null;
}
