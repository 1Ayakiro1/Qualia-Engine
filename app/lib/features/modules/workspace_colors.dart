import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_model.dart';
import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';

extension WorkspaceColorAppearance on WorkspaceNodeColor {
  String label(BuildContext context) => switch (this) {
    WorkspaceNodeColor.none => context.l10n.workspaceColorNone,
    WorkspaceNodeColor.red => context.l10n.workspaceColorRed,
    WorkspaceNodeColor.orange => context.l10n.workspaceColorOrange,
    WorkspaceNodeColor.yellow => context.l10n.workspaceColorYellow,
    WorkspaceNodeColor.green => context.l10n.workspaceColorGreen,
    WorkspaceNodeColor.blue => context.l10n.workspaceColorBlue,
    WorkspaceNodeColor.purple => context.l10n.workspaceColorPurple,
  };

  Color? get tint => switch (this) {
    WorkspaceNodeColor.none => null,
    WorkspaceNodeColor.red => const Color(0xFFE57373),
    WorkspaceNodeColor.orange => const Color(0xFFFFB074),
    WorkspaceNodeColor.yellow => const Color(0xFFE7CF75),
    WorkspaceNodeColor.green => const Color(0xFF81C995),
    WorkspaceNodeColor.blue => const Color(0xFF80B4EE),
    WorkspaceNodeColor.purple => const Color(0xFFBE9AE8),
  };

  Color headerBackground(BuildContext context) => tint == null
      ? context.palette.panel
      : Color.alphaBlend(
          tint!.withAlpha(context.palette.isDark ? 75 : 95),
          context.palette.panel,
        );
}

List<DesktopMenuEntry<String>> workspaceColorEntries(
  BuildContext context,
  String prefix,
) => [
  for (final color in WorkspaceNodeColor.values)
    DesktopMenuEntry(
      value: '$prefix${color.name}',
      label: color.label(context),
      markerColor: color.tint,
    ),
];
