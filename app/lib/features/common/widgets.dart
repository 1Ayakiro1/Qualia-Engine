import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import 'desktop_menu.dart';
import 'desktop_focus.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// Tooltip used by desktop controls throughout the shell.
///
/// Flutter's default tooltip surface follows the platform theme and can turn
/// white even while the rest of the application is dark. Keeping this in the
/// shared widgets file makes rail, topbar and explorer controls identical.
class DesktopTooltip extends StatelessWidget {
  const DesktopTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    waitDuration: const Duration(seconds: 1),
    showDuration: const Duration(seconds: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    textStyle: TextStyle(color: context.palette.text, fontSize: 14),
    child: child,
  );
}

/// Shared surface for the rounded desktop panes used by split workspaces.
class DesktopPane extends StatelessWidget {
  const DesktopPane({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.color,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Pane fill; defaults to the palette panel color of the current theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? context.palette.panel,
      borderRadius: borderRadius,
    );
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

/// Shared desktop resize handle for rail, explorer and split panes.
class DesktopResizeHandle extends StatefulWidget {
  const DesktopResizeHandle({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  State<DesktopResizeHandle> createState() => _DesktopResizeHandleState();
}

class _DesktopResizeHandleState extends State<DesktopResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
      child: SizedBox(
        width: 8,
        child: Center(
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.hoverCurve,
            width: _hovered ? 2 : 1,
            height: _hovered ? 34 : 20,
            decoration: BoxDecoration(
              color: _hovered
                  ? context.palette.mutedText
                  : context.palette.mutedText.withAlpha(110),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Interactive tile with the shell's unified hover behavior.
///
/// List rows and menu triggers used to rely on ink highlights that snap in
/// instantly. This tile cross-fades its background over the shared hover
/// duration instead, so every interactive element eases in and out equally.
class DesktopHoverTile extends StatefulWidget {
  const DesktopHoverTile({
    super.key,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.color,
    this.selectedColor,
    this.hoverColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.cursor = SystemMouseCursors.click,
    this.keyboardFocusable = true,
    this.focusNode,
    this.label,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool selected;

  /// Resting fill; defaults to the hover tint faded to zero alpha so the
  /// transition animates alpha only and never flashes muddy.
  final Color? color;

  /// Fill of the selected state; defaults to the palette background.
  final Color? selectedColor;

  /// Fill of the hover state; defaults to the palette hover tint.
  final Color? hoverColor;
  final BorderRadius borderRadius;
  final MouseCursor cursor;
  final bool keyboardFocusable;
  final FocusNode? focusNode;
  final String? label;

  @override
  State<DesktopHoverTile> createState() => _DesktopHoverTileState();
}

class _DesktopHoverTileState extends State<DesktopHoverTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tile = MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.hoverCurve,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.hoverColor ?? palette.hover
                : widget.selected
                ? widget.selectedColor ?? palette.background
                : widget.color ?? palette.hover.withAlpha(0),
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
    return widget.keyboardFocusable
        ? DesktopFocusableAction(
            onActivate: widget.onTap,
            focusNode: widget.focusNode,
            label: widget.label,
            child: tile,
          )
        : tile;
  }
}

/// Cross-fades a color over the shared hover duration.
///
/// Used for icon and text colors that follow hover state: they fade together
/// with the background instead of switching a frame earlier.
class DesktopColorTransition extends StatelessWidget {
  const DesktopColorTransition({
    super.key,
    required this.color,
    required this.builder,
  });

  final Color color;
  final Widget Function(BuildContext context, Color color) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(begin: color, end: color),
    duration: AppTheme.hoverDuration,
    curve: AppTheme.hoverCurve,
    builder: (context, animatedColor, _) =>
        builder(context, animatedColor ?? color),
  );
}

/// Compact rectangular desktop action control shared by toolbars, tabs and
/// dialogs. It deliberately avoids IconButton's circular splash/hover halo.
class DesktopIconButton extends StatefulWidget {
  const DesktopIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 30,
    this.iconSize = 17,
    this.active = false,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool active;
  final String? label;

  @override
  State<DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<DesktopIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color iconColor = widget.onPressed == null
        ? palette.mutedText.withAlpha(120)
        : _hovered || widget.active
        ? palette.text
        : palette.mutedText;
    final Color labelColor = widget.onPressed == null
        ? palette.mutedText.withAlpha(120)
        : palette.text;
    return DesktopFocusableAction(
      onActivate: widget.onPressed,
      label: widget.tooltip,
      child: DesktopTooltip(
        message: widget.tooltip,
        child: MouseRegion(
          cursor: widget.onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Semantics(
            button: true,
            enabled: widget.onPressed != null,
            label: widget.tooltip,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: AppTheme.hoverDuration,
                curve: AppTheme.hoverCurve,
                width: widget.label == null ? widget.size : null,
                height: widget.size,
                alignment: Alignment.center,
                padding: widget.label == null
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _hovered || widget.active
                      ? palette.hover
                      : palette.hover.withAlpha(0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DesktopColorTransition(
                      color: iconColor,
                      builder: (context, color) => Icon(
                        widget.icon,
                        size: widget.iconSize,
                        color: color,
                      ),
                    ),
                    if (widget.label case final label?) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: DesktopColorTransition(
                          color: labelColor,
                          builder: (context, color) => Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact vertical explorer section heading with a shared disclosure arrow.
class ExplorerSectionHeader extends StatefulWidget {
  const ExplorerSectionHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<ExplorerSectionHeader> createState() => _ExplorerSectionHeaderState();
}

class _ExplorerSectionHeaderState extends State<ExplorerSectionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => DesktopFocusableAction(
    onActivate: widget.onToggle,
    label: widget.title,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.hoverCurve,
          decoration: BoxDecoration(
            color: _hovered
                ? context.palette.hover
                : context.palette.hover.withAlpha(0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
            child: Row(
              children: [
                Icon(
                  widget.expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: context.palette.text,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.text,
                      fontSize: 11,
                      letterSpacing: .8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A consistent disclosure block used by all Explorer-style sidebars.
///
/// The section deliberately changes state immediately: Explorer sections are
/// layout controls, not buttons, so they do not use ripple or press animation.
class ExplorerDisclosureSection extends StatelessWidget {
  const ExplorerDisclosureSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.showDivider = true,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExplorerSectionHeader(
        title: title,
        expanded: expanded,
        onToggle: onToggle,
      ),
      if (expanded) ...children,
      if (showDivider) const Divider(height: 1),
    ],
  );
}

/// Reusable floating context menu matching the shell's File/View menus.
class DesktopContextMenu extends StatefulWidget {
  const DesktopContextMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
    required this.child,
    this.menuWidth = 220,
    this.menuOffset = const Offset(0, 32),
  });

  final String tooltip;
  final List<String> actions;
  final ValueChanged<String> onSelected;
  final Widget child;
  final double menuWidth;
  final Offset menuOffset;

  @override
  State<DesktopContextMenu> createState() => _DesktopContextMenuState();
}

class _DesktopContextMenuState extends State<DesktopContextMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _menuFocusNode = FocusNode(
    debugLabel: 'Extension context menu',
  );
  late final AnimationController _animationController;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _menuFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() => _overlayEntry == null ? _open() : _close();

  void _open() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Focus(
        focusNode: _menuFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: widget.menuOffset,
              child: Align(
                alignment: Alignment.topLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: DesktopMenuSurface<String>(
                      width: desktopMenuWidth(context, [
                        for (final action in widget.actions)
                          DesktopMenuEntry(
                            value: action,
                            label: context.hostLabel(action),
                          ),
                      ], widget.menuWidth),
                      entries: [
                        for (final action in widget.actions)
                          DesktopMenuEntry(
                            value: action,
                            label: context.hostLabel(action),
                          ),
                      ],
                      onSelected: (entry) {
                        widget.onSelected(entry.value);
                        _close();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
    _menuFocusNode.requestFocus();
    _animationController.forward(from: 0);
    setState(() {});
  }

  void _close() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    _animationController.reverse().whenCompleteOrCancel(() {
      entry.remove();
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: DesktopTooltip(
      message: widget.tooltip,
      child: DesktopHoverTile(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(6),
        child: widget.child,
      ),
    ),
  );
}

/// Small colored status indicator with a label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null
          ? Icon(icon, size: 16, color: color)
          : CircleAvatar(radius: 5, backgroundColor: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Card with a title header, used across screens.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.headerIcon,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final IconData? headerIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trailing == null)
              _InfoCardTitle(title: title, headerIcon: headerIcon, theme: theme)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 460) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoCardTitle(
                          title: title,
                          headerIcon: headerIcon,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 4, children: [trailing!]),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _InfoCardTitle(
                          title: title,
                          headerIcon: headerIcon,
                          theme: theme,
                        ),
                      ),
                      trailing!,
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoCardTitle extends StatelessWidget {
  const _InfoCardTitle({
    required this.title,
    required this.headerIcon,
    required this.theme,
  });

  final String title;
  final IconData? headerIcon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (headerIcon != null) ...[
        Icon(headerIcon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
      ],
      Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
    ],
  );
}

/// Key-value line used inside InfoCard.
class KeyValue extends StatelessWidget {
  const KeyValue({super.key, required this.keyLabel, required this.value});

  final String keyLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Text(
              keyLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Empty/placeholder state for future features.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.note,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Compact metric tile (label + value) used on the session screen.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Section header used on top of screen content.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
