import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import 'module_registry.dart';

/// CRUD for the signed-in user's module drafts in Supabase.
class ModuleRepository {
  ModuleRepository({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  final AuthService _auth;

  SupabaseClient get _client => Supabase.instance.client;

  /// Published metadata only. Reading a manifest does not install or execute
  /// its package; package verification remains a separate host concern.
  Future<List<SystemModule>> listPublishedPage({
    required int offset,
    int limit = 24,
  }) async {
    if (!_auth.isInitialized) return const [];
    final rows = await _client
        .from('modules')
        .select(
          '*, module_releases(id, version, manifest, published_at, review_state)',
        )
        .eq('review_state', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _publishedModules(rows);
  }

  Future<List<SystemModule>> findPublishedByIds(List<String> ids) async {
    if (!_auth.isInitialized || ids.isEmpty) return const [];
    final modules = <SystemModule>[];
    // Bound query size for imported presets, which support up to 500 IDs.
    for (var offset = 0; offset < ids.length; offset += 50) {
      final rows = await _client
          .from('modules')
          .select(
            '*, module_releases(id, version, manifest, published_at, review_state)',
          )
          .eq('review_state', 'published')
          .inFilter('slug', ids.skip(offset).take(50).toList());
      modules.addAll(_publishedModules(rows));
    }
    return modules;
  }

  List<SystemModule> _publishedModules(List<dynamic> rows) {
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      final releases =
          (json['module_releases'] as List? ?? [])
              .whereType<Map>()
              .where((release) => release['review_state'] == 'published')
              .toList()
            ..sort(
              (a, b) => (b['published_at'] as String? ?? '').compareTo(
                a['published_at'] as String? ?? '',
              ),
            );
      if (releases.isNotEmpty) {
        json['version'] = releases.first['version'];
        json['manifest'] = releases.first['manifest'];
        json['release_id'] = releases.first['id'];
      }
      return SystemModule.fromJson(json);
    }).toList();
  }

  Future<List<SystemModule>> listMine() async {
    if (!_auth.isInitialized || _auth.currentUser == null) {
      return const <SystemModule>[];
    }
    final rows = await _client
        .from('modules')
        .select(
          'id, slug, author_id, name, summary, description, category, review_state, created_at',
        )
        .eq('kind', 'user')
        .eq('author_id', _auth.currentUser!.id)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SystemModule.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SystemModule> saveDraft(SystemModule module) async {
    if (!_auth.isInitialized) {
      throw StateError('Supabase Auth is unavailable.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in with GitHub before creating a module.');
    }

    final payload = <String, dynamic>{
      'slug': module.id,
      'kind': 'user',
      'author_id': user.id,
      'publisher': null,
      'name': module.name,
      'summary': module.summary,
      'description': module.description,
      'category': module.category,
    };
    final Map<String, dynamic> saved;
    if (module.databaseId == null) {
      payload['review_state'] = 'draft';
      saved = await _client.from('modules').insert(payload).select().single();
    } else {
      saved = await _client
          .from('modules')
          .update(<String, dynamic>{
            'slug': module.id,
            'name': module.name,
            'summary': module.summary,
            'description': module.description,
            'category': module.category,
          })
          .eq('id', module.databaseId!)
          .eq('author_id', user.id)
          .select()
          .single();
    }
    return SystemModule.fromJson(saved);
  }

  Future<void> delete(SystemModule module) async {
    if (!_auth.isInitialized || _auth.currentUser == null) {
      throw StateError('Sign in with GitHub to manage your modules.');
    }
    if (module.databaseId == null) return;
    if (module.reviewState != 'draft' && module.reviewState != 'rejected') {
      throw StateError('Only unpublished module drafts can be removed.');
    }
    await _client
        .from('modules')
        .delete()
        .eq('id', module.databaseId!)
        .eq('author_id', _auth.currentUser!.id);
  }
}
