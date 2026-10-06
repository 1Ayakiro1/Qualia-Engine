import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../l10n/app_strings.dart';
import '../common/widgets.dart';
import '../common/navigation_bindings.dart';
import 'navigation_shortcuts.dart';

/// Shared editable navigation preferences, also opened from global search.
class KeyboardShortcutsPanel extends StatelessWidget {
  const KeyboardShortcutsPanel({super.key, this.compact = false, this.onClose});
  final bool compact;
  final VoidCallback? onClose;

  Future<void> _edit(BuildContext context, NavigationShortcut shortcut) async {
    final chord = await showDialog<NavigationChord>(
      context: context,
      builder: (_) => _CaptureDialog(shortcut: shortcut),
    );
    if (chord != null) {
      await NavigationBindings.instance.setBinding(shortcut.action, chord);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.navigationTitle,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onClose != null)
                DesktopIconButton(
                  onPressed: onClose,
                  icon: Icons.close,
                  tooltip: context.l10n.textClose110,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text(
          context.l10n.navigationDescription,
          style: TextStyle(color: context.palette.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('navigation shortcuts scroll'),
            child: Column(
              children: [
                for (final group in navigationShortcutGroups.entries) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 7),
                      child: Text(
                        switch (group.key) {
                          'workspace' => context.l10n.textWORKSPACE356,
                          'interface' => context.l10n.textINTERFACE357,
                          'menus' => context.l10n.navigationMenus,
                          _ => context.l10n.navigationModules,
                        },
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  for (final shortcut in group.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: DesktopPane(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) => Row(
                              key: ValueKey(
                                'navigation shortcut ${shortcut.id}',
                              ),
                              children: [
                                Expanded(
                                  child: Text(
                                    shortcut.label(context.l10n),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * .52,
                                  ),
                                  child: DesktopIconButton(
                                    key: ValueKey(
                                      'edit navigation ${shortcut.id}',
                                    ),
                                    icon: Icons.edit_outlined,
                                    label: shortcut.keys(context.l10n),
                                    tooltip: context.l10n.textEditShortcuts359,
                                    onPressed: () => _edit(context, shortcut),
                                    size: 34,
                                    iconSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.navigationEditableHint,
          style: TextStyle(color: context.palette.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: DesktopIconButton(
            key: const ValueKey('navigation reset'),
            icon: Icons.restore,
            label: context.l10n.navigationReset,
            tooltip: context.l10n.navigationReset,
            onPressed: () => NavigationBindings.instance.reset(),
            size: 34,
          ),
        ),
      ],
    ),
  );
}

class _CaptureDialog extends StatefulWidget {
  const _CaptureDialog({required this.shortcut});
  final NavigationShortcut shortcut;
  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  NavigationChord? _chord;
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.handled;
      if (_chord != null &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isControlPressed &&
          NavigationBindings.instance.conflict(
                widget.shortcut.action,
                _chord!,
              ) ==
              null) {
        Navigator.pop(context, _chord);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
      } else {
        final chord = NavigationChord.fromEvent(event);
        if (chord != null) setState(() => _chord = chord);
      }
      return KeyEventResult.handled;
    },
    child: AlertDialog(
      title: Text(widget.shortcut.label(context.l10n)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.textPressKeys360),
            const SizedBox(height: 16),
            Text(
              _chord?.label ?? widget.shortcut.keys(context.l10n),
              key: const ValueKey('navigation captured chord'),
              style: const TextStyle(fontSize: 18),
            ),
            if (_chord != null &&
                NavigationBindings.instance.conflict(
                      widget.shortcut.action,
                      _chord!,
                    ) !=
                    null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(context.l10n.navigationConflict),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.textCancel198),
        ),
        FilledButton(
          onPressed:
              _chord == null ||
                  NavigationBindings.instance.conflict(
                        widget.shortcut.action,
                        _chord!,
                      ) !=
                      null
              ? null
              : () => Navigator.pop(context, _chord),
          child: Text(context.l10n.workspacePortSave),
        ),
      ],
    ),
  );
}
