import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      titleSpacing: 20,
      title: Row(
        children: [
          Text(
            'File',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            'Edit',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            'View',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            'Help',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
        ],
      ),
      actions: [
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
