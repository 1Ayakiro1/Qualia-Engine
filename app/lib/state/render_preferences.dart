import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/render/render_preferences.dart';

class RenderPreferencesController extends Notifier<RenderPreferences> {
  int _revision = 0;
  Future<void> _writes = Future<void>.value();
  @override
  RenderPreferences build() {
    _load();
    return RenderPreferences();
  }

  Future<void> _load() async {
    final revision = _revision;
    try {
      final loaded = await RenderPreferences.load();
      if (ref.mounted && revision == _revision) state = loaded;
    } catch (_) {
      /* Settings failure must not prevent the workspace opening. */
    }
  }

  Future<void> update({
    RenderBackend? backend,
    RenderQuality? quality,
    int? frameRate,
  }) async {
    _revision++;
    final next = state.copyWith(
      backend: backend,
      quality: quality,
      frameRate: frameRate,
    );
    state = next;
    _writes = _writes.catchError((Object _) {}).then((_) => next.save());
    await _writes;
  }
}

final renderPreferencesProvider =
    NotifierProvider<RenderPreferencesController, RenderPreferences>(
      RenderPreferencesController.new,
    );
