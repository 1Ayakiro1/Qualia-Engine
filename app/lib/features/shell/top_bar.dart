import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/logging/log_window.dart';
import '../../../state/app_state.dart';
import '../../../state/engine_state.dart';
import '../common/widgets.dart';

/// Top bar: app title, engine status chip and the usage mode selector.
class ShellTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const ShellTopBar({super.key, required this.mode, required this.engine});

  final AppMode mode;
  final EngineState engine;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppBar(
      titleSpacing: 16,
      title: Text(AppInfo.appName, style: theme.textTheme.titleLarge),
      actions: [
        IconButton(
          tooltip: 'Консоль логов (отдельное окно)',
          icon: const Icon(Icons.terminal),
          onPressed: () async {
            try {
              await openLogConsole();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Не удалось открыть консоль: $e')),
                );
              }
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: StatusChip(
            label: engine.isOnline
                ? (engine.runState == EngineRunState.running
                    ? 'Ядро: активна сессия'
                    : 'Ядро: онлайн')
                : 'Ядро: офлайн',
            color: !engine.isOnline
                ? theme.colorScheme.outline
                : engine.runState == EngineRunState.running
                    ? Colors.greenAccent
                    : theme.colorScheme.primary,
            icon: !engine.isOnline
                ? Icons.power_off
                : engine.runState == EngineRunState.running
                    ? Icons.bolt
                    : Icons.check_circle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<AppMode>(
            tooltip: 'Режим использования',
            initialValue: mode,
            onSelected: (AppMode value) =>
                ref.read(appModeProvider.notifier).setMode(value),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<AppMode>>[
              for (final AppMode m in AppMode.values)
                PopupMenuItem<AppMode>(
                  value: m,
                  child: ListTile(
                    dense: true,
                    leading: Icon(switch (m) {
                      AppMode.consumer => Icons.person_outline,
                      AppMode.researcher => Icons.science_outlined,
                      AppMode.developer => Icons.code,
                    }),
                    title: Text(m.label),
                    subtitle: Text(m.hint, style: theme.textTheme.bodySmall),
                  ),
                ),
            ],
            child: Chip(
              avatar: const Icon(Icons.switch_account, size: 16),
              label: Text(mode.label),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
