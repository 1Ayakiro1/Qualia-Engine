import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/debug_terminal_app.dart';
import 'core/logging/debug_terminal_launcher.dart';
import 'core/logging/log_entry.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/supabase_config.dart';
import 'features/modules/module_window_app.dart';

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

  if (args.contains('--module-window')) {
    try {
      final index = args.indexOf('--module-window');
      final port = int.parse(args[index + 1]);
      final token = args[index + 2];
      if (port < 1 ||
          port > 65535 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
        throw const FormatException('Invalid module window session');
      }
      final socket = await WebSocket.connect('ws://127.0.0.1:$port/$token');
      // Keep one subscription: updates arriving during native initialization
      // stay buffered instead of disappearing between broadcast listeners.
      final messages = StreamIterator<dynamic>(socket);
      if (!await messages.moveNext().timeout(const Duration(seconds: 10))) {
        throw const FormatException('Module window host disconnected');
      }
      final initial =
          jsonDecode(messages.current as String) as Map<String, dynamic>;
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        WindowOptions(
          size: const Size(960, 700),
          minimumSize: const Size(480, 360),
          center: true,
          title: '${(initial['node'] as Map)['module']['name']} — Qualia',
          titleBarStyle: TitleBarStyle.normal,
        ),
        () async {
          await windowManager.show();
          await windowManager.focus();
        },
      );
      runApp(
        ModuleWindowApp(socket: socket, messages: messages, initial: initial),
      );
    } catch (error) {
      debugPrint('Module window unavailable: $error');
      exit(1);
    }
    return;
  }

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
  try {
    await AuthService.instance.initialize();
    await _handleAuthCallbackArguments(args);
  } catch (error) {
    AppLogger.instance.log(
      LogSource.profile,
      'Supabase Auth недоступен: $error',
      level: LogLevel.warning,
    );
  }
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.log(
      LogSource.flutter,
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

/// GTK forwards a registered URI scheme as a command-line argument when the
/// desktop application is launched for an OAuth callback. Consume it here as
/// well as listening for live links, since Linux can start a fresh process.
Future<void> _handleAuthCallbackArguments(List<String> args) async {
  if (!AuthService.instance.isInitialized) return;
  for (final argument in args) {
    final uri = Uri.tryParse(argument);
    if (uri == null ||
        uri.scheme != Uri.parse(SupabaseConfig.oauthRedirect).scheme ||
        uri.host != 'auth' ||
        uri.path != '/callback') {
      continue;
    }
    await AuthService.instance.handleOAuthCallback(uri);
    return;
  }
}
