import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_info.dart';
import '../../core/logging/log_window.dart';
import '../../core/modules/module_registry.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../datasets/datasets_screen.dart';
import '../developer/developer_screen.dart';
import '../devices/devices_screen.dart';
import '../models/models_screen.dart';
import '../modules/modules_screen.dart';
import '../pipeline/pipeline_screen.dart';
import '../session/session_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_screen.dart';
import 'layout_model.dart';
import 'nav_registry.dart';

IconData _phosphorFor(SectionId id) {
  switch (id) {
    case SectionId.dashboard:
      return Icons.grid_view_outlined;
    case SectionId.devices:
      return Icons.usb_outlined;
    case SectionId.session:
      return Icons.radio_button_checked_outlined;
    case SectionId.pipeline:
      return Icons.account_tree_outlined;
    case SectionId.spectrogram:
      return Icons.graphic_eq;
    case SectionId.modules:
      return Icons.extension_outlined;
    case SectionId.datasets:
      return Icons.folder_open_outlined;
    case SectionId.models:
      return Icons.psychology_outlined;
    case SectionId.developer:
      return Icons.terminal;
    case SectionId.profile:
      return Icons.account_circle_outlined;
    case SectionId.settings:
      return Icons.settings_outlined;
  }
}

/// Desktop IDE-like shell. Navigation is deliberately split into a compact
/// activity rail and an Explorer pane so the work area stays uncluttered.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool terminalOpen = true;
  bool modeSwitcherOpen = false;
  String settingsItem = 'General';
  bool _debugConsoleVisible = false;

  /// User-facing scale. The shell deliberately renders at a 120% base density
  /// while keeping this preference at the familiar 100% default.
  double uiScale = 1.0;
  ShellLayoutConfig layout = const ShellLayoutConfig.defaults();

  static const double _minScale = 0.8;
  static const double _maxScale = 1.5;
  static const double _baseScale = 1.2;
  static const double _scaleStep = 0.1;
  static const double _minExplorerWidth = 180;
  static const double _maxExplorerWidth = 520;

  double get _visualScale => uiScale * _baseScale;

  void _changeScale(double delta) {
    setState(() {
      uiScale = (uiScale + delta).clamp(_minScale, _maxScale).toDouble();
    });
  }

  void _resetScale() => setState(() => uiScale = 1.0);

  Future<void> _openDebugConsole(BuildContext context) async {
    if (!mounted) return;
    setState(() => _debugConsoleVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final section = ref.watch(navSectionProvider);
    final sections = visibleSections(mode);
    final selected = sections.indexWhere((item) => item.id == section);
    final active = selected < 0 ? sections.first : sections[selected];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _changeScale(_scaleStep),
        const SingleActivator(LogicalKeyboardKey.add, control: true): () =>
            _changeScale(_scaleStep),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _changeScale(-_scaleStep),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            _resetScale,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final visualScale = _visualScale;
            final width = constraints.maxWidth / visualScale;
            final height = constraints.maxHeight / visualScale;
            final bounds = _explorerWidthBounds(width);
            final effectiveExplorerWidth = layout.explorerWidth
                .clamp(bounds.$1, bounds.$2)
                .toDouble();
            final mediaQuery = MediaQuery.of(context);
            final logicalMediaQuery = mediaQuery.copyWith(
              size: Size(width, height),
              padding: mediaQuery.padding / visualScale,
              viewPadding: mediaQuery.viewPadding / visualScale,
              viewInsets: mediaQuery.viewInsets / visualScale,
            );
            return ColoredBox(
              color: AppTheme.background,
              child: ClipRect(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Transform.scale(
                      scale: visualScale,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: MediaQuery(
                          data: logicalMediaQuery,
                          child: Scaffold(
                            body: Column(
                              children: [
                                _TitleBar(
                                  compact: width < 1050,
                                  onOpenDebugConsole: () =>
                                      _openDebugConsole(context),
                                  scale: uiScale,
                                  onScaleChanged: (value) =>
                                      setState(() => uiScale = value),
                                  onOpenPreferences: () => setState(() {
                                    settingsItem = 'General';
                                    ref
                                        .read(navSectionProvider.notifier)
                                        .select(SectionId.settings);
                                  }),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: section == SectionId.profile
                                            ? ProfileScreen(
                                                onBack: () => ref
                                                    .read(
                                                      navSectionProvider
                                                          .notifier,
                                                    )
                                                    .select(
                                                      SectionId.dashboard,
                                                    ),
                                              )
                                            : section == SectionId.settings
                                            ? SettingsScreen(
                                                initialItem: settingsItem,
                                                onBack: () => ref
                                                    .read(
                                                      navSectionProvider
                                                          .notifier,
                                                    )
                                                    .select(
                                                      SectionId.dashboard,
                                                    ),
                                              )
                                            : Padding(
                                                padding: EdgeInsets.all(
                                                  layout.gap,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        _ShellSurface(
                                                          width:
                                                              layout.railWidth,
                                                          radius: layout.radius,
                                                          child: _ActivityRail(
                                                            sections: sections,
                                                            selected:
                                                                selected < 0
                                                                ? 0
                                                                : selected,
                                                            modeSwitcherOpen:
                                                                modeSwitcherOpen,
                                                            onModeSwitcher:
                                                                () => setState(
                                                                  () => modeSwitcherOpen =
                                                                      !modeSwitcherOpen,
                                                                ),
                                                            onNavigate: (id) {
                                                              if (id ==
                                                                  SectionId
                                                                      .settings) {
                                                                settingsItem =
                                                                    'General';
                                                              }
                                                              final target =
                                                                  kNavSections
                                                                      .firstWhere(
                                                                        (
                                                                          item,
                                                                        ) =>
                                                                            item.id ==
                                                                            id,
                                                                      );
                                                              if (!target
                                                                  .visibleIn(
                                                                    mode,
                                                                  )) {
                                                                final nextMode =
                                                                    target.modes
                                                                        .contains(
                                                                          AppMode
                                                                              .researcher,
                                                                        )
                                                                    ? AppMode
                                                                          .researcher
                                                                    : AppMode
                                                                          .developer;
                                                                ref
                                                                    .read(
                                                                      appModeProvider
                                                                          .notifier,
                                                                    )
                                                                    .setMode(
                                                                      nextMode,
                                                                    );
                                                              }
                                                              ref
                                                                  .read(
                                                                    navSectionProvider
                                                                        .notifier,
                                                                  )
                                                                  .select(id);
                                                            },
                                                            onProfile: () => ref
                                                                .read(
                                                                  navSectionProvider
                                                                      .notifier,
                                                                )
                                                                .select(
                                                                  SectionId
                                                                      .profile,
                                                                ),
                                                          ),
                                                        ),
                                                        _LayoutDivider(
                                                          onDrag: (delta) => setState(() {
                                                            layout = layout.copyWith(
                                                              railWidth:
                                                                  (layout.railWidth +
                                                                          delta)
                                                                      .clamp(
                                                                        40,
                                                                        96,
                                                                      )
                                                                      .toDouble(),
                                                            );
                                                          }),
                                                        ),
                                                        _ShellSurface(
                                                          width:
                                                              effectiveExplorerWidth,
                                                          radius: layout.radius,
                                                          child: _Explorer(
                                                            width:
                                                                effectiveExplorerWidth,
                                                            sections: sections,
                                                            selected:
                                                                selected < 0
                                                                ? 0
                                                                : selected,
                                                            onSelected: (index) => ref
                                                                .read(
                                                                  navSectionProvider
                                                                      .notifier,
                                                                )
                                                                .select(
                                                                  sections[index]
                                                                      .id,
                                                                ),
                                                          ),
                                                        ),
                                                        _LayoutDivider(
                                                          key:
                                                              const ValueKey<
                                                                String
                                                              >(
                                                                'explorer resize handle',
                                                              ),
                                                          onDrag: (delta) =>
                                                              _resizeExplorer(
                                                                delta,
                                                                width,
                                                              ),
                                                        ),
                                                        Expanded(
                                                          child: _ShellSurface(
                                                            radius:
                                                                layout.radius,
                                                            child: Column(
                                                              children: [
                                                                _EditorTabs(
                                                                  active:
                                                                      active,
                                                                ),
                                                                Expanded(
                                                                  child: _SectionBody(
                                                                    section:
                                                                        active
                                                                            .id,
                                                                  ),
                                                                ),
                                                                _TerminalPanel(
                                                                  open:
                                                                      terminalOpen,
                                                                  onToggle: () =>
                                                                      setState(
                                                                        () => terminalOpen =
                                                                            !terminalOpen,
                                                                      ),
                                                                  onOpenWindow: () =>
                                                                      _openDebugConsole(
                                                                        context,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (modeSwitcherOpen)
                                                      Positioned(
                                                        left:
                                                            layout.railWidth +
                                                            layout.gap,
                                                        bottom: 54,
                                                        child: _ModeSwitcherPanel(
                                                          current: mode,
                                                          onSelected: (value) {
                                                            ref
                                                                .read(
                                                                  appModeProvider
                                                                      .notifier,
                                                                )
                                                                .setMode(value);
                                                            setState(
                                                              () =>
                                                                  modeSwitcherOpen =
                                                                      false,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                      if (_debugConsoleVisible)
                                        Positioned(
                                          right: layout.gap,
                                          bottom: layout.gap,
                                          width: math.min(900, width - 24),
                                          height: math.min(620, height - 24),
                                          child: Material(
                                            color: AppTheme.background,
                                            elevation: 20,
                                            clipBehavior: Clip.antiAlias,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: const BorderSide(
                                                color: AppTheme.border,
                                              ),
                                            ),
                                            child: LogConsoleScreen(
                                              onClose: () => setState(
                                                () => _debugConsoleVisible =
                                                    false,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _resizeExplorer(double delta, double availableWidth) {
    final bounds = _explorerWidthBounds(availableWidth);
    setState(() {
      layout = layout.copyWith(
        explorerWidth: (layout.explorerWidth + delta)
            .clamp(bounds.$1, bounds.$2)
            .toDouble(),
      );
    });
  }

  (double, double) _explorerWidthBounds(double availableWidth) {
    final available =
        availableWidth - (layout.gap * 2) - layout.railWidth - 16 - 180;
    final minimum = math.min(_minExplorerWidth, math.max(140.0, available));
    final maximum = math.max(minimum, math.min(_maxExplorerWidth, available));
    return (minimum, maximum);
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.compact,
    required this.onOpenDebugConsole,
    required this.onOpenPreferences,
    required this.scale,
    required this.onScaleChanged,
  });
  final bool compact;
  final VoidCallback onOpenDebugConsole;
  final VoidCallback onOpenPreferences;
  final double scale;
  final ValueChanged<double> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DragToMoveArea(child: const SizedBox.expand()),
          ),
          Row(
            children: [
              const SizedBox(
                width: 0,
                height: 0,
                child: Text('Ayakiro BCI Engine'),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.asset('assets/icons/bci_engine_64.png'),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: AppTheme.border),
              const SizedBox(width: 6),
              _TopMenuItem(label: 'File', onPreferences: onOpenPreferences),
              _TopMenuItem(label: 'Edit'),
              _TopMenuItem(label: 'View'),
              _TopMenuItem(label: 'Build'),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedContextMenuButton<double>(
                        tooltip: 'Масштаб интерфейса (Ctrl + / Ctrl -)',
                        menuWidth: 150,
                        onSelected: onScaleChanged,
                        actions: [
                          for (final value in <double>[
                            0.8,
                            0.9,
                            1.0,
                            1.1,
                            1.2,
                            1.3,
                            1.5,
                          ])
                            _MenuAction<double>(
                              value: value,
                              label: '${(value * 100).round()}%',
                            ),
                        ],
                        child: Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.panel,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(scale * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const _WindowControls(),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!compact)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 320,
                      height: 26,
                      child: _GlobalSearch(),
                    ),
                    const SizedBox(width: 6),
                    _DebugConsoleButton(onPressed: onOpenDebugConsole),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebugConsoleButton extends StatelessWidget {
  const _DebugConsoleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Открыть терминал отладки',
    child: IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.bug_report_outlined, size: 17),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.panel,
        foregroundColor: AppTheme.text,
        minimumSize: const Size(28, 28),
        maximumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximizedState();
  }

  Future<void> _syncMaximizedState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {
      // Native window methods are unavailable in widget tests.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  Future<void> _toggleMaximize() async {
    try {
      if (_maximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
      await _syncMaximizedState();
    } catch (_) {}
  }

  Widget _button({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 15),
    color: AppTheme.mutedText,
    hoverColor: AppTheme.border,
    splashRadius: 16,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
  );

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(
        tooltip: 'Свернуть окно',
        icon: Icons.remove,
        onPressed: () => windowManager.minimize(),
      ),
      _button(
        tooltip: _maximized ? 'Восстановить окно' : 'Развернуть окно',
        icon: _maximized ? Icons.filter_none : Icons.crop_square,
        onPressed: _toggleMaximize,
      ),
      _button(
        tooltip: 'Закрыть окно',
        icon: Icons.close,
        onPressed: () => windowManager.close(),
      ),
    ],
  );
}

class _TopMenuItem extends StatelessWidget {
  const _TopMenuItem({required this.label, this.onPreferences});

  final String label;
  final VoidCallback? onPreferences;

  List<_MenuAction<String>> _items() {
    switch (label) {
      case 'File':
        return const [
          _MenuAction(value: 'new', label: 'New workspace'),
          _MenuAction(value: 'open', label: 'Open project', shortcut: 'Ctrl+O'),
          _MenuAction(
            value: 'import',
            label: 'Import module (soon)',
            enabled: false,
            shortcut: 'Ctrl+Shift+M',
            dividerBefore: true,
          ),
          _MenuAction(
            value: 'preferences',
            label: 'Preferences',
            shortcut: 'Ctrl+,',
            dividerBefore: true,
          ),
        ];
      case 'Edit':
        return const [
          _MenuAction(value: 'undo', label: 'Undo', shortcut: 'Ctrl+Z'),
          _MenuAction(
            value: 'redo',
            label: 'Redo',
            enabled: false,
            shortcut: 'Ctrl+Y',
          ),
          _MenuAction(
            value: 'preferences',
            label: 'Preferences (soon)',
            enabled: false,
            dividerBefore: true,
          ),
        ];
      case 'View':
        return const [
          _MenuAction(
            value: 'explorer',
            label: 'Explorer',
            shortcut: 'Ctrl+Shift+E',
          ),
          _MenuAction(value: 'terminal', label: 'Terminal', shortcut: 'Ctrl+J'),
          _MenuAction(
            value: 'layout',
            label: 'Customize layout (soon)',
            enabled: false,
            dividerBefore: true,
          ),
        ];
      default:
        return const [
          _MenuAction(
            value: 'build',
            label: 'Build project',
            shortcut: 'Ctrl+B',
          ),
          _MenuAction(value: 'run', label: 'Run session', shortcut: 'F5'),
          _MenuAction(
            value: 'tasks',
            label: 'Build tasks (soon)',
            enabled: false,
            dividerBefore: true,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => _AnimatedContextMenuButton<String>(
    key: ValueKey<String>('$label menu button'),
    tooltip: '$label menu',
    actions: _items(),
    onSelected: (value) {
      if (value == 'preferences') onPreferences?.call();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppTheme.mutedText),
      ),
    ),
  );
}

class _MenuAction<T> {
  const _MenuAction({
    required this.value,
    required this.label,
    this.enabled = true,
    this.dividerBefore = false,
    this.shortcut,
  });

  final T value;
  final String label;
  final bool enabled;
  final bool dividerBefore;
  final String? shortcut;
}

class _AnimatedContextMenuButton<T> extends StatefulWidget {
  const _AnimatedContextMenuButton({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
    required this.child,
    this.menuWidth = 220,
  });

  final String tooltip;
  final List<_MenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final Widget child;
  final double menuWidth;

  @override
  State<_AnimatedContextMenuButton<T>> createState() =>
      _AnimatedContextMenuButtonState<T>();
}

class _AnimatedContextMenuButtonState<T>
    extends State<_AnimatedContextMenuButton<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
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
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 32),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: widget.menuWidth,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 16,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in widget.actions) ...[
                        if (action.dividerBefore)
                          const Divider(height: 8, indent: 8, endIndent: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _AnimatedMenuAction(
                            action: action,
                            onSelected: () {
                              widget.onSelected(action.value);
                              _closeMenu();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
    _animationController.forward(from: 0);
  }

  void _closeMenu() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    _animationController.reverse().whenCompleteOrCancel(() {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: _toggleMenu,
        hoverColor: AppTheme.border,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(6),
        child: widget.child,
      ),
    ),
  );
}

class _AnimatedMenuAction<T> extends StatefulWidget {
  const _AnimatedMenuAction({required this.action, required this.onSelected});

  final _MenuAction<T> action;
  final VoidCallback onSelected;

  @override
  State<_AnimatedMenuAction<T>> createState() => _AnimatedMenuActionState<T>();
}

class _AnimatedMenuActionState<T> extends State<_AnimatedMenuAction<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    cursor: widget.action.enabled
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: widget.action.enabled ? widget.onSelected : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: 38,
        decoration: BoxDecoration(
          color: _hovered && widget.action.enabled
              ? AppTheme.border
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.action.label,
                  style: TextStyle(
                    color: widget.action.enabled
                        ? AppTheme.text
                        : AppTheme.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.action.shortcut != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.action.enabled
                        ? AppTheme.panel
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.action.shortcut!,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final Object _tapRegionGroup = Object();
  OverlayEntry? _overlayEntry;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted && !_disposing) setState(() {});
  }

  @override
  void dispose() {
    _disposing = true;
    _focusNode.removeListener(_onFocusChanged);
    _removeMenu();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 32),
              child: TapRegion(
                groupId: _tapRegionGroup,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.panel,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchSectionTitle('QUICK ACTIONS'),
                        _SearchAction(
                          icon: Icons.file_open_outlined,
                          label: 'Open project',
                          shortcut: 'Ctrl+O',
                        ),
                        _SearchAction(
                          icon: Icons.extension_outlined,
                          label: 'Find module',
                          shortcut: 'Ctrl+Shift+M',
                        ),
                        Divider(height: 12),
                        _SearchSectionTitle('KEYBOARD SHORTCUTS'),
                        _SearchAction(
                          icon: Icons.zoom_in,
                          label: 'Increase interface scale',
                          shortcut: 'Ctrl++',
                        ),
                        _SearchAction(
                          icon: Icons.zoom_out,
                          label: 'Decrease interface scale',
                          shortcut: 'Ctrl+-',
                        ),
                        _SearchAction(
                          icon: Icons.tune,
                          label: 'Shortcuts',
                          onTap: _openShortcuts,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _focusNode.unfocus();
    if (mounted && !_disposing) setState(() {});
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _removeMenu();
      return;
    }
    _showMenu();
    _focusNode.requestFocus();
  }

  void _openShortcuts() {
    _removeMenu();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _ShortcutDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: _focusNode.hasFocus ? AppTheme.panel : AppTheme.background,
        border: Border.all(
          color: _focusNode.hasFocus ? AppTheme.text : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TapRegion(
        groupId: _tapRegionGroup,
        onTapOutside: (_) => _removeMenu(),
        child: TextField(
          key: const ValueKey<String>('global search field'),
          controller: _controller,
          focusNode: _focusNode,
          onTap: _toggleMenu,
          onSubmitted: (_) => _removeMenu(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.text, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Search files, symbols...  (Ctrl+P)',
            hintStyle: TextStyle(color: AppTheme.mutedText, fontSize: 11),
            prefixIcon: Icon(Icons.search, size: 16),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            isDense: true,
          ),
        ),
      ),
    ),
  );
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 5),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.mutedText,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({
    required this.icon,
    required this.label,
    this.shortcut,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _HoverSearchAction(
    icon: icon,
    label: label,
    shortcut: shortcut,
    onTap: onTap,
  );
}

class _HoverSearchAction extends StatefulWidget {
  const _HoverSearchAction({
    required this.icon,
    required this.label,
    this.shortcut,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;

  @override
  State<_HoverSearchAction> createState() => _HoverSearchActionState();
}

class _HoverSearchActionState extends State<_HoverSearchAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.border : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: AppTheme.text),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.text),
                ),
              ),
              if (widget.shortcut != null)
                Text(
                  widget.shortcut!,
                  style: const TextStyle(color: AppTheme.mutedText),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShortcutDialog extends StatefulWidget {
  const _ShortcutDialog();

  @override
  State<_ShortcutDialog> createState() => _ShortcutDialogState();
}

class _ShortcutDialogState extends State<_ShortcutDialog> {
  bool _editing = false;
  final Map<String, String> _shortcuts = {
    'Open project': 'Ctrl+O',
    'Find module': 'Ctrl+Shift+M',
    'Increase interface scale': 'Ctrl++',
    'Decrease interface scale': 'Ctrl+-',
    'Reset interface scale': 'Ctrl+0',
  };

  static const _shortcutGroups = <String, List<String>>{
    'WORKSPACE': ['Open project', 'Find module'],
    'INTERFACE': [
      'Increase interface scale',
      'Decrease interface scale',
      'Reset interface scale',
    ],
  };

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppTheme.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.border),
    ),
    child: SizedBox(
      width: math.min(660, MediaQuery.sizeOf(context).width - 48),
      height: math.min(700, MediaQuery.sizeOf(context).height - 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.keyboard_alt_outlined, size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keyboard shortcuts',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Configure the commands you use most often',
                        style: TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 17),
                  color: AppTheme.mutedText,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'KEYBOARD SHORTCUTS',
              style: TextStyle(
                color: AppTheme.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final group in _shortcutGroups.entries) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 7),
                          child: Text(
                            group.key,
                            style: const TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ),
                      for (final label in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: _ShortcutRow(
                            label: label,
                            shortcut: _shortcuts[label]!,
                            editing: _editing,
                            onChanged: (value) =>
                                setState(() => _shortcuts[label] = value),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.border),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Click a key field and press a new combination.',
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                  ),
                ),
                _ShortcutEditButton(
                  editing: _editing,
                  onPressed: () => setState(() => _editing = !_editing),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShortcutEditButton extends StatefulWidget {
  const _ShortcutEditButton({required this.editing, required this.onPressed});

  final bool editing;
  final VoidCallback onPressed;

  @override
  State<_ShortcutEditButton> createState() => _ShortcutEditButtonState();
}

class _ShortcutEditButtonState extends State<_ShortcutEditButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.border : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.mutedText),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.editing ? Icons.check : Icons.edit_outlined,
              size: 16,
              color: AppTheme.text,
            ),
            const SizedBox(width: 8),
            Text(
              widget.editing ? 'Done' : 'Edit shortcuts',
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
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
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.text, fontSize: 14),
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
    final key = event.logicalKey.keyLabel;
    final isModifier = <LogicalKeyboardKey>{
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
    }.contains(event.logicalKey);
    if (key.isNotEmpty && !isModifier) parts.add(key);
    return parts.join('+');
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 158,
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
          hintText: widget.editing ? 'Press keys' : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: widget.editing ? AppTheme.panel : Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        style: const TextStyle(color: AppTheme.text, fontSize: 13),
      ),
    ),
  );
}

class _ShellSurface extends StatelessWidget {
  const _ShellSurface({required this.child, required this.radius, this.width});

  final Widget child;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    ),
  );
}

class _LayoutDivider extends StatefulWidget {
  const _LayoutDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  State<_LayoutDivider> createState() => _LayoutDividerState();
}

class _LayoutDividerState extends State<_LayoutDivider> {
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
            duration: const Duration(milliseconds: 120),
            width: _hovered ? 2 : 1,
            height: _hovered ? 34 : 20,
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.mutedText : AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActivityRail extends StatelessWidget {
  const _ActivityRail({
    required this.sections,
    required this.selected,
    required this.modeSwitcherOpen,
    required this.onModeSwitcher,
    required this.onNavigate,
    required this.onProfile,
  });
  final List<NavSection> sections;
  final int selected;
  final bool modeSwitcherOpen;
  final VoidCallback onModeSwitcher;
  final ValueChanged<SectionId> onNavigate;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const railItems = <NavSection>[
      NavSection(
        id: SectionId.dashboard,
        label: 'User profile button',
        icon: Icons.account_circle_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.dashboard,
        label: 'projects',
        icon: Icons.folder_open_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.modules,
        label: 'marketplace',
        icon: Icons.storefront_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.pipeline,
        label: 'Modules',
        icon: Icons.account_tree_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.developer,
        label: 'bug report',
        icon: Icons.bug_report_outlined,
        modes: {},
      ),
    ];

    return Container(
      width: 48,
      color: AppTheme.background,
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final item in railItems)
            _RailButton(
              item: item,
              active:
                  !modeSwitcherOpen &&
                  item.label != 'User profile button' &&
                  item.id == sections[selected].id,
              enabled: true,
              onTap: item.label == 'User profile button'
                  ? onProfile
                  : () => onNavigate(item.id),
            ),
          const Spacer(),
          _RailButton(
            item: const NavSection(
              id: SectionId.session,
              label: 'user&dev switcher',
              icon: Icons.person_outline,
              modes: {},
            ),
            active: modeSwitcherOpen,
            enabled: true,
            onTap: onModeSwitcher,
          ),
          const SizedBox(height: 2),
          _RailButton(
            item: const NavSection(
              id: SectionId.settings,
              label: 'configs',
              icon: Icons.settings_outlined,
              modes: {},
            ),
            active:
                !modeSwitcherOpen &&
                sections[selected].id == SectionId.settings,
            enabled: true,
            onTap: () => onNavigate(SectionId.settings),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.enabled,
    required this.onTap,
  });
  final NavSection item;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.item.label,
    waitDuration: const Duration(seconds: 1),
    showDuration: const Duration(seconds: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    textStyle: const TextStyle(color: AppTheme.text, fontSize: 14),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? AppTheme.border
                : widget.active
                ? AppTheme.panel
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: widget.active ? Border.all(color: AppTheme.border) : null,
          ),
          child: Center(
            child: Icon(
              widget.item.icon,
              size: 20,
              color: widget.active
                  ? AppTheme.text
                  : widget.enabled
                  ? AppTheme.mutedText
                  : AppTheme.mutedText.withAlpha(110),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Explorer extends StatefulWidget {
  const _Explorer({
    required this.width,
    required this.sections,
    required this.selected,
    required this.onSelected,
  });
  final double width;
  final List<NavSection> sections;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends State<_Explorer> {
  final ScrollController _moduleScrollController = ScrollController();
  final TextEditingController _activeModuleController = TextEditingController();
  final TextEditingController _catalogModuleController =
      TextEditingController();
  String _activeModuleQuery = '';
  String _catalogModuleQuery = '';

  List<SystemModule> _filterModules(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return kSystemModules;
    return kSystemModules.where((module) {
      return module.name.toLowerCase().contains(normalized) ||
          module.id.toLowerCase().contains(normalized) ||
          module.category.toLowerCase().contains(normalized) ||
          module.stage.toLowerCase().contains(normalized);
    }).toList();
  }

  List<SystemModule> get _activeModules =>
      _filterModules(_activeModuleQuery)
          .where((module) => module.active)
          .toList();

  List<SystemModule> get _catalogModules => _filterModules(_catalogModuleQuery);

  @override
  void dispose() {
    _moduleScrollController.dispose();
    _activeModuleController.dispose();
    _catalogModuleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.width,
      child: ColoredBox(
        color: AppTheme.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
              child: Row(
                children: [
                  Text(
                    'EXPLORER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.add, size: 17),
                  const SizedBox(width: 7),
                  const Icon(Icons.create_new_folder_outlined, size: 17),
                  const SizedBox(width: 7),
                  const Icon(Icons.refresh, size: 16),
                  const SizedBox(width: 7),
                  const Icon(Icons.more_horiz, size: 18),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.dragged)) {
                      return AppTheme.mutedText.withAlpha(155);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return AppTheme.mutedText.withAlpha(125);
                    }
                    return AppTheme.mutedText.withAlpha(70);
                  }),
                  trackColor: const WidgetStatePropertyAll(Colors.transparent),
                  trackBorderColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  thickness: const WidgetStatePropertyAll(3),
                  minThumbLength: 24,
                  radius: const Radius.circular(3),
                ),
                child: Scrollbar(
                  controller: _moduleScrollController,
                  thumbVisibility: false,
                  child: SingleChildScrollView(
                    controller: _moduleScrollController,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExplorerHeading(
                          title: 'ACTIVE MODULES',
                          icon: Icons.expand_more,
                        ),
                        _ModuleSearchField(
                          controller: _activeModuleController,
                          hintText: 'Search active modules...',
                          query: _activeModuleQuery,
                          onChanged: (value) =>
                              setState(() => _activeModuleQuery = value),
                          onClear: () {
                            _activeModuleController.clear();
                            setState(() => _activeModuleQuery = '');
                          },
                        ),
                        if (_activeModules.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 4, 14, 10),
                            child: Text(
                              'No active modules found',
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        for (final module in _activeModules)
                          _ModuleItem(module: module),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Divider(height: 1),
                        ),
                        _ExplorerHeading(
                          title: 'MODULE CATALOG',
                          icon: Icons.search,
                        ),
                        _ModuleSearchField(
                          controller: _catalogModuleController,
                          hintText: 'Search modules...',
                          query: _catalogModuleQuery,
                          onChanged: (value) =>
                              setState(() => _catalogModuleQuery = value),
                          onClear: () {
                            _catalogModuleController.clear();
                            setState(() => _catalogModuleQuery = '');
                          },
                        ),
                        if (_catalogModules.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 4, 14, 10),
                            child: Text(
                              'No modules found',
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        for (final module in _catalogModules)
                          _ModuleItem(module: module, catalog: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'NerveGears Engine ${AppInfo.version}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerHeading extends StatelessWidget {
  const _ExplorerHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.text),
        const SizedBox(width: 3),
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: .8,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
      ],
    ),
  );
}

class _ModuleSearchField extends StatelessWidget {
  const _ModuleSearchField({
    required this.controller,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 17),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear module search',
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.text),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 9),
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _ModuleItem extends StatefulWidget {
  const _ModuleItem({required this.module, this.catalog = false});
  final SystemModule module;
  final bool catalog;

  @override
  State<_ModuleItem> createState() => _ModuleItemState();
}

class _ModuleItemState extends State<_ModuleItem> {
  bool _hovered = false;

  IconData get _icon {
    return switch (widget.module.category) {
      'acquisition' => Icons.bolt_outlined,
      'dsp' => Icons.layers_outlined,
      'feature' => Icons.memory_outlined,
      'utility' => Icons.inventory_2_outlined,
      'output' => Icons.storage_outlined,
      _ => Icons.extension_outlined,
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.border : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 17,
              color: widget.catalog ? AppTheme.mutedText : AppTheme.text,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.module.name,
                style: const TextStyle(color: AppTheme.text, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.circle,
              size: 6,
              color: widget.module.active ? AppTheme.text : AppTheme.mutedText,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeSwitcherPanel extends StatefulWidget {
  const _ModeSwitcherPanel({required this.current, required this.onSelected});

  final AppMode current;
  final ValueChanged<AppMode> onSelected;

  @override
  State<_ModeSwitcherPanel> createState() => _ModeSwitcherPanelState();
}

class _ModeSwitcherPanelState extends State<_ModeSwitcherPanel> {
  AppMode? _hoveredMode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in AppMode.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: '${mode.label}: ${mode.hint}',
                  waitDuration: const Duration(seconds: 1),
                  showDuration: const Duration(seconds: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  textStyle: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                  ),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredMode = mode),
                    onExit: (_) => setState(() => _hoveredMode = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onSelected(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _hoveredMode == mode || widget.current == mode
                              ? AppTheme.border
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: widget.current == mode
                                ? AppTheme.text
                                : AppTheme.border,
                            width: widget.current == mode ? 1.2 : 1,
                          ),
                        ),
                        child: Icon(
                          switch (mode) {
                            AppMode.consumer => Icons.person_outline,
                            AppMode.researcher => Icons.science_outlined,
                            AppMode.developer => Icons.code_outlined,
                          },
                          size: 20,
                          color: widget.current == mode
                              ? AppTheme.text
                              : AppTheme.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({required this.active});
  final NavSection active;
  @override
  Widget build(BuildContext context) => Container(
    height: 35,
    color: AppTheme.background,
    child: Row(
      children: [
        Container(
          width: 205,
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_phosphorFor(active.id), size: 15, color: AppTheme.text),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    active.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.close, size: 14, color: AppTheme.mutedText),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.view_sidebar_outlined,
            size: 17,
            color: AppTheme.mutedText,
          ),
        ),
      ],
    ),
  );
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.open,
    required this.onToggle,
    required this.onOpenWindow,
  });
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpenWindow;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: open ? 200 : 32,
    color: AppTheme.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            return SizedBox(
              height: 32,
              child: Row(
                children: [
                  InkWell(
                    onTap: onToggle,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'TERMINAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!compact)
                    const Text(
                      'OUTPUT',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                    ),
                  const Spacer(),
                  if (!compact)
                    IconButton(
                      onPressed: onOpenWindow,
                      tooltip: 'Открыть отдельное окно',
                      icon: const Icon(Icons.open_in_new, size: 16),
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      open
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 18,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            );
          },
        ),
        if (open)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(15, 3, 10, 8),
              child: SelectableText(
                'engine ~/project % npm run build\n> engine@0.2.2 build\n> Compiling core modules...\n[BUILD] core-renderer v2.4kb  ✓\n[BUILD] physics-engine v8.1kb  ✓\n[BUILD] Done in 1.34s ✓',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF7DCB9B),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({required this.section});
  final SectionId section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (section) {
      case SectionId.dashboard:
        return const DashboardScreen();
      case SectionId.devices:
        return const DevicesScreen();
      case SectionId.session:
        return const SessionScreen();
      case SectionId.pipeline:
        return const PipelineScreen();
      case SectionId.spectrogram:
        return const SpectrogramScreen();
      case SectionId.modules:
        return const ModulesScreen();
      case SectionId.datasets:
        return const DatasetsScreen();
      case SectionId.models:
        return const ModelsScreen();
      case SectionId.developer:
        return const DeveloperScreen();
      case SectionId.profile:
        return ProfileScreen(
          onBack: () =>
              ref.read(navSectionProvider.notifier).select(SectionId.dashboard),
        );
      case SectionId.settings:
        return SettingsScreen(
          onBack: () =>
              ref.read(navSectionProvider.notifier).select(SectionId.dashboard),
        );
    }
  }
}
