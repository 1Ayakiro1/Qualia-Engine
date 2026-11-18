import 'dart:convert';

/// Versioned codec for the on-disk workspace document.
///
/// The recovery copy in SharedPreferences and the per-project files use the
/// same envelope. Keeping migrations here means import, recovery and normal
/// file loading cannot silently drift apart.
class WorkspaceDocumentSchema {
  const WorkspaceDocumentSchema._();

  static const currentVersion = 1;

  static Map<String, dynamic> encode(Map<String, dynamic> document) => {
    ...document,
    'schemaVersion': currentVersion,
  };

  static Map<String, dynamic> decode(Object value) {
    final map = value is String
        ? jsonDecode(value) as Map
        : value as Map;
    return migrate(Map<String, dynamic>.from(map));
  }

  static Map<String, dynamic> migrate(Map<String, dynamic> document) {
    var version = (document['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version > currentVersion) {
      throw const FormatException('Workspace document is from a newer version.');
    }
    var result = Map<String, dynamic>.from(document);
    for (final migration in _migrations.where((item) => item.from >= version)) {
      result = migration.apply(result);
      version = migration.to;
    }
    result['schemaVersion'] = currentVersion;
    return result;
  }

  static final List<_Migration> _migrations = [
    _Migration(0, 1, (document) {
      // v0 was the implicit preferences format. No fields are renamed yet;
      // recording the explicit version is the important first migration.
      return document;
    }),
  ];
}

class _Migration {
  const _Migration(this.from, this.to, this.apply);
  final int from;
  final int to;
  final Map<String, dynamic> Function(Map<String, dynamic>) apply;
}
