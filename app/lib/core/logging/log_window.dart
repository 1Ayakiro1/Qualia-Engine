import '../../l10n/app_strings.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../../features/common/widgets.dart';
import 'app_logger.dart';
import 'log_entry.dart';

/// In-app debug terminal with the same compact, neutral visual language as the
/// main application.
class LogConsoleScreen extends ConsumerStatefulWidget {
  const LogConsoleScreen({
    super.key,
    required this.onClose,
    this.onDrag,
    this.onDragStart,
  });

  final VoidCallback onClose;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onDragStart;

  @override
  ConsumerState<LogConsoleScreen> createState() => _LogConsoleScreenState();
}

class _LogConsoleScreenState extends ConsumerState<LogConsoleScreen> {
  final List<LogEntry> _entries = <LogEntry>[];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  Timer? _poller;
  RandomAccessFile? _tail;
  bool _openingTail = false;
  int _fileOffset = 0;
  String _tailBuffer = '';

  bool _paused = false;
  bool _autoScroll = true;
  String _query = '';
  bool _fileMissing = true;
  final Set<LogLevel> _enabledLevels = LogLevel.values.toSet();

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() => _query = _search.text.trim().toLowerCase()),
    );
    _openTail();
    _poller = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _openTail() async {
    if (_openingTail || !mounted) return;
    _openingTail = true;
    try {
      final File file = LogLocations.latestFile();
      if (!await file.exists()) {
        if (mounted) setState(() => _fileMissing = true);
        return;
      }
      await _tail?.close();
      _tail = await file.open(mode: FileMode.read);
      _fileOffset = 0;
      setState(() => _fileMissing = false);
      _poll();
    } catch (_) {
      if (mounted) setState(() => _fileMissing = true);
    } finally {
      _openingTail = false;
    }
  }

  Future<void> _poll() async {
    if (!mounted || _paused) {
      return;
    }
    if (_tail == null) {
      await _openTail();
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
        _entries.add(
          entry ??
              LogEntry(
                time: DateTime.now(),
                level: LogLevel.info,
                source: 'raw',
                message: trimmed,
              ),
        );
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
      await _tail?.close();
      _tail = null;
      if (mounted) setState(() => _fileMissing = true);
    }
  }

  List<LogEntry> get _visible {
    return _entries.where((LogEntry e) {
      if (!_enabledLevels.contains(e.level)) {
        return false;
      }
      if (_query.isNotEmpty &&
          !('${e.source} ${e.message}'.toLowerCase().contains(_query))) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _levelColor(BuildContext context, LogLevel level, ColorScheme scheme) {
    switch (level) {
      case LogLevel.debug:
        // Grey spectrum one step quieter than INFO. The old scheme.outline
        // became the near-black hover tint in the borderless palettes and
        // was unreadable on the terminal background.
        return context.palette.mutedText;
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
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final File target = File(
        '${dir.path}${Platform.pathSeparator}console-export-$stamp.log',
      );
      final IOSink sink = target.openWrite();
      for (final LogEntry e in _visible) {
        sink.writeln(e.formatted);
      }
      await sink.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logSaved(target.path))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logSaveFailed(e.toString()))),
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
    final ThemeData theme = Theme.of(context);
    final List<LogEntry> visible = _visible;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: context.palette.background,
        body: Column(
          children: [
            _LogHeader(
              paused: _paused,
              autoScroll: _autoScroll,
              onPause: () => setState(() => _paused = !_paused),
              onAutoScroll: () => setState(() => _autoScroll = !_autoScroll),
              onSave: _saveAs,
              onClear: () => setState(_entries.clear),
              onClose: widget.onClose,
              onDrag: widget.onDrag,
              onDragStart: widget.onDragStart,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: context.l10n.textSearchSourceAndText8,
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    context.l10n.textLEVELS9,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (final level in LogLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _LogLevelButton(
                        level: level,
                        selected: _enabledLevels.contains(level),
                        onPressed: () => setState(() {
                          if (!_enabledLevels.remove(level)) {
                            _enabledLevels.add(level);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _fileMissing
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_empty, size: 42),
                          const SizedBox(height: 12),
                          Text(context.l10n.textTheLatestLogFileHasNotBeen10),
                          const SizedBox(height: 4),
                          Text(context.l10n.textOpenTheApplicationWorkspace11),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _openTail,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.textRetry12),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          color: _paused
                              ? Colors.amber.withAlpha(40)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(60),
                          child: Text(
                            _paused
                                ? context.l10n.logPausedCount(_entries.length)
                                : context.l10n.logVisibleCount(
                                    visible.length,
                                    _entries.length,
                                  ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.palette.mutedText,
                              fontSize: 13,
                            ),
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
                                  horizontal: 16,
                                  vertical: 3,
                                ),
                                child: SelectableText(
                                  e.formatted,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    height: 1.35,
                                    color: _levelColor(
                                      context,
                                      e.level,
                                      theme.colorScheme,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader({
    required this.paused,
    required this.autoScroll,
    required this.onPause,
    required this.onAutoScroll,
    required this.onSave,
    required this.onClear,
    required this.onClose,
    required this.onDrag,
    required this.onDragStart,
  });

  final bool paused;
  final bool autoScroll;
  final VoidCallback onPause;
  final VoidCallback onAutoScroll;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onDragStart;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(color: context.palette.panel),
    child: Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: onDragStart == null
                        ? null
                        : (_) => onDragStart!(),
                    onPanUpdate: onDrag == null
                        ? null
                        : (details) => onDrag!(details.delta),
                    child: Row(
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 19,
                          color: context.palette.text,
                        ),
                        SizedBox(width: 10),
                        Text(
                          context.l10n.textDebugTerminal13,
                          style: TextStyle(
                            color: context.palette.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _LogIconButton(
                  tooltip: paused
                      ? context.l10n.textResume14
                      : context.l10n.textPause15,
                  icon: paused ? Icons.play_arrow : Icons.pause,
                  onPressed: onPause,
                ),
                _LogIconButton(
                  tooltip: context.l10n.textAutoScroll16,
                  icon: autoScroll
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_top,
                  active: autoScroll,
                  onPressed: onAutoScroll,
                ),
                _LogIconButton(
                  tooltip: context.l10n.textSaveVisibleEntries17,
                  icon: Icons.save_outlined,
                  onPressed: onSave,
                ),
                _LogIconButton(
                  tooltip: context.l10n.textClearView18,
                  icon: Icons.delete_sweep_outlined,
                  onPressed: onClear,
                ),
                _LogIconButton(
                  tooltip: context.l10n.textCloseWindow19,
                  icon: Icons.close,
                  onPressed: onClose,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LogIconButton extends StatelessWidget {
  const _LogIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: DesktopIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      size: 36,
      iconSize: 19,
      active: active,
    ),
  );
}

class _LogLevelButton extends StatefulWidget {
  const _LogLevelButton({
    required this.level,
    required this.selected,
    required this.onPressed,
  });

  final LogLevel level;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_LogLevelButton> createState() => _LogLevelButtonState();
}

class _LogLevelButtonState extends State<_LogLevelButton> {
  bool _hovered = false;

  String get _shortLabel {
    switch (widget.level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.hostLabel(widget.level.label),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.hoverCurve,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: widget.selected || _hovered
                ? context.palette.hover
                : context.palette.hover.withAlpha(0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              _shortLabel,
              style: TextStyle(
                color: widget.selected
                    ? context.palette.text
                    : context.palette.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .3,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
