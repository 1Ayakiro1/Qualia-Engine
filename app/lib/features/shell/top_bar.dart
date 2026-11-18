import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';

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
            context.l10n.textFile60,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            context.l10n.textEdit61,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            context.l10n.textView62,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(width: 25),
          Text(
            context.l10n.textHelp63,
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
                      ? context.l10n.textCoreSessionActive64
                      : context.l10n.textCoreOnline65)
                : context.l10n.textCoreOffline66,
            color: !engine.isOnline
                ? theme.colorScheme.outline
                : engine.runState == EngineRunState.running
                ? Colors.greenAccent
                : theme.colorScheme.primary,
            icon: !engine.isOnline
                ? AppIcons.plugOff
                : engine.runState == EngineRunState.running
                ? AppIcons.bolt
                : AppIcons.checkCircle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: DesktopMenuButton<AppMode>(
            tooltip: context.l10n.textUsageMode67,
            onSelected: (AppMode value) =>
                ref.read(appModeProvider.notifier).setMode(value),
            entries: [
              for (final AppMode m in AppMode.values)
                DesktopMenuEntry<AppMode>(
                  value: m,
                  label: context.hostLabel(m.label),
                ),
            ],
            child: Chip(
              avatar: const Icon(AppIcons.users, size: 16),
              label: Text(context.hostLabel(mode.label)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
