import 'dart:ffi';

/// Package target IDs describe the running process ABI, not the device label.
/// An x64 app under Rosetta selects x64 payloads even on an ARM Mac.
class ModulePlatform {
  static const supported = {
    'linux-x64',
    'linux-arm64',
    'windows-x64',
    'windows-arm64',
    'macos-x64',
    'macos-arm64',
  };

  static String get current => switch (Abi.current()) {
    Abi.linuxX64 => 'linux-x64',
    Abi.linuxArm64 => 'linux-arm64',
    Abi.windowsX64 => 'windows-x64',
    Abi.windowsArm64 => 'windows-arm64',
    Abi.macosX64 => 'macos-x64',
    Abi.macosArm64 => 'macos-arm64',
    _ => throw UnsupportedError(
      'Unsupported module host ABI: ${Abi.current()}',
    ),
  };

  static Map<String, Map<String, dynamic>> launches(Map<String, dynamic> m) {
    if (m['targets'] is Map) {
      return {
        for (final entry in (m['targets'] as Map).entries)
          entry.key as String: Map<String, dynamic>.from(entry.value as Map),
      };
    }
    return {
      m['platform'] as String: m['runtime'] == 'process-v1'
          ? Map<String, dynamic>.from(m['launch'] as Map)
          : {'executable': 'bin/module', 'arguments': <String>[]},
    };
  }

  static Map<String, dynamic> select(Map<String, dynamic> m, {String? target}) {
    final platform = target ?? current;
    final variants = launches(m);
    final launch = variants[platform];
    if (launch == null) {
      throw FormatException(
        'This package has no $platform payload. Available: ${variants.keys.join(', ')}.',
      );
    }
    return launch;
  }

  static int _u16(List<int> b, int o) => b[o] | b[o + 1] << 8;
  static int _u32(List<int> b, int o, {bool big = false}) => big
      ? b[o] << 24 | b[o + 1] << 16 | b[o + 2] << 8 | b[o + 3]
      : b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;

  /// Validate format/architecture before spawning. This is NOT a security scan
  /// or an ABI/dependency check; the OS loader still validates the full binary.
  static bool matches(List<int> b, String target) {
    if (!supported.contains(target)) return false;
    final arm = target.endsWith('arm64');
    if (target.startsWith('linux-')) {
      return b.length >= 20 &&
          b[0] == 127 &&
          b[1] == 69 &&
          b[2] == 76 &&
          b[3] == 70 &&
          b[4] == 2 &&
          b[5] == 1 &&
          [2, 3].contains(_u16(b, 16)) &&
          _u16(b, 18) == (arm ? 183 : 62);
    }
    if (target.startsWith('windows-')) {
      if (b.length < 64 || b[0] != 77 || b[1] != 90) return false;
      final pe = _u32(b, 60);
      if (pe < 64 || pe + 26 > b.length || _u32(b, pe) != 0x4550) return false;
      return _u16(b, pe + 4) == (arm ? 0xaa64 : 0x8664) &&
          (_u16(b, pe + 22) & 0x2000) == 0 && // Not a DLL.
          _u16(b, pe + 24) == 0x20b; // PE32+.
    }
    final cpu = arm ? 0x0100000c : 0x01000007;
    if (b.length < 32) return false;
    final magic = _u32(b, 0);
    if (magic == 0xfeedfacf) {
      return _u32(b, 4) == cpu && _u32(b, 12) == 2; // MH_EXECUTE.
    }
    // Universal Mach-O: validate an actual matching slice, not just the table.
    final fat = _u32(b, 0, big: true);
    if (fat != 0xcafebabe && fat != 0xcafebabf) return false;
    final count = _u32(b, 4, big: true);
    final stride = fat == 0xcafebabf ? 32 : 20;
    if (count < 1 || count > 16 || 8 + count * stride > b.length) return false;
    for (var i = 0; i < count; i++) {
      final o = 8 + i * stride;
      if (_u32(b, o, big: true) != cpu) continue;
      // Current package size is <=256 MiB; high 32 bits must be zero.
      if (stride == 32 &&
          (_u32(b, o + 8, big: true) != 0 || _u32(b, o + 16, big: true) != 0)) {
        return false;
      }
      final offset = _u32(b, o + (stride == 32 ? 12 : 8), big: true);
      final size = _u32(b, o + (stride == 32 ? 20 : 12), big: true);
      if (size < 32 ||
          offset < 8 + count * stride ||
          offset + size > b.length) {
        return false;
      }
      return _u32(b, offset) == 0xfeedfacf &&
          _u32(b, offset + 4) == cpu &&
          _u32(b, offset + 12) == 2;
    }
    return false;
  }

  static bool needsExecutePermission(List<int> b) =>
      b.length >= 4 &&
      (_u32(b, 0) == 0x464c457f ||
          _u32(b, 0) == 0xfeedfacf ||
          _u32(b, 0, big: true) == 0xcafebabe ||
          _u32(b, 0, big: true) == 0xcafebabf);
}
