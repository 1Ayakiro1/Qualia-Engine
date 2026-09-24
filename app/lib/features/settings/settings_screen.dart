import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../state/app_state.dart';
import '../../state/engine_state.dart';
import '../common/widgets.dart';

/// Settings: modes, build info, licensing placeholder.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppMode mode = ref.watch(appModeProvider);
    final String version = ref.watch(versionLabelProvider);

    return ListView(
      children: [
        const ScreenHeader(
          title: 'Настройки',
          subtitle: 'Режимы использования и сборка',
        ),
        InfoCard(
          title: 'Режим использования',
          headerIcon: Icons.switch_account,
          children: [
            SegmentedButton<AppMode>(
              segments: <ButtonSegment<AppMode>>[
                for (final AppMode m in AppMode.values)
                  ButtonSegment<AppMode>(
                    value: m,
                    label: Text(m.label),
                    icon: Icon(switch (m) {
                      AppMode.consumer => Icons.person_outline,
                      AppMode.researcher => Icons.science_outlined,
                      AppMode.developer => Icons.code,
                    }),
                  ),
              ],
              selected: <AppMode>{mode},
              onSelectionChanged: (Set<AppMode> selection) =>
                  ref.read(appModeProvider.notifier).setMode(selection.first),
            ),
            const SizedBox(height: 10),
            Text(
              'Потребитель делится на личный и медицинский подрежимы '
              '(разграничение прав — v0.2, Permission & Sandbox Manager).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        InfoCard(
          title: 'Сборка',
          headerIcon: Icons.build_outlined,
          children: [
            KeyValue(keyLabel: 'Приложение', value: version),
            KeyValue(keyLabel: 'Стадия', value: AppInfo.stage),
            KeyValue(keyLabel: 'Оффлайн-режим', value: 'включен (offline-first)'),
            KeyValue(keyLabel: 'Ограничение функционала', value: 'JSON-конфиг (запланировано)'),
          ],
        ),
        InfoCard(
          title: 'Лицензии и данные',
          headerIcon: Icons.policy_outlined,
          children: [
            Text(
              'Медицинский режим будет требовать согласий и журналирования '
              'действий. Хранение сырых данных — локально; метаданные и '
              'синхронизация — Postgres/Supabase (v0.3+).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
