import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/log_entry.dart';
import 'core/logging/log_window.dart';

/// Main entrypoint. The detached log console is the same binary running as a
/// second engine: desktop_multi_window passes `log_console` via
/// [WindowController.fromCurrentEngine] (NOT via main() args), so we check it.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // window_manager may be missing in edge cases (plugin not registered for
  // this engine) — degrade gracefully instead of crashing the window.
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('BCI Engine — Консоль логов');
    await windowManager.setMinimumSize(const Size(760, 480));
  } catch (e) {
    debugPrint('window_manager недоступен: $e');
  }

  String windowArgs = args.contains('log_console') ? 'log_console' : '';
  try {
    final WindowController controller =
        await WindowController.fromCurrentEngine();
    if (controller.arguments.isNotEmpty) {
      windowArgs = controller.arguments;
    }
  } catch (_) {
    // Main window before any multi-window registration — ignore.
  }

  if (windowArgs == 'log_console') {
    runApp(const LogConsoleApp());
    return;
  }
  await AppLogger.instance.init();
  // Smoke/CI hook: open the log console automatically so automated runs can
  // verify the second-window path without synthesizing mouse clicks.
  if (Platform.environment['BCI_OPEN_LOG_CONSOLE'] == '1') {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        await openLogConsole();
      } catch (e) {
        AppLogger.instance.log('app', 'smoke: консоль не открылась: $e',
            level: LogLevel.error);
      }
    });
  }
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

