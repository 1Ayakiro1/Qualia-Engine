import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../../core/theme/app_palette.dart';
import '../common/widgets.dart';

/// Shared keyboard-shortcuts surface used by Preferences and global search.
/// Keeping the editor in one widget prevents the two entry points from drifting
/// apart visually or functionally.
class KeyboardShortcutsPanel extends StatefulWidget {
  const KeyboardShortcutsPanel({super.key, this.compact = false, this.onClose});

  final bool compact;
  final VoidCallback? onClose;

  @override
  State<KeyboardShortcutsPanel> createState() => _KeyboardShortcutsPanelState();
}

class _KeyboardShortcutsPanelState extends State<KeyboardShortcutsPanel> {
  bool _editing = false;
  final Map<String, String> _shortcuts = <String, String>{
    'Open project': 'Ctrl+O',
    'Find module': 'Ctrl+Shift+M',
    'Increase interface scale': 'Ctrl++',
    'Decrease interface scale': 'Ctrl+-',
    'Reset interface scale': 'Ctrl+0',
  };

  static const Map<String, List<String>> _groups = <String, List<String>>{
    'WORKSPACE': <String>['Open project', 'Find module'],
    'INTERFACE': <String>[
      'Increase interface scale',
      'Decrease interface scale',
      'Reset interface scale',
    ],
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.compact) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.textKeyboardShortcuts358,
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.onClose != null)
              DesktopIconButton(
                onPressed: widget.onClose,
                icon: Icons.close,
                iconSize: 17,
                tooltip: context.l10n.textClose110,
              ),
          ],
        ),
        const SizedBox(height: 28),
      ],
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final group in _groups.entries) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 7),
                    child: Text(
                      context.hostLabel(group.key),
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ),
                for (final label in group.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _ShortcutSettingRow(
                      label: label,
                      shortcut: _shortcuts[label]!,
                      editing: _editing,
                      onChanged: (value) {
                        setState(() => _shortcuts[label] = value);
                        logI(
                          LogSource.settings,
                          'горячая клавиша «$label» → $value',
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 152),
          child: _ShortcutEditButton(
            editing: _editing,
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ),
      ),
    ],
  );
}

class _ShortcutSettingRow extends StatelessWidget {
  const _ShortcutSettingRow({
    required this.label,
    required this.shortcut,
    required this.editing,
    required this.onChanged,
  });

  final String label;
  final String shortcut;
  final bool editing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 62),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    decoration: BoxDecoration(
      color: context.palette.background.withAlpha(90),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.hostLabel(label),
            style: TextStyle(color: context.palette.text, fontSize: 14),
          ),
        ),
        const SizedBox(width: 14),
        _ShortcutCapture(
          value: shortcut,
          editing: editing,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _ShortcutEditButton extends StatelessWidget {
  const _ShortcutEditButton({required this.editing, required this.onPressed});

  final bool editing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DesktopIconButton(
    key: const ValueKey<String>('shortcut edit action'),
    icon: editing ? Icons.check : Icons.edit_outlined,
    tooltip: editing
        ? context.l10n.textDone229
        : context.l10n.textEditShortcuts359,
    label: editing
        ? context.l10n.textDone229
        : context.l10n.textEditShortcuts359,
    onPressed: onPressed,
    size: 30,
    iconSize: 14,
    active: editing,
  );
}

class _ShortcutCapture extends StatefulWidget {
  const _ShortcutCapture({
    required this.value,
    required this.editing,
    required this.onChanged,
  });

  final String value;
  final bool editing;
  final ValueChanged<String> onChanged;

  @override
  State<_ShortcutCapture> createState() => _ShortcutCaptureState();
}

class _ShortcutCaptureState extends State<_ShortcutCapture> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ShortcutCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final parts = <String>[];
    if (keyboard.isControlPressed) parts.add('Ctrl');
    if (keyboard.isAltPressed) parts.add('Alt');
    if (keyboard.isShiftPressed) parts.add('Shift');
    if (keyboard.isMetaPressed) parts.add('Meta');
    final modifiers = <LogicalKeyboardKey>{
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    };
    if (event.logicalKey.keyLabel.isNotEmpty &&
        !modifiers.contains(event.logicalKey)) {
      parts.add(event.logicalKey.keyLabel);
    }
    return parts.join('+');
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 184,
    height: 38,
    child: Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (!widget.editing || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final value = _formatKey(event);
        if (value.isNotEmpty) widget.onChanged(value);
        return KeyEventResult.handled;
      },
      child: TextField(
        controller: _controller,
        readOnly: true,
        enabled: widget.editing,
        onTap: widget.editing ? _focusNode.requestFocus : null,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: widget.editing ? context.l10n.textPressKeys360 : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: widget.editing
              ? context.palette.panel
              : Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        style: TextStyle(
          color: context.palette.text,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    ),
  );
}
