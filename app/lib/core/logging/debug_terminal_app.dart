import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'log_window.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';

/// Standalone application used by the `--debug-terminal` process mode.
class DebugTerminalApp extends StatefulWidget {
  const DebugTerminalApp({super.key, required this.lockHandle});

  final RandomAccessFile lockHandle;

  @override
  State<DebugTerminalApp> createState() => _DebugTerminalAppState();
}

class _DebugTerminalAppState extends State<DebugTerminalApp>
    with WindowListener {
  bool _lockClosed = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(_releaseLock());
    super.dispose();
  }

  Future<void> _releaseLock() async {
    if (_lockClosed) return;
    _lockClosed = true;
    try {
      await widget.lockHandle.unlock();
    } catch (_) {}
    try {
      await widget.lockHandle.close();
    } catch (_) {}
  }

  Future<void> _close() async {
    await _releaseLock();
    await windowManager.close();
  }

  @override
  void onWindowClose() {
    unawaited(_releaseLock());
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        title: 'Ayakiro Debug Terminal',
        debugShowCheckedModeBanner: false,
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.dark(),
        builder: (context, child) => AppThemeScope(
          palette: AppPalette.dark,
          child: child ?? const SizedBox.shrink(),
        ),
        home: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ColoredBox(
            color: AppPalette.dark.background,
            child: LogConsoleScreen(
              onClose: () => unawaited(_close()),
              onDragStart: () => unawaited(windowManager.startDragging()),
            ),
          ),
        ),
      ),
    ),
  );
}
