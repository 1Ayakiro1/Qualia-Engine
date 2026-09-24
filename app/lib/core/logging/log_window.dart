import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'log_entry.dart';

/// Opens the detached log console in a separate OS window.
///
/// The console is a second Flutter engine running the same binary with the
/// `log_console` argument; it tails `logs/latest.log` from disk, so no shared
/// memory is required between engines.
Future<void> openLogConsole() async {
  AppLogger.instance.log('app', 'открытие окна консоли логов');
  try {
    final WindowController controller = await WindowController.create(
      WindowConfiguration(arguments: 'log_console'),
    );
    await controller.show();
  } catch (e) {
    AppLogger.instance
        .log('app', 'не удалось открыть консоль логов: $e', level: LogLevel.error);
    rethrow;
  }
}

/// Root widget of the detached log console window (second engine entrypoint).
class LogConsoleApp extends StatelessWidget {
  const LogConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'BCI Engine — Консоль логов',
        debugShowCheckedModeBanner: false,
        home: LogConsoleScreen(),
      ),
    );
  }
}

/// Minimalist (GNOME-style) log console: filter, pause, save, clear.
class LogConsoleScreen extends ConsumerStatefulWidget {
  const LogConsoleScreen({super.key});

  @override
  ConsumerState<LogConsoleScreen> createState() => _LogConsoleScreenState();
}

class _LogConsoleScreenState extends ConsumerState<LogConsoleScreen> {
  final List<LogEntry> _entries = <LogEntry>[];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  Timer? _poller;
  RandomAccessFile? _tail;
  int _fileOffset = 0;
  String _tailBuffer = '';

  bool _paused = false;
  bool _autoScroll = true;
  LogLevel? _levelFilter; // null = all
  String _query = '';
  bool _fileMissing = true;


  static const List<LogLevel?> _filterOrder = <LogLevel?>[
    null,
    LogLevel.debug,
    LogLevel.info,
    LogLevel.warning,
    LogLevel.error,
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(
        () => setState(() => _query = _search.text.trim().toLowerCase()));
    _openTail();
    _poller = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _openTail() async {
    try {
      final File file = LogLocations.latestFile();
      if (!await file.exists()) {
        setState(() => _fileMissing = true);
        return;
      }
      _tail = await file.open(mode: FileMode.read);
      _fileOffset = 0;
      setState(() => _fileMissing = false);
      _poll();
    } catch (_) {
      setState(() => _fileMissing = true);
    }
  }

  Future<void> _poll() async {
    if (_paused || _tail == null || !mounted) {
      return;
    }
    try {
      final int length = await _tail!.length();
      if (length < _fileOffset) {
        // File was rewritten on app restart — start over.
        _fileOffset = 0;
        _tailBuffer = '';
        if (mounted) {
          setState(_entries.clear);
        }
      }
      if (length == _fileOffset) {
        return;
      }
      await _tail!.setPosition(_fileOffset);
      final List<int> chunk = await _tail!.read(length - _fileOffset);
      _fileOffset = length;
      _tailBuffer += utf8.decode(chunk, allowMalformed: true);
      final List<String> lines = _tailBuffer.split('\n');
      _tailBuffer = lines.removeLast(); // keep incomplete tail
      bool added = false;
      for (final String line in lines) {
        final String trimmed = line.trimRight();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        final LogEntry? entry = LogEntry.tryParse(trimmed);
        _entries.add(entry ??
            LogEntry(
                time: DateTime.now(),
                level: LogLevel.info,
                source: 'raw',
                message: trimmed));
        added = true;
      }
      if (added && mounted) {
        setState(() {});
        if (_autoScroll && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      }
    } catch (_) {
      // Tailing must never crash the console.
    }
  }

  List<LogEntry> get _visible {
    return _entries.where((LogEntry e) {
      if (_levelFilter != null && e.level != _levelFilter) {
        return false;
      }
      if (_query.isNotEmpty &&
          !('${e.source} ${e.message}'.toLowerCase().contains(_query))) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _levelColor(LogLevel level, ColorScheme scheme) {
    switch (level) {
      case LogLevel.debug:
        return scheme.outline;
      case LogLevel.info:
        return scheme.primary;
      case LogLevel.warning:
        return Colors.amber;
      case LogLevel.error:
        return scheme.error;
    }
  }

  Future<void> _saveAs() async {
    // No file picker plugin in the skeleton: save next to latest.log with a
    // timestamped name and report the path.
    try {
      final Directory dir = LogLocations.sessionLogDir();
      await dir.create(recursive: true);
      final String stamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final File target =
          File('${dir.path}${Platform.pathSeparator}console-export-$stamp.log');
      final IOSink sink = target.openWrite();
      for (final LogEntry e in _visible) {
        sink.writeln(e.formatted);
      }
      await sink.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: ${target.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _tail?.close();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData.dark(useMaterial3: true);
    final List<LogEntry> visible = _visible;
    final String filterLabel =
        _levelFilter == null ? 'Все уровни' : _levelFilter!.label;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Консоль логов'),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: _paused ? 'Продолжить' : 'Пауза',
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => _paused = !_paused),
            ),
            IconButton(
              tooltip: 'Автопрокрутка',
              icon: Icon(_autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_top),
              color: _autoScroll ? theme.colorScheme.primary : null,
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
            ),
            PopupMenuButton<LogLevel?>(
              tooltip: 'Фильтр уровня',
              initialValue: _levelFilter,
              onSelected: (LogLevel? v) => setState(() => _levelFilter = v),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<LogLevel?>>[
                for (final LogLevel? level in _filterOrder)
                  PopupMenuItem<LogLevel?>(
                    value: level,
                    child: Text(level == null ? 'Все уровни' : level.label),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18),
                    const SizedBox(width: 4),
                    Text(filterLabel),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Сохранить видимое в файл',
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveAs,
            ),
            IconButton(
              tooltip: 'Очистить вид',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(_entries.clear),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Поиск по источнику и тексту…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
        body: _fileMissing
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty, size: 48),
                    const SizedBox(height: 12),
                    const Text('Файл latest.log пока не создан.'),
                    const SizedBox(height: 4),
                    const Text('Запустите основное окно приложения.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openTail,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: _paused
                        ? Colors.amber.withAlpha(40)
                        : theme.colorScheme.surfaceContainerHighest
                            .withAlpha(60),
                    child: Text(
                      _paused
                          ? 'Пауза — новые строки не подгружаются '
                              '(${_entries.length})'
                          : 'Строк: ${visible.length} / ${_entries.length} · '
                              'файл: latest.log (обновление 0.4 с)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int index) {
                        final LogEntry e = visible[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 1),
                          child: SelectableText(
                            e.formatted,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: _levelColor(e.level, theme.colorScheme),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
