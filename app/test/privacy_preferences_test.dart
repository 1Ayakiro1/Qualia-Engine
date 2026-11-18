import 'dart:convert';

import 'package:bci_engine/core/privacy/privacy_http_client.dart';
import 'package:bci_engine/core/privacy/privacy_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrivacyPreferences.instance.load();
  });

  test('all opt-ins default off and survive reload independently', () async {
    final privacy = PrivacyPreferences.instance;
    expect(privacy.crashReports, isFalse);
    expect(privacy.metrics, isFalse);
    expect(privacy.externalData, isFalse);
    await privacy.setCrashReports(true);
    await privacy.setMetrics(true);
    await privacy.load();
    expect(privacy.crashReports, isTrue);
    expect(privacy.metrics, isTrue);
    expect(privacy.externalData, isFalse);
    await privacy.setExternalData(true);
    await privacy.load();
    expect(privacy.externalData, isTrue);
    await privacy.setExternalData(false);
    await privacy.load();
    expect(privacy.externalData, isFalse);
  });

  test('external requests are blocked until explicit consent', () async {
    var called = false;
    final client = PrivacyHttpClient(
      inner: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      audit: (_) async {},
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/rest/catalog')),
      throwsStateError,
    );
    expect(called, isFalse);
    client.close();
  });

  test('consented requests audit fields but never payload values', () async {
    await PrivacyPreferences.instance.setExternalData(true);
    final events = <Map<String, Object?>>[];
    final client = PrivacyHttpClient(
      inner: MockClient((request) async {
        expect(request.url.path, '/rest/catalog');
        return http.Response('{}', 200);
      }),
      audit: (event) async => events.add(event),
    );

    final response = await client.post(
      Uri.parse('https://example.test/rest/catalog'),
      body: '{"signal":"private-value","workspaceId":"workspace-1"}',
    );

    expect(response.statusCode, 200);
    expect(events.map((event) => event['phase']), contains('attempt'));
    expect(events.map((event) => event['phase']), contains('response'));
    expect(jsonEncode(events), isNot(contains('private-value')));
    expect(jsonEncode(events), isNot(contains('workspace-1')));
    expect(
      (events.first['fields'] as List<Object?>),
      containsAll(<Object?>['signal', 'workspaceId']),
    );
    expect(events.first['destination'], 'https://example.test');
    client.close();
  });

  test(
    'audit failure blocks sending; revocation while auditing also blocks',
    () async {
      final privacy = PrivacyPreferences.instance;
      await privacy.setExternalData(true);
      var sent = 0;
      final failing = PrivacyHttpClient(
        inner: MockClient((_) async {
          sent++;
          return http.Response('', 200);
        }),
        audit: (_) async => throw StateError('disk unavailable'),
      );
      await expectLater(
        failing.get(Uri.parse('https://example.test')),
        throwsStateError,
      );
      expect(sent, 0);
      failing.close();
      final revoked = PrivacyHttpClient(
        inner: MockClient((_) async {
          sent++;
          return http.Response('', 200);
        }),
        audit: (_) => privacy.setExternalData(false),
      );
      await expectLater(
        revoked.get(Uri.parse('https://example.test')),
        throwsStateError,
      );
      expect(sent, 0);
      revoked.close();
    },
  );

  test(
    'HTTP is refused and redirects cannot bypass the audit boundary',
    () async {
      await PrivacyPreferences.instance.setExternalData(true);
      final client = PrivacyHttpClient(
        inner: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.test'},
          );
        }),
        audit: (_) async {},
      );
      await expectLater(
        client.get(Uri.parse('http://example.test')),
        throwsStateError,
      );
      expect(
        (await client.get(Uri.parse('https://example.test'))).statusCode,
        302,
      );
      client.close();
    },
  );

  test('batch fields are audited without URL, header or body values', () async {
    await PrivacyPreferences.instance.setExternalData(true);
    final events = <Map<String, Object?>>[];
    final client = PrivacyHttpClient(
      inner: MockClient((_) async => http.Response('', 200)),
      audit: (event) async => events.add(event),
    );
    await client.post(
      Uri.parse('https://example.test/private-path?token=private-query'),
      headers: {'authorization': 'private-token'},
      body: '[{"name":"private-name","package":{"signal":"private-signal"}}]',
    );
    expect(events.first['fields'], containsAll(['name', 'package', 'token']));
    expect(jsonEncode(events), isNot(contains('private-')));
    client.close();
  });

  test('revoked consent blocks a previously initialized client', () async {
    final privacy = PrivacyPreferences.instance;
    await privacy.setExternalData(true);
    var sent = false;
    final client = PrivacyHttpClient(
      inner: MockClient((_) async {
        sent = true;
        return http.Response('', 200);
      }),
      audit: (_) async {},
    );
    await privacy.setExternalData(false);
    await expectLater(
      client.get(Uri.parse('https://example.test')),
      throwsStateError,
    );
    expect(sent, isFalse);
    client.close();
  });
}
