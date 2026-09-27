import 'dart:io';

import 'package:flutter/foundation.dart';

import 'log_entry.dart';

/// Resolves the per-user directory for session log files (pure dart:io,
/// no plugins required so the log console window stays dependency-light).
class LogLocations {
  const LogLocations._();

  static Directory appDataDir() {
    if (Platform.isWindows) {
      final String base =
          Platform.environment['APPDATA'] ??
          '${Platform.environment['USERPROFILE'] ?? '.'}\\AppData\\Roaming';
      return Directory('$base\\com.ayakiro.bci_engine');
    }
    if (Platform.isMacOS) {
      final String home = Platform.environment['HOME'] ?? '.';
      return Directory(
        '$home/Library/Application Support/com.ayakiro.bci_engine',
      );
    }
    final String? xdg = Platform.environment['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return Directory('$xdg/bci_engine');
    }
    final String home = Platform.environment['HOME'] ?? '.';
    return Directory('$home/.local/share/bci_engine');
  }

  static Directory sessionLogDir({Directory? override}) => Directory(
    '${(override ?? appDataDir()).path}${Platform.pathSeparator}logs',
  );

  /// File tailed by the log console window. Rewritten on every app start.
  static File latestFile({Directory? override}) => File(
    '${sessionLogDir(override: override).path}${Platform.pathSeparator}latest.log',
  );

  /// Process lock held by the standalone debug terminal window.
  static File debugTerminalLockFile({Directory? override}) => File(
    '${(override ?? appDataDir()).path}${Platform.pathSeparator}debug-terminal.lock',
  );

  static String sessionFileName(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'session-${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}.log';
  }
}

/// Global application logger.
///
/// - Keeps a capped in-memory ring buffer (shown nowhere in the main window).
/// - Appends every entry to `logs/latest.log` plus a per-run `session-*.log`.
/// - The in-app debug terminal tails `latest.log` from disk, keeping the
///   visible console independent from the logger's in-memory ring buffer.
class AppLogger extends ChangeNotifier {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int defaultCapacity = 5000;

  final List<LogEntry> _entries = <LogEntry>[];
  int maxEntries = defaultCapacity;

  /// When false, entries are kept in memory but NOT appended to the file.
  /// Toggled from the log console ("Запись в файл").
  bool recording = true;

  IOSink? _sink;
  File? currentSessionFile;
  File? latestFile;
  bool _initialized = false;

  bool get initialized => _initialized;

  List<LogEntry> snapshot() => List<LogEntry>.unmodifiable(_entries);

  int get length => _entries.length;

  Future<void> init({Directory? overrideDir}) async {
    if (_initialized) {
      return;
    }
    try {
      final Directory dir = LogLocations.sessionLogDir(override: overrideDir);
      await dir.create(recursive: true);
      final DateTime now = DateTime.now();
      currentSessionFile = File(
        '${dir.path}${Platform.pathSeparator}${LogLocations.sessionFileName(now)}',
      );
      await currentSessionFile!.create();
      latestFile = LogLocations.latestFile(override: overrideDir);
      // Fresh file for this app run; the console window tails exactly it.
      _sink = latestFile!.openWrite(mode: FileMode.write);
      _sink!.writeln('# Ayakiro BCI Engine — session log, started $now');
      await currentSessionFile!.writeAsString(
        '# Ayakiro BCI Engine — session log, started $now\n',
      );
    } catch (e) {
      // Logging must never crash the app: fall back to memory-only mode.
      debugPrint('AppLogger: file sink unavailable: $e');
      _sink = null;
    }
    _initialized = true;
    log('app', 'приложение запущено (Platform: ${Platform.operatingSystem})');
  }

  void log(String source, String message, {LogLevel level = LogLevel.info}) {
    final LogEntry entry = LogEntry(
      time: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
    if (recording && _sink != null) {
      try {
        _sink!.writeln(entry.formatted);
        currentSessionFile?.writeAsStringSync(
          '${entry.formatted}\n',
          mode: FileMode.append,
        );
      } catch (e) {
        debugPrint('AppLogger: write failed: $e');
      }
    }
  }

  void setRecording(bool value) {
    if (recording == value) {
      return;
    }
    recording = value;
    log(
      'app',
      value
          ? 'запись лога в файл продолжена'
          : 'запись лога в файл приостановлена',
    );
  }

  /// Copies the current `latest.log` to [targetPath]. Returns the target file.
  Future<File> saveCopyTo(String targetPath) async {
    final File? src = latestFile;
    if (src == null || !await src.exists()) {
      throw StateError('файл лога ещё не создан');
    }
    await _sink?.flush();
    return src.copy(targetPath);
  }

  Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (e) {
      debugPrint('AppLogger: flush failed: $e');
    }
  }

  Future<void> close() async {
    log('app', 'приложение завершается');
    await flush();
    try {
      await _sink?.close();
    } catch (e) {
      debugPrint('AppLogger: close failed: $e');
    }
    _sink = null;
  }
}

// Convenience shortcuts used across the app.
void logD(String source, String message) =>
    AppLogger.instance.log(source, message, level: LogLevel.debug);
void logI(String source, String message) =>
    AppLogger.instance.log(source, message, level: LogLevel.info);
void logW(String source, String message) =>
    AppLogger.instance.log(source, message, level: LogLevel.warning);
void logE(String source, String message) =>
    AppLogger.instance.log(source, message, level: LogLevel.error);
