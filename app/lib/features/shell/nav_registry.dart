import '../../core/theme/app_icons.dart';

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
    icon: AppIcons.grid,
    subtitle: 'Состояние системы',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.devices,
    label: 'Устройства',
    icon: AppIcons.usb,
    subtitle: 'HAL, подключение плат',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.session,
    label: 'Сессия',
    icon: AppIcons.record,
    subtitle: 'Запись и live-метрики',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.pipeline,
    label: 'Конвейер',
    icon: AppIcons.workflow,
    subtitle: 'Цепочка модулей обработки',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.spectrogram,
    label: 'Спектрограмма',
    icon: AppIcons.waveform,
    subtitle: 'Real-time визуализация',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.modules,
    label: 'Workspace',
    icon: AppIcons.puzzle,
    subtitle: 'Канвас обработки модулей',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.entity,
    label: 'Entity',
    icon: AppIcons.network,
    subtitle: 'Neural network entities',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.datasets,
    label: 'Датасеты',
    icon: AppIcons.folders,
    subtitle: 'Загрузка и сравнение',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.models,
    label: 'Модели',
    icon: AppIcons.brain,
    subtitle: 'Обучение и реестр моделей',
    modes: {AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.developer,
    label: 'Разработчик',
    icon: AppIcons.terminal,
    subtitle: 'FFI-консоль ядра',
    modes: {AppMode.developer},
  ),
  NavSection(
    id: SectionId.extensions,
    label: 'Marketplace',
    icon: AppIcons.grid,
    subtitle: 'Пользовательские расширения',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.bugReport,
    label: 'Bug report',
    icon: AppIcons.bug,
    subtitle: 'Сообщить о проблеме',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
  NavSection(
    id: SectionId.settings,
    label: 'Настройки',
    icon: AppIcons.settings,
    subtitle: 'Режимы, сборка, лицензии',
    modes: {AppMode.consumer, AppMode.researcher, AppMode.developer},
  ),
];

/// Sections visible for a given mode, in display order.
List<NavSection> visibleSections(AppMode mode) =>
    kNavSections.where((NavSection s) => s.visibleIn(mode)).toList();
