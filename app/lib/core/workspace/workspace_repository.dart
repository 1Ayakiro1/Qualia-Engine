import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../modules/module_registry.dart';
import '../modules/module_repository.dart';
import '../modules/module_preview_data.dart';
import 'workspace_project.dart';

class PublishedWorkspace {
  const PublishedWorkspace({
    required this.id,
    required this.project,
    required this.author,
    required this.license,
    this.createdAt,
  });
  final String id, author, license;
  final WorkspaceProject project;
  final DateTime? createdAt;
  factory PublishedWorkspace.fromJson(Map<String, dynamic> row) {
    final project = WorkspaceProject.fromPackage(
      Map<String, dynamic>.from(row['package'] as Map),
    );
    return PublishedWorkspace(
      id: row['id'] as String,
      project: project.copyWith(
        name: row['name'] as String,
        description: row['description'] as String?,
      ),
      author:
          (row['profiles'] as Map?)?['display_name'] as String? ?? 'Community',
      license: row['license'] as String,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }
}

class WorkspaceRepository {
  Future<List<PublishedWorkspace>> listPublishedPage({
    required int offset,
    int limit = 24,
  }) async {
    if (!AuthService.instance.isInitialized) return [];
    final rows = await Supabase.instance.client
        .from('workspace_catalog')
        // Profiles are private under RLS; public reads must not depend on a
        // join to another user's private profile.
        .select()
        .eq('review_state', 'published')
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((row) => PublishedWorkspace.fromJson(row)).toList();
  }

  Future<void> submit(
    WorkspaceProject project, {
    required String license,
  }) async {
    final auth = AuthService.instance;
    if (auth.currentUser == null) {
      throw StateError('Sign in with GitHub to submit a workspace.');
    }
    final package = project.toPackage();
    if (utf8.encode(jsonEncode(package)).length > 2 * 1024 * 1024) {
      throw const FormatException('Workspace package exceeds 2 MiB.');
    }
    WorkspaceProject.fromPackage(package);
    await Supabase.instance.client.from('workspace_catalog').insert({
      'author_id': auth.currentUser!.id,
      'name': project.name,
      'description': project.description,
      'license': license,
      'package': package,
    });
  }
}

class WorkspaceDependencyException implements Exception {
  const WorkspaceDependencyException(this.missing);
  final List<String> missing;
  @override
  String toString() => missing.join(', ');
}

/// Exact versions, with host-owned local previews. Embedded manifests are not
/// trusted as installed modules and never become executable code.
Future<List<SystemModule>> resolveWorkspaceModules(
  WorkspaceProject project,
  List<SystemModule> library, {
  ModuleRepository? repository,
}) async {
  final required = {
    for (final node in project.nodes)
      '${node.module.id}@${node.module.version}:${node.module.releaseId ?? ''}':
          node.module,
  }.values.toList();
  final available = [...previewModules, ...previewExtensions, ...library];
  final unresolved = required
      .where(
        (m) => !available.any(
          (a) =>
              a.id == m.id &&
              a.version == m.version &&
              (!m.isLocal || a.localPackage == m.localPackage) &&
              (m.releaseId == null || m.releaseId == a.releaseId),
        ),
      )
      .toList();
  if (unresolved.isNotEmpty) {
    available.addAll(
      await (repository ?? ModuleRepository()).findPublishedVersions(
        unresolved.where((m) => !m.isLocal).toList(),
      ),
    );
  }
  final resolved = <SystemModule>[];
  final missing = <String>[];
  for (final module in required) {
    final match = available
        .where(
          (a) =>
              a.id == module.id &&
              a.version == module.version &&
              (!module.isLocal || a.localPackage == module.localPackage) &&
              (module.releaseId == null || module.releaseId == a.releaseId),
        )
        .firstOrNull;
    if (match == null) {
      missing.add('${module.id}@${module.version}');
    } else {
      resolved.add(match);
    }
  }
  if (missing.isNotEmpty) throw WorkspaceDependencyException(missing);
  return resolved;
}
