import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/debug_terminal_app.dart';
import 'core/logging/debug_terminal_launcher.dart';
import 'core/logging/log_entry.dart';

Future<RandomAccessFile?> _acquireDebugTerminalLock() async {
  final File lockFile = LogLocations.debugTerminalLockFile();
  try {
    await lockFile.parent.create(recursive: true);
    final RandomAccessFile handle = await lockFile.open(
      mode: FileMode.writeOnlyAppend,
    );
    try {
      await handle.lock(FileLock.exclusive);
      await handle.setPosition(0);
      await handle.truncate(0);
      await handle.writeString('$pid\n');
      return handle;
    } catch (_) {
      await handle.close();
      return null;
    }
  } catch (_) {
    return null;
  }
}

/// Main entrypoint. `--debug-terminal` starts an independent native window.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool debugTerminal = args.contains('--debug-terminal');
  final bool withDebugTerminal = args.contains('--with-debug-terminal');

  if (debugTerminal) {
    final RandomAccessFile? lockHandle = await _acquireDebugTerminalLock();
    if (lockHandle == null) {
      return;
    }
    try {
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: Size(900, 620),
          minimumSize: Size(620, 360),
          center: true,
          title: 'Ayakiro Debug Terminal',
          titleBarStyle: TitleBarStyle.hidden,
        ),
        () async {
          await windowManager.show();
          await windowManager.focus();
        },
      );
    } catch (error) {
      await lockHandle.close();
      debugPrint('debug terminal window unavailable: $error');
      return;
    }
    runApp(DebugTerminalApp(lockHandle: lockHandle));
    return;
  }

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
  if (withDebugTerminal) {
    await DebugTerminalLauncher.launch();
  }
  runApp(const ProviderScope(child: BciApp()));
}
