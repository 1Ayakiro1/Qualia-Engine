/// Application-wide constants: name, version, identifiers.
class AppInfo {
  const AppInfo._();

  static const String appName = 'Ayakiro BCI Engine';
  static const String appId = 'com.ayakiro.bci_engine';
  static const String version = '0.2.7';
  static const String stage = 'skeleton + log-console';
  static const String organization = 'Ayakiro';

  /// Expected ABI of libbci_engine_core (must match BCI_CORE_ABI_VERSION).
  static const int expectedCoreAbi = 2;
}
