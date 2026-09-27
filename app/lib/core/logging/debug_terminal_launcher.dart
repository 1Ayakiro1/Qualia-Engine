import 'dart:io';

import 'app_logger.dart';

/// Starts the debug terminal as a separate process.
///
/// The child process uses the same executable with `--debug-terminal`. It has
/// its own Flutter engine and native window, so closing or crashing it cannot
/// block the main application. A lock in the child prevents duplicate windows.
class DebugTerminalLauncher {
  const DebugTerminalLauncher._();

  static const String argument = '--debug-terminal';

  static Future<bool> launch() async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const <String>[argument],
        workingDirectory: File(Platform.resolvedExecutable).parent.path,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (error) {
      logE('debug-terminal', 'не удалось запустить отдельное окно: $error');
      return false;
    }
  }
}
