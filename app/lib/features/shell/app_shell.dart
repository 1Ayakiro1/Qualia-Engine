import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_info.dart';
import '../../core/logging/debug_terminal_launcher.dart';
import '../../core/modules/module_registry.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../datasets/datasets_screen.dart';
import '../developer/developer_screen.dart';
import '../devices/devices_screen.dart';
import '../entity/entity_screen.dart';
import '../bug_report/bug_report_screen.dart';
import '../common/widgets.dart';
import '../extensions/extensions_screen.dart';
import '../models/models_screen.dart';
import '../modules/modules_screen.dart';
import '../pipeline/pipeline_screen.dart';
import '../session/session_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/keyboard_shortcuts_panel.dart';
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
    case SectionId.entity:
      return Icons.hub_outlined;
    case SectionId.datasets:
      return Icons.folder_open_outlined;
    case SectionId.models:
      return Icons.psychology_outlined;
    case SectionId.developer:
      return Icons.terminal;
    case SectionId.extensions:
      return Icons.auto_awesome_mosaic_outlined;
    case SectionId.bugReport:
      return Icons.bug_report_outlined;
    case SectionId.profile:
      return Icons.account_circle_outlined;
    case SectionId.settings:
      return Icons.settings_outlined;
  }
}

/// Search remains part of the same tap region as the window controls, so
/// maximizing/restoring the native window does not count as an outside click.
final Object _globalSearchTapRegionGroup = Object();

