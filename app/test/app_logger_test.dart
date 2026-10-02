import 'package:bci_engine/core/logging/app_logger.dart';
import 'package:bci_engine/core/logging/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('log entry formats and parses back', () {
    final LogEntry entry = LogEntry(
      time: DateTime.utc(2026, 9, 24, 15, 30, 1, 123),
      level: LogLevel.info,
      source: 'core',
      message: 'engine started',
    );
    final String line = entry.formatted;
    expect(line, contains('[INFO ]'));
    expect(line, contains('[core     ]'));
    final LogEntry? parsed = LogEntry.tryParse(line);
    expect(parsed, isNotNull);
    expect(parsed!.level, LogLevel.info);
    expect(parsed.source, 'core');
    expect(parsed.message, 'engine started');
  });

  test('log sources render as fixed-width tags', () {
    for (final LogSource source in LogSource.values) {
      expect(source.tag.length, lessThanOrEqualTo(9), reason: source.name);
      final LogEntry entry = LogEntry(
        time: DateTime.utc(2026, 9, 24),
        level: LogLevel.info,
        source: source.tag,
        message: 'x',
      );
      expect(entry.formatted, contains('[${source.tag.padRight(9)}]'));
    }
  });

  test('app logger keeps a capped ring buffer', () async {
    final AppLogger logger = AppLogger.instance;
    logger.maxEntries = 10;
    for (int i = 0; i < 15; i++) {
      logger.log(LogSource.app, 'line $i', level: LogLevel.debug);
    }
    expect(logger.length, 10);
    expect(logger.snapshot().last.message, 'line 14');
    logger.maxEntries = AppLogger.defaultCapacity;
  });

  test('typed sources land in the entry source column', () {
    final int before = AppLogger.instance.length;
    logI(LogSource.shell, 'таб открыт: Devices');
    final List<LogEntry> fresh = AppLogger.instance
        .snapshot()
        .skip(before)
        .toList();
    expect(fresh, hasLength(1));
    expect(fresh.single.source, 'shell');
    expect(fresh.single.message, 'таб открыт: Devices');
    expect(fresh.single.level, LogLevel.info);
  });
}
