import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import 'widgets.dart';

/// Host menu entries use stable values; labels are localized by the caller.
class DesktopMenuEntry<T> {
  const DesktopMenuEntry({
    required this.value,
    required this.label,
    this.enabled = true,
    this.dividerBefore = false,
    this.shortcut,
    this.submenu,
  });
  final T value;
  final String label;
  final bool enabled;
  final bool dividerBefore;
  final String? shortcut;
  final List<DesktopMenuEntry<T>>? submenu;
}

/// One surface for top-bar, dropdown and right-click menus.
class DesktopMenuSurface<T> extends StatelessWidget {
  const DesktopMenuSurface({
    super.key,
    required this.entries,
    required this.onSelected,
    this.width = 240,
  });
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<DesktopMenuEntry<T>> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 5)),
      ],
    ),
    child: SingleChildScrollView(
      primary: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries) ...[
            if (entry.dividerBefore)
              Divider(
                height: 8,
                indent: 8,
                endIndent: 8,
                color: context.palette.hover,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _MenuTile(entry: entry, onTap: () => onSelected(entry)),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Fit translated labels and shortcut badges without reducing the font size.
double desktopMenuWidth<T>(
  BuildContext context,
  List<DesktopMenuEntry<T>> entries,
  double minimum,
) {
  double measure(String text) => (TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout()).width;
  return entries.fold<double>(
    minimum,
    (width, entry) => math.max(
      width,
      48 +
          measure(entry.label) +
          (entry.shortcut == null ? 0 : measure(entry.shortcut!) + 26) +
          (entry.submenu == null ? 0 : 16),
    ),
  );
}

class _MenuTile<T> extends StatelessWidget {
  const _MenuTile({required this.entry, required this.onTap});
  final DesktopMenuEntry<T> entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DesktopHoverTile(
    onTap: entry.enabled ? onTap : null,
    borderRadius: BorderRadius.circular(8),
    child: TextButton(
      onPressed: entry.enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor: context.palette.text,
        disabledForegroundColor: context.palette.mutedText,
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14),
      ),
      child: Row(
        children: [
          Expanded(child: Text(entry.label, overflow: TextOverflow.ellipsis)),
          if (entry.shortcut != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.palette.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.shortcut!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
          if (entry.submenu != null)
            Icon(
              Icons.chevron_right,
              size: 16,
              color: context.palette.mutedText,
            ),
        ],
      ),
    ),
  );
}

Future<T?> showDesktopMenu<T>({
  required BuildContext context,
  required Offset position,
  required List<DesktopMenuEntry<T>> entries,
  double width = 240,
}) {
  return Navigator.of(context).push<T>(
    _DesktopMenuRoute<T>(
      position: position,
      entries: entries,
      width: desktopMenuWidth(context, entries, width),
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context).context,
      ),
      palette: context.palette,
    ),
  );
}

class _DesktopMenuRoute<T> extends PopupRoute<T> {
  _DesktopMenuRoute({
    required this.position,
    required this.entries,
    required this.width,
    required this.themes,
    required this.palette,
  });
  final Offset position;
  final List<DesktopMenuEntry<T>> entries;
  final double width;
  final CapturedThemes themes;
  final AppPalette palette;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    AppThemeScope(
      palette: palette,
      child: _MenuPage<T>(position: position, entries: entries, width: width),
    ),
  );
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

class _MenuPage<T> extends StatefulWidget {
  const _MenuPage({
    required this.position,
    required this.entries,
    required this.width,
  });
  final Offset position;
  final List<DesktopMenuEntry<T>> entries;
  final double width;
  @override
  State<_MenuPage<T>> createState() => _MenuPageState<T>();
}

class _MenuPageState<T> extends State<_MenuPage<T>> {
  DesktopMenuEntry<T>? _submenu;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final width = math.min(
          widget.width,
          math.max(0.0, bounds.maxWidth - 16),
        );
        final height = widget.entries.fold<double>(
          16,
          (height, entry) => height + 38 + (entry.dividerBefore ? 8 : 0),
        );
        final left = widget.position.dx
            .clamp(8.0, math.max(8.0, bounds.maxWidth - width - 8))
            .toDouble();
        final top = widget.position.dy
            .clamp(
              8.0,
              math.max(
                8.0,
                bounds.maxHeight - math.min(height, bounds.maxHeight - 16) - 8,
              ),
            )
            .toDouble();
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(context),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(0, bounds.maxHeight - top - 8),
                    ),
                    child: DesktopMenuSurface<T>(
                      entries: widget.entries,
                      width: width,
                      onSelected: (entry) {
                        if (entry.submenu != null) {
                          setState(
                            () => _submenu = _submenu == entry ? null : entry,
                          );
                        } else {
                          Navigator.pop(context, entry.value);
                        }
                      },
                    ),
                  ),
                ),
                if (_submenu != null)
                  Positioned(
                    left: left + width * 2 + 5 < bounds.maxWidth
                        ? left + width + 5
                        : math.max(8, left - width - 5),
                    top: top,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(0, bounds.maxHeight - top - 8),
                      ),
                      child: DesktopMenuSurface<T>(
                        entries: _submenu!.submenu!,
                        width: width,
                        onSelected: (entry) =>
                            Navigator.pop(context, entry.value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class DesktopMenuButton<T> extends StatelessWidget {
  const DesktopMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    required this.child,
    this.width = 240,
  });
  final String tooltip;
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => DesktopTooltip(
    message: tooltip,
    child: DesktopHoverTile(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        final box = context.findRenderObject() as RenderBox;
        final value = await showDesktopMenu<T>(
          context: context,
          position: box.localToGlobal(Offset(0, box.size.height)),
          entries: entries,
          width: width,
        );
        if (value != null && context.mounted) onSelected(value);
      },
      child: child,
    ),
  );
}

/// Form-field variant with the same menu surface as toolbar actions.
class DesktopSelectField<T> extends StatelessWidget {
  const DesktopSelectField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.entries,
    required this.onSelected,
  });
  final String label;
  final String valueLabel;
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) => DesktopMenuButton<T>(
    tooltip: label,
    entries: entries,
    onSelected: onSelected,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              valueLabel,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );
}
