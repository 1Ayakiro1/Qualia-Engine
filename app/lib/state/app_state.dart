import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/log_entry.dart';
import '../features/shell/nav_registry.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final IconData icon;
  final DateTime createdAt;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    message: message,
    icon: icon,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}

class NotificationController extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => const <AppNotification>[];

  void add({
    required String id,
    required String title,
    required String message,
    required IconData icon,
  }) {
    state = [
      AppNotification(
        id: '$id-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        message: message,
        icon: icon,
        createdAt: DateTime.now(),
      ),
      ...state,
    ];
    logI(LogSource.shell, 'уведомление: $title — $message');
  }

  void markRead(String id) {
    state = [
      for (final item in state)
        item.id == id ? item.copyWith(read: true) : item,
    ];
  }

  void markAllRead() {
    state = [for (final item in state) item.copyWith(read: true)];
  }
}

final NotifierProvider<NotificationController, List<AppNotification>>
notificationProvider =
    NotifierProvider<NotificationController, List<AppNotification>>(
      NotificationController.new,
    );

/// Theme mode of the application (dark-first).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    if (state == mode) {
      return;
    }
    state = mode;
    logI(LogSource.ui, switch (mode) {
      ThemeMode.system => 'тема: системная',
      ThemeMode.dark => 'тема: тёмная',
      ThemeMode.light => 'тема: светлая',
    });
  }
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
    if (state == mode) {
      return;
    }
    state = mode;
    logI(LogSource.shell, 'режим работы: ${mode.label}');
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
  entity,
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
  SectionId build() => SectionId.modules;

  void select(SectionId section) {
    if (state == section) {
      return;
    }
    state = section;
    // High-frequency noise: kept at debug level for the action timeline.
    logD(LogSource.shell, 'раздел: ${section.name}');
  }

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
