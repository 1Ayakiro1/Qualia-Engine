import 'dart:convert';
import 'dart:isolate';

import 'workspace_document_schema.dart';

/// JSON work is deliberately performed in a worker isolate. The isolate only
/// handles JSON/schema data, so no Flutter objects or mutable workspace state
/// cross the boundary.
class WorkspaceIsolateCodec {
  const WorkspaceIsolateCodec._();

  static Future<Map<String, dynamic>> decode(String source) async {
    final result = await Isolate.run(() {
      final decoded = jsonDecode(source);
      return WorkspaceDocumentSchema.decode(decoded);
    });
    return Map<String, dynamic>.from(result);
  }

  static Future<String> encode(Map<String, dynamic> document) => Isolate.run(
    () => const JsonEncoder.withIndent('  ').convert(
      WorkspaceDocumentSchema.encode(document),
    ),
  );

  static Future<String> encodeJson(Object value) => Isolate.run(
    () => const JsonEncoder.withIndent('  ').convert(value),
  );

  static Future<dynamic> decodeJson(String source) =>
      Isolate.run(() => jsonDecode(source));
}
