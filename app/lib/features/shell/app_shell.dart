import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_info.dart';
import '../../core/logging/log_window.dart';
import '../../core/modules/module_registry.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../state/engine_provider.dart';
import '../../state/engine_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../datasets/datasets_screen.dart';
import '../developer/developer_screen.dart';
import '../devices/devices_screen.dart';
import '../models/models_screen.dart';
import '../modules/modules_screen.dart';
import '../pipeline/pipeline_screen.dart';
import '../session/session_screen.dart';
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

  /// User-facing scale. The shell deliberately renders at a 120% base density
  /// while keeping this preference at the familiar 100% default.
  double uiScale = 1.0;
  ShellLayoutConfig layout = const ShellLayoutConfig.defaults();

  static const double _minScale = 0.8;
  static const double _maxScale = 1.5;
  static const double _baseScale = 1.2;
  static const double _scaleStep = 0.1;

  double get _visualScale => uiScale * _baseScale;

  void _changeScale(double delta) {
    setState(() {
      uiScale = (uiScale + delta).clamp(_minScale, _maxScale).toDouble();
    });
  }

  void _resetScale() => setState(() => uiScale = 1.0);

  Future<void> _openDebugConsole(BuildContext context) async {
    try {
      await openLogConsole();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть консоль: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final section = ref.watch(navSectionProvider);
    final engine = ref.watch(engineProvider);
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
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: visualScale,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: MediaQuery(
                          data: logicalMediaQuery,
                          child: Scaffold(
                            body: Column(
                              children: [
                                _TitleBar(
                                  engine: engine,
                                  onRun: () => ref
                                      .read(navSectionProvider.notifier)
                                      .select(SectionId.session),
                                  onOpenDebugConsole: () =>
                                      _openDebugConsole(context),
                                  scale: uiScale,
                                  onScaleChanged: (value) =>
                                      setState(() => uiScale = value),
                                  onOpenPreferences: () => ref
                                      .read(navSectionProvider.notifier)
                                      .select(SectionId.settings),
                                ),
                                Expanded(
                                  child: section == SectionId.settings
                                      ? SettingsScreen(
                                          onBack: () => ref
                                              .read(navSectionProvider.notifier)
                                              .select(SectionId.dashboard),
                                        )
                                      : Padding(
                                          padding: EdgeInsets.all(layout.gap),
                                          child: Stack(
                                            children: [
                                              Row(
                                                children: [
                                                  _ShellSurface(
                                                    width: layout.railWidth,
                                                    radius: layout.radius,
                                                    child: _ActivityRail(
                                                      sections: sections,
                                                      selected: selected < 0
                                                          ? 0
                                                          : selected,
                                                      modeSwitcherOpen:
                                                          modeSwitcherOpen,
                                                      onModeSwitcher: () => setState(
                                                        () => modeSwitcherOpen =
                                                            !modeSwitcherOpen,
                                                      ),
                                                      onNavigate: (id) {
                                                        final target =
                                                            kNavSections
                                                                .firstWhere(
                                                                  (item) =>
                                                                      item.id ==
                                                                      id,
                                                                );
                                                        if (!target.visibleIn(
                                                          mode,
                                                        )) {
                                                          final nextMode =
                                                              target.modes.contains(
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
                                                    ),
                                                  ),
                                                  _LayoutDivider(
                                                    onDrag: (delta) => setState(() {
                                                      layout = layout.copyWith(
                                                        railWidth:
                                                            (layout.railWidth +
                                                                    delta)
                                                                .clamp(40, 96)
                                                                .toDouble(),
                                                      );
                                                    }),
                                                  ),
                                                  _ShellSurface(
                                                    width: layout.explorerWidth,
                                                    radius: layout.radius,
                                                    child: _Explorer(
                                                      width:
                                                          layout.explorerWidth,
                                                      sections: sections,
                                                      selected: selected < 0
                                                          ? 0
                                                          : selected,
                                                      onSelected: (index) => ref
                                                          .read(
                                                            navSectionProvider
                                                                .notifier,
                                                          )
                                                          .select(
                                                            sections[index].id,
                                                          ),
                                                    ),
                                                  ),
                                                  _LayoutDivider(
                                                    onDrag: (delta) => setState(() {
                                                      layout = layout.copyWith(
                                                        explorerWidth:
                                                            (layout.explorerWidth +
                                                                    delta)
                                                                .clamp(220, 420)
                                                                .toDouble(),
                                                      );
                                                    }),
                                                  ),
                                                  Expanded(
                                                    child: _ShellSurface(
                                                      radius: layout.radius,
                                                      child: Column(
                                                        children: [
                                                          _EditorTabs(
                                                            active: active,
                                                          ),
                                                          Expanded(
                                                            child: _SectionBody(
                                                              section:
                                                                  active.id,
                                                            ),
                                                          ),
                                                          _TerminalPanel(
                                                            open: terminalOpen,
                                                            onToggle: () => setState(
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
                                                        () => modeSwitcherOpen =
                                                            false,
                                                      );
                                                    },
                                                  ),
                                                ),
                                            ],
                                          ),
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
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.engine,
    required this.onRun,
    required this.onOpenDebugConsole,
    required this.onOpenPreferences,
    required this.scale,
    required this.onScaleChanged,
  });
  final EngineState engine;
  final VoidCallback onRun;
  final VoidCallback onOpenDebugConsole;
  final VoidCallback onOpenPreferences;
  final double scale;
  final ValueChanged<double> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 1100;
    final narrowHeader = MediaQuery.sizeOf(context).width < 1250;
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
              if (!compact) ...[
                _TopMenuItem(label: 'File', onPreferences: onOpenPreferences),
                _TopMenuItem(label: 'Edit'),
                _TopMenuItem(label: 'View'),
                _TopMenuItem(label: 'Build'),
                const Spacer(),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: 210, maxWidth: 320),
                    child: SizedBox(height: 26, child: _GlobalSearch()),
                  ),
                ),
                const SizedBox(width: 4),
                if (!narrowHeader)
                  IconButton(
                    onPressed: onOpenDebugConsole,
                    tooltip: 'Открыть терминал отладки',
                    icon: const Icon(Icons.bug_report_outlined, size: 17),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.panel,
                      foregroundColor: AppTheme.text,
                      minimumSize: const Size(28, 28),
                      maximumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ] else
                const Spacer(),
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
              Icon(Icons.circle, size: 8, color: AppTheme.mutedText),
              const SizedBox(width: 7),
              Text(
                engine.isOnline ? 'Engine online' : 'Engine offline',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRun,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Run'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.text),
              ),
              const SizedBox(width: 8),
              const _WindowControls(),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }
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
          _MenuAction(value: 'open', label: 'Open project'),
          _MenuAction(
            value: 'import',
            label: 'Import module (soon)',
            enabled: false,
            dividerBefore: true,
          ),
          _MenuAction(
            value: 'preferences',
            label: 'Preferences',
            dividerBefore: true,
          ),
        ];
      case 'Edit':
        return const [
          _MenuAction(value: 'undo', label: 'Undo'),
          _MenuAction(value: 'redo', label: 'Redo', enabled: false),
          _MenuAction(
            value: 'preferences',
            label: 'Preferences (soon)',
            enabled: false,
            dividerBefore: true,
          ),
        ];
      case 'View':
        return const [
          _MenuAction(value: 'explorer', label: 'Explorer'),
          _MenuAction(value: 'terminal', label: 'Terminal'),
          _MenuAction(
            value: 'layout',
            label: 'Customize layout (soon)',
            enabled: false,
            dividerBefore: true,
          ),
        ];
      default:
        return const [
          _MenuAction(value: 'build', label: 'Build project'),
          _MenuAction(value: 'run', label: 'Run session'),
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
  });

  final T value;
  final String label;
  final bool enabled;
  final bool dividerBefore;
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                        _AnimatedMenuAction(
                          action: action,
                          onSelected: () {
                            widget.onSelected(action.value);
                            _closeMenu();
                          },
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
        height: 32,
        color: _hovered && widget.action.enabled
            ? AppTheme.border
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.action.label,
              style: TextStyle(
                color: widget.action.enabled
                    ? AppTheme.text
                    : AppTheme.mutedText,
                fontSize: 13,
              ),
            ),
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
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeMenu();
    _focusNode.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 32),
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
              child: const Column(
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
                    label: 'Customize shortcuts (soon)',
                    disabled: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search, size: 16),
          Expanded(
            child: GestureDetector(
              onTap: _showMenu,
              child: const Text(
                'Search files, symbols...  (Ctrl+P)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
              ),
            ),
          ),
          SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              key: const ValueKey<String>('global search field'),
              focusNode: _focusNode,
              onTap: _showMenu,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      height: 36,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: disabled ? AppTheme.mutedText : AppTheme.text,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: disabled ? AppTheme.mutedText : AppTheme.text,
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 8),
              Text(
                shortcut!,
                style: const TextStyle(color: AppTheme.mutedText),
              ),
            ],
          ],
        ),
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

class _LayoutDivider extends StatelessWidget {
  const _LayoutDivider({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: const SizedBox(width: 8),
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
  });
  final List<NavSection> sections;
  final int selected;
  final bool modeSwitcherOpen;
  final VoidCallback onModeSwitcher;
  final ValueChanged<SectionId> onNavigate;

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
              active: item.id == sections[selected].id,
              enabled: true,
              onTap: () => onNavigate(item.id),
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
            active: sections[selected].id == SectionId.settings,
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
    waitDuration: const Duration(milliseconds: 1333),
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
    textStyle: const TextStyle(color: AppTheme.text, fontSize: 12),
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
              child: SingleChildScrollView(
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

class _ModeSwitcherPanel extends StatelessWidget {
  const _ModeSwitcherPanel({required this.current, required this.onSelected});

  final AppMode current;
  final ValueChanged<AppMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.background,
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
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'change mode',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
              ),
            ),
            for (final mode in AppMode.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Tooltip(
                  message: '${mode.label}: ${mode.hint}',
                  child: InkWell(
                    onTap: () => onSelected(mode),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: current == mode
                            ? AppTheme.panel
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: current == mode
                            ? Border.all(color: AppTheme.border)
                            : null,
                      ),
                      child: Icon(
                        switch (mode) {
                          AppMode.consumer => Icons.person_outline,
                          AppMode.researcher => Icons.science_outlined,
                          AppMode.developer => Icons.code_outlined,
                        },
                        size: 24,
                        color: current == mode
                            ? AppTheme.text
                            : AppTheme.mutedText,
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
      case SectionId.settings:
        return SettingsScreen(
          onBack: () =>
              ref.read(navSectionProvider.notifier).select(SectionId.dashboard),
        );
    }
  }
}
