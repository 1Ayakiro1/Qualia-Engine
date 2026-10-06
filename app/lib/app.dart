import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'state/app_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'features/common/navigation_bindings.dart';

/// Root widget of the Ayakiro BCI Engine application.
///
/// The resolved appearance follows [themeModeProvider] and the platform
/// brightness. Switching it runs a single [AppPalette] cross-fade: the
/// MaterialApp theme and every shell surface interpolate the same tokens
/// over the same curve, so nothing snaps or inverts.
class BciApp extends ConsumerStatefulWidget {
  const BciApp({super.key, this.onOpenDebugTerminal});

  final VoidCallback? onOpenDebugTerminal;

  @override
  ConsumerState<BciApp> createState() => _BciAppState();
}

class _BciAppState extends ConsumerState<BciApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearance = AnimationController(
    vsync: this,
    duration: AppTheme.transitionDuration,
    value: 0, // dark-first
  );
  bool? _lightAppearance;

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Ayakiro BCI Engine',
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: AppTheme.transitionDuration,
      themeAnimationCurve: AppTheme.transitionCurve,
      builder: (context, child) {
        final bool lightAppearance = switch (themeMode) {
          ThemeMode.light => true,
          ThemeMode.dark => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.light,
        };
        final bool? previous = _lightAppearance;
        if (previous == null) {
          // First frame renders the resolved appearance without a transition.
          _appearance.value = lightAppearance ? 1 : 0;
        } else if (previous != lightAppearance) {
          _appearance.animateTo(
            lightAppearance ? 1 : 0,
            curve: AppTheme.transitionCurve,
          );
        }
        _lightAppearance = lightAppearance;
        return AnimatedBuilder(
          animation: _appearance,
          builder: (context, _) => AppThemeScope(
            palette: AppPalette.dark.lerpTo(
              AppPalette.light,
              _appearance.value,
            ),
            child: NavigationScope(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      home: AppShell(onOpenDebugTerminal: widget.onOpenDebugTerminal),
    );
  }
}
