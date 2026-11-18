import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'workspace_document_schema.dart';
import 'workspace_project.dart';
import 'workspace_isolate_codec.dart';

/// File-backed workspace documents plus a small SQLite metadata index.
///
/// Graph data never goes into SQLite: one project is one JSON document. SQLite
/// only answers listing/search questions and records the latest schema/digest.
class WorkspaceDocumentStore {
  WorkspaceDocumentStore._(this.root, this._database);

  final Directory root;
  final Database _database;

  static Future<WorkspaceDocumentStore> open() async {
    // Do not silently fall back to a shared temp directory: that would make
    // independent test runs/users share a document index. Desktop startup has
    // path_provider registered; callers treat a missing channel as a safe
    // recovery-only mode.
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'qualia', 'workspaces'));
    await root.create(recursive: true);
    final database = sqlite3.open(p.join(root.path, 'index.sqlite3'));
    final store = WorkspaceDocumentStore._(root, database);
    store._migrateIndex();
    return store;
  }

  void _migrateIndex() {
    _database.execute('PRAGMA journal_mode = WAL');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        file_name TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _database.execute(
      'INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (?, ?)',
      [1, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<void> save(WorkspaceProject project) async {
    final fileName = '${_safeId(project.id)}.json';
    final target = File(p.join(root.path, fileName));
    final staging = File(
      p.join(root.path, '.$fileName.${DateTime.now().microsecondsSinceEpoch}.tmp'),
    );
    final payload = WorkspaceDocumentSchema.encode(project.toJson());
    await staging.writeAsString(
      await WorkspaceIsolateCodec.encode(payload),
      flush: true,
    );
    await staging.rename(target.path);
    _database.execute(
      '''INSERT INTO workspaces(id, name, file_name, schema_version, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET name=excluded.name,
           file_name=excluded.file_name, schema_version=excluded.schema_version,
           updated_at=excluded.updated_at''',
      [
        project.id,
        project.name,
        fileName,
        WorkspaceDocumentSchema.currentVersion,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<WorkspaceProject?> load(String id) async {
    final rows = _database.select(
      'SELECT file_name FROM workspaces WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final file = File(p.join(root.path, rows.first['file_name'] as String));
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final document = await WorkspaceIsolateCodec.decode(raw);
    return WorkspaceProject.fromJson(document);
  }

  Future<List<String>> ids() async => [
    for (final row in _database.select(
      'SELECT id FROM workspaces ORDER BY updated_at DESC',
    ))
      row['id'] as String,
  ];

  void dispose() => _database.dispose();

  static String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
