import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/log_entry.dart';

/// Main entrypoint. The debug terminal is rendered inside the main shell.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // window_manager may be missing in edge cases (plugin not registered for
  // this engine) — degrade gracefully instead of crashing the window.
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Ayakiro BCI Engine');
    await windowManager.setMinimumSize(const Size(760, 480));
  } catch (e) {
    debugPrint('window_manager недоступен: $e');
  }

  try {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  } catch (e) {
    debugPrint('не удалось скрыть системную панель окна: $e');
  }
  await AppLogger.instance.init();
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.log(
      'flutter',
      'неперехваченная ошибка: ${details.exceptionAsString()}',
      level: LogLevel.error,
    );
    FlutterError.presentError(details);
  };
  runApp(const ProviderScope(child: BciApp()));
}
