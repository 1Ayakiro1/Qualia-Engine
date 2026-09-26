import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_window.dart';
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
        const ScreenHeader(
          title: 'Обзор',
          subtitle: 'Состояние движка и быстрый старт',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppTheme.border),
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
                      'Интерфейс обновлён · рабочая область готова',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                );
                final action = OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.settings),
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text('Настроить'),
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
                              Icons.auto_awesome,
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
                        Icons.auto_awesome,
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
          title: 'Ядро (C++ / FFI)',
          headerIcon: Icons.memory,
          trailing: StatusChip(
            label: engine.isOnline ? 'онлайн' : 'офлайн',
            color: engine.isOnline
                ? Colors.greenAccent
                : theme.colorScheme.outline,
          ),
          children: [
            KeyValue(
              keyLabel: 'Версия ядра',
              value: engine.coreVersion.isEmpty ? '—' : engine.coreVersion,
            ),
            KeyValue(
              keyLabel: 'ABI',
              value:
                  '${engine.abiVersion} (ожидается ${AppInfo.expectedCoreAbi})',
            ),
            KeyValue(
              keyLabel: 'Библиотека',
              value: engine.libraryPath.isEmpty
                  ? 'не найдена'
                  : engine.libraryPath,
            ),
            KeyValue(
              keyLabel: 'Модулей в конвейере',
              value: '${engine.moduleCount}',
            ),
            if (engine.lastError.isNotEmpty)
              KeyValue(keyLabel: 'Ошибка', value: engine.lastError),
          ],
        ),
        InfoCard(
          title: 'Быстрый старт',
          headerIcon: Icons.bolt,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.session),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Запустить тестовую сессию'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.spectrogram),
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('Спектрограмма (demo)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(navSectionProvider.notifier)
                      .select(SectionId.modules),
                  icon: const Icon(Icons.extension_outlined),
                  label: const Text('Реестр модулей'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Устройство ещё не подключено — сессия запустится на '
              'встроенном симуляторе сигнала (256 Гц, 1 канал).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  AppLogger.instance.log(
                    'app',
                    'консоль логов открыта с дашборда',
                  );
                  try {
                    await openLogConsole();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Не удалось открыть консоль: $e'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.terminal),
                label: const Text('Открыть консоль логов'),
              ),
            ),
          ],
        ),
        InfoCard(
          title: 'Последние сессии',
          headerIcon: Icons.history,
          children: [
            const KeyValue(
              keyLabel: '24.09 · тест',
              value: 'Симулятор · 00:32 · качество 0.86',
            ),
            const KeyValue(
              keyLabel: '23.09 · калибровка',
              value: 'Симулятор · 03:12 · готово',
            ),
            const KeyValue(
              keyLabel: '22.09 · сон',
              value: 'Симулятор · 01:05 · качество 0.71',
            ),
            Text(
              'Хранение сессий будет реализовано в Storage Service (v0.2).',
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
