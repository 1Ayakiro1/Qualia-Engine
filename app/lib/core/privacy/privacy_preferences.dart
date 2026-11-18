import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../logging/log_entry.dart';

/// User consent for optional diagnostics and any future external adapter.
///
/// The defaults are deliberately local-only. This class is policy storage, not
/// a telemetry transport: no data leaves the process unless an adapter checks
/// these flags and the user has enabled the corresponding consent.
class PrivacyPreferences extends ChangeNotifier {
  PrivacyPreferences._();

  static final instance = PrivacyPreferences._();

  static const crashReportsKey = 'qualia.privacy.crash-reports.v1';
  static const metricsKey = 'qualia.privacy.metrics.v1';
  static const externalDataKey = 'qualia.privacy.external-data.v1';

  bool _crashReports = false;
  bool _metrics = false;
  bool _externalData = false;
  bool get crashReports => _crashReports;
  bool get metrics => _metrics;
  bool get externalData => _externalData;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _crashReports = prefs.getBool(crashReportsKey) ?? false;
    _metrics = prefs.getBool(metricsKey) ?? false;
    _externalData = prefs.getBool(externalDataKey) ?? false;
    notifyListeners();
  }

  Future<void> setCrashReports(bool value) async {
    await _save(crashReportsKey, value, 'краш-репорты');
    _crashReports = value;
    notifyListeners();
  }

  Future<void> setMetrics(bool value) async {
    await _save(metricsKey, value, 'анонимные метрики');
    _metrics = value;
    notifyListeners();
  }

  Future<void> setExternalData(bool value) async {
    // Revocation takes effect before any asynchronous disk work.
    if (!value) {
      _externalData = false;
      notifyListeners();
    }
    await _save(externalDataKey, value, 'вынос данных наружу');
    _externalData = value;
    notifyListeners();
  }

  void requireExternalConsent() {
    if (!externalData) {
      throw StateError(
        'External transfer is disabled. Enable Data privacy → Allow data outside the app first.',
      );
    }
  }

  Future<void> _save(String key, bool value, String label) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(key, value)) {
      throw StateError('Could not save privacy consent.');
    }
    logI(
      LogSource.settings,
      'политика приватности: $label ${value ? 'разрешены' : 'запрещены'}',
    );
  }
}
