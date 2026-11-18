import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../modules/module_registry.dart';
import '../logic/logic_blocks.dart';
import 'workspace_id.dart';

enum WorkspaceNodeKind { module, logic }

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
    this.kind = WorkspaceNodeKind.module,
    this.logicType = LogicBlockType.condition,
    this.position = const Offset(80, 80),
    double width = defaultWidth,
    double? height,
    List<String>? inputs,
    List<String>? outputs,
    Map<String, dynamic>? settings,
    this.headerColor = WorkspaceNodeColor.none,
    this.fullyHidden = false,
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
       width = width.isFinite
           ? width.clamp(
               kind == WorkspaceNodeKind.logic &&
                       logicType == LogicBlockType.junction
                   ? 28
                   : minWidth,
               maxSize,
             )
           : (kind == WorkspaceNodeKind.logic &&
                     logicType == LogicBlockType.junction
                 ? 28
                 : defaultWidth),
       preferredHeight = height != null && height.isFinite
           ? height.clamp(0, maxSize)
           : 0;
  final String id;
  final WorkspaceNodeKind kind;
  final LogicBlockType logicType;
  bool get isLogic => kind == WorkspaceNodeKind.logic;
  bool get isJunction => isLogic && logicType == LogicBlockType.junction;
  SystemModule module;
  Offset position;
  WorkspaceNodeColor headerColor;

  /// Host-owned canvas visibility, never an author/module parameter.
  bool fullyHidden;
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

  /// Short-lived numeric series for custom module charts. Never persisted.
  final Map<String, List<double>> runtimeHistory = {};
  String? runtimeStatus;
  // Minimum size follows the port count; manual height never clips new ports.
  double get minHeight => isJunction
      ? 28
      : 144 + math.max(inputs.length, outputs.length) * portRowHeight;
  double get height => math.max(minHeight, preferredHeight);
  void resize(Size size) {
    if (!size.width.isFinite || !size.height.isFinite) return;
    width = size.width.clamp(isJunction ? 28 : minWidth, maxSize);
    preferredHeight = size.height.clamp(minHeight, maxSize);
  }

  Offset portPosition(String port, bool output) => isJunction
      ? position + Offset(width / 2, height / 2)
      : position +
            Offset(
              output ? width : 0,
              1 +
                  headerHeight +
                  portsTopPadding +
                  portRowHeight / 2 +
                  (output ? outputs : inputs).indexOf(port) * portRowHeight,
            );
  Map<String, dynamic> toJson({bool includeRuntime = false}) => {
    'id': id,
    'kind': kind.name,
    if (isLogic) 'logicType': logicType.name,
    'module': module.toWorkspaceJson(),
    'x': position.dx,
    'y': position.dy,
    'width': width,
    'height': preferredHeight,
    'inputs': inputs,
    'outputs': outputs,
    'settings': settings,
    if (includeRuntime) 'runtimeValues': runtimeValues,
    if (includeRuntime) 'runtimeHistory': runtimeHistory,
    if (includeRuntime) 'runtimeStatus': runtimeStatus,
    'headerColor': headerColor.name,
    if (fullyHidden) 'fullyHidden': true,
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
    if (json['kind'] != null && !['module', 'logic'].contains(json['kind'])) {
      throw const FormatException('Unknown workspace node kind.');
    }
    final isLogic = json['kind'] == 'logic';
    final logicType = LogicBlockType.values
        .where((t) => t.name == json['logicType'])
        .firstOrNull;
    if (isLogic && logicType == null) {
      throw const FormatException('Unknown logic block.');
    }
    final node = WorkspaceNode(
      id: json['id'] as String,
      kind: isLogic ? WorkspaceNodeKind.logic : WorkspaceNodeKind.module,
      logicType: logicType ?? LogicBlockType.condition,
      module: isLogic
          ? LogicBlocks.module(logicType!)
          : SystemModule.fromJson(
              Map<String, dynamic>.from(json['module'] as Map),
            ),
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      width: (json['width'] as num?)?.toDouble() ?? defaultWidth,
      height: (json['height'] as num?)?.toDouble(),
      inputs: isLogic ? ['input'] : List<String>.from(json['inputs'] as List),
      outputs: isLogic
          ? LogicBlocks.outputs(logicType!)
          : List<String>.from(json['outputs'] as List),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      headerColor: WorkspaceNodeColor.fromJson(json['headerColor']),
      inputColors: _portColorsFromJson(json['inputColors']),
      outputColors: _portColorsFromJson(json['outputColors']),
      inputLabels: _portLabelsFromJson(json['inputLabels']),
      outputLabels: _portLabelsFromJson(json['outputLabels']),
      inputTypes: _portTypesFromJson(json['inputTypes']),
      outputTypes: _portTypesFromJson(json['outputTypes']),
    );
    node.fullyHidden = json['fullyHidden'] == true;
    if (json['runtimeValues'] is Map) {
      node.runtimeValues.addAll(
        Map<String, dynamic>.from(json['runtimeValues'] as Map),
      );
    }
    if (json['runtimeHistory'] is Map) {
      for (final entry in (json['runtimeHistory'] as Map).entries) {
        if (entry.key is String && entry.value is List) {
          node.runtimeHistory[entry.key as String] = (entry.value as List)
              .whereType<num>()
              .map((value) => value.toDouble())
              .take(240)
              .toList();
        }
      }
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

/// Host-owned freehand markup drawn over a workspace graph. It is separate
/// from module settings and never participates in runtime execution.
class WorkspaceAnnotation {
  const WorkspaceAnnotation({
    required this.id,
    required this.points,
    this.color = 0xFFE7E7E7,
    this.width = 3,
  });

  final String id;
  final List<Offset> points;
  final int color;
  final double width;

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final point in points) [point.dx, point.dy],
    ],
    'color': color,
    'width': width,
  };

  factory WorkspaceAnnotation.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List? ?? const [];
    if (rawPoints.length > 10000) {
      throw const FormatException('Workspace annotation is too large.');
    }
    final points = <Offset>[];
    for (final raw in rawPoints) {
      if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
        throw const FormatException('Invalid workspace annotation point.');
      }
      final point = Offset(
        (raw[0] as num).toDouble(),
        (raw[1] as num).toDouble(),
      );
      if (!point.dx.isFinite || !point.dy.isFinite) {
        throw const FormatException('Invalid workspace annotation point.');
      }
      points.add(point);
    }
    final width = (json['width'] as num?)?.toDouble() ?? 3;
    if (width <= 0 || !width.isFinite) {
      throw const FormatException('Invalid workspace annotation width.');
    }
    return WorkspaceAnnotation(
      id: json['id'] as String? ?? WorkspaceId.create('annotation'),
      points: points,
      color: (json['color'] as num?)?.toInt() ?? 0xFFE7E7E7,
      width: width.clamp(1, 32).toDouble(),
    );
  }
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
      id: (json['id'] as String?) ?? WorkspaceId.create('preset'),
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
