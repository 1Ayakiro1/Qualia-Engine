import 'dart:math';

/// Wall-clock timestamps are not unique, especially with Windows clock granularity.
/// Random 128-bit identities also survive imports and independent app sessions.
class WorkspaceId {
  static final Random _random = Random.secure();
  static String create(String prefix) =>
      '$prefix-${List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}
