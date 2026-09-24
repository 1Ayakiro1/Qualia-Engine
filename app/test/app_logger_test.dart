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

  test('app logger keeps a capped ring buffer', () async {
    final AppLogger logger = AppLogger.instance;
    logger.maxEntries = 10;
    for (int i = 0; i < 15; i++) {
      logger.log('test', 'line $i', level: LogLevel.debug);
    }
    expect(logger.length, 10);
    expect(logger.snapshot().last.message, 'line 14');
    logger.maxEntries = AppLogger.defaultCapacity;
  });
}
