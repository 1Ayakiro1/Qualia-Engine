import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'state/app_state.dart';

/// Root widget of the Ayakiro BCI Engine application.
class BciApp extends ConsumerWidget {
  const BciApp({super.key, this.onOpenDebugTerminal});

  final VoidCallback? onOpenDebugTerminal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Ayakiro BCI Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: AppShell(onOpenDebugTerminal: onOpenDebugTerminal),
    );
  }
}
