import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_palette.dart';
import '../../state/engine_provider.dart';
import '../../state/engine_state.dart';
import '../../state/app_state.dart';
import '../common/widgets.dart';

/// Overview: engine status, quick start, recent sessions (mock).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EngineState engine = ref.watch(engineProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 34, 34, 70),
      children: [
        ScreenHeader(
          title: context.l10n.textDashboard36,
          subtitle: context.l10n.textEngineStatusAndQuickStart235,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.panel,
              borderRadius: BorderRadius.circular(17),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NerveGears Engine',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.textInterfaceUpdatedWorkspaceReady236,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.mutedText,
                      ),
                    ),
                  ],
                );
                final action = OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.settings),
                  icon: const Icon(AppIcons.settings, size: 17),
                  label: Text(context.l10n.textConfigure237),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              AppIcons.sparkles,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: copy),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppIcons.sparkles,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
        InfoCard(
          title: context.l10n.textCoreCFFI238,
          headerIcon: AppIcons.cpu,
          trailing: StatusChip(
            label: engine.isOnline
                ? context.l10n.textOnline239
                : context.l10n.textOffline240,
            color: engine.isOnline
                ? Colors.greenAccent
                : theme.colorScheme.outline,
          ),
          children: [
            KeyValue(
              keyLabel: context.hostLabel('Версия ядра'),
              value: engine.coreVersion.isEmpty ? '—' : engine.coreVersion,
            ),
            KeyValue(
              keyLabel: 'ABI',
              value:
                  '${engine.abiVersion} (ожидается ${AppInfo.expectedCoreAbi})',
            ),
            KeyValue(
              keyLabel: context.hostLabel('Библиотека'),
              value: engine.libraryPath.isEmpty
                  ? 'не найдена'
                  : engine.libraryPath,
            ),
            KeyValue(
              keyLabel: context.hostLabel('Модулей в конвейере'),
              value: '${engine.moduleCount}',
            ),
            if (engine.lastError.isNotEmpty)
              KeyValue(
                keyLabel: context.hostLabel('Ошибка'),
                value: context.hostLabel(engine.lastError),
              ),
          ],
        ),
        InfoCard(
          title: context.l10n.textQuickStart247,
          headerIcon: AppIcons.bolt,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.session),
                  icon: const Icon(AppIcons.play),
                  label: Text(context.l10n.textStartATestSession248),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.spectrogram),
                  icon: const Icon(AppIcons.waveform),
                  label: Text(context.l10n.textSpectrogramDemo249),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.modules),
                  icon: const Icon(AppIcons.puzzle),
                  label: Text(context.l10n.textModuleRegistry250),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.simulatorNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        InfoCard(
          title: context.l10n.recentSessions,
          headerIcon: AppIcons.history,
          children: [
            KeyValue(
              keyLabel: context.hostLabel('24.09 · тест'),
              value: context.hostLabel('Симулятор · 00:32 · качество 0.86'),
            ),
            KeyValue(
              keyLabel: context.hostLabel('23.09 · калибровка'),
              value: context.hostLabel('Симулятор · 03:12 · готово'),
            ),
            KeyValue(
              keyLabel: context.hostLabel('22.09 · сон'),
              value: context.hostLabel('Симулятор · 01:05 · качество 0.71'),
            ),
            Text(
              context.l10n.textSessionStorageWillBeImplementedInStorage257,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