/// Desktop IDE-like shell. Navigation is deliberately split into a compact
/// activity rail and an Explorer pane so the work area stays uncluttered.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.onOpenDebugTerminal});

  final VoidCallback? onOpenDebugTerminal;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  final FocusNode _shellFocusNode = FocusNode(
    debugLabel: 'app shell shortcuts',
  );
  bool terminalOpen = true;
  bool modeSwitcherOpen = false;
  bool _explorerVisible = true;
  String settingsItem = 'General';
  SystemModule? _selectedModule;
  NeuralEntity? _selectedEntity;
  String? _selectedExtensionId;
  bool _moduleInspectorOpen = false;
  bool _entityInspectorOpen = false;
  bool _extensionInspectorOpen = false;
  final List<NavSection> _openTabs = <NavSection>[];
  SectionId? _activeTab;
  List<SystemModule> _workspaceModules = List<SystemModule>.of(kSystemModules);
  List<NeuralEntity> _entities = List<NeuralEntity>.of(kNeuralEntities);

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

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    final initial = kNavSections.first;
    _openTabs.add(initial);
    _activeTab = initial.id;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _shellFocusNode.dispose();
    super.dispose();
  }

  void _restoreShellFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shellFocusNode.requestFocus();
    });
  }

  @override
  void onWindowFocus() => _restoreShellFocus();

  NavSection? get _activeTabSection {
    for (final tab in _openTabs) {
      if (tab.id == _activeTab) return tab;
    }
    return null;
  }

  NavSection _tabDescriptor(SectionId id) {
    if (id == SectionId.profile) {
      return const NavSection(
        id: SectionId.profile,
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        modes: {},
      );
    }
    if (id == SectionId.bugReport) {
      return const NavSection(
        id: SectionId.bugReport,
        label: 'Bug report',
        icon: Icons.bug_report_outlined,
        modes: {},
      );
    }
    return kNavSections.firstWhere((item) => item.id == id);
  }

  void _openTab(SectionId id) {
    final target = _tabDescriptor(id);
    setState(() {
      if (!_openTabs.any((tab) => tab.id == id)) _openTabs.add(target);
      _activeTab = id;
    });
  }

  void _closeTab(SectionId id) {
    setState(() {
      final index = _openTabs.indexWhere((tab) => tab.id == id);
      if (index < 0) return;
      _openTabs.removeAt(index);
      if (_activeTab == id) {
        _activeTab = _openTabs.isEmpty
            ? null
            : _openTabs[math.min(index, _openTabs.length - 1)].id;
      }
    });
    final next = _activeTab;
    ref.read(navSectionProvider.notifier).select(next ?? SectionId.dashboard);
  }

  void _returnToApp() {
    ref.read(navSectionProvider.notifier).select(SectionId.dashboard);
    _openTab(SectionId.dashboard);
  }

  void _selectSection(SectionId id, AppMode mode) {
    if (id == SectionId.settings) settingsItem = 'General';
    if (id == SectionId.profile) {
      ref.read(navSectionProvider.notifier).select(id);
      _openTab(id);
      return;
    }
    if (id == SectionId.bugReport) {
      ref.read(navSectionProvider.notifier).select(id);
      _openTab(id);
      return;
    }
    final target = _tabDescriptor(id);
    if (!target.visibleIn(mode)) {
      final nextMode = target.modes.contains(AppMode.researcher)
          ? AppMode.researcher
          : AppMode.developer;
      ref.read(appModeProvider.notifier).setMode(nextMode);
    }
    ref.read(navSectionProvider.notifier).select(id);
    _openTab(id);
  }

  Future<void> _showTabPicker(AppMode mode) async {
    final id = await showDialog<SectionId>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('New tab'),
        children: [
          for (final item in visibleSections(mode))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item.id),
              child: Text(item.label),
            ),
        ],
      ),
    );
    if (id != null && mounted) _selectSection(id, mode);
  }

  Future<void> _showModuleEditor([SystemModule? existing]) async {
    final result = await showDialog<SystemModule>(
      context: context,
      builder: (context) => _ModuleEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _workspaceModules.indexWhere(
        (module) => module.id == result.id,
      );
      if (index < 0) {
        _workspaceModules = [..._workspaceModules, result];
      } else {
        final updated = [..._workspaceModules]..[index] = result;
        _workspaceModules = updated;
      }
    });
    _addNotification(
      existing == null ? 'Module added' : 'Module updated',
      '${result.name} is now available in the Modules workspace.',
      Icons.extension_outlined,
    );
  }

  Future<void> _showEntityEditor([NeuralEntity? existing]) async {
    final result = await showDialog<NeuralEntity>(
      context: context,
      builder: (context) => _EntityEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _entities.indexWhere((entity) => entity.id == result.id);
      if (index < 0) {
        _entities = [..._entities, result];
      } else {
        _entities = [..._entities]..[index] = result;
      }
      _selectedEntity = result;
    });
    _addNotification(
      existing == null ? 'Entity added' : 'Entity updated',
      '${result.name} is now available in Entity.',
      Icons.hub_outlined,
    );
  }

  void _removeEntity(NeuralEntity entity) {
    setState(() {
      _entities = _entities.where((item) => item.id != entity.id).toList();
      if (_selectedEntity?.id == entity.id) _selectedEntity = null;
    });
    _addNotification(
      'Entity removed',
      '${entity.name} was removed from Entity.',
      Icons.delete_outline,
    );
  }

  void _toggleEntityInstalled(NeuralEntity entity) {
    setState(() {
      final replacement = entity.copyWith(installed: !entity.installed);
      _entities = _entities
          .map((item) => item.id == entity.id ? replacement : item)
          .toList();
      _selectedEntity = replacement;
    });
    _addNotification(
      entity.installed ? 'Entity uninstalled' : 'Entity installed',
      entity.name,
      Icons.hub_outlined,
    );
  }

  void _removeModule(SystemModule module) {
    setState(() {
      _workspaceModules = _workspaceModules
          .where((item) => item.id != module.id)
          .toList();
    });
    _addNotification(
      'Module removed',
      '${module.name} was removed from the workspace.',
      Icons.delete_outline,
    );
  }

  void _addNotification(String title, String message, IconData icon) {
    ref
        .read(notificationProvider.notifier)
        .add(id: title, title: title, message: message, icon: icon);
  }

  void _changeScale(double delta) {
    setState(() {
      uiScale = (uiScale + delta).clamp(_minScale, _maxScale).toDouble();
    });
  }

  void _resetScale() => setState(() => uiScale = 1.0);

  void _openDebugConsole() {
    if (widget.onOpenDebugTerminal != null) {
      widget.onOpenDebugTerminal!();
      _restoreShellFocus();
      return;
    }
    unawaited(DebugTerminalLauncher.launch());
    _restoreShellFocus();
  }

  void _handleHelpAction(String action) {
    if (action == 'report_issue') {
      _selectSection(SectionId.bugReport, ref.read(appModeProvider));
      return;
    }

    final content = switch (action) {
      'documentation' => (
        'Documentation',
        'Learn how to configure workspaces, devices, sessions and modules in Qualia Engine.',
      ),
      'about' => (
        'About Us',
        '${AppInfo.appName}\nVersion ${AppInfo.version}\n\nBuilt by ${AppInfo.organization} for focused brain-computer interface workflows.',
      ),
      'welcome' => (
        'Welcome to Qualia Engine',
        'Qualia Engine is a desktop workspace for exploring BCI data, sessions and modular signal-processing pipelines.',
      ),
      'tutorials' => (
        'Tutorials',
        'Start with the Dashboard, connect a device, create a session and open Modules to build your processing workflow.',
      ),
      'license' => (
        'License',
        'Qualia Engine is distributed under the project license. See the repository license file for the complete terms.',
      ),
      'updates' => (
        'Check updates',
        'You are running Qualia Engine ${AppInfo.version}. Update checking will be connected to the release channel in a future build.',
      ),
      'youtube' => (
        'Our Youtube',
        'Video tutorials and project updates will be available on the Qualia Engine YouTube channel.',
      ),
      _ => ('Help', 'This help action is not available yet.'),
    };

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(content.$1),
        content: Text(content.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleViewAction(String action) {
    final mode = switch (action) {
      'theme_system' => ThemeMode.system,
      'theme_dark' => ThemeMode.dark,
      'theme_light' => ThemeMode.light,
      _ => null,
    };
    if (mode != null) {
      ref.read(themeModeProvider.notifier).setThemeMode(mode);
    }
  }

  void _selectMode(AppMode value) {
    ref.read(appModeProvider.notifier).setMode(value);
    _openTab(SectionId.dashboard);
    ref.read(navSectionProvider.notifier).select(SectionId.dashboard);
    setState(() => modeSwitcherOpen = false);
  }

  Widget _modeSwitcherOverlay({required Widget child, required AppMode mode}) =>
      Stack(
        children: [
          Positioned.fill(child: child),
          if (modeSwitcherOpen)
            Positioned(
              left: layout.railWidth + layout.gap,
              bottom: 54,
              child: _ModeSwitcherPanel(current: mode, onSelected: _selectMode),
            ),
        ],
      );

  Widget _buildActivityRail({
    required List<NavSection> sections,
    required AppMode mode,
    required SectionId section,
  }) {
    return _ShellSurface(
      key: const ValueKey<String>('activity rail surface'),
      width: layout.railWidth,
      radius: layout.radius,
      child: _ActivityRail(
        sections: sections,
        selectedSection: section,
        modeSwitcherOpen: modeSwitcherOpen,
        onModeSwitcher: () =>
            setState(() => modeSwitcherOpen = !modeSwitcherOpen),
        onNavigate: (id) => _selectSection(id, mode),
        onProfile: () => _selectSection(SectionId.profile, mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final section = ref.watch(navSectionProvider);
    final sections = visibleSections(mode);
    final selected = sections.indexWhere((item) => item.id == section);
    final active =
        _activeTabSection ??
        (selected < 0 ? sections.first : sections[selected]);

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
        focusNode: _shellFocusNode,
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
                                  compact: width < 760,
                                  onOpenDebugConsole: _openDebugConsole,
                                  scale: uiScale,
                                  onScaleChanged: (value) =>
                                      setState(() => uiScale = value),
                                  onOpenPreferences: () => setState(() {
                                    settingsItem = 'General';
                                    ref
                                        .read(navSectionProvider.notifier)
                                        .select(SectionId.settings);
                                  }),
                                  onHelpAction: _handleHelpAction,
                                  onViewAction: _handleViewAction,
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: section == SectionId.profile
                                            ? Padding(
                                                padding: EdgeInsets.all(
                                                  layout.gap,
                                                ),
                                                child: _modeSwitcherOverlay(
                                                  mode: mode,
                                                  child: Row(
                                                    children: [
                                                      _buildActivityRail(
                                                        sections: sections,
                                                        mode: mode,
                                                        section: section,
                                                      ),
                                                      _LayoutDivider(
                                                        key:
                                                            const ValueKey<
                                                              String
                                                            >(
                                                              'rail resize handle',
                                                            ),
                                                        onDrag: _resizeRail,
                                                      ),
                                                      Expanded(
                                                        child: _ShellSurface(
                                                          radius: layout.radius,
                                                          child: ProfileScreen(
                                                            onBack:
                                                                _returnToApp,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : section == SectionId.bugReport
                                            ? Padding(
                                                padding: EdgeInsets.all(
                                                  layout.gap,
                                                ),
                                                child: _modeSwitcherOverlay(
                                                  mode: mode,
                                                  child: Row(
                                                    children: [
                                                      _buildActivityRail(
                                                        sections: sections,
                                                        mode: mode,
                                                        section: section,
                                                      ),
                                                      _LayoutDivider(
                                                        key:
                                                            const ValueKey<
                                                              String
                                                            >(
                                                              'rail resize handle',
                                                            ),
                                                        onDrag: _resizeRail,
                                                      ),
                                                      Expanded(
                                                        child: _ShellSurface(
                                                          radius: layout.radius,
                                                          child:
                                                              const BugReportScreen(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : section == SectionId.settings
                                            ? SettingsScreen(
                                                initialItem: settingsItem,
                                                onBack: _returnToApp,
                                              )
                                            : Padding(
                                                padding: EdgeInsets.all(
                                                  layout.gap,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        _buildActivityRail(
                                                          sections: sections,
                                                          mode: mode,
                                                          section: section,
                                                        ),
                                                        _LayoutDivider(
                                                          key:
                                                              const ValueKey<
                                                                String
                                                              >(
                                                                'rail resize handle',
                                                              ),
                                                          onDrag: _resizeRail,
                                                        ),
                                                        if (_explorerVisible) ...[
                                                          _ShellSurface(
                                                            key:
                                                                active.id ==
                                                                    SectionId
                                                                        .extensions
                                                                ? const ValueKey<
                                                                    String
                                                                  >(
                                                                    'extensions explorer pane',
                                                                  )
                                                                : null,
                                                            width:
                                                                effectiveExplorerWidth,
                                                            radius:
                                                                layout.radius,
                                                            child: _Explorer(
                                                              width:
                                                                  effectiveExplorerWidth,
                                                              sections:
                                                                  sections,
                                                              selected:
                                                                  selected < 0
                                                                  ? 0
                                                                  : selected,
                                                              showModuleActions:
                                                                  active.id ==
                                                                  SectionId
                                                                      .modules,
                                                              showEntityActions:
                                                                  active.id ==
                                                                  SectionId
                                                                      .entity,
                                                              showExtensionActions:
                                                                  active.id ==
                                                                  SectionId
                                                                      .extensions,
                                                              inspectorOpen:
                                                                  active.id ==
                                                                      SectionId
                                                                          .modules
                                                                  ? _moduleInspectorOpen
                                                                  : active.id ==
                                                                        SectionId
                                                                            .entity
                                                                  ? _entityInspectorOpen
                                                                  : _extensionInspectorOpen,
                                                              modules:
                                                                  _workspaceModules,
                                                              entities:
                                                                  _entities,
                                                              extensions:
                                                                  kUserExtensions,
                                                              selectedExtensionId:
                                                                  _selectedExtensionId,
                                                              onExtensionSelected:
                                                                  (
                                                                    extension,
                                                                  ) => setState(
                                                                    () => _selectedExtensionId =
                                                                        extension
                                                                            .id,
                                                                  ),
                                                              onExtensionNotification:
                                                                  _addNotification,
                                                              onToggleInspector: () => setState(() {
                                                                if (active.id ==
                                                                    SectionId
                                                                        .modules) {
                                                                  _moduleInspectorOpen =
                                                                      !_moduleInspectorOpen;
                                                                } else if (active
                                                                        .id ==
                                                                    SectionId
                                                                        .entity) {
                                                                  _entityInspectorOpen =
                                                                      !_entityInspectorOpen;
                                                                } else if (active
                                                                        .id ==
                                                                    SectionId
                                                                        .extensions) {
                                                                  _extensionInspectorOpen =
                                                                      !_extensionInspectorOpen;
                                                                }
                                                              }),
                                                              selectedEntity:
                                                                  _selectedEntity,
                                                              onSelected: (index) =>
                                                                  _selectSection(
                                                                    sections[index]
                                                                        .id,
                                                                    mode,
                                                                  ),
                                                              onAddModule:
                                                                  _showModuleEditor,
                                                              onRemoveModule:
                                                                  _removeModule,
                                                              onEditModule:
                                                                  _showModuleEditor,
                                                              onAddEntity:
                                                                  _showEntityEditor,
                                                              onRemoveEntity:
                                                                  _removeEntity,
                                                              onEditEntity:
                                                                  _showEntityEditor,
                                                              onEntitySelected:
                                                                  (
                                                                    entity,
                                                                  ) => setState(
                                                                    () => _selectedEntity =
                                                                        entity,
                                                                  ),
                                                              selectedModule:
                                                                  _selectedModule,
                                                              onModuleSelected:
                                                                  (
                                                                    module,
                                                                  ) => setState(
                                                                    () => _selectedModule =
                                                                        module,
                                                                  ),
                                                            ),
                                                          ),
                                                          _LayoutDivider(
                                                            key:
                                                                active.id ==
                                                                    SectionId
                                                                        .extensions
                                                                ? const ValueKey<
                                                                    String
                                                                  >(
                                                                    'extensions resize handle',
                                                                  )
                                                                : const ValueKey<
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
                                                        ],
                                                        Expanded(
                                                          child: _ShellSurface(
                                                            radius:
                                                                layout.radius,
                                                            child: Column(
                                                              children: [
                                                                _EditorTabs(
                                                                  tabs:
                                                                      _openTabs,
                                                                  active:
                                                                      _activeTab,
                                                                  onCreate: () =>
                                                                      _showTabPicker(
                                                                        mode,
                                                                      ),
                                                                  onSelect: (id) =>
                                                                      _selectSection(
                                                                        id,
                                                                        mode,
                                                                      ),
                                                                  onClose:
                                                                      _closeTab,
                                                                  explorerVisible:
                                                                      _explorerVisible,
                                                                  onToggleExplorer:
                                                                      () => setState(
                                                                        () => _explorerVisible =
                                                                            !_explorerVisible,
                                                                      ),
                                                                  showExplorerToggle:
                                                                      active
                                                                          .id ==
                                                                      SectionId
                                                                          .modules,
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      _activeTabSection ==
                                                                          null
                                                                      ? _EmptyEditor(
                                                                          onCreate: () => _showTabPicker(
                                                                            mode,
                                                                          ),
                                                                        )
                                                                      : _SectionBody(
                                                                          section:
                                                                              active.id,
                                                                          modules:
                                                                              _workspaceModules,
                                                                          onAddModule:
                                                                              _showModuleEditor,
                                                                          onEditModule:
                                                                              _showModuleEditor,
                                                                          onRemoveModule:
                                                                              _removeModule,
                                                                          entities:
                                                                              _entities,
                                                                          selectedModule:
                                                                              _selectedModule,
                                                                          inspectorOpen:
                                                                              active.id == SectionId.modules
                                                                              ? _moduleInspectorOpen
                                                                              : active.id == SectionId.entity
                                                                              ? _entityInspectorOpen
                                                                              : _extensionInspectorOpen,
                                                                          selectedExtensionId:
                                                                              _selectedExtensionId,
                                                                          extensionInspectorOpen:
                                                                              _extensionInspectorOpen,
                                                                          onToggleInspector: () => setState(() {
                                                                            if (active.id ==
                                                                                SectionId.modules) {
                                                                              _moduleInspectorOpen = !_moduleInspectorOpen;
                                                                            } else if (active.id ==
                                                                                SectionId.entity) {
                                                                              _entityInspectorOpen = !_entityInspectorOpen;
                                                                            } else if (active.id ==
                                                                                SectionId.extensions) {
                                                                              _extensionInspectorOpen = !_extensionInspectorOpen;
                                                                            }
                                                                          }),
                                                                          onSelectExtension: (
                                                                            extension,
                                                                          ) => setState(() => _selectedExtensionId = extension.id),
                                                                          selectedEntity:
                                                                              _selectedEntity,
                                                                          onAddEntity:
                                                                              _showEntityEditor,
                                                                          onEditEntity:
                                                                              _showEntityEditor,
                                                                          onRemoveEntity:
                                                                              _removeEntity,
                                                                          onToggleEntityInstalled:
                                                                              _toggleEntityInstalled,
                                                                        ),
                                                                ),
                                                                _TerminalPanel(
                                                                  open:
                                                                      terminalOpen,
                                                                  onToggle: () => setState(() {
                                                                    terminalOpen =
                                                                        !terminalOpen;
                                                                    _restoreShellFocus();
                                                                  }),
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
                                                        child:
                                                            _ModeSwitcherPanel(
                                                              current: mode,
                                                              onSelected:
                                                                  _selectMode,
                                                            ),
                                                      ),
                                                  ],
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

  void _resizeRail(double delta) {
    setState(() {
      layout = layout.copyWith(
        railWidth: (layout.railWidth + delta).clamp(40.0, 96.0).toDouble(),
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
    required this.onHelpAction,
    required this.onViewAction,
    required this.scale,
    required this.onScaleChanged,
  });
  final bool compact;
  final VoidCallback onOpenDebugConsole;
  final VoidCallback onOpenPreferences;
  final ValueChanged<String> onHelpAction;
  final ValueChanged<String> onViewAction;
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
              TapRegion(
                groupId: _AnimatedContextMenuButtonState._topMenuTapRegionGroup,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopMenuItem(
                      label: 'File',
                      onPreferences: onOpenPreferences,
                    ),
                    _TopMenuItem(label: 'Edit'),
                    _TopMenuItem(label: 'View', onAction: onViewAction),
                    _TopMenuItem(label: 'Build'),
                    if (!compact)
                      _TopMenuItem(label: 'Help', onAction: onHelpAction),
                  ],
                ),
              ),
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
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _NotificationsButton(),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: compact ? 180 : 320,
                    height: 26,
                    child: const _GlobalSearch(),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    _DebugConsoleButton(onPressed: onOpenDebugConsole),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header notification control backed by the app-wide notification provider.
class _NotificationsButton extends ConsumerStatefulWidget {
  const _NotificationsButton();

  @override
  ConsumerState<_NotificationsButton> createState() =>
      _NotificationsButtonState();
}

class _NotificationsButtonState extends ConsumerState<_NotificationsButton> {
  static const double _panelWidth = 330;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<AppNotification> get _items => ref.watch(notificationProvider);

  bool get _hasUnread => _items.any((item) => !item.read);

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggle() {
    if (_overlayEntry == null) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
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
            offset: const Offset(-300, 32),
            child: Material(
              color: AppTheme.panel,
              elevation: 12,
              borderRadius: BorderRadius.circular(9),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: _panelWidth,
                child: _NotificationPanel(
                  items: _items,
                  hasUnread: _hasUnread,
                  onMarkRead: _markRead,
                  onMarkAllRead: _markAllRead,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() {});
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  void _markRead(String id) {
    ref.read(notificationProvider.notifier).markRead(id);
    _overlayEntry?.markNeedsBuild();
  }

  void _markAllRead() {
    ref.read(notificationProvider.notifier).markAllRead();
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AppNotification>>(notificationProvider, (previous, next) {
      _overlayEntry?.markNeedsBuild();
    });
    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DesktopIconButton(
            key: const ValueKey<String>('notifications button'),
            icon: _hasUnread
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
            tooltip: 'Notifications',
            onPressed: _toggle,
            size: 30,
            iconSize: 17,
            active: _overlayEntry != null,
          ),
          if (_hasUnread)
            Positioned(
              top: 3,
              right: 3,
              child: IgnorePointer(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.text,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _notificationTime(DateTime createdAt) {
  final elapsed = DateTime.now().difference(createdAt);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
  return '${elapsed.inDays} d ago';
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.items,
    required this.hasUnread,
    required this.onMarkRead,
    required this.onMarkAllRead,
  });

  final List<AppNotification> items;
  final bool hasUnread;
  final ValueChanged<String> onMarkRead;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 360),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasUnread)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No notifications',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedText),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 5),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => onMarkRead(item.id),
                  hoverColor: AppTheme.border,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, size: 18, color: AppTheme.mutedText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: AppTheme.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 11,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _notificationTime(item.createdAt),
                                style: const TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!item.read)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.text,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _DebugConsoleButton extends StatelessWidget {
  const _DebugConsoleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DesktopIconButton(
    icon: Icons.bug_report_outlined,
    tooltip: 'Открыть терминал отладки',
    onPressed: onPressed,
    size: 30,
    iconSize: 17,
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
  }) => TapRegion(
    groupId: _globalSearchTapRegionGroup,
    child: DesktopIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      size: 30,
      iconSize: 15,
    ),
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
  const _TopMenuItem({required this.label, this.onPreferences, this.onAction});

  final String label;
  final VoidCallback? onPreferences;
  final ValueChanged<String>? onAction;

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
          _MenuAction(
            value: 'theme',
            label: 'Theme',
            dividerBefore: true,
            submenu: [
              _MenuAction(value: 'theme_system', label: 'System'),
              _MenuAction(value: 'theme_dark', label: 'Dark'),
              _MenuAction(value: 'theme_light', label: 'White'),
            ],
          ),
        ];
      case 'Help':
        return const [
          _MenuAction(value: 'documentation', label: 'Documentation'),
          _MenuAction(value: 'about', label: 'About Us'),
          _MenuAction(value: 'welcome', label: 'Welcome'),
          _MenuAction(value: 'tutorials', label: 'Tutorials'),
          _MenuAction(value: 'license', label: 'License'),
          _MenuAction(
            value: 'updates',
            label: 'Check updates',
            dividerBefore: true,
          ),
          _MenuAction(value: 'report_issue', label: 'Report Issue'),
          _MenuAction(value: 'youtube', label: 'Our Youtube'),
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
      onAction?.call(value);
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
    this.submenu,
  });

  final T value;
  final String label;
  final bool enabled;
  final bool dividerBefore;
  final String? shortcut;
  final List<_MenuAction<T>>? submenu;
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
  bool _submenuOpen = false;
  Object? _menuToken;

  static Object? _activeMenuToken;
  static VoidCallback? _activeMenuCloser;
  static final Object _topMenuTapRegionGroup = Object();

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
    if (identical(_activeMenuToken, _menuToken)) {
      _activeMenuCloser = null;
      _activeMenuToken = null;
    }
    _menuToken = null;
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

  double _submenuTopOffset(
    List<_MenuAction<T>> actions,
    _MenuAction<T> target,
  ) {
    var offset = 8.0;
    for (final action in actions) {
      if (identical(action, target)) return offset;
      if (action.dividerBefore) offset += 8;
      offset += 38;
    }
    return offset;
  }

  Widget _menuSurface(
    List<_MenuAction<T>> actions, {
    required double width,
    required ValueChanged<_MenuAction<T>> onAction,
  }) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 5)),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions) ...[
          if (action.dividerBefore)
            const Divider(height: 8, indent: 8, endIndent: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _AnimatedMenuAction<T>(
              action: action,
              onSelected: () => onAction(action),
            ),
          ),
        ],
      ],
    ),
  );

  void _openMenu() {
    _activeMenuCloser?.call();
    final token = Object();
    _menuToken = token;
    _activeMenuToken = token;
    _activeMenuCloser = _closeMenu;
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 32),
            child: TapRegion(
              groupId: _topMenuTapRegionGroup,
              onTapOutside: (_) => _closeMenu(),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOut,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuSurface(
                        widget.actions,
                        width: widget.menuWidth,
                        onAction: (action) {
                          if (action.submenu != null) {
                            _submenuOpen = !_submenuOpen;
                            _overlayEntry?.markNeedsBuild();
                          } else {
                            widget.onSelected(action.value);
                            _closeMenu();
                          }
                        },
                      ),
                      for (final action in widget.actions)
                        if (_submenuOpen && action.submenu != null) ...[
                          const SizedBox(width: 5),
                          Padding(
                            padding: EdgeInsets.only(
                              top: _submenuTopOffset(widget.actions, action),
                            ),
                            child: _menuSurface(
                              action.submenu!,
                              width: 160,
                              onAction: (submenuAction) {
                                widget.onSelected(submenuAction.value);
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
    if (entry == null) {
      if (identical(_activeMenuToken, _menuToken)) {
        _activeMenuCloser = null;
        _activeMenuToken = null;
        _menuToken = null;
      }
      return;
    }
    _overlayEntry = null;
    _submenuOpen = false;
    if (identical(_activeMenuToken, _menuToken)) {
      _activeMenuCloser = null;
      _activeMenuToken = null;
    }
    _menuToken = null;
    _animationController.reverse().whenCompleteOrCancel(() {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: TapRegion(
      groupId: _topMenuTapRegionGroup,
      child: DesktopTooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: _toggleMenu,
          hoverColor: AppTheme.border,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(6),
          child: widget.child,
        ),
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
              if (widget.action.submenu != null) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.mutedText,
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

class _GlobalSearchState extends State<_GlobalSearch>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final Object _tapRegionGroup = _globalSearchTapRegionGroup;
  OverlayEntry? _overlayEntry;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeMetrics() => _overlayEntry?.markNeedsBuild();

  void _onFocusChanged() {
    if (mounted && !_disposing) setState(() {});
  }

  @override
  void dispose() {
    _disposing = true;
    WidgetsBinding.instance.removeObserver(this);
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

class _ShortcutDialog extends StatelessWidget {
  const _ShortcutDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppTheme.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.border),
    ),
    child: SizedBox(
      width: math.min(980, MediaQuery.sizeOf(context).width - 32),
      height: math.min(700, MediaQuery.sizeOf(context).height - 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: KeyboardShortcutsPanel(
          onClose: () {
            Navigator.of(context).pop();
            // Return keyboard ownership to the shell after the modal route is
            // removed so Ctrl+/Ctrl- shortcuts keep working immediately.
            context
                .findAncestorStateOfType<_AppShellState>()
                ?._restoreShellFocus();
          },
        ),
      ),
    ),
  );
}

class _ShellSurface extends StatelessWidget {
  const _ShellSurface({
    super.key,
    required this.child,
    required this.radius,
    this.width,
  });

  final Widget child;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DesktopPane(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    ),
  );
}

class _LayoutDivider extends StatelessWidget {
  const _LayoutDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) => DesktopResizeHandle(onDrag: onDrag);
}

class _ActivityRail extends StatelessWidget {
  const _ActivityRail({
    required this.sections,
    required this.selectedSection,
    required this.modeSwitcherOpen,
    required this.onModeSwitcher,
    required this.onNavigate,
    required this.onProfile,
  });
  final List<NavSection> sections;
  final SectionId selectedSection;
  final bool modeSwitcherOpen;
  final VoidCallback onModeSwitcher;
  final ValueChanged<SectionId> onNavigate;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const railItems = <NavSection>[
      NavSection(
        id: SectionId.profile,
        label: 'User profile button',
        icon: Icons.account_circle_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.extensions,
        label: 'extensions',
        icon: Icons.auto_awesome_mosaic_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.modules,
        label: 'Modules',
        icon: Icons.extension_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.entity,
        label: 'Entity',
        icon: Icons.hub_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.bugReport,
        label: 'bug report',
        icon: Icons.bug_report_outlined,
        modes: {},
      ),
    ];

    return Container(
      key: const ValueKey<String>('activity rail content'),
      width: double.infinity,
      color: AppTheme.background,
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final item in railItems)
            _RailButton(
              item: item,
              active: !modeSwitcherOpen && item.id == selectedSection,
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
            active: !modeSwitcherOpen && selectedSection == SectionId.settings,
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
  Widget build(BuildContext context) => DesktopTooltip(
    message: widget.item.label,
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
    required this.showModuleActions,
    required this.showEntityActions,
    required this.showExtensionActions,
    required this.inspectorOpen,
    required this.modules,
    required this.entities,
    required this.extensions,
    required this.selectedExtensionId,
    required this.selectedEntity,
    required this.selectedModule,
    required this.onModuleSelected,
    this.onAddModule,
    this.onRemoveModule,
    this.onEditModule,
    this.onAddEntity,
    this.onRemoveEntity,
    this.onEditEntity,
    required this.onEntitySelected,
    required this.onExtensionSelected,
    required this.onExtensionNotification,
    required this.onToggleInspector,
  });
  final double width;
  final List<NavSection> sections;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool showModuleActions;
  final bool showEntityActions;
  final bool showExtensionActions;
  final bool inspectorOpen;
  final List<SystemModule> modules;
  final List<NeuralEntity> entities;
  final List<UserExtension> extensions;
  final String? selectedExtensionId;
  final NeuralEntity? selectedEntity;
  final SystemModule? selectedModule;
  final ValueChanged<SystemModule> onModuleSelected;
  final VoidCallback? onAddModule;
  final ValueChanged<SystemModule>? onRemoveModule;
  final ValueChanged<SystemModule>? onEditModule;
  final VoidCallback? onAddEntity;
  final ValueChanged<NeuralEntity>? onRemoveEntity;
  final ValueChanged<NeuralEntity>? onEditEntity;
  final ValueChanged<NeuralEntity> onEntitySelected;
  final ValueChanged<UserExtension> onExtensionSelected;
  final void Function(String title, String message, IconData icon)
  onExtensionNotification;
  final VoidCallback onToggleInspector;

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
  bool _activeModulesExpanded = true;
  bool _catalogModulesExpanded = true;
  bool _installedExtensionsExpanded = true;
  bool _recommendedExtensionsExpanded = false;

  List<SystemModule> _filterModules(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return widget.modules;
    return widget.modules.where((module) {
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

  List<UserExtension> get _installedExtensions =>
      widget.extensions.where((extension) => extension.downloaded).toList();

  List<UserExtension> get _recommendedExtensions =>
      widget.extensions.where((extension) => !extension.downloaded).toList();

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
                  if (widget.showModuleActions) ...[
                    _ExplorerActionButton(
                      icon: Icons.add,
                      tooltip: 'Add module',
                      onPressed: widget.onAddModule,
                    ),
                    _ExplorerActionButton(
                      icon: Icons.remove,
                      tooltip: 'Remove module',
                      onPressed: () {
                        final module =
                            widget.selectedModule ??
                            (_activeModules.isEmpty
                                ? null
                                : _activeModules.first);
                        if (module != null) {
                          widget.onRemoveModule?.call(module);
                        }
                      },
                    ),
                    _ExplorerActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit module',
                      onPressed: () {
                        final module =
                            widget.selectedModule ??
                            (_activeModules.isEmpty
                                ? null
                                : _activeModules.first);
                        if (module != null) {
                          widget.onEditModule?.call(module);
                        }
                      },
                    ),
                  ],
                  if (widget.showEntityActions) ...[
                    _ExplorerActionButton(
                      icon: Icons.add,
                      tooltip: 'Add entity',
                      onPressed: widget.onAddEntity,
                    ),
                    _ExplorerActionButton(
                      icon: Icons.remove,
                      tooltip: 'Remove entity',
                      onPressed: () {
                        final entity =
                            widget.selectedEntity ??
                            (widget.entities.isEmpty
                                ? null
                                : widget.entities.first);
                        if (entity != null) widget.onRemoveEntity?.call(entity);
                      },
                    ),
                    _ExplorerActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit entity',
                      onPressed: () {
                        final entity =
                            widget.selectedEntity ??
                            (widget.entities.isEmpty
                                ? null
                                : widget.entities.first);
                        if (entity != null) widget.onEditEntity?.call(entity);
                      },
                    ),
                  ],
                  if (widget.showExtensionActions ||
                      widget.showModuleActions ||
                      widget.showEntityActions)
                    _ExplorerActionButton(
                      key: widget.showExtensionActions
                          ? const ValueKey<String>('toggle extension inspector')
                          : null,
                      icon: widget.inspectorOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      tooltip: widget.inspectorOpen
                          ? 'Hide ${widget.showExtensionActions
                                ? 'extension'
                                : widget.showEntityActions
                                ? 'entity'
                                : 'module'} inspector'
                          : 'Show ${widget.showExtensionActions
                                ? 'extension'
                                : widget.showEntityActions
                                ? 'entity'
                                : 'module'} inspector',
                      onPressed: widget.onToggleInspector,
                    ),
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
                        if (widget.showModuleActions) ...[
                          ExplorerDisclosureSection(
                            title: 'ACTIVE MODULES',
                            expanded: _activeModulesExpanded,
                            onToggle: () => setState(
                              () => _activeModulesExpanded =
                                  !_activeModulesExpanded,
                            ),
                            children: [
                              _ModuleSearchField(
                                fieldKey: const ValueKey<String>(
                                  'active module search',
                                ),
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
                                _ModuleItem(
                                  module: module,
                                  selected:
                                      widget.selectedModule?.id == module.id,
                                  onTap: () => widget.onModuleSelected(module),
                                ),
                            ],
                          ),
                          ExplorerDisclosureSection(
                            title: 'MODULE CATALOG',
                            expanded: _catalogModulesExpanded,
                            onToggle: () => setState(
                              () => _catalogModulesExpanded =
                                  !_catalogModulesExpanded,
                            ),
                            showDivider: false,
                            children: [
                              _ModuleSearchField(
                                fieldKey: const ValueKey<String>(
                                  'catalog module search',
                                ),
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
                                _ModuleItem(
                                  module: module,
                                  catalog: true,
                                  selected:
                                      widget.selectedModule?.id == module.id,
                                  onTap: () => widget.onModuleSelected(module),
                                ),
                            ],
                          ),
                        ] else if (widget.showEntityActions) ...[
                          ExplorerSectionHeader(
                            title: 'INSTALLED ENTITIES',
                            expanded: _activeModulesExpanded,
                            onToggle: () => setState(
                              () => _activeModulesExpanded =
                                  !_activeModulesExpanded,
                            ),
                          ),
                          if (_activeModulesExpanded)
                            for (final entity in widget.entities.where(
                              (e) => e.installed,
                            ))
                              _EntityExplorerItem(
                                entity: entity,
                                selected:
                                    entity.id == widget.selectedEntity?.id,
                                onTap: () => widget.onEntitySelected(entity),
                              ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Divider(height: 1),
                          ),
                          ExplorerSectionHeader(
                            title: 'ENTITY CATALOG',
                            expanded: _catalogModulesExpanded,
                            onToggle: () => setState(
                              () => _catalogModulesExpanded =
                                  !_catalogModulesExpanded,
                            ),
                          ),
                          if (_catalogModulesExpanded)
                            for (final entity in widget.entities.where(
                              (e) => !e.installed,
                            ))
                              _EntityExplorerItem(
                                entity: entity,
                                selected:
                                    entity.id == widget.selectedEntity?.id,
                                onTap: () => widget.onEntitySelected(entity),
                              ),
                        ] else if (widget.showExtensionActions) ...[
                          ExplorerDisclosureSection(
                            title: 'Installed',
                            expanded: _installedExtensionsExpanded,
                            onToggle: () => setState(
                              () => _installedExtensionsExpanded =
                                  !_installedExtensionsExpanded,
                            ),
                            children: [
                              for (final extension in _installedExtensions)
                                _ExtensionExplorerItem(
                                  extension: extension,
                                  selected:
                                      extension.id ==
                                      widget.selectedExtensionId,
                                  onTap: () =>
                                      widget.onExtensionSelected(extension),
                                  onNotification:
                                      widget.onExtensionNotification,
                                ),
                            ],
                          ),
                          ExplorerDisclosureSection(
                            title: 'Recommended',
                            expanded: _recommendedExtensionsExpanded,
                            onToggle: () => setState(
                              () => _recommendedExtensionsExpanded =
                                  !_recommendedExtensionsExpanded,
                            ),
                            showDivider: false,
                            children: [
                              for (final extension in _recommendedExtensions)
                                _ExtensionExplorerItem(
                                  extension: extension,
                                  selected:
                                      extension.id ==
                                      widget.selectedExtensionId,
                                  onTap: () =>
                                      widget.onExtensionSelected(extension),
                                  onNotification:
                                      widget.onExtensionNotification,
                                ),
                            ],
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 28, 14, 14),
                            child: Text(
                              'No active workspace items',
                              style: TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleSearchField extends StatelessWidget {
  const _ModuleSearchField({
    this.fieldKey,
    required this.controller,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
    child: TextField(
      key: fieldKey,
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

class _ExplorerActionButton extends StatelessWidget {
  const _ExplorerActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DesktopIconButton(
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    size: 27,
    iconSize: 17,
  );
}

class _ModuleItem extends StatefulWidget {
  const _ModuleItem({
    required this.module,
    required this.onTap,
    this.catalog = false,
    this.selected = false,
  });
  final SystemModule module;
  final VoidCallback onTap;
  final bool catalog;
  final bool selected;

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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: widget.selected || _hovered
                ? AppTheme.border
                : Colors.transparent,
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
                color: widget.module.active
                    ? AppTheme.text
                    : AppTheme.mutedText,
              ),
            ],
          ),
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
  const _EditorTabs({
    required this.tabs,
    required this.active,
    required this.onCreate,
    required this.onSelect,
    required this.onClose,
    required this.explorerVisible,
    required this.onToggleExplorer,
    required this.showExplorerToggle,
  });

  final List<NavSection> tabs;
  final SectionId? active;
  final VoidCallback onCreate;
  final ValueChanged<SectionId> onSelect;
  final ValueChanged<SectionId> onClose;
  final bool explorerVisible;
  final VoidCallback onToggleExplorer;
  final bool showExplorerToggle;

  @override
  Widget build(BuildContext context) => Container(
    height: 35,
    color: AppTheme.background,
    child: Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              for (final tab in tabs)
                _EditorTab(
                  tab: tab,
                  selected: active == tab.id,
                  onSelect: () => onSelect(tab.id),
                  onClose: () => onClose(tab.id),
                ),
              _EditorTabAction(
                icon: Icons.add,
                tooltip: 'Create new tab',
                onPressed: onCreate,
              ),
            ],
          ),
        ),
        if (showExplorerToggle)
          _EditorTabAction(
            icon: explorerVisible
                ? Icons.view_sidebar_outlined
                : Icons.view_sidebar,
            tooltip: explorerVisible ? 'Hide Explorer' : 'Show Explorer',
            onPressed: onToggleExplorer,
          ),
        const SizedBox(width: 8),
      ],
    ),
  );
}

class _EditorTab extends StatefulWidget {
  const _EditorTab({
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final NavSection tab;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 205,
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppTheme.panel
              : _hovered
              ? AppTheme.border
              : AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(_phosphorFor(widget.tab.id), size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: DesktopIconButton(
                icon: Icons.close,
                tooltip: 'Close tab',
                onPressed: widget.onClose,
                size: 22,
                iconSize: 14,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EditorTabAction extends StatelessWidget {
  const _EditorTabAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DesktopIconButton(
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    size: 30,
    iconSize: 17,
  );
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tab_unselected, size: 42, color: AppTheme.mutedText),
          const SizedBox(height: 12),
          const Text('No open tabs', style: TextStyle(color: AppTheme.text)),
          const SizedBox(height: 5),
          const Text(
            'Create a new tab to continue',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create new tab'),
          ),
        ],
      ),
    ),
  );
}

class _ModuleEditorDialog extends StatefulWidget {
  const _ModuleEditorDialog({this.existing});

  final SystemModule? existing;

  @override
  State<_ModuleEditorDialog> createState() => _ModuleEditorDialogState();
}

class _ModuleEditorDialogState extends State<_ModuleEditorDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final module = widget.existing;
    _id = TextEditingController(text: module?.id ?? 'custom.module');
    _name = TextEditingController(text: module?.name ?? 'New module');
    _category = TextEditingController(text: module?.category ?? 'utility');
    _description = TextEditingController(
      text: module?.description ?? 'Custom module description.',
    );
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add module' : 'Edit module'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final old = widget.existing;
          Navigator.pop(
            context,
            SystemModule(
              id: _id.text.trim().isEmpty ? 'custom.module' : _id.text.trim(),
              name: _name.text.trim().isEmpty
                  ? 'New module'
                  : _name.text.trim(),
              category: _category.text.trim().isEmpty
                  ? 'utility'
                  : _category.text.trim(),
              description: _description.text.trim(),
              version: old?.version ?? '0.1.0',
              active: old?.active ?? true,
              stage: old?.stage ?? 'Custom',
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _EntityEditorDialog extends StatefulWidget {
  const _EntityEditorDialog({this.existing});

  final NeuralEntity? existing;

  @override
  State<_EntityEditorDialog> createState() => _EntityEditorDialogState();
}

class _EntityEditorDialogState extends State<_EntityEditorDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _framework;
  late final TextEditingController _version;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final entity = widget.existing;
    _id = TextEditingController(text: entity?.id ?? 'custom.neural-entity');
    _name = TextEditingController(text: entity?.name ?? 'New neural entity');
    _framework = TextEditingController(
      text: entity?.framework ?? 'ONNX Runtime',
    );
    _version = TextEditingController(text: entity?.version ?? '1.0.0');
    _description = TextEditingController(
      text: entity?.description ?? 'Neural network description.',
    );
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _framework.dispose();
    _version.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add entity' : 'Edit entity'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _framework,
              decoration: const InputDecoration(labelText: 'Framework'),
            ),
            TextField(
              controller: _version,
              decoration: const InputDecoration(labelText: 'Version'),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          NeuralEntity(
            id: _id.text.trim().isEmpty
                ? 'custom.neural-entity'
                : _id.text.trim(),
            name: _name.text.trim().isEmpty
                ? 'New neural entity'
                : _name.text.trim(),
            framework: _framework.text.trim().isEmpty
                ? 'Unknown'
                : _framework.text.trim(),
            version: _version.text.trim().isEmpty
                ? '1.0.0'
                : _version.text.trim(),
            description: _description.text.trim(),
            installed: widget.existing?.installed ?? false,
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}

class _EntityExplorerItem extends StatelessWidget {
  const _EntityExplorerItem({
    required this.entity,
    required this.selected,
    required this.onTap,
  });

  final NeuralEntity entity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ExplorerItem(
    title: entity.name,
    subtitle: '${entity.framework} · v${entity.version}',
    icon: Icons.hub_outlined,
    selected: selected,
    onTap: onTap,
  );
}

class _ExtensionExplorerItem extends StatelessWidget {
  const _ExtensionExplorerItem({
    required this.extension,
    required this.selected,
    required this.onTap,
    required this.onNotification,
  });

  final UserExtension extension;
  final bool selected;
  final VoidCallback onTap;
  final void Function(String title, String message, IconData icon)
  onNotification;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Material(
      color: selected ? AppTheme.background : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.border,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(extension.icon, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extension.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      extension.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (extension.downloaded)
                DesktopContextMenu(
                  tooltip: 'Extension settings',
                  actions: const [
                    'Disable/enable',
                    'Autoupdate',
                    'Uninstall',
                    'Copy link',
                    'Copy name',
                    'Keyboard',
                    'Profiles operate',
                    'Shortcuts',
                  ],
                  menuWidth: 208,
                  menuOffset: const Offset(-178, 30),
                  onSelected: (action) => onNotification(
                    'Extension changed',
                    '${extension.name}: $action selected.',
                    Icons.auto_awesome_mosaic_outlined,
                  ),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.settings_outlined,
                      size: 16,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExplorerItem extends StatelessWidget {
  const _ExplorerItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Material(
      color: selected ? AppTheme.background : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.border,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppTheme.text),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 10,
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
  );
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.open, required this.onToggle});
  final bool open;
  final VoidCallback onToggle;
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
                  IconButton(
                    key: const ValueKey<String>('terminal panel toggle'),
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
  const _SectionBody({
    required this.section,
    required this.modules,
    required this.onAddModule,
    required this.onEditModule,
    required this.onRemoveModule,
    required this.entities,
    required this.selectedEntity,
    required this.onAddEntity,
    required this.onEditEntity,
    required this.onRemoveEntity,
    required this.onToggleEntityInstalled,
    required this.selectedModule,
    required this.inspectorOpen,
    required this.selectedExtensionId,
    required this.extensionInspectorOpen,
    required this.onToggleInspector,
    required this.onSelectExtension,
  });
  final SectionId section;
  final List<SystemModule> modules;
  final VoidCallback onAddModule;
  final ValueChanged<SystemModule> onEditModule;
  final ValueChanged<SystemModule> onRemoveModule;
  final List<NeuralEntity> entities;
  final NeuralEntity? selectedEntity;
  final VoidCallback onAddEntity;
  final ValueChanged<NeuralEntity> onEditEntity;
  final ValueChanged<NeuralEntity> onRemoveEntity;
  final ValueChanged<NeuralEntity> onToggleEntityInstalled;
  final SystemModule? selectedModule;
  final bool inspectorOpen;
  final String? selectedExtensionId;
  final bool extensionInspectorOpen;
  final VoidCallback onToggleInspector;
  final ValueChanged<UserExtension> onSelectExtension;
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
        return ModulesScreen(
          modules: modules,
          onAdd: onAddModule,
          onEdit: onEditModule,
          onRemove: onRemoveModule,
          selectedModule: selectedModule,
          inspectorOpen: inspectorOpen,
          onToggleInspector: onToggleInspector,
        );
      case SectionId.entity:
        return EntityWorkspace(
          entity: selectedEntity,
          inspectorOpen: inspectorOpen,
          onToggleInspector: onToggleInspector,
          onEdit: onEditEntity,
          onRemove: onRemoveEntity,
          onToggleInstalled: onToggleEntityInstalled,
        );
      case SectionId.datasets:
        return const DatasetsScreen();
      case SectionId.models:
        return const ModelsScreen();
      case SectionId.developer:
        return const DeveloperScreen();
      case SectionId.extensions:
        return ExtensionsScreen(
          selectedExtensionId: selectedExtensionId,
          inspectorOpen: extensionInspectorOpen,
          onToggleInspector: onToggleInspector,
          onSelectExtension: onSelectExtension,
        );
      case SectionId.bugReport:
        return const BugReportScreen();
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
