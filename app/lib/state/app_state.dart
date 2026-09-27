import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/shell/nav_registry.dart';

/// Theme mode of the application (dark-first).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) => state = mode;
}

final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Usage modes from the ТЗ: Потребитель / Исследователь / Разработчик.
enum AppMode { consumer, researcher, developer }

extension AppModeX on AppMode {
  String get label {
    switch (this) {
      case AppMode.consumer:
        return 'Потребитель';
      case AppMode.researcher:
        return 'Исследователь';
      case AppMode.developer:
        return 'Разработчик';
    }
  }

  String get hint {
    switch (this) {
      case AppMode.consumer:
        return 'Личный и медицинский режим';
      case AppMode.researcher:
        return 'Датасеты, спектрограммы, эксперименты';
      case AppMode.developer:
        return 'Модули, API, низкоуровневый доступ';
    }
  }
}

class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() => AppMode.consumer;

  void setMode(AppMode mode) {
    state = mode;
    // Reset navigation so the shell never points to a hidden section.
    ref.read(navSectionProvider.notifier).resetForMode(mode);
  }
}

/// Stable section identifiers for the navigation rail.
enum SectionId {
  dashboard,
  devices,
  session,
  pipeline,
  spectrogram,
  modules,
  datasets,
  models,
  developer,
  extensions,
  bugReport,
  profile,
  settings,
}

class NavSectionController extends Notifier<SectionId> {
  @override
  SectionId build() => SectionId.dashboard;

  void select(SectionId section) => state = section;

  /// Falls back to the first visible section when the mode changes.
  void resetForMode(AppMode mode) {
    final bool visible = visibleSections(mode)
        .any((NavSection s) => s.id == state);
    if (!visible) {
      state = SectionId.dashboard;
    }
  }
}

final NotifierProvider<AppModeController, AppMode> appModeProvider =
    NotifierProvider<AppModeController, AppMode>(AppModeController.new);

final NotifierProvider<NavSectionController, SectionId> navSectionProvider =
    NotifierProvider<NavSectionController, SectionId>(NavSectionController.new);
