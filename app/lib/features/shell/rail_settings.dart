import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_state.dart';
import '../../l10n/module_strings.dart';
import '../../state/workspace_state.dart';
import '../../core/theme/app_palette.dart';
import 'nav_registry.dart';
import '../../core/modules/module_registry.dart';
import '../modules/module_ui.dart';
import '../common/widgets.dart';
import '../common/desktop_scroll.dart';
import '../common/desktop_menu.dart';

class RailConfiguration {
  const RailConfiguration({
    this.visible = true,
    this.sections = const {
      SectionId.profile,
      SectionId.extensions,
      SectionId.modules,
      SectionId.entity,
      SectionId.bugReport,
      SectionId.settings,
    },
    this.extensions = const {},
    this.order = const [],
    this.bottom = const {},
  });
  final bool visible;
  final Set<SectionId> sections;
  final Set<String> extensions;

  /// Stable host IDs; extension package IDs are namespaced separately.
  final List<String> order;
  final Set<String> bottom;
  List<String> get topKeys =>
      orderedKeys.where((key) => !bottom.contains(key)).toList();
  List<String> get bottomKeys => orderedKeys.where(bottom.contains).toList();

  List<String> get orderedKeys {
    final enabled = {
      for (final id in sections) sectionRailKey(id),
      for (final id in extensions) extensionRailKey(id),
    };
    return [
      ...{...order, ...defaultRailOrder, ...enabled}.where(enabled.contains),
    ];
  }
}

String sectionRailKey(SectionId id) => 'section:${id.name}';
String extensionRailKey(String id) => 'extension:$id';

final defaultRailOrder = [
  for (final id in [
    SectionId.profile,
    SectionId.extensions,
    SectionId.modules,
    SectionId.entity,
    SectionId.bugReport,
    ...SectionId.values.where((id) => id != SectionId.settings),
    SectionId.settings,
  ])
    sectionRailKey(id),
];

class RailController extends Notifier<RailConfiguration> {
  bool _disposed = false;
  bool _edited = false;
  @override
  RailConfiguration build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const RailConfiguration();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('qualia.rail.v1');
      if (raw == null || _disposed || _edited) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = RailConfiguration(
        visible: json['visible'] != false,
        sections: SectionId.values
            .where((id) => (json['sections'] as List).contains(id.name))
            .toSet(),
        extensions: Set<String>.from(json['extensions'] as List? ?? []),
        order: List<String>.from(json['order'] as List? ?? []),
        bottom: Set<String>.from(json['bottom'] as List? ?? []),
      );
    } catch (_) {
      /* Retain safe defaults if preferences are unavailable. */
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Read after await so overlapping edits cannot persist stale ordering.
      final raw = jsonEncode({
        'visible': state.visible,
        'sections': state.sections.map((id) => id.name).toList(),
        'extensions': state.extensions.toList(),
        'order': state.order,
        'bottom': state.bottom.toList(),
      });
      await prefs.setString('qualia.rail.v1', raw);
    } catch (_) {
      /* In-memory settings still work. */
    }
  }

  void setVisible(bool value) {
    _edited = true;
    state = RailConfiguration(
      visible: value,
      sections: state.sections,
      extensions: state.extensions,
      order: state.order,
      bottom: state.bottom,
    );
    unawaited(_save());
  }

  void setSection(SectionId id, bool enabled) {
    _edited = true;
    final sections = {...state.sections};
    enabled ? sections.add(id) : sections.remove(id);
    state = RailConfiguration(
      visible: state.visible,
      sections: sections,
      extensions: state.extensions,
      order: state.order,
      bottom: state.bottom,
    );
    unawaited(_save());
  }

  void setExtension(String id, bool enabled) {
    _edited = true;
    final extensions = {...state.extensions};
    enabled ? extensions.add(id) : extensions.remove(id);
    state = RailConfiguration(
      visible: state.visible,
      sections: state.sections,
      extensions: extensions,
      order: state.order,
      bottom: state.bottom,
    );
    unawaited(_save());
  }

  void setItem(String key, bool enabled) {
    if (key.startsWith('section:')) {
      final id = SectionId.values.where((id) => sectionRailKey(id) == key);
      if (id.isNotEmpty) setSection(id.first, enabled);
    } else if (key.startsWith('extension:')) {
      setExtension(key.substring('extension:'.length), enabled);
    }
  }

  /// [index] is an insertion slot in the pre-move visible ordering.
  void place(String key, int index, {bool? atBottom}) {
    final bottomZone = atBottom ?? state.bottom.contains(key);
    final keys = atBottom == null
        ? state.orderedKeys
        : (bottomZone ? state.bottomKeys : state.topKeys);
    final oldIndex = keys.indexOf(key);
    if (oldIndex >= 0 && oldIndex < index) index--;
    keys.remove(key);
    keys.insert(index.clamp(0, keys.length), key);
    setItem(key, true);
    state = RailConfiguration(
      visible: state.visible,
      sections: state.sections,
      extensions: state.extensions,
      order: List.unmodifiable(
        atBottom == null
            ? keys
            : [
                ...(bottomZone ? state.topKeys.where((id) => id != key) : keys),
                ...(bottomZone
                    ? keys
                    : state.bottomKeys.where((id) => id != key)),
              ],
      ),
      bottom: {...state.bottom.where((id) => id != key), if (bottomZone) key},
    );
    unawaited(_save());
  }
}

