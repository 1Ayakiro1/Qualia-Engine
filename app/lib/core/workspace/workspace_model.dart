import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../modules/module_registry.dart';

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
  }) : inputs = inputs ?? ['input'],
       outputs = outputs ?? ['output'],
       settings = settings ?? {},
       width = width.isFinite ? width.clamp(minWidth, maxSize) : defaultWidth,
       preferredHeight = height != null && height.isFinite
           ? height.clamp(0, maxSize)
           : 0;
  final String id;
  SystemModule module;
  Offset position;
  static const defaultWidth = 300.0;
  static const minWidth = 280.0;
  static const maxSize = 2000.0;
  static const headerHeight = 44.0;
  static const categoryHeight = 24.0;
  static const portRowHeight = 32.0;
  double width;
  double preferredHeight;
  final List<String> inputs;
  final List<String> outputs;
  final Map<String, dynamic> settings;
  // Minimum size follows the port count; manual height never clips new ports.
  double get minHeight =>
      160 + math.max(inputs.length, outputs.length) * portRowHeight;
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
            categoryHeight +
            portRowHeight / 2 +
            (output ? outputs : inputs).indexOf(port) * portRowHeight,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'module': module.toWorkspaceJson(),
    'x': position.dx,
    'y': position.dy,
    'width': width,
    'height': preferredHeight,
    'inputs': inputs,
    'outputs': outputs,
    'settings': settings,
  };
  factory WorkspaceNode.fromJson(Map<String, dynamic> json) => WorkspaceNode(
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
  );
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
