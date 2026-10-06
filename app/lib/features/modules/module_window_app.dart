import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/workspace/workspace_model.dart';
import '../../l10n/generated/app_localizations.dart';
import 'active_module_view.dart';
import '../common/navigation_bindings.dart';

/// Isolated native window; no auth startup and no shared-preferences writes.
class ModuleWindowApp extends StatefulWidget {
  const ModuleWindowApp({
    super.key,
    required this.socket,
    required this.messages,
    required this.initial,
  });
  final WebSocket socket;
  final StreamIterator<dynamic> messages;
  final Map<String, dynamic> initial;
  @override
  State<ModuleWindowApp> createState() => _ModuleWindowAppState();
}

class _ModuleWindowAppState extends State<ModuleWindowApp> {
  late WorkspaceNode _node = WorkspaceNode.fromJson(
    Map<String, dynamic>.from(widget.initial['node'] as Map),
  );
  bool _closed = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readMessages());
  }

  Future<void> _readMessages() async {
    try {
      while (await widget.messages.moveNext()) {
        if (_closed || !mounted) return;
        final message = widget.messages.current;
        try {
          final data = jsonDecode(message as String) as Map;
          if (data['type'] == 'focus') {
            unawaited(windowManager.show());
            unawaited(windowManager.focus());
          } else if (data['type'] == 'node') {
            setState(
              () => _node = WorkspaceNode.fromJson(
                Map<String, dynamic>.from(data['node'] as Map),
              ),
            );
          }
        } catch (_) {}
      }
    } catch (_) {
      // Losing the host invalidates this view; never persist an orphan copy.
    } finally {
      if (!_closed) await windowManager.close();
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(widget.messages.cancel());
    unawaited(widget.socket.close());
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    await windowManager.setFullScreen(!_fullscreen);
    if (mounted) setState(() => _fullscreen = !_fullscreen);
  }

  @override
  Widget build(BuildContext context) {
    final light = widget.initial['light'] == true;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(widget.initial['locale'] as String? ?? 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: light ? AppTheme.light() : AppTheme.dark(),
      builder: (_, child) => AppThemeScope(
        palette: light ? AppPalette.light : AppPalette.dark,
        child: NavigationScope(child: child!),
      ),
      home: Scaffold(
        body: ActiveModuleView(
          node: _node,
          fullscreen: _fullscreen,
          onBack: () => _fullscreen
              ? unawaited(_toggleFullscreen())
              : unawaited(windowManager.close()),
          onFullscreen: () => unawaited(_toggleFullscreen()),
          onChanged: (key, value) => widget.socket.add(
            jsonEncode({'type': 'parameter', 'key': key, 'value': value}),
          ),
        ),
      ),
    );
  }
}