final railProvider = NotifierProvider<RailController, RailConfiguration>(
  RailController.new,
);

/// Full-window editor inside the shell's logical coordinate space: the panel,
/// rail and drag feedback all inherit the same UI scale and palette.
class RailCustomizer extends ConsumerStatefulWidget {
  const RailCustomizer({
    super.key,
    required this.railWidth,
    required this.gap,
    required this.feedbackScale,
    required this.onClose,
  });
  final double railWidth;
  final double gap;
  final double feedbackScale;
  final VoidCallback onClose;

  @override
  ConsumerState<RailCustomizer> createState() => _RailCustomizerState();
}

class _RailCustomizerState extends ConsumerState<RailCustomizer> {
  final _surface = GlobalKey();
  final _unusedHeader = GlobalKey();
  final _availablePanel = GlobalKey();
  final Map<String, GlobalKey> _railKeys = {};
  final Map<String, GlobalKey> _availableKeys = {};
  Rect? _flightFrom, _flightTo;
  RailEntry? _flying;
  int _flightNumber = 0;
  double get railWidth => widget.railWidth;
  double get gap => widget.gap;
  double get feedbackScale => widget.feedbackScale;
  VoidCallback get onClose => widget.onClose;

  Rect? _rect(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    final surface = _surface.currentContext?.findRenderObject();
    if (box is! RenderBox || surface is! RenderBox || !box.hasSize) return null;
    return Rect.fromPoints(
      surface.globalToLocal(box.localToGlobal(Offset.zero)),
      surface.globalToLocal(
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      ),
    );
  }

