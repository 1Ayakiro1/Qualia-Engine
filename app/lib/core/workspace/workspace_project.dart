import 'workspace_model.dart';

/// Immutable lineage metadata for a workspace package.
///
/// It is intentionally separate from the graph itself: a fork changes the
/// project id/name but keeps an auditable link to the exact parent package.
class WorkspaceRevision {
  const WorkspaceRevision({
    required this.revision,
    this.parentRevision,
    this.parentDigest,
    this.kind = 'snapshot',
    this.createdAt,
    this.packageDigest,
  });

  final String revision;
  final String? parentRevision;
  final String? parentDigest;
  final String kind;
  final String? createdAt;
  final String? packageDigest;

  Map<String, dynamic> toJson() => {
    'revision': revision,
    if (parentRevision != null) 'parentRevision': parentRevision,
    if (parentDigest != null) 'parentDigest': parentDigest,
    'kind': kind,
    if (createdAt != null) 'createdAt': createdAt,
    if (packageDigest != null) 'packageDigest': packageDigest,
  };

  factory WorkspaceRevision.fromJson(dynamic value) {
    if (value is! Map || value['revision'] is! String) {
      throw const FormatException('Invalid workspace revision.');
    }
    final revision = value['revision'] as String;
    if (revision.isEmpty || revision.length > 256) {
      throw const FormatException('Invalid workspace revision.');
    }
    return WorkspaceRevision(
      revision: revision,
      parentRevision: value['parentRevision'] as String?,
      parentDigest: value['parentDigest'] as String?,
      kind: value['kind'] as String? ?? 'snapshot',
      createdAt: value['createdAt'] as String?,
      packageDigest: value['packageDigest'] as String?,
    );
  }
}

/// Independent graph document. Catalog/library preferences remain host-global.
class WorkspaceProject {
  const WorkspaceProject({
    required this.id,
    required this.name,
    this.description = '',
    this.nodes = const [],
    this.links = const [],
    this.presetModuleIds,
    this.revision,
  });
  final String id, name, description;
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final List<String>? presetModuleIds;
  final WorkspaceRevision? revision;
  WorkspaceProject copyWith({
    String? name,
    String? description,
    List<WorkspaceNode>? nodes,
    List<WorkspaceLink>? links,
    List<String>? presetModuleIds,
    bool clearPreset = false,
    WorkspaceRevision? revision,
    bool clearRevision = false,
  }) => WorkspaceProject(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    nodes: nodes ?? this.nodes,
    links: links ?? this.links,
    presetModuleIds: clearPreset
        ? null
        : presetModuleIds ?? this.presetModuleIds,
    revision: clearRevision ? null : revision ?? this.revision,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'links': links.map((l) => l.toJson()).toList(),
    'presetModuleIds': presetModuleIds,
    if (revision != null) 'revision': revision!.toJson(),
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
      revision: json.containsKey('revision')
          ? WorkspaceRevision.fromJson(json['revision'])
          : null,
    );
  }

  /// Values are declarative only. Installing executable packages is a separate
  /// trusted installation operation; module references are resolved by the host.
  Map<String, dynamic> toPackage() {
    final project = toJson()..remove('revision');
    return {
      'format': 'qualia-workspace',
      'version': 1,
      'project': project,
      if (revision != null) 'revision': revision!.toJson(),
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
  }

  static WorkspaceProject fromPackage(Map<String, dynamic> json) {
    if (json['format'] != 'qualia-workspace' ||
        json['version'] != 1 ||
        json['project'] is! Map) {
      throw const FormatException('Unsupported workspace package.');
    }
    final project = WorkspaceProject.fromJson(
      Map<String, dynamic>.from(json['project'] as Map),
    );
    if (json['revision'] is Map) {
      return project.copyWith(
        revision: WorkspaceRevision.fromJson(json['revision']),
      );
    }
    return project;
  }
}
