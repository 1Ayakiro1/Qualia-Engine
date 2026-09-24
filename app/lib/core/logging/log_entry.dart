import 'package:flutter/foundation.dart';

/// Severity of a log entry. Ordered from the most verbose to the most severe.
enum LogLevel { debug, info, warning, error }

extension LogLevelX on LogLevel {
  /// Fixed-width tag used in the text format, e.g. `[INFO ]`.
  String get tag {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'Отладка';
      case LogLevel.info:
        return 'Инфо';
      case LogLevel.warning:
        return 'Предупреждения';
      case LogLevel.error:
        return 'Ошибки';
    }
  }

  static LogLevel? fromTag(String tag) {
    switch (tag.trim()) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARN':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      default:
        return null;
    }
  }
}

/// One line of the application log.
///
/// Text format (also written to the session log file):
/// `[2026-09-24T15:30:01.123] [INFO ] [app     ] движок стартовал`
@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final String source;
  final String message;

  /// Human-readable single line.
  String get formatted {
    final String ts = time.toIso8601String();
    final String src = source.length > 9 ? source.substring(0, 9) : source.padRight(9);
    final String oneLine = message.replaceAll('\n', ' | ');
    return '[$ts] [${level.tag}] [$src] $oneLine';
  }

  static final RegExp _linePattern =
      RegExp(r'^\[(.+?)\] \[(.+?)\] \[(.+?)\] (.*)$');

  /// Parses a line produced by [formatted]; returns null when it does not match.
  static LogEntry? tryParse(String line) {
    final RegExpMatch? m = _linePattern.firstMatch(line);
    if (m == null) {
      return null;
    }
    final DateTime? time = DateTime.tryParse(m.group(1)!);
    final LogLevel? level = LogLevelX.fromTag(m.group(2)!);
    if (time == null || level == null) {
      return null;
    }
    return LogEntry(
      time: time,
      level: level,
      source: m.group(3)!.trim(),
      message: m.group(4)!,
    );
  }

  @override
  String toString() => formatted;
}
