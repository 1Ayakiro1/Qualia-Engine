import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// One navigation entry of the shell.
class NavSection {
  const NavSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.modes,
    this.subtitle = '',
  });

  final SectionId id;
  final String label;
  final IconData icon;
  final Set<AppMode> modes;
  final String subtitle;

  bool visibleIn(AppMode mode) => modes.contains(mode);
}

const List<NavSection> kNavSections = <NavSection>[
  NavSection(
    id: SectionId.dashboard,
    label: 'Обзор',
    icon: Icons.dashboard_outlined,
    subtitle: 'Состояние системы',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.devices,
    label: 'Устройства',
    icon: Icons.usb_outlined,
    subtitle: 'HAL, подключение плат',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.session,
    label: 'Сессия',
    icon: Icons.radio_button_checked_outlined,
    subtitle: 'Запись и live-метрики',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.pipeline,
    label: 'Конвейер',
    icon: Icons.linear_scale,
    subtitle: 'Цепочка модулей обработки',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.spectrogram,
    label: 'Спектрограмма',
    icon: Icons.graphic_eq,
    subtitle: 'Real-time визуализация',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.modules,
    label: 'Workspace',
    icon: Icons.extension_outlined,
    subtitle: 'Канвас обработки модулей',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.entity,
    label: 'Entity',
    icon: Icons.hub_outlined,
    subtitle: 'Neural network entities',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.datasets,
    label: 'Датасеты',
    icon: Icons.folder_copy_outlined,
    subtitle: 'Загрузка и сравнение',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.models,
    label: 'Модели',
    icon: Icons.psychology_outlined,
    subtitle: 'Обучение и реестр моделей',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.developer,
    label: 'Разработчик',
    icon: Icons.terminal,
    subtitle: 'FFI-консоль ядра',
    modes: {AppMode.developer},
  ),
  NavSection(
    id: SectionId.extensions,
    label: 'Marketplace',
    icon: Icons.auto_awesome_mosaic_outlined,
    subtitle: 'Пользовательские расширения',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.bugReport,
    label: 'Bug report',
    icon: Icons.bug_report_outlined,
    subtitle: 'Сообщить о проблеме',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.settings,
    label: 'Настройки',
    icon: Icons.settings_outlined,
    subtitle: 'Режимы, сборка, лицензии',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
];

/// Sections visible for a given mode, in display order.
List<NavSection> visibleSections(AppMode mode) =>
    kNavSections.where((NavSection s) => s.visibleIn(mode)).toList();
