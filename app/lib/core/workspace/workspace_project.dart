import 'workspace_model.dart';

/// Independent graph document. Catalog/library preferences remain host-global.
class WorkspaceProject {
  const WorkspaceProject({
    required this.id,
    required this.name,
    this.description = '',
    this.nodes = const [],
    this.links = const [],
    this.presetModuleIds,
  });
  final String id, name, description;
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final List<String>? presetModuleIds;
  WorkspaceProject copyWith({
    String? name,
    String? description,
    List<WorkspaceNode>? nodes,
    List<WorkspaceLink>? links,
    List<String>? presetModuleIds,
    bool clearPreset = false,
  }) => WorkspaceProject(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    nodes: nodes ?? this.nodes,
    links: links ?? this.links,
    presetModuleIds: clearPreset
        ? null
        : presetModuleIds ?? this.presetModuleIds,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'links': links.map((l) => l.toJson()).toList(),
    'presetModuleIds': presetModuleIds,
  };
  factory WorkspaceProject.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List? ?? [];
    final rawLinks = json['links'] as List? ?? [];
    if (rawNodes.length > 500 || rawLinks.length > 8000) {
      throw const FormatException('Workspace graph is too large.');
    }
    final nodes = rawNodes
        .map((n) => WorkspaceNode.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
    if (nodes.map((n) => n.id).toSet().length != nodes.length ||
        nodes.any(
          (n) =>
              !n.position.dx.isFinite ||
              !n.position.dy.isFinite ||
              n.inputs.length > 16 ||
              n.outputs.length > 16,
        )) {
      throw const FormatException('Invalid workspace nodes.');
    }
    final links = <WorkspaceLink>[];
    for (final item in rawLinks) {
      final link = WorkspaceLink.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
      if (validateWorkspaceLink(nodes, links, link) != null) {
        throw const FormatException('Invalid workspace connection.');
      }
      links.add(link);
    }
    final name = (json['name'] as String? ?? 'Workspace').trim();
    final id = json['id'] as String;
    final description = json['description'] as String? ?? '';
    if (id.isEmpty ||
        id.length > 160 ||
        description.length > 4000 ||
        name.isEmpty ||
        name.length > 80) {
      throw const FormatException('Invalid workspace name.');
    }
    return WorkspaceProject(
      id: id,
      name: name,
      description: description,
      nodes: nodes,
      links: links,
      presetModuleIds: (json['presetModuleIds'] as List?)?.cast<String>(),
    );
  }

  /// Values are declarative only. Installing executable packages is a separate
  /// trusted installation operation; module references are resolved by the host.
  Map<String, dynamic> toPackage() => {
    'format': 'qualia-workspace',
    'version': 1,
    'project': toJson(),
    'dependencies': [
      for (final module in {
        for (final n in nodes)
          if (!n.isLogic)
            '${n.module.id}@${n.module.version}:${n.module.releaseId ?? ''}':
                n.module,
      }.values)
        {
          'slug': module.id,
          'version': module.version,
          'releaseId': module.releaseId,
        },
    ],
  };
  static WorkspaceProject fromPackage(Map<String, dynamic> json) {
    if (json['format'] != 'qualia-workspace' ||
        json['version'] != 1 ||
        json['project'] is! Map) {
      throw const FormatException('Unsupported workspace package.');
    }
    return WorkspaceProject.fromJson(
      Map<String, dynamic>.from(json['project'] as Map),
    );
  }
}
