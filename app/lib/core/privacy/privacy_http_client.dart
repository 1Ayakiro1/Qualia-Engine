import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../logging/app_logger.dart';
import 'privacy_preferences.dart';

/// Application-owned HTTPS egress. Never logs URL queries, headers or values.
/// Module processes and process-v1 TCP are separate trust boundaries.
class PrivacyHttpClient extends http.BaseClient {
  PrivacyHttpClient({
    http.Client? inner,
    Future<void> Function(Map<String, Object?>)? audit,
  }) : _inner = inner ?? http.Client(),
       _audit = audit ?? appendAudit;

  final http.Client _inner;
  final Future<void> Function(Map<String, Object?>) _audit;
  static int _sequence = 0;

  static Future<void> appendAudit(Map<String, Object?> event) async {
    final file = File('${LogLocations.sessionLogDir().path}/outbound.jsonl');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(event)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static Future<void> auditBrowserLaunch(Uri url) async {
    PrivacyPreferences.instance.requireExternalConsent();
    await appendAudit({
      'time': DateTime.now().toUtc().toIso8601String(),
      'phase': 'browser-handoff',
      'destination': url.origin,
      'category': 'oauth',
      'fields': ['provider', 'redirect_to', 'code_challenge'],
    });
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final privacy = PrivacyPreferences.instance;
    privacy.requireExternalConsent();
    if (request.url.scheme != 'https') {
      throw StateError('External application requests require HTTPS.');
    }
    final bytes = await request.finalize().toBytes();
    final fields = <String>{...request.url.queryParameters.keys};
    try {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is Map) fields.addAll(body.keys.whereType<String>());
      if (body is List) {
        for (final item in body.whereType<Map>()) {
          fields.addAll(item.keys.whereType<String>());
        }
      }
    } on FormatException {
      /* Non-JSON bodies are audited by size only. */
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final event = <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'id': id,
      'destination': request.url.origin,
      // Only service route categories, never arbitrary author paths or tokens.
      'category': request.url.path.startsWith('/auth/')
          ? 'auth'
          : request.url.path.startsWith('/rest/')
          ? 'catalog'
          : 'resource',
      'method': request.method,
      'bodyBytes': bytes.length,
      'fields': fields
          .where(
            (key) => RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$').hasMatch(key),
          )
          .take(64)
          .toList(),
    };
    // Fail closed when audit storage is unavailable. Attempts are not successes.
    await _audit({...event, 'phase': 'attempt'});
    privacy.requireExternalConsent();
    final outgoing = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes
      ..followRedirects = false;
    try {
      final response = await _inner.send(outgoing);
      await _audit({
        ...event,
        'phase': 'response',
        'status': response.statusCode,
      });
      return response;
    } catch (_) {
      await _audit({...event, 'phase': 'failed'});
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
