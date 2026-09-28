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
    final Brightness platformBrightness = View.of(context)
        .platformDispatcher
        .platformBrightness;
    final bool lightAppearance =
        themeMode == ThemeMode.light ||
        (themeMode == ThemeMode.system &&
            platformBrightness == Brightness.light);
    return MaterialApp(
      title: 'Ayakiro BCI Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!lightAppearance) return content;
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -1,
            0,
            0,
            0,
            255,
            0,
            -1,
            0,
            0,
            255,
            0,
            0,
            -1,
            0,
            255,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: content,
        );
      },
      home: AppShell(onOpenDebugTerminal: onOpenDebugTerminal),
    );
  }
}
