import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'navigation_bindings.dart';

/// Keyboard counterpart of a mouse action. One tab stop, visible focus and
/// standard activation, without changing the shared hover/selected styling.
class DesktopFocusableAction extends StatefulWidget {
  const DesktopFocusableAction({
    super.key,
    required this.onActivate,
    required this.child,
    this.label,
    this.autofocus = false,
    this.focusNode,
    this.onFocus,
    this.onContextMenu,
  });
  final VoidCallback? onActivate;
  final Widget child;
  final String? label;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onContextMenu;

  @override
  State<DesktopFocusableAction> createState() => _DesktopFocusableActionState();
}

class _DesktopFocusableActionState extends State<DesktopFocusableAction> {
  late final FocusNode _node = FocusNode(
    debugLabel: widget.label ?? 'desktop action',
  );
  @override
  void initState() {
    super.initState();
    NavigationBindings.instance.attach();
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      NavigationBindings.instance,
      widget.focusNode ?? _node,
    ]),
    builder: (context, _) => Semantics(
      button: true,
      enabled: widget.onActivate != null,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: widget.onActivate != null,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode ?? _node,
        shortcuts: {
          ...NavigationBindings.instance.activationShortcuts,
          if (widget.onContextMenu != null) ...{
            for (final key in NavigationBindings.instance.chords(
              NavigationAction.contextMenu,
            ))
              key.activator: const _ContextMenuIntent(),
          },
        },
        actions: {
          _ContextMenuIntent: CallbackAction<_ContextMenuIntent>(
            onInvoke: (_) {
              widget.onContextMenu?.call();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onActivate?.call();
              return null;
            },
          ),
        },
        onFocusChange: (focused) {
          if (!focused) return;
          widget.onFocus?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Scrollable.maybeOf(context) != null) {
              Scrollable.ensureVisible(
                context,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border:
                NavigationBindings.instance.keyboardMode &&
                    (widget.focusNode ?? _node).hasFocus
                ? Border.all(color: context.palette.mutedText)
                : null,
          ),
          // Foreground decoration keeps focus visible on opaque child surfaces.
          position: DecorationPosition.foreground,
          child: widget.child,
        ),
      ),
    ),
  );
}

class _ContextMenuIntent extends Intent {
  const _ContextMenuIntent();
}
