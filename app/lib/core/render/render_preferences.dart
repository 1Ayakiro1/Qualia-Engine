import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled display policy. Acquisition and processing clocks are not
/// changed by these values: they only control how much work the UI commits.
enum RenderBackend { auto, skia, impeller }

enum RenderQuality { low, balanced, high }

class RenderPreferences {
  const RenderPreferences({
    this.backend = RenderBackend.auto,
    this.quality = RenderQuality.balanced,
    this.frameRate = 0,
  });

  static const _key = 'render_preferences_v1';
  final RenderBackend backend;
  final RenderQuality quality;

  /// 0 follows the display's native refresh timing. Other values are a UI
  /// commit cap and never pretend to change the monitor refresh rate.
  final int frameRate;

  static Future<RenderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return RenderPreferences();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RenderPreferences(
        backend: RenderBackend.values.firstWhere(
          (value) => value.name == map['backend'],
          orElse: () => RenderBackend.auto,
        ),
        quality: RenderQuality.values.firstWhere(
          (value) => value.name == map['quality'],
          orElse: () => RenderQuality.balanced,
        ),
        frameRate: _validFrameRate(map['frameRate']),
      );
    } catch (_) {
      return RenderPreferences();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'backend': backend.name,
        'quality': quality.name,
        'frameRate': frameRate,
      }),
    );
    // Linux chooses the renderer before Dart starts. Store only this small
    // startup setting separately; GTK reads it before creating FlView.
    if (Platform.isLinux) {
      final config =
          Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME']}/.config';
      final file = File('$config/com.ayakiro.bci_engine/render-backend');
      await file.parent.create(recursive: true);
      final staging = File('${file.path}.tmp');
      await staging.writeAsString(backend.name, flush: true);
      await staging.rename(file.path);
    }
  }

  RenderPreferences copyWith({
    RenderBackend? backend,
    RenderQuality? quality,
    int? frameRate,
  }) => RenderPreferences(
    backend: backend ?? this.backend,
    quality: quality ?? this.quality,
    frameRate: _validFrameRate(frameRate ?? this.frameRate),
  );

  static int _validFrameRate(Object? value) {
    final rate = value is num && value.isFinite ? value.toInt() : 0;
    return const [0, 30, 60, 90, 120, 144, 165, 240].contains(rate) ? rate : 0;
  }
}
