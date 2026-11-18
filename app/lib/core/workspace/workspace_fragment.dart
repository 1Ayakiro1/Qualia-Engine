import 'dart:convert';

import 'package:flutter/painting.dart';

import 'workspace_model.dart';
import 'workspace_project.dart';

/// Detached graph snapshot for the clipboard. Only edges inside the selection
/// are included; pasting never reconnects to an unrelated existing instance.
class WorkspaceFragment {
  WorkspaceFragment._(this.project);
  final WorkspaceProject project;

  factory WorkspaceFragment.capture(
    List<WorkspaceNode> nodes,
    List<WorkspaceLink> links,
    Set<String> ids,
  ) => WorkspaceFragment._(
    WorkspaceProject.fromJson(
      jsonDecode(
        jsonEncode({
          'id': 'clipboard',
          'name': 'Clipboard',
          'nodes': [
            for (final node in nodes)
              if (ids.contains(node.id)) node.toJson(),
          ],
          'links': [
            for (final link in links)
              if (ids.contains(link.source) && ids.contains(link.target))
                link.toJson(),
          ],
        }),
      ) as Map<String, dynamic>,
    ),
  );

  Offset get origin => project.nodes.fold<Offset>(
    project.nodes.first.position,
    (origin, node) => Offset(
      origin.dx < node.position.dx ? origin.dx : node.position.dx,
      origin.dy < node.position.dy ? origin.dy : node.position.dy,
    ),
  );

  String encode() => jsonEncode({
    'format': 'qualia-workspace-fragment',
    'version': 1,
    'project': project.toJson(),
  });

  static WorkspaceFragment? decode(String? text) {
    if (text == null || text.length > 4 * 1024 * 1024) return null;
    try {
      final data = jsonDecode(text);
      if (data is! Map ||
          data['format'] != 'qualia-workspace-fragment' ||
          data['version'] != 1) {
        return null;
      }
      final project = WorkspaceProject.fromJson(
        Map<String, dynamic>.from(data['project'] as Map),
      );
      return project.nodes.isEmpty ? null : WorkspaceFragment._(project);
    } catch (_) {
      return null;
    }
  }
}