  void _remove(RailEntry entry, {Offset? from}) {
    final surface = _surface.currentContext?.findRenderObject() as RenderBox?;
    final origin = from != null && surface != null
        ? surface.globalToLocal(from) & const Size(40, 40)
        : _rect(_railKeys[entry.id]);
    ref.read(railProvider.notifier).setItem(entry.id, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || origin == null) return;
      final panel = _rect(_availablePanel);
      final item = _rect(_availableKeys[entry.id]);
      final destination =
          item != null && panel != null && panel.contains(item.center)
          ? item
          : _rect(_unusedHeader) ?? panel;
      if (destination == null) return;
      setState(() {
        _flightFrom = Rect.fromCenter(
          center: origin.center,
          width: 40,
          height: 40,
        );
        _flightTo = Rect.fromCenter(
          center: Offset(destination.left + 24, destination.center.dy),
          width: 40,
          height: 40,
        );
        _flying = entry;
        _flightNumber++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(railProvider);
    final controller = ref.read(railProvider.notifier);
    final entries = railEntries(context, ref.watch(workspaceProvider).library);
    final byKey = {for (final entry in entries) entry.id: entry};
    final keys = config.orderedKeys.where(byKey.containsKey).toList();
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: FocusScope(
        key: _surface,
        autofocus: true,
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final left = gap + railWidth + 12;
              final panelWidth = math.min(
                320.0,
                constraints.maxWidth - left - gap,
              );
              return Stack(
                key: const ValueKey('rail customization overlay'),
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('rail customization scrim'),
                      onTap: onClose,
                      child: ColoredBox(color: Colors.black.withAlpha(160)),
                    ),
                  ),
                  Positioned(
                    left: gap,
                    top: 36 + gap,
                    bottom: gap,
                    width: railWidth,
                    child: DesktopPane(
                      color: context.palette.background,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          DesktopIconButton(
                            icon: AppIcons.check,
                            tooltip: context.l10n.textDone229,
                            size: 36,
                            iconSize: 19,
                            onPressed: onClose,
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: _RailEditList(
                              entries: [
                                for (final key in config.topKeys.where(
                                  byKey.containsKey,
                                ))
                                  byKey[key]!,
                              ],
                              onPlace: (id, index) =>
                                  controller.place(id, index, atBottom: false),
                              onRemove: (id) => _remove(byKey[id]!),
                              itemKeys: _railKeys,
                              feedbackScale: feedbackScale,
                            ),
                          ),
                          DesktopTooltip(
                            message: context.l10n.railBottomZone,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Icon(
                                AppIcons.toBottom,
                                size: 16,
                                color: context.palette.mutedText,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                64,
                                (constraints.maxHeight - 150) * .45,
                              ),
                            ),
                            child: SizedBox(
                              height: math.max(
                                64,
                                config.bottomKeys.length * 44.0 + 20,
                              ),
                              child: _RailEditList(
                                zoneKey: 'bottom',
                                entries: [
                                  for (final key in config.bottomKeys.where(
                                    byKey.containsKey,
                                  ))
                                    byKey[key]!,
                                ],
                                onPlace: (id, index) =>
                                    controller.place(id, index, atBottom: true),
                                onRemove: (id) => _remove(byKey[id]!),
                                itemKeys: _railKeys,
                                feedbackScale: feedbackScale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: 36 + gap,
                    height: math.min(
                      680.0,
                      constraints.maxHeight - 36 - gap * 2,
                    ),
                    width: panelWidth,
                    child: DragTarget<String>(
                      key: _availablePanel,
                      onWillAcceptWithDetails: (details) =>
                          keys.contains(details.data),
                      onAcceptWithDetails: (details) =>
                          _remove(byKey[details.data]!, from: details.offset),
                      builder: (context, candidates, _) => DesktopPane(
                        color: candidates.isNotEmpty
                            ? context.palette.hover
                            : context.palette.panel,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.l10n.textRailSettings129,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DesktopIconButton(
                                    icon: AppIcons.close,
                                    tooltip:
                                        context.l10n.textCloseRailSettings221,
                                    onPressed: onClose,
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                context.l10n.railDragHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: context.palette.mutedText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                key: const ValueKey('rail settings scroll'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                children: [
                                  Padding(
                                    key: _unusedHeader,
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      4,
                                      10,
                                      8,
                                    ),
                                    child: Text(
                                      context.l10n.railUnusedItems,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.palette.mutedText,
                                      ),
                                    ),
                                  ),
                                  for (final entry in entries.where(
                                    (entry) => !keys.contains(entry.id),
                                  ))
                                    _RailDragItem(
                                      key: _availableKeys.putIfAbsent(
                                        entry.id,
                                        GlobalKey.new,
                                      ),
                                      entry: entry,
                                      compact: false,
                                      enabled: keys.contains(entry.id),
                                      feedbackScale: feedbackScale,
                                      onToggle: () =>
                                          controller.setItem(entry.id, true),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      16,
                                      10,
                                      8,
                                    ),
                                    child: Text(
                                      context.l10n.railUsedItems,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.palette.mutedText,
                                      ),
                                    ),
                                  ),
                                  for (final key in keys)
                                    _RailDragItem(
                                      entry: byKey[key]!,
                                      compact: false,
                                      enabled: true,
                                      feedbackScale: feedbackScale,
                                      onToggle: () => _remove(byKey[key]!),
                                      onPin: () => controller.place(
                                        key,
                                        config.bottom.contains(key)
                                            ? config.topKeys.length
                                            : config.bottomKeys.length,
                                        atBottom: !config.bottom.contains(key),
                                      ),
                                      atBottom: config.bottom.contains(key),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: DesktopHoverTile(
                                key: const ValueKey('rail setting Show rail'),
                                onTap: () =>
                                    controller.setVisible(!config.visible),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        config.visible
                                            ? AppIcons.eye
                                            : AppIcons.eyeOff,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          context.l10n.textShowRail223,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Icon(
                                        config.visible
                                            ? AppIcons.check
                                            : AppIcons.add,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                context
                                    .l10n
                                    .textChangesAreSavedAutomatically228,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.palette.mutedText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_flying != null &&
                      _flightFrom != null &&
                      _flightTo != null)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('rail return flight $_flightNumber'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeInOutCubic,
                      onEnd: () {
                        if (mounted) setState(() => _flying = null);
                      },
                      builder: (context, t, _) {
                        final rect = Rect.lerp(_flightFrom, _flightTo, t)!;
                        return Positioned.fromRect(
                          rect: rect,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 1 - t * .45,
                              child: Transform.scale(
                                scale: 1 - t * .25,
                                child: Material(
                                  color: context.palette.hover,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Icon(
                                    _flying!.icon,
                                    size: 20,
                                    color: context.palette.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class RailEntry {
  const RailEntry(this.id, this.label, this.icon, {this.section, this.module});
  final String id;
  final String label;
  final IconData icon;
  final SectionId? section;
  final SystemModule? module;
}

List<RailEntry> railEntries(BuildContext context, List<SystemModule> library) =>
    [
      RailEntry(
        sectionRailKey(SectionId.profile),
        context.l10n.textProfile75,
        AppIcons.userCircle,
        section: SectionId.profile,
      ),
      for (final section in kNavSections)
        RailEntry(
          sectionRailKey(section.id),
          context.hostLabel(section.label),
          section.icon,
          section: section.id,
        ),
      for (final module in library.where(
        (m) => m.manifest['kind'] == 'extension' && m.manifest['rail'] is Map,
      ))
        RailEntry(
          extensionRailKey(module.id),
          module.displayName(context),
          extensionRailIcon(module),
          module: module,
        ),
    ];

class _RailEditList extends StatefulWidget {
  const _RailEditList({
    required this.entries,
    required this.onPlace,
    required this.onRemove,
    required this.feedbackScale,
    required this.itemKeys,
    this.zoneKey = 'top',
  });
  final List<RailEntry> entries;
  final void Function(String, int) onPlace;
  final ValueChanged<String> onRemove;
  final double feedbackScale;
  final Map<String, GlobalKey> itemKeys;
  final String zoneKey;
  @override
  State<_RailEditList> createState() => _RailEditListState();
}

class _RailEditListState extends State<_RailEditList> {
  final _scroll = DesktopScrollController(debugLabel: 'rail customization');
  int? _slot;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    key: ValueKey('rail ${widget.zoneKey} drop zone'),
    onWillAcceptWithDetails: (_) => true,
    onMove: (details) {
      final box = context.findRenderObject() as RenderBox;
      final y = box.globalToLocal(details.offset).dy + _scroll.offset;
      final slot = (y / 44).round().clamp(0, widget.entries.length);
      if (_slot != slot) setState(() => _slot = slot);
      // Edge scrolling also makes a full rail editable on short windows.
      final localY = y - _scroll.offset;
      final delta = localY < 32
          ? -14.0
          : localY > box.size.height - 32
          ? 14.0
          : 0.0;
      if (delta != 0 && _scroll.hasClients) {
        _scroll.jumpTo(
          (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    },
    onLeave: (_) => setState(() => _slot = null),
    onAcceptWithDetails: (details) {
      widget.onPlace(details.data, _slot ?? widget.entries.length);
      setState(() => _slot = null);
    },
    builder: (context, candidates, _) => ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 44),
      children: [
        SizedBox(
          height: widget.entries.length * 44.0 + 20,
          child: Stack(
            children: [
              if (candidates.isNotEmpty && _slot != null)
                AnimatedPositioned(
                  key: const ValueKey('rail insertion'),
                  duration: const Duration(milliseconds: 160),
                  top: _slot! * 44.0,
                  left: 8,
                  right: 8,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.palette.hover,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              for (var i = 0; i < widget.entries.length; i++)
                AnimatedPositioned(
                  key: ValueKey(widget.entries[i].id),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  top:
                      i * 44.0 +
                      (candidates.isNotEmpty && _slot != null && i >= _slot!
                          ? 20
                          : 0),
                  left: 0,
                  right: 0,
                  height: 44,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.arrowUp,
                        alt: true,
                      ): () =>
                          widget.onPlace(widget.entries[i].id, i - 1),
                      const SingleActivator(
                        LogicalKeyboardKey.arrowDown,
                        alt: true,
                      ): () =>
                          widget.onPlace(widget.entries[i].id, i + 2),
                      const SingleActivator(LogicalKeyboardKey.delete): () =>
                          widget.onRemove(widget.entries[i].id),
                    },
                    child: _RailDragItem(
                      key: widget.itemKeys.putIfAbsent(
                        widget.entries[i].id,
                        GlobalKey.new,
                      ),
                      entry: widget.entries[i],
                      compact: true,
                      enabled: true,
                      feedbackScale: widget.feedbackScale,
                      onToggle: () => widget.onRemove(widget.entries[i].id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RailDragItem extends StatelessWidget {
  const _RailDragItem({
    super.key,
    required this.entry,
    required this.compact,
    required this.enabled,
    required this.onToggle,
    required this.feedbackScale,
    this.onPin,
    this.atBottom = false,
  });
  final RailEntry entry;
  final bool compact;
  final bool enabled;
  final VoidCallback onToggle;
  final double feedbackScale;
  final VoidCallback? onPin;
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    final tile = compact
        ? DesktopTooltip(
            message: entry.label,
            child: DesktopHoverTile(
              label: entry.label,
              onTap: onToggle,
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Icon(
                    entry.icon,
                    size: 20,
                    color: context.palette.text,
                  ),
                ),
              ),
            ),
          )
        : DesktopHoverTile(
            key: ValueKey('rail setting ${entry.label}'),
            label: entry.label,
            onTap: onToggle,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 20,
                      color: context.palette.mutedText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.label,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onPin != null)
                      DesktopIconButton(
                        icon: atBottom ? AppIcons.toTop : AppIcons.toBottom,
                        tooltip: atBottom
                            ? context.l10n.railPinTop
                            : context.l10n.railPinBottom,
                        onPressed: onPin,
                        size: 28,
                        iconSize: 16,
                      ),
                    Icon(
                      enabled ? AppIcons.check : AppIcons.add,
                      size: 18,
                      color: context.palette.mutedText,
                    ),
                  ],
                ),
              ),
            ),
          );
    return GestureDetector(
      onSecondaryTapDown: compact
          ? (details) async {
              final scope = ProviderScope.containerOf(context);
              final config = scope.read(railProvider);
              final atBottom = config.bottom.contains(entry.id);
              final action = await showDesktopMenu<String>(
                context: context,
                position: details.globalPosition,
                entries: [
                  DesktopMenuEntry(
                    value: 'pin',
                    label: atBottom
                        ? context.l10n.railPinTop
                        : context.l10n.railPinBottom,
                  ),
                ],
              );
              if (action == 'pin') {
                scope
                    .read(railProvider.notifier)
                    .place(
                      entry.id,
                      atBottom
                          ? config.topKeys.length
                          : config.bottomKeys.length,
                      atBottom: !atBottom,
                    );
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: LongPressDraggable<String>(
          key: ValueKey(
            '${compact ? 'rail edit' : 'rail available'} ${entry.id}',
          ),
          data: entry.id,
          delay: const Duration(milliseconds: 160),
          maxSimultaneousDrags: 1,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Transform.scale(
            scale: feedbackScale,
            alignment: Alignment.topLeft,
            child: _RailDragFeedback(entry: entry),
          ),
          childWhenDragging: Opacity(opacity: .25, child: tile),
          child: MouseRegion(cursor: SystemMouseCursors.grab, child: tile),
        ),
      ),
    );
  }
}

/// Only the held button wiggles; normal editing doesn't run endless animations.
class _RailDragFeedback extends StatefulWidget {
  const _RailDragFeedback({required this.entry});
  final RailEntry entry;
  @override
  State<_RailDragFeedback> createState() => _RailDragFeedbackState();
}

class _RailDragFeedbackState extends State<_RailDragFeedback>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) =>
        Transform.rotate(angle: (_animation.value - .5) * .09, child: child),
    child: Material(
      color: context.palette.panel,
      elevation: 8,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(widget.entry.icon, size: 20, color: context.palette.text),
      ),
    ),
  );
}

/// Icon names are allowlisted rather than constructing fonts from remote data.
IconData extensionRailIcon(SystemModule module) {
  final rail = module.manifest['rail'] as Map?;
  return switch (rail?['icon']) {
    'chart' => AppIcons.chart,
    'notes' => AppIcons.note,
    'signal' => AppIcons.waveform,
    'folder' => AppIcons.folderOpen,
    'brain' => AppIcons.brain,
    _ => AppIcons.grid,
  };
}

class ExtensionRailPage extends StatefulWidget {
  const ExtensionRailPage({
    super.key,
    required this.module,
    required this.onBack,
  });
  final SystemModule module;
  final VoidCallback onBack;
  @override
  State<ExtensionRailPage> createState() => _ExtensionRailPageState();
}

class _ExtensionRailPageState extends State<ExtensionRailPage> {
  final _values = <String, dynamic>{};
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.background,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            DesktopIconButton(
              icon: AppIcons.arrowBack,
              tooltip: context.l10n.textBack233,
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 10),
            Text(
              widget.module.displayName(context),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(widget.module.displayDescription(context)),
        const SizedBox(height: 20),
        ModuleControls(
          localizePreview: widget.module.isLocalPreview,
          schema: widget.module.manifest['ui'] is List
              ? widget.module.manifest['ui'] as List
              : const [],
          values: _values,
          onChanged: (key, value) => setState(() => _values[key] = value),
        ),
      ],
    ),
  );
}
