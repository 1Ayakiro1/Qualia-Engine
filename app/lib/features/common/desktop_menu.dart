import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import 'widgets.dart';
import 'desktop_focus.dart';
import 'navigation_bindings.dart';

/// Host menu entries use stable values; labels are localized by the caller.
class DesktopMenuEntry<T> {
  const DesktopMenuEntry({
    required this.value,
    required this.label,
    this.enabled = true,
    this.dividerBefore = false,
    this.shortcut,
    this.submenu,
    this.markerColor,
  });
  final T value;
  final String label;
  final bool enabled;
  final bool dividerBefore;
  final String? shortcut;
  final List<DesktopMenuEntry<T>>? submenu;
  final Color? markerColor;
}

/// Optional catalog search above fixed actions, using the same menu surface.
class DesktopMenuSearch<T> {
  const DesktopMenuSearch({
    required this.hint,
    required this.results,
    required this.emptyLabel,
  });
  final String hint;
  final String emptyLabel;
  final List<DesktopMenuEntry<T>> Function(String query) results;
}

/// One surface for top-bar, dropdown and right-click menus.
class DesktopMenuSurface<T> extends StatelessWidget {
  const DesktopMenuSurface({
    super.key,
    required this.entries,
    required this.onSelected,
    this.width = 240,
    this.itemHeight = 38,
    this.header,
    this.onEntryHover,
  });
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<DesktopMenuEntry<T>> onSelected;
  final double width;
  final double itemHeight;
  final Widget? header;
  final ValueChanged<DesktopMenuEntry<T>>? onEntryHover;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.panel,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: CallbackShortcuts(
          bindings: NavigationBindings.instance.callbacks({
            NavigationAction.menuDown: () =>
                FocusManager.instance.primaryFocus?.nextFocus(),
            NavigationAction.menuUp: () =>
                FocusManager.instance.primaryFocus?.previousFocus(),
          }),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?header,
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
                    child: MouseRegion(
                      onEnter: (_) => onEntryHover?.call(entry),
                      child: _MenuTile(
                        entry: entry,
                        itemHeight: itemHeight,
                        onTap: () => onSelected(entry),
                        autofocus:
                            header == null &&
                            entry ==
                                entries
                                    .where((item) => item.enabled)
                                    .firstOrNull,
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
          (entry.markerColor == null ? 0 : 22) +
          (entry.submenu == null ? 0 : 16),
    ),
  );
}

class _MenuTile<T> extends StatelessWidget {
  const _MenuTile({
    required this.entry,
    required this.onTap,
    required this.itemHeight,
    required this.autofocus,
  });
  final DesktopMenuEntry<T> entry;
  final VoidCallback onTap;
  final double itemHeight;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => DesktopHoverTile(
    keyboardFocusable: false,
    onTap: entry.enabled ? onTap : null,
    borderRadius: BorderRadius.circular(8),
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            NavigationBindings.instance.matches(
              NavigationAction.submenuOpen,
              event,
            ) &&
            entry.submenu != null &&
            entry.enabled) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DesktopFocusableAction(
        autofocus: autofocus,
        onActivate: entry.enabled ? onTap : null,
        label: entry.label,
        child: ExcludeFocus(
          child: TextButton(
            onPressed: entry.enabled ? onTap : null,
            style: TextButton.styleFrom(
              foregroundColor: context.palette.text,
              disabledForegroundColor: context.palette.mutedText,
              minimumSize: Size(0, itemHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 14),
            ),
            child: Row(
              children: [
                if (entry.markerColor != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.markerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(entry.label, overflow: TextOverflow.ellipsis),
                ),
                if (entry.shortcut != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
        ),
      ),
    ),
  );
}

Future<T?> showDesktopMenu<T>({
  required BuildContext context,
  required Offset position,
  required List<DesktopMenuEntry<T>> entries,
  double width = 240,
  double itemHeight = 38,
  DesktopMenuSearch<T>? search,
}) {
  return Navigator.of(context).push<T>(
    _DesktopMenuRoute<T>(
      position: position,
      entries: entries,
      width: desktopMenuWidth(context, entries, width),
      itemHeight: itemHeight,
      search: search,
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
    required this.itemHeight,
    this.search,
  });
  final Offset position;
  final List<DesktopMenuEntry<T>> entries;
  final double width;
  final CapturedThemes themes;
  final AppPalette palette;
  final double itemHeight;
  final DesktopMenuSearch<T>? search;
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
      child: _MenuPage<T>(
        position: position,
        entries: entries,
        width: width,
        itemHeight: itemHeight,
        search: search,
      ),
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
    required this.itemHeight,
    this.search,
  });
  final Offset position;
  final List<DesktopMenuEntry<T>> entries;
  final double width;
  final double itemHeight;
  final DesktopMenuSearch<T>? search;
  @override
  State<_MenuPage<T>> createState() => _MenuPageState<T>();
}

class _MenuPageState<T> extends State<_MenuPage<T>> {
  DesktopMenuEntry<T>? _submenu;
  String _query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final results = _query.trim().isEmpty
              ? <DesktopMenuEntry<T>>[]
              : widget.search?.results(_query) ?? [];
          final entries = _query.trim().isNotEmpty && widget.search != null
              ? results
              : widget.entries;
          final width = math.min(
            widget.width,
            math.max(0.0, bounds.maxWidth - 16),
          );
          final height = entries.fold<double>(
            widget.search == null
                ? 16
                : 76 + (_query.trim().isNotEmpty && results.isEmpty ? 38 : 0),
            (height, entry) =>
                height + widget.itemHeight + (entry.dividerBefore ? 8 : 0),
          );
          final left = widget.position.dx
              .clamp(8.0, math.max(8.0, bounds.maxWidth - width - 8))
              .toDouble();
          final top = widget.position.dy
              .clamp(
                8.0,
                math.max(
                  8.0,
                  bounds.maxHeight -
                      math.min(height, bounds.maxHeight - 16) -
                      8,
                ),
              )
              .toDouble();
          return CallbackShortcuts(
            bindings: NavigationBindings.instance.callbacks({
              NavigationAction.dismiss: () => _submenu == null
                  ? Navigator.pop(context)
                  : setState(() => _submenu = null),
              NavigationAction.submenuBack: () {
                if (_submenu != null) setState(() => _submenu = null);
              },
            }),
            child: Focus(
              canRequestFocus: false,
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
                        entries: entries,
                        width: width,
                        itemHeight: widget.itemHeight,
                        header: widget.search == null
                            ? null
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      key: const ValueKey(
                                        'desktop menu search',
                                      ),
                                      autofocus: true,
                                      onChanged: (value) => setState(() {
                                        _query = value;
                                        _submenu = null;
                                      }),
                                      onSubmitted: (_) {
                                        if (results.isNotEmpty) {
                                          Navigator.pop(
                                            context,
                                            results.first.value,
                                          );
                                        }
                                      },
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: widget.search!.hint,
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    if (_query.trim().isNotEmpty &&
                                        results.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          widget.search!.emptyLabel,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: context.palette.mutedText,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                        onSelected: (entry) {
                          if (entry.submenu != null) {
                            setState(() => _submenu = entry);
                          } else {
                            Navigator.pop(context, entry.value);
                          }
                        },
                        onEntryHover: (entry) {
                          final submenu = entry.enabled && entry.submenu != null
                              ? entry
                              : null;
                          if (_submenu != submenu) {
                            setState(() => _submenu = submenu);
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
                        child: FocusScope(
                          key: ValueKey(_submenu!.value),
                          child: DesktopMenuSurface<T>(
                            entries: _submenu!.submenu!,
                            width: width,
                            itemHeight: widget.itemHeight,
                            onSelected: (entry) =>
                                Navigator.pop(context, entry.value),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
    this.itemHeight = 38,
  });
  final String tooltip;
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final Widget child;
  final double width;
  final double itemHeight;
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
          itemHeight: itemHeight,
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
    this.showLabel = true,
  });
  final String label;
  final String valueLabel;
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final bool showLabel;
  @override
  Widget build(BuildContext context) => DesktopMenuButton<T>(
    tooltip: label,
    entries: entries,
    onSelected: onSelected,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: showLabel ? label : null,
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
