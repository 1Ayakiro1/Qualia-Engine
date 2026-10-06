/// Module metadata. Local installation identity is independent of the catalog.
///
/// The name is retained while existing workspace widgets are migrated away
/// from their old local system-module stubs.
class SystemModule {
  const SystemModule({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.summary = '',
    this.version = '0.1.0',
    this.active = false,
    this.stage = 'Workspace',
    this.databaseId,
    this.authorId,
    this.reviewState = 'draft',
    this.manifest = const {},
    this.createdAt,
    this.updatedAt,
    this.publisher,
    this.releaseId,
    this.localPackage,
  });

  /// Catalog slug (unique, user-authored id).
  final String id;
  final String name;
  final String category;
  final String description;
  final String summary;
  final String version;
  final bool active;
  final String stage;
  final String? databaseId;
  final String? authorId;
  final String reviewState;
  final Map<String, dynamic> manifest;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? publisher;
  final String? releaseId;

  /// Content hash of a host-installed, explicitly trusted native package.
  final String? localPackage;
  bool get isLocal => localPackage != null;

  SystemModule withManifest(Map<String, dynamic> value) => SystemModule(
    id: id,
    name: name,
    category: category,
    description: description,
    summary: summary,
    version: version,
    active: active,
    stage: stage,
    databaseId: databaseId,
    authorId: authorId,
    reviewState: reviewState,
    manifest: value,
    createdAt: createdAt,
    updatedAt: updatedAt,
    publisher: publisher,
    releaseId: releaseId,
    localPackage: localPackage,
  );

  Map<String, dynamic> toWorkspaceJson() => {
    'slug': id,
    'name': name,
    'category': category,
    'description': description,
    'summary': summary,
    'version': version,
    'id': databaseId,
    'author_id': authorId,
    'review_state': reviewState,
    'manifest': manifest,
    'publisher': publisher,
    'release_id': releaseId,
    'local_package': localPackage,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory SystemModule.fromJson(Map<String, dynamic> json) => SystemModule(
    id: json['slug'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    description: (json['description'] as String?) ?? '',
    summary: (json['summary'] as String?) ?? '',
    active: json['review_state'] == 'published',
    databaseId: json['id'] as String?,
    authorId: json['author_id'] as String?,
    reviewState: (json['review_state'] as String?) ?? 'draft',
    version: (json['version'] as String?) ?? '0.1.0',
    manifest: Map<String, dynamic>.from(json['manifest'] as Map? ?? {}),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    publisher: json['publisher'] as String?,
    releaseId: json['release_id'] as String?,
    localPackage: json['local_package'] as String?,
  );
}
