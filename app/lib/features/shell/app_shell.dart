import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';
import '../common/desktop_menu.dart';
import '../common/desktop_scroll.dart';
import '../common/desktop_focus.dart';
import '../common/navigation_bindings.dart';
import '../modules/workspace_manager.dart';
import '../modules/workspace_group_dialog.dart';
import '../../core/workspace/workspace_project.dart';

import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_info.dart';
import '../../core/auth/auth_service.dart';
import '../../core/logging/debug_terminal_launcher.dart';
import '../../core/modules/module_registry.dart';
import '../../core/modules/local_module_store.dart';
import '../../core/modules/module_repository.dart';
import '../../core/modules/module_preview_data.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../state/workspace_state.dart';
import '../../state/workspace_providers.dart';
import '../../core/workspace/workspace_model.dart';
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
import '../modules/workspace_canvas_controller.dart';
import '../modules/workspace_presets.dart';
import '../marketplace/marketplace_screen.dart';
import '../marketplace/catalog_cover.dart';
import '../pipeline/pipeline_screen.dart';
import '../session/session_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/keyboard_shortcuts_panel.dart';
import '../spectrogram/spectrogram_screen.dart';
import 'layout_model.dart';
import 'nav_registry.dart';
import 'rail_settings.dart';

IconData _sectionIcon(SectionId id) {
  switch (id) {
    case SectionId.dashboard:
      return AppIcons.grid;
    case SectionId.devices:
      return AppIcons.usb;
    case SectionId.session:
      return AppIcons.record;
    case SectionId.pipeline:
      return AppIcons.workflow;
    case SectionId.spectrogram:
      return AppIcons.waveform;
    case SectionId.modules:
      return AppIcons.puzzle;
    case SectionId.entity:
      return AppIcons.network;
    case SectionId.datasets:
      return AppIcons.folders;
    case SectionId.models:
      return AppIcons.brain;
    case SectionId.developer:
      return AppIcons.terminal;
    case SectionId.extensions:
      return AppIcons.grid;
    case SectionId.bugReport:
      return AppIcons.bug;
    case SectionId.profile:
      return AppIcons.userCircle;
    case SectionId.settings:
      return AppIcons.settings;
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
  bool _explorerVisible = true;
  String settingsItem = 'General';
  SystemModule? _selectedModule;
  String? _selectedNodeId;
  NeuralEntity? _selectedEntity;
  String? _selectedExtensionId;
  bool _moduleInspectorOpen = false;
  bool _extensionInspectorOpen = false;
  bool _windowMaximized = false;
  bool _windowFullScreen = false;
  bool _canvasFullscreen = false;
  final _workspaceBodyKey = GlobalKey();
  final _workspaceCanvasController = WorkspaceCanvasController();
  final List<NavSection> _openTabs = <NavSection>[];
  SectionId? _activeTab;
  List<SystemModule> _workspaceModules = const <SystemModule>[];
  String? _railExtensionId;
  bool _railEditing = false;
  int _presetRequest = 0;

  List<SystemModule> get _availableModules =>
      {
        for (final module in [
          ...previewWorkspaceModules,
          ..._workspaceModules,
          ...ref.read(workspaceProvider).library,
        ])
          if (!ref.read(workspaceProvider).removedModuleIds.contains(module.id))
            module.id: module,
      }.values.map((module) {
        final workspace = ref.read(workspaceProvider);
        final manifest = workspace.authorMetadata[module.databaseId];
        final resolved = manifest == null
            ? module
            : module.withManifest(manifest);
        return resolved.withActive(
          workspace.moduleActiveOverrides[resolved.id] ??
              (resolved.active ||
                  workspace.nodes.any(
                    (n) =>
                        n.module.id == resolved.id &&
                        n.settings['enabled'] != false,
                  )),
        );
      }).toList();

  void _setModuleActive(SystemModule module, bool active) {
    ref.read(workspaceProvider.notifier).setModuleActive(module.id, active);
    setState(() {
      if (_selectedModule?.id == module.id) {
        _selectedModule = module.withActive(active);
      }
    });
  }

  Future<void> _showModuleSettings(SystemModule module, Offset position) async {
    final graph = ref.read(workspaceProvider);
    final moduleNodes = graph.projects
        .expand((project) => project.nodes)
        .where((node) => node.module.id == module.id)
        .toList();
    final action = await showDesktopMenu<String>(
      context: context,
      position: position,
      scale: _visualScale,
      width: 250,
      entries: [
        DesktopMenuEntry(value: 'delete', label: context.l10n.moduleDelete),
        DesktopMenuEntry(
          value: 'active',
          label: module.active
              ? context.l10n.moduleDeactivate
              : context.l10n.moduleActivate,
        ),
        DesktopMenuEntry(
          value: 'hidden',
          label: graph.hiddenModuleIds.contains(module.id)
              ? context.l10n.textShow232
              : context.l10n.textHide231,
        ),
        DesktopMenuEntry(
          value: 'fullyHidden',
          label:
              moduleNodes.isNotEmpty &&
                  moduleNodes.every((node) => node.fullyHidden)
              ? context.l10n.workspaceShowFully
              : context.l10n.workspaceHideFully,
        ),
        DesktopMenuEntry(
          value: 'edit',
          label: context.l10n.textEditModule160,
          dividerBefore: true,
        ),
        DesktopMenuEntry(
          value: 'move',
          label: context.l10n.moduleMoveToWorkspace,
          enabled:
              graph.nodes.any((n) => n.module.id == module.id) &&
              graph.projects.length > 1,
          submenu: [
            for (final project in graph.projects)
              if (project.id != graph.activeProjectId)
                DesktopMenuEntry(
                  value: 'move:${project.id}',
                  label: project.name,
                ),
          ],
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action.startsWith('move:')) {
      await moveWorkspaceNodes(
        context,
        ref,
        graph.nodes
            .where((n) => n.module.id == module.id)
            .map((n) => n.id)
            .toSet(),
        action.substring(5),
      );
      return;
    }
    switch (action) {
      case 'delete':
        await _removeModule(module);
      case 'active':
        _setModuleActive(module, !module.active);
      case 'hidden':
        ref
            .read(workspaceProvider.notifier)
            .setModuleHidden(
              module.id,
              !graph.hiddenModuleIds.contains(module.id),
            );
      case 'fullyHidden':
        ref
            .read(workspaceProvider.notifier)
            .setModuleFullyHidden(
              module.id,
              moduleNodes.isEmpty ||
                  !moduleNodes.every((node) => node.fullyHidden),
            );
      case 'edit':
        await _showModuleEditStub(module);
    }
  }

  Future<void> _showSceneNodeMenu(WorkspaceNode node, Offset position) async {
    final graph = ref.read(workspaceProvider);
    final hidden =
        graph.hiddenNodeIds.contains(node.id) ||
        graph.hiddenModuleIds.contains(node.module.id) ||
        node.fullyHidden;
    final action = await showDesktopMenu<String>(
      context: context,
      position: position,
      scale: _visualScale,
      width: 260,
      entries: [
        DesktopMenuEntry(value: 'select', label: context.l10n.textOpen309),
        DesktopMenuEntry(
          value: 'copy',
          label: context.l10n.workspaceCopy,
          shortcut: 'Ctrl+C',
        ),
        DesktopMenuEntry(
          value: 'cut',
          label: context.l10n.workspaceCut,
          shortcut: 'Ctrl+X',
        ),
        if (!node.isLogic)
          DesktopMenuEntry(
            value: 'settings',
            label: context.l10n.textModuleSettings301,
          ),
        DesktopMenuEntry(
          value: 'visibility',
          label: hidden ? context.l10n.textShow232 : context.l10n.textHide231,
        ),
        if (!node.isLogic && !node.fullyHidden)
          DesktopMenuEntry(
            value: 'fullyHidden',
            label: context.l10n.workspaceHideFully,
          ),
        DesktopMenuEntry(
          value: 'group',
          label: context.l10n.sceneMoveToGroup,
          submenu: [
            DesktopMenuEntry(
              value: 'newGroup',
              label: context.l10n.sceneCreateGroup,
            ),
            for (final group in graph.activeProject.groups)
              DesktopMenuEntry(
                value: 'group:${group.id}',
                label: group.name,
                shortcut: group.nodeIds.contains(node.id) ? '✓' : null,
              ),
            DesktopMenuEntry(
              value: 'ungroup',
              label: context.l10n.sceneRemoveFromGroup,
            ),
          ],
        ),
        DesktopMenuEntry(
          value: 'delete',
          label: context.l10n.moduleDelete,
          dividerBefore: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action.startsWith('group:')) {
      ref.read(workspaceProvider.notifier).moveToSceneGroup({
        node.id,
      }, action.substring(6));
      return;
    }
    switch (action) {
      case 'newGroup':
        await showDialog<void>(
          context: context,
          builder: (_) => WorkspaceGroupDialog(initialNodeId: node.id),
        );
      case 'copy':
        _workspaceCanvasController.copy?.call(node);
      case 'cut':
        _workspaceCanvasController.cut?.call(node);
      case 'ungroup':
        ref.read(workspaceProvider.notifier).moveToSceneGroup({node.id}, null);
      case 'select':
        setState(() {
          _selectedNodeId = node.id;
          _selectedModule = node.isLogic ? null : node.module;
        });
      case 'settings':
        setState(() {
          _selectedNodeId = node.id;
          _selectedModule = node.isLogic ? null : node.module;
        });
      case 'visibility':
        if (node.fullyHidden) {
          ref
              .read(workspaceProvider.notifier)
              .setNodeFullyHidden(node.id, false);
        } else {
          ref.read(workspaceProvider.notifier).setNodeHidden(node.id, !hidden);
        }
      case 'fullyHidden':
        ref.read(workspaceProvider.notifier).setNodeFullyHidden(node.id, true);
      case 'delete':
        ref.read(workspaceProvider.notifier).removeNode(node.id);
        if (_selectedNodeId == node.id) {
          setState(() {
            _selectedNodeId = null;
            _selectedModule = null;
          });
        }
    }
  }

  Future<void> _showModuleEditStub(SystemModule module) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.textEditModule160),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(module.displayName(context)),
            const SizedBox(height: 12),
            Text(
              context.l10n.textModuleSettings301,
              style: TextStyle(color: context.palette.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.moduleEditorPlaceholder,
              style: TextStyle(color: context.palette.mutedText),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.textClose110),
        ),
      ],
    ),
  );

  Future<void> _addPreset() async {
    final preset = await showWorkspacePresetEditor(context, _availableModules);
    if (preset != null && mounted) {
      ref.read(workspaceProvider.notifier).addPreset(preset);
    }
  }

  Future<void> _importPreset() async {
    try {
      final preset = await importWorkspacePreset();
      if (preset == null || !mounted) return;
      ref.read(workspaceProvider.notifier).addPreset(preset);
      _loadPreset(preset);
    } catch (error) {
      if (mounted) {
        _addNotification(
          context.l10n.textPresetNotImported69,
          '$error',
          AppIcons.error,
        );
      }
    }
  }

  Future<void> _loadPreset(WorkspacePreset preset) async {
    final request = ++_presetRequest;
    var missing = ref
        .read(workspaceProvider.notifier)
        .loadPreset(preset, _availableModules);
    _selectSection(SectionId.modules, ref.read(appModeProvider));
    if (missing.isNotEmpty) {
      try {
        final modules = await ModuleRepository().findPublishedByIds(missing);
        if (!mounted || request != _presetRequest) return;
        for (final module in modules) {
          ref.read(workspaceProvider.notifier).addToLibrary(module);
        }
        missing = missing
            .where((id) => !modules.any((module) => module.id == id))
            .toList();
      } catch (error) {
        if (!mounted || request != _presetRequest) return;
        _addNotification(
          context.l10n.textPresetCatalogUnavailable70,
          context.l10n.textArg0ThePresetRemainsLoaded71((error).toString()),
          AppIcons.warning,
        );
      }
    }
    if (!mounted || request != _presetRequest) return;
    if (missing.isNotEmpty) {
      _addNotification(
        context.l10n.textMissingWorkspaceModules72,
        context.l10n.textArg0Arg1ThePresetIsSavedFind73(
          (preset.name).toString(),
          (missing.join(', ')).toString(),
        ),
        AppIcons.warning,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.textMissingModulesArg074(
              (missing.join(', ')).toString(),
            ),
          ),
        ),
      );
    }
  }

  void _handleFileAction(String action) {
    if (action == 'save') unawaited(_saveWorkspace());
    if (action == 'add_workspace_preset') _addPreset();
    if (action == 'import_workspace_preset') _importPreset();
    if (action == 'new') {
      _selectSection(SectionId.modules, ref.read(appModeProvider));
      editWorkspace(context, ref);
    }
    if (action == 'open') _openWorkspaceManager();
  }

  void _openWorkspaceManager() {
    _selectSection(SectionId.modules, ref.read(appModeProvider));
    showWorkspaceManager(context);
  }

  void _handleEditAction(String action) {
    if (action == 'rail_settings') _openRailSettings();
    if (action == 'undo') ref.read(workspaceProvider.notifier).undo();
    if (action == 'redo') ref.read(workspaceProvider.notifier).redo();
  }

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

  bool get _windowUsesFullBounds => _windowMaximized || _windowFullScreen;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true).catchError((_) {}));
    ref.listenManual(workspaceProvider, (_, next) {
      final controller = ref.read(workspaceProvider.notifier);
      if (_lastHistoryNotice == controller.historyNotice) return;
      _lastHistoryNotice = controller.historyNotice;
      final redo = controller.lastHistoryWasRedo;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showHistoryNotice(
            redo
                ? context.l10n.workspaceRedoNotice
                : context.l10n.workspaceUndoNotice,
          );
        }
      });
    });
    _syncWindowBoundsState();
    ref.listenManual(authUserProvider, (previous, next) {
      next.whenData((_) => _loadUserModules());
    });
    _loadUserModules();
    final initial = kNavSections.firstWhere((s) => s.id == SectionId.modules);
    _openTabs.add(initial);
    _activeTab = initial.id;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _workspaceNoticeTimer?.cancel();
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

  int _lastHistoryNotice = 0;
  bool _closing = false;
  bool _savingWorkspace = false;
  String? _workspaceNotice;
  Timer? _workspaceNoticeTimer;

  void _showWorkspaceNotice(String message) {
    _workspaceNoticeTimer?.cancel();
    if (!mounted) return;
    setState(() => _workspaceNotice = message);
    _workspaceNoticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _workspaceNotice = null);
    });
  }

  void _showHistoryNotice(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          width: 300,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _saveWorkspace() async {
    if (_savingWorkspace) return;
    _savingWorkspace = true;
    try {
      if (await saveWorkspaceProgress(context, ref) && mounted) {
        _showWorkspaceNotice(context.l10n.workspaceSaved);
      }
    } finally {
      _savingWorkspace = false;
    }
  }

  @override
  void onWindowClose() async {
    if (_closing || _savingWorkspace) return;
    _closing = true;
    try {
      if (await confirmWorkspaceClose(context, ref) && mounted) {
        await windowManager.destroy();
      }
    } finally {
      _closing = false;
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _windowMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _windowMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _windowFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _windowFullScreen = false);
  }

  Future<void> _syncWindowBoundsState() async {
    try {
      final maximized = await windowManager.isMaximized();
      final fullScreen = await windowManager.isFullScreen();
      if (!mounted) return;
      setState(() {
        _windowMaximized = maximized;
        _windowFullScreen = fullScreen;
      });
    } catch (_) {
      // Native window methods are unavailable in widget tests.
    }
  }

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
        icon: AppIcons.userCircle,
        modes: {},
      );
    }
    if (id == SectionId.bugReport) {
      return const NavSection(
        id: SectionId.bugReport,
        label: 'Bug report',
        icon: AppIcons.bug,
        modes: {},
      );
    }
    return kNavSections.firstWhere((item) => item.id == id);
  }

  void _openTab(SectionId id) {
    final target = _tabDescriptor(id);
    final bool created = !_openTabs.any((tab) => tab.id == id);
    setState(() {
      if (created) _openTabs.add(target);
      _activeTab = id;
    });
    if (created) {
      logI(LogSource.shell, 'таб открыт: ${target.label}');
    }
  }

  void _closeTab(SectionId id) {
    logI(LogSource.shell, 'таб закрыт: ${_tabDescriptor(id).label}');
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
    ref.read(navSectionProvider.notifier).select(SectionId.modules);
    _openTab(SectionId.modules);
  }

  void _selectSection(SectionId id, AppMode mode) {
    _railExtensionId = null;
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
        title: Text(context.l10n.textNewTab76),
        children: [
          for (final item in visibleSections(mode))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item.id),
              child: Text(context.hostLabel(item.label)),
            ),
        ],
      ),
    );
    if (id != null && mounted) _selectSection(id, mode);
  }

  Future<void> _showModuleEditor([SystemModule? existing]) async {
    if (existing != null) {
      await _showModuleEditStub(existing);
      return;
    }
    if (AuthService.instance.currentUser == null) {
      _addNotification(
        context.l10n.textSignInRequired79,
        context.l10n.textSignInWithGitHubBeforeCreatingA1,
        AppIcons.userCircle,
      );
      ref.read(navSectionProvider.notifier).select(SectionId.profile);
      _openTab(SectionId.profile);
      return;
    }
    final result = await showDialog<SystemModule>(
      context: context,
      builder: (context) => _ModuleEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      final saved = await ModuleRepository().saveDraft(result);
      if (!mounted) return;
      ref
          .read(workspaceProvider.notifier)
          .saveAuthorMetadata(saved.databaseId!, result.manifest);
      setState(() {
        final index = _workspaceModules.indexWhere(
          (module) => module.databaseId == saved.databaseId,
        );
        _workspaceModules =
            index < 0 ? [..._workspaceModules, saved] : [..._workspaceModules]
              ..[index] = saved;
        _selectedModule = saved;
      });
    } catch (error) {
      if (!mounted) return;
      _addNotification(
        context.l10n.textModuleNotSaved80,
        '$error',
        AppIcons.error,
      );
      return;
    }
    logI(
      LogSource.modules,
      existing == null
          ? 'модуль добавлен: ${result.name} (${result.id})'
          : 'модуль изменён: ${result.name} (${result.id})',
    );
    _addNotification(
      existing == null
          ? context.l10n.textModuleAdded81
          : context.l10n.textModuleUpdated82,
      context.l10n.textArg0IsNowAvailableInWorkspace83(
        (result.name).toString(),
      ),
      AppIcons.puzzle,
    );
  }

  Future<void> _showModuleActions({Offset? position}) async {
    final box = context.findRenderObject() as RenderBox;
    final action = await showDesktopMenu<String>(
      context: context,
      position: position ?? box.localToGlobal(const Offset(80, 100)),
      scale: _visualScale,
      width: 280,
      itemHeight: 38,
      entries: [
        for (final entry in {
          'create-local': context.l10n.moduleCreateLocal,
          'create-online': context.l10n.moduleCreateOnline,
          'add-local': context.l10n.moduleAddLocal,
          'add-online': context.l10n.moduleAddOnline,
        }.entries)
          DesktopMenuEntry(value: entry.key, label: entry.value),
      ],
    );
    if (!mounted) return;
    try {
      switch (action) {
        case 'create-local':
          final directory = await getDirectoryPath();
          if (directory == null) return;
          await LocalModuleStore().createProject(directory);
          if (mounted) {
            _addNotification(
              context.l10n.localModuleProject,
              '$directory\npython3 qmod.py build .',
              AppIcons.code,
            );
          }
        case 'create-online':
          await _showModuleEditor();
        case 'add-local':
          final file = await openFile(
            acceptedTypeGroups: [
              const XTypeGroup(label: 'Qualia module', extensions: ['qmod']),
            ],
          );
          if (file == null || !mounted) return;
          if (await File(file.path).length() > LocalModuleStore.maxBytes) {
            throw const FormatException('Package is too large.');
          }
          if (!mounted) return;
          final trusted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.localModuleTrustTitle),
              content: Text(context.l10n.localModuleTrustWarning),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.textCancel198),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.moduleAddLocal),
                ),
              ],
            ),
          );
          if (trusted != true) return;
          final module = await LocalModuleStore().installFile(File(file.path));
          if (!mounted) return;
          ref.read(workspaceProvider.notifier).addToLibrary(module);
          setState(() => _selectedModule = module);
        case 'add-online':
          _selectSection(SectionId.extensions, ref.read(appModeProvider));
        default:
          break;
      }
    } catch (error) {
      if (mounted) {
        _addNotification(
          context.l10n.localModuleError,
          '$error',
          AppIcons.error,
        );
      }
    }
  }

  Future<void> _loadUserModules() async {
    if (!AuthService.instance.isInitialized ||
        AuthService.instance.currentUser == null) {
      if (mounted) {
        setState(() {
          _workspaceModules = const <SystemModule>[];
          _selectedModule = null;
        });
      }
      return;
    }
    try {
      final modules = await ModuleRepository().listMine();
      if (!mounted) return;
      setState(() {
        _workspaceModules = modules;
        final selectedId = _selectedModule?.databaseId;
        _selectedModule = selectedId == null
            ? null
            : modules
                  .where((module) => module.databaseId == selectedId)
                  .firstOrNull;
      });
    } catch (error) {
      logE(
        LogSource.modules,
        'ошибка загрузки пользовательских модулей: $error',
      );
      if (mounted) {
        _addNotification(
          context.l10n.textModulesUnavailable84,
          context.l10n.textCouldNotLoadModulesFromYourAccount85,
          AppIcons.cloudOffline,
        );
      }
    }
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
    logI(
      LogSource.entity,
      existing == null
          ? 'нейросеть добавлена: ${result.name} (${result.framework} v${result.version})'
          : 'нейросеть изменена: ${result.name}',
    );
    _addNotification(
      existing == null
          ? context.l10n.textEntityAdded86
          : context.l10n.textEntityUpdated87,
      context.l10n.textArg0IsNowAvailableInEntity88((result.name).toString()),
      AppIcons.network,
    );
  }

  void _removeEntity(NeuralEntity entity) {
    logI(LogSource.entity, 'нейросеть удалена: ${entity.name}');
    setState(() {
      _entities = _entities.where((item) => item.id != entity.id).toList();
      if (_selectedEntity?.id == entity.id) _selectedEntity = null;
    });
    _addNotification(
      context.l10n.textEntityRemoved89,
      context.l10n.textArg0WasRemovedFromEntity90((entity.name).toString()),
      AppIcons.trash,
    );
  }

  void _toggleEntityInstalled(NeuralEntity entity) {
    logI(
      LogSource.entity,
      entity.installed
          ? 'нейросеть деустановлена: ${entity.name}'
          : 'нейросеть установлена: ${entity.name}',
    );
    setState(() {
      final replacement = entity.copyWith(installed: !entity.installed);
      _entities = _entities
          .map((item) => item.id == entity.id ? replacement : item)
          .toList();
      _selectedEntity = replacement;
    });
    _addNotification(
      entity.installed
          ? context.l10n.textEntityUninstalled91
          : context.l10n.textEntityInstalled92,
      entity.name,
      AppIcons.network,
    );
  }

  Future<void> _removeModule(SystemModule module) async {
    ref.read(workspaceProvider.notifier).removeWorkspaceModule(module.id);
    setState(() {
      if (_selectedModule?.id == module.id) _selectedModule = null;
    });
    logI(LogSource.modules, 'модуль удалён из Workspace: ${module.id}');
  }

  void _addNotification(String title, String message, IconData icon) {
    ref
        .read(notificationProvider.notifier)
        .add(id: title, title: title, message: message, icon: icon);
  }

  void _changeScale(double delta) => _setScale(uiScale + delta);

  void _resetScale() => _setScale(1.0);

  /// Single funnel for scale changes: clamps the value and records the
  /// resulting percentage in the action log.
  void _setScale(double value) {
    final double next = value.clamp(_minScale, _maxScale).toDouble();
    if (next == uiScale) {
      return;
    }
    setState(() => uiScale = next);
    logI(LogSource.ui, 'масштаб интерфейса: ${(next * 100).round()}%');
  }

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
        context.l10n.textArg0VersionArg1BuiltByArg2For98(
          AppInfo.appName,
          AppInfo.version,
          AppInfo.organization,
        ),
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
        context.l10n.textYouAreRunningQualiaEngineArg0Update106(
          AppInfo.version,
        ),
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
        title: Text(dialogContext.hostLabel(content.$1)),
        content: Text(dialogContext.hostLabel(content.$2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.textClose110),
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

  Widget _buildActivityRail({
    required List<NavSection> sections,
    required AppMode mode,
    required SectionId section,
  }) {
    final config = ref.watch(railProvider);
    if (!config.visible) return const SizedBox.shrink();
    return _ShellSurface(
      key: const ValueKey<String>('activity rail surface'),
      width: layout.railWidth,
      radius: layout.radius,
      child: _ActivityRail(
        sections: sections,
        selectedSection: section,
        onNavigate: (id) => _selectSection(id, mode),
        onProfile: () => _selectSection(SectionId.profile, mode),
        config: config,
        onRailSettings: _openRailSettings,
        extensions: ref
            .watch(workspaceProvider)
            .library
            .where(
              (module) =>
                  config.extensions.contains(module.id) &&
                  module.manifest['kind'] == 'extension' &&
                  module.manifest['rail'] is Map,
            )
            .toList(),
        onExtension: (module) => setState(() => _railExtensionId = module.id),
      ),
    );
  }

  void _openRailSettings() => setState(() => _railEditing = true);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => _buildShell(context),
  );

  Widget _buildShell(BuildContext context) {
    final graph = ref.watch(workspaceProvider);
    final railVisible = ref.watch(railProvider).visible;
    final mode = ref.watch(appModeProvider);
    final section = ref.watch(navSectionProvider);
    final sections = visibleSections(mode);
    final selected = sections.indexWhere((item) => item.id == section);
    final active =
        _activeTabSection ??
        (selected < 0 ? sections.first : sections[selected]);
    final canvasFullscreen =
        _canvasFullscreen && active.id == SectionId.modules;
    final sectionBody = _SectionBody(
      key: _workspaceBodyKey,
      onOpenMarketplace: () => _selectSection(SectionId.extensions, mode),
      section: active.id,
      modules: _availableModules,
      onAddModule: _showModuleActions,
      onEditModule: _showModuleEditor,
      onRemoveModule: _removeModule,
      entities: _entities,
      selectedEntity: _selectedEntity,
      onAddEntity: _showEntityEditor,
      onEditEntity: _showEntityEditor,
      onRemoveEntity: _removeEntity,
      onToggleEntityInstalled: _toggleEntityInstalled,
      selectedModule: _selectedModule,
      inspectorOpen: active.id == SectionId.modules
          ? _moduleInspectorOpen
          : _extensionInspectorOpen,
      selectedExtensionId: _selectedExtensionId,
      extensionInspectorOpen: _extensionInspectorOpen,
      explorerVisible: _explorerVisible,
      onToggleExplorer: () =>
          setState(() => _explorerVisible = !_explorerVisible),
      onToggleInspector: () {
        if (active.id == SectionId.modules) {
          setState(() => _moduleInspectorOpen = !_moduleInspectorOpen);
        } else if (active.id == SectionId.extensions) {
          setState(() => _extensionInspectorOpen = !_extensionInspectorOpen);
        }
      },
      onSelectedModule: (module) => setState(() => _selectedModule = module),
      selectedNodeId: _selectedNodeId,
      onSelectedNode: (nodeId) => setState(() => _selectedNodeId = nodeId),
      onSelectExtension: (extension) =>
          setState(() => _selectedExtensionId = extension.id),
      canvasFullscreen: canvasFullscreen,
      onToggleCanvasFullscreen: () =>
          setState(() => _canvasFullscreen = !_canvasFullscreen),
      workspaceNotice: _workspaceNotice,
      canvasController: _workspaceCanvasController,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveWorkspace,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            ref.read(workspaceProvider.notifier).undo(),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () =>
            ref.read(workspaceProvider.notifier).redo(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            ref.read(workspaceProvider.notifier).redo(),
        ...NavigationBindings.instance.callbacks({
          NavigationAction.scaleUp: () => _changeScale(_scaleStep),
          NavigationAction.scaleDown: () => _changeScale(-_scaleStep),
          NavigationAction.scaleReset: _resetScale,
          NavigationAction.openWorkspace: _openWorkspaceManager,
          NavigationAction.findModule: () =>
              _selectSection(SectionId.modules, mode),
        }),
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
            return ClipRRect(
              borderRadius: BorderRadius.circular(
                _windowUsesFullBounds ? 0 : 8,
              ),
              child: ColoredBox(
                color: context.palette.background,
                child: ClipRect(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: width,
                      maxWidth: width,
                      minHeight: height,
                      maxHeight: height,
                      child: Transform.scale(
                        scale: visualScale,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: MediaQuery(
                            data: logicalMediaQuery,
                            child: Scaffold(
                              body: Stack(
                                children: [
                                  if (canvasFullscreen)
                                    Positioned.fill(child: sectionBody)
                                  else
                                    ExcludeFocus(
                                      excluding: _railEditing,
                                      child: Column(
                                        children: [
                                          _TitleBar(
                                            compact: width < 760,
                                            onOpenDebugConsole:
                                                _openDebugConsole,
                                            scale: uiScale,
                                            onScaleChanged: _setScale,
                                            onOpenPreferences: () => setState(
                                              () {
                                                settingsItem = 'General';
                                                ref
                                                    .read(
                                                      navSectionProvider
                                                          .notifier,
                                                    )
                                                    .select(SectionId.settings);
                                              },
                                            ),
                                            onHelpAction: _handleHelpAction,
                                            onViewAction: _handleViewAction,
                                            onFileAction: _handleFileAction,
                                            onEditAction: _handleEditAction,
                                          ),
                                          Expanded(
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child:
                                                      section ==
                                                          SectionId.profile
                                                      ? Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                layout.gap,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              _buildActivityRail(
                                                                sections:
                                                                    sections,
                                                                mode: mode,
                                                                section:
                                                                    section,
                                                              ),
                                                              if (railVisible)
                                                                _LayoutDivider(
                                                                  key:
                                                                      const ValueKey<
                                                                        String
                                                                      >(
                                                                        'rail resize handle',
                                                                      ),
                                                                  onDrag:
                                                                      _resizeRail,
                                                                ),
                                                              Expanded(
                                                                child: _ShellSurface(
                                                                  radius: layout
                                                                      .radius,
                                                                  child: ProfileScreen(
                                                                    onBack:
                                                                        _returnToApp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : section ==
                                                            SectionId.bugReport
                                                      ? Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                layout.gap,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              _buildActivityRail(
                                                                sections:
                                                                    sections,
                                                                mode: mode,
                                                                section:
                                                                    section,
                                                              ),
                                                              if (railVisible)
                                                                _LayoutDivider(
                                                                  key:
                                                                      const ValueKey<
                                                                        String
                                                                      >(
                                                                        'rail resize handle',
                                                                      ),
                                                                  onDrag:
                                                                      _resizeRail,
                                                                ),
                                                              Expanded(
                                                                child: _ShellSurface(
                                                                  radius: layout
                                                                      .radius,
                                                                  child:
                                                                      const BugReportScreen(),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : section ==
                                                            SectionId.settings
                                                      ? SettingsScreen(
                                                          initialItem:
                                                              settingsItem,
                                                          onBack: _returnToApp,
                                                        )
                                                      : Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                layout.gap,
                                                              ),
                                                          child: Stack(
                                                            children: [
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .stretch,
                                                                children: [
                                                                  _buildActivityRail(
                                                                    sections:
                                                                        sections,
                                                                    mode: mode,
                                                                    section:
                                                                        section,
                                                                  ),
                                                                  if (railVisible)
                                                                    _LayoutDivider(
                                                                      key:
                                                                          const ValueKey<
                                                                            String
                                                                          >(
                                                                            'rail resize handle',
                                                                          ),
                                                                      onDrag:
                                                                          _resizeRail,
                                                                    ),
                                                                  if (_explorerVisible &&
                                                                      active.id !=
                                                                          SectionId
                                                                              .modules &&
                                                                      active.id !=
                                                                          SectionId
                                                                              .extensions &&
                                                                      _railExtensionId ==
                                                                          null) ...[
                                                                    _ShellSurface(
                                                                      key:
                                                                          active.id ==
                                                                              SectionId.extensions
                                                                          ? const ValueKey<
                                                                              String
                                                                            >(
                                                                              'extensions explorer pane',
                                                                            )
                                                                          : null,
                                                                      width:
                                                                          effectiveExplorerWidth,
                                                                      radius: layout
                                                                          .radius,
                                                                      child: _Explorer(
                                                                        width:
                                                                            effectiveExplorerWidth,
                                                                        sections:
                                                                            sections,
                                                                        selected:
                                                                            selected <
                                                                                0
                                                                            ? 0
                                                                            : selected,
                                                                        showModuleActions:
                                                                            active.id ==
                                                                            SectionId.modules,
                                                                        showEntityActions:
                                                                            active.id ==
                                                                            SectionId.entity,
                                                                        showExtensionActions:
                                                                            active.id ==
                                                                            SectionId.extensions,
                                                                        modules:
                                                                            _availableModules,
                                                                        hiddenModuleIds:
                                                                            graph.hiddenModuleIds,
                                                                        canvasModuleIds: graph
                                                                            .nodes
                                                                            .where(
                                                                              (n) => !n.isLogic,
                                                                            )
                                                                            .map(
                                                                              (n) => n.module.id,
                                                                            )
                                                                            .toSet(),
                                                                        workspaceNodes:
                                                                            graph.nodes,
                                                                        selectedNodeId:
                                                                            _selectedNodeId,
                                                                        onWorkspaceNodeSelected: (node) {
                                                                          setState(() {
                                                                            _selectedNodeId =
                                                                                node.id;
                                                                            _selectedModule =
                                                                                node.isLogic
                                                                                ? null
                                                                                : node.module;
                                                                          });
                                                                        },
                                                                        onShowModule: (module) => ref
                                                                            .read(
                                                                              workspaceProvider.notifier,
                                                                            )
                                                                            .setModuleHidden(
                                                                              module.id,
                                                                              false,
                                                                            ),
                                                                        entities:
                                                                            _entities,
                                                                        extensions:
                                                                            kUserExtensions,
                                                                        selectedExtensionId:
                                                                            _selectedExtensionId,
                                                                        onExtensionSelected: (
                                                                          extension,
                                                                        ) => setState(() => _selectedExtensionId = extension.id),
                                                                        onExtensionNotification:
                                                                            _addNotification,
                                                                        selectedEntity:
                                                                            _selectedEntity,
                                                                        onSelected: (index) => _selectSection(
                                                                          sections[index]
                                                                              .id,
                                                                          mode,
                                                                        ),
                                                                        onAddModule: (
                                                                          position,
                                                                        ) => _showModuleActions(position: position),
                                                                        onRemoveModule:
                                                                            _removeModule,
                                                                        onEditModule:
                                                                            _showModuleEditStub,
                                                                        onModuleSettings: (
                                                                          module,
                                                                          position,
                                                                        ) => _showModuleSettings(module, position),
                                                                        onModuleActiveChanged:
                                                                            _setModuleActive,
                                                                        onAddEntity:
                                                                            _showEntityEditor,
                                                                        onRemoveEntity:
                                                                            _removeEntity,
                                                                        onEditEntity:
                                                                            _showEntityEditor,
                                                                        onEntitySelected: (
                                                                          entity,
                                                                        ) => setState(() => _selectedEntity = entity),
                                                                        selectedModule:
                                                                            _selectedModule,
                                                                        onModuleSelected: (
                                                                          module,
                                                                        ) => setState(() => _selectedModule = module),
                                                                      ),
                                                                    ),
                                                                    _LayoutDivider(
                                                                      key:
                                                                          active.id ==
                                                                              SectionId.extensions
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
                                                                      onDrag:
                                                                          (
                                                                            delta,
                                                                          ) => _resizeExplorer(
                                                                            delta,
                                                                            width,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                  Expanded(
                                                                    child: _ShellSurface(
                                                                      radius: layout
                                                                          .radius,
                                                                      child:
                                                                          _railExtensionId !=
                                                                              null
                                                                          ? ExtensionRailPage(
                                                                              module: graph.library.firstWhere(
                                                                                (module) => module.id == _railExtensionId,
                                                                              ),
                                                                              onBack: () => setState(
                                                                                () => _railExtensionId = null,
                                                                              ),
                                                                            )
                                                                          : active.id ==
                                                                                SectionId.extensions
                                                                          ? const MarketplaceScreen()
                                                                          : Column(
                                                                              children: [
                                                                                if (active.id != SectionId.modules)
                                                                                  _EditorTabs(
                                                                                    tabs: _openTabs,
                                                                                    active: _activeTab,
                                                                                    onCreate: () => _showTabPicker(mode),
                                                                                    onSelect: (id) => _selectSection(id, mode),
                                                                                    onClose: _closeTab,
                                                                                    explorerVisible: _explorerVisible,
                                                                                    onToggleExplorer: () => setState(() => _explorerVisible = !_explorerVisible),
                                                                                    showExplorerToggle: active.id == SectionId.modules,
                                                                                  ),
                                                                                Expanded(
                                                                                  child: _activeTabSection == null
                                                                                      ? _EmptyEditor(onCreate: () => _showTabPicker(mode))
                                                                                      : sectionBody,
                                                                                ),
                                                                                if (active.id != SectionId.modules)
                                                                                  _TerminalPanel(
                                                                                    open: terminalOpen,
                                                                                    onToggle: () {
                                                                                      setState(() {
                                                                                        terminalOpen = !terminalOpen;
                                                                                      });
                                                                                      logD(
                                                                                        LogSource.terminal,
                                                                                        terminalOpen
                                                                                            ? 'панель терминала раскрыта'
                                                                                            : 'панель терминала свернута',
                                                                                      );
                                                                                      _restoreShellFocus();
                                                                                    },
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                    ),
                                                                  ),
                                                                  if (_explorerVisible &&
                                                                      active.id ==
                                                                          SectionId
                                                                              .modules &&
                                                                      _railExtensionId ==
                                                                          null) ...[
                                                                    KeyedSubtree(
                                                                      key:
                                                                          const ValueKey<
                                                                            String
                                                                          >(
                                                                            'explorer resize handle',
                                                                          ),
                                                                      child: _LayoutDivider(
                                                                        key:
                                                                            const ValueKey<
                                                                              String
                                                                            >(
                                                                              'workspace scene collection resize handle',
                                                                            ),
                                                                        onDrag: (delta) => _resizeExplorer(
                                                                          -delta,
                                                                          width,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    _ShellSurface(
                                                                      key:
                                                                          const ValueKey<
                                                                            String
                                                                          >(
                                                                            'workspace scene collection pane',
                                                                          ),
                                                                      width:
                                                                          effectiveExplorerWidth,
                                                                      radius: layout
                                                                          .radius,
                                                                      child: _WorkspaceScenePane(
                                                                        canvasController:
                                                                            _workspaceCanvasController,
                                                                        width:
                                                                            effectiveExplorerWidth,
                                                                        nodes: graph
                                                                            .nodes,
                                                                        hiddenModuleIds:
                                                                            graph.hiddenModuleIds,
                                                                        hiddenNodeIds:
                                                                            graph.hiddenNodeIds,
                                                                        onAddModule: (
                                                                          position,
                                                                        ) => _showModuleActions(position: position),
                                                                        selectedNodeId:
                                                                            _selectedNodeId,
                                                                        onWorkspaceNodeSelected: (node) {
                                                                          setState(() {
                                                                            _selectedNodeId =
                                                                                node.id;
                                                                            _selectedModule =
                                                                                node.isLogic
                                                                                ? null
                                                                                : node.module;
                                                                          });
                                                                        },
                                                                        onNodeMenu: (
                                                                          node,
                                                                          position,
                                                                        ) => _showSceneNodeMenu(node, position),
                                                                        onShowNode: (node) {
                                                                          final controller = ref.read(
                                                                            workspaceProvider.notifier,
                                                                          );
                                                                          if (node
                                                                              .fullyHidden) {
                                                                            controller.setNodeFullyHidden(
                                                                              node.id,
                                                                              false,
                                                                            );
                                                                          } else {
                                                                            controller.setNodeHidden(
                                                                              node.id,
                                                                              false,
                                                                            );
                                                                          }
                                                                        },
                                                                        onHideNode: (node) => ref
                                                                            .read(
                                                                              workspaceProvider.notifier,
                                                                            )
                                                                            .setNodeHidden(
                                                                              node.id,
                                                                              true,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
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
                                  if (_railEditing)
                                    Positioned.fill(
                                      child: RailCustomizer(
                                        railWidth: layout.railWidth,
                                        feedbackScale: visualScale,
                                        gap: layout.gap,
                                        onClose: () {
                                          setState(() => _railEditing = false);
                                          _restoreShellFocus();
                                        },
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
    required this.onFileAction,
    required this.onEditAction,
    required this.scale,
    required this.onScaleChanged,
  });
  final bool compact;
  final VoidCallback onOpenDebugConsole;
  final VoidCallback onOpenPreferences;
  final ValueChanged<String> onHelpAction;
  final ValueChanged<String> onViewAction;
  final ValueChanged<String> onFileAction;
  final ValueChanged<String> onEditAction;
  final double scale;
  final ValueChanged<double> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('shell titlebar'),
      height: 36,
      decoration: BoxDecoration(color: context.palette.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: DragToMoveArea(child: const SizedBox.expand()),
          ),
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 0,
                  height: 0,
                  child: Text('Ayakiro BCI Engine'),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 26,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.panel,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.asset('assets/icons/bci_engine_64.png'),
                ),
                const SizedBox(width: 8),
                TapRegion(
                  groupId:
                      _AnimatedContextMenuButtonState._topMenuTapRegionGroup,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TopMenuItem(
                        label: 'File',
                        onPreferences: onOpenPreferences,
                        onAction: onFileAction,
                      ),
                      _TopMenuItem(label: 'Edit', onAction: onEditAction),
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
                          tooltip: context.l10n.textInterfaceScaleCtrlCtrl112,
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
                              color: context.palette.panel,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(scale * 100).round()}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: context.palette.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const _WindowControls(),
                        const SizedBox(width: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              color: context.palette.panel,
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
            icon: _hasUnread ? AppIcons.bellRinging : AppIcons.bell,
            tooltip: context.l10n.textNotifications113,
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
                  decoration: BoxDecoration(
                    color: context.palette.text,
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

String _notificationTime(BuildContext context, DateTime createdAt) {
  final elapsed = DateTime.now().difference(createdAt);
  if (elapsed.inMinutes < 1) return context.hostLabel('Just now');
  if (elapsed.inHours < 1) {
    return context.l10n.textArg0MinAgo115(elapsed.inMinutes.toString());
  }
  if (elapsed.inDays < 1) {
    return context.l10n.textArg0HAgo116(elapsed.inHours.toString());
  }
  return context.l10n.textArg0DAgo117(elapsed.inDays.toString());
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
              Expanded(
                child: Text(
                  context.l10n.textNotifications113,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasUnread)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: context.palette.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.textMarkAllAsRead118,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              context.l10n.textNoNotifications119,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.mutedText),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 5),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return DesktopHoverTile(
                  onTap: () => onMarkRead(item.id),
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: context.palette.mutedText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: context.palette.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.palette.mutedText,
                                  fontSize: 11,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _notificationTime(context, item.createdAt),
                                style: TextStyle(
                                  color: context.palette.mutedText,
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
                            decoration: BoxDecoration(
                              color: context.palette.text,
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
    icon: AppIcons.bug,
    tooltip: context.l10n.textOpenDebugTerminal120,
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
        tooltip: context.l10n.textMinimizeWindow121,
        icon: AppIcons.minus,
        onPressed: () => windowManager.minimize(),
      ),
      _button(
        tooltip: _maximized
            ? context.l10n.textRestoreWindow122
            : context.l10n.textMaximizeWindow123,
        icon: _maximized ? AppIcons.copy : AppIcons.square,
        onPressed: _toggleMaximize,
      ),
      _button(
        tooltip: context.l10n.textCloseWindow19,
        icon: AppIcons.close,
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

  List<_MenuAction<String>> _items(BuildContext context) {
    switch (label) {
      case 'File':
        return [
          _MenuAction(
            value: 'save',
            label: context.l10n.workspaceSave,
            shortcut: 'Ctrl+S',
          ),
          _MenuAction(
            value: 'add_workspace_preset',
            label: context.l10n.textAddWorkspacePreset124,
          ),
          _MenuAction(
            value: 'import_workspace_preset',
            label: context.l10n.textImportWorkspacePreset165,
          ),
          _MenuAction(value: 'new', label: context.l10n.textNewWorkspace125),
          _MenuAction(
            value: 'open',
            label: context.l10n.textOpenProject126,
            shortcut: NavigationBindings.instance.label(
              NavigationAction.openWorkspace,
            ),
          ),
          _MenuAction(
            value: 'import',
            label: context.l10n.textImportModuleSoon127,
            enabled: false,
            shortcut: 'Ctrl+Shift+M',
            dividerBefore: true,
          ),
          _MenuAction(
            value: 'preferences',
            label: context.l10n.textPreferences128,
            shortcut: 'Ctrl+,',
            dividerBefore: true,
          ),
        ];
      case 'Edit':
        return [
          _MenuAction(
            value: 'rail_settings',
            label: context.l10n.textRailSettings129,
          ),
          _MenuAction(
            value: 'undo',
            label: context.l10n.textUndo130,
            shortcut: 'Ctrl+Z',
          ),
          _MenuAction(
            value: 'redo',
            label: context.l10n.textRedo131,
            shortcut: 'Ctrl+Y',
          ),
          _MenuAction(
            value: 'preferences',
            label: context.l10n.textPreferencesSoon132,
            enabled: false,
            dividerBefore: true,
          ),
        ];
      case 'View':
        return [
          _MenuAction(
            value: 'explorer',
            label: context.l10n.textExplorer133,
            shortcut: 'Ctrl+Shift+E',
          ),
          _MenuAction(
            value: 'terminal',
            label: context.l10n.textTerminal134,
            shortcut: 'Ctrl+J',
          ),
          _MenuAction(
            value: 'layout',
            label: context.l10n.textCustomizeLayoutSoon135,
            enabled: false,
            dividerBefore: true,
          ),
          _MenuAction(
            value: 'theme',
            label: context.l10n.textTheme136,
            dividerBefore: true,
            submenu: [
              _MenuAction(
                value: 'theme_system',
                label: context.l10n.textSystem137,
              ),
              _MenuAction(value: 'theme_dark', label: context.l10n.textDark138),
              _MenuAction(
                value: 'theme_light',
                label: context.l10n.textWhite139,
              ),
            ],
          ),
        ];
      case 'Help':
        return [
          _MenuAction(
            value: 'documentation',
            label: context.l10n.textDocumentation95,
          ),
          _MenuAction(value: 'about', label: context.l10n.textAboutUs97),
          _MenuAction(value: 'welcome', label: context.l10n.textWelcome140),
          _MenuAction(value: 'tutorials', label: context.l10n.textTutorials101),
          _MenuAction(value: 'license', label: context.l10n.textLicense103),
          _MenuAction(
            value: 'updates',
            label: context.l10n.textCheckUpdates105,
            dividerBefore: true,
          ),
          _MenuAction(
            value: 'report_issue',
            label: context.l10n.textReportIssue141,
          ),
          _MenuAction(value: 'youtube', label: context.l10n.textOurYoutube107),
        ];
      default:
        return [
          _MenuAction(
            value: 'build',
            label: context.l10n.textBuildProject142,
            shortcut: 'Ctrl+B',
          ),
          _MenuAction(
            value: 'run',
            label: context.l10n.textRunSession143,
            shortcut: 'F5',
          ),
          _MenuAction(
            value: 'tasks',
            label: context.l10n.textBuildTasksSoon144,
            enabled: false,
            dividerBefore: true,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => _AnimatedContextMenuButton<String>(
    key: ValueKey<String>('$label menu button'),
    tooltip: context.l10n.textArg0Menu145(context.hostLabel(label)),
    actions: _items(context),
    onSelected: (value) {
      if (value == 'preferences') onPreferences?.call();
      onAction?.call(value);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        context.hostLabel(label),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: context.palette.mutedText),
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
  late final FocusNode _triggerFocus = FocusNode(debugLabel: widget.tooltip);
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
  void didUpdateWidget(covariant _AnimatedContextMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    if (identical(_activeMenuToken, _menuToken)) {
      _activeMenuCloser = null;
      _activeMenuToken = null;
    }
    _menuToken = null;
    _triggerFocus.dispose();
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
  }) {
    final entries = [
      for (final action in actions)
        DesktopMenuEntry<_MenuAction<T>>(
          value: action,
          label: action.label,
          enabled: action.enabled,
          dividerBefore: action.dividerBefore,
          shortcut: action.shortcut,
          submenu: action.submenu == null ? null : const [],
        ),
    ];
    return DesktopMenuSurface<_MenuAction<T>>(
      width: desktopMenuWidth(context, entries, width),
      entries: entries,
      onSelected: (entry) => onAction(entry.value),
    );
  }

  void _openMenu() {
    _activeMenuCloser?.call();
    final token = Object();
    _menuToken = token;
    _activeMenuToken = token;
    _activeMenuCloser = _closeMenu;
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => FocusScope(
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (_submenuOpen) {
                _submenuOpen = false;
                _overlayEntry?.markNeedsBuild();
              } else {
                _closeMenu();
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                _submenuOpen) {
              _submenuOpen = false;
              _overlayEntry?.markNeedsBuild();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
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
                                  top: _submenuTopOffset(
                                    widget.actions,
                                    action,
                                  ),
                                ),
                                child: FocusScope(
                                  child: _menuSurface(
                                    action.submenu!,
                                    width: 160,
                                    onAction: (submenuAction) {
                                      widget.onSelected(submenuAction.value);
                                      _closeMenu();
                                    },
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
    _triggerFocus.requestFocus();
    _animationController.reverse().whenCompleteOrCancel(() {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: TapRegion(
      groupId: _topMenuTapRegionGroup,
      child: MouseRegion(
        onEnter: (_) {
          if (_activeMenuToken != null && _overlayEntry == null) _openMenu();
        },
        child: DesktopTooltip(
          message: widget.tooltip,
          child: DesktopHoverTile(
            onTap: _toggleMenu,
            focusNode: _triggerFocus,
            label: widget.tooltip,
            borderRadius: BorderRadius.circular(6),
            child: widget.child,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchSectionTitle('QUICK ACTIONS'),
                        _SearchAction(
                          icon: AppIcons.fileOpen,
                          label: 'Open project',
                          shortcut: 'Ctrl+O',
                        ),
                        _SearchAction(
                          icon: AppIcons.puzzle,
                          label: 'Find module',
                          shortcut: 'Ctrl+Shift+M',
                        ),
                        Divider(height: 12),
                        _SearchSectionTitle('KEYBOARD SHORTCUTS'),
                        _SearchAction(
                          icon: AppIcons.zoomIn,
                          label: 'Increase interface scale',
                          shortcut: 'Ctrl++',
                        ),
                        _SearchAction(
                          icon: AppIcons.zoomOut,
                          label: 'Decrease interface scale',
                          shortcut: 'Ctrl+-',
                        ),
                        _SearchAction(
                          icon: AppIcons.sliders,
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
      duration: AppTheme.hoverDuration,
      curve: AppTheme.hoverCurve,
      decoration: BoxDecoration(
        color: context.palette.searchField,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TapRegion(
        groupId: _tapRegionGroup,
        onTapOutside: (_) => _removeMenu(),
        child: TextField(
          key: const ValueKey<String>('global search field'),
          controller: _controller,
          focusNode: _focusNode,
          onTapAlwaysCalled: true,
          onTap: _toggleMenu,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              logI(LogSource.ui, 'поиск: ${value.trim()}');
            }
            _removeMenu();
          },
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.text, fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.palette.searchField,
            hintText: context.l10n.textSearchFilesSymbolsCtrlP152,
            hintStyle: TextStyle(
              color: context.palette.mutedText,
              fontSize: 11,
            ),
            prefixIcon: Icon(AppIcons.search, size: 16),
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
      style: TextStyle(
        color: context.palette.mutedText,
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
      child: DesktopFocusableAction(
        onActivate: widget.onTap,
        label: context.hostLabel(widget.label),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.hoverCurve,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? context.palette.hover
                  : context.palette.hover.withAlpha(0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 17, color: context.palette.text),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.hostLabel(widget.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.text),
                  ),
                ),
                if (widget.shortcut != null)
                  Text(
                    widget.shortcut!,
                    style: TextStyle(color: context.palette.mutedText),
                  ),
              ],
            ),
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
    backgroundColor: context.palette.panel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    required this.onNavigate,
    required this.onProfile,
    required this.config,
    required this.onRailSettings,
    required this.extensions,
    required this.onExtension,
  });
  final List<NavSection> sections;
  final SectionId selectedSection;
  final ValueChanged<SectionId> onNavigate;
  final VoidCallback onProfile;
  final RailConfiguration config;
  final VoidCallback onRailSettings;
  final List<SystemModule> extensions;
  final ValueChanged<SystemModule> onExtension;

  @override
  Widget build(BuildContext context) {
    final entries = {
      for (final entry in railEntries(context, extensions)) entry.id: entry,
    };
    final ordered = [
      ...config.topKeys,
      ...config.bottomKeys,
    ].where(entries.containsKey).map((key) => entries[key]!).toList();

    return GestureDetector(
      onSecondaryTapDown: (details) async {
        final action = await showDesktopMenu<String>(
          context: context,
          position: details.globalPosition,
          entries: [
            DesktopMenuEntry(
              value: 'settings',
              label: context.l10n.textRailSettings129,
            ),
          ],
        );
        if (action == 'settings') onRailSettings();
      },
      child: Container(
        key: const ValueKey<String>('activity rail content'),
        width: double.infinity,
        color: context.palette.background,
        child: Column(
          children: [
            const SizedBox(height: 8),
            DesktopIconButton(
              icon: AppIcons.sliders,
              tooltip: context.l10n.textRailSettings129,
              onPressed: onRailSettings,
              size: 36,
              iconSize: 19,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in ordered) ...[
                        if (config.bottomKeys.firstOrNull == item.id)
                          SizedBox(
                            height: math.max(
                              0,
                              bounds.maxHeight - ordered.length * 44,
                            ),
                          ),
                        if (item.section != null)
                          _RailButton(
                            item: NavSection(
                              id: item.section!,
                              label: switch (item.section!) {
                                SectionId.profile =>
                                  context.l10n.textUserProfileButton153,
                                SectionId.settings => 'configs',
                                SectionId.bugReport =>
                                  context.l10n.textBugReport154,
                                _ => item.label,
                              },
                              icon: item.icon,
                              modes: const {},
                            ),
                            active: item.section == selectedSection,
                            enabled: true,
                            onTap: item.section == SectionId.profile
                                ? onProfile
                                : () => onNavigate(item.section!),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: DesktopIconButton(
                              icon: item.icon,
                              tooltip: item.label,
                              onPressed: () => onExtension(item.module!),
                              size: 40,
                              iconSize: 20,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    message: context.hostLabel(widget.item.label),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: DesktopFocusableAction(
        onActivate: widget.enabled ? widget.onTap : null,
        label: context.hostLabel(widget.item.label),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.hoverCurve,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _hovered && widget.enabled
                  ? context.palette.hover
                  : widget.active
                  ? context.palette.panel
                  : context.palette.hover.withAlpha(0),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: DesktopColorTransition(
                color: widget.active
                    ? context.palette.text
                    : widget.enabled
                    ? context.palette.mutedText
                    : context.palette.mutedText.withAlpha(110),
                builder: (context, color) => Icon(
                  AppIcons.resolve(widget.item.icon, active: widget.active),
                  size: 20,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Workspace-only right pane: scene instances, never the module catalog.
class _WorkspaceScenePane extends ConsumerStatefulWidget {
  const _WorkspaceScenePane({
    required this.width,
    required this.nodes,
    required this.hiddenModuleIds,
    required this.hiddenNodeIds,
    required this.selectedNodeId,
    required this.onWorkspaceNodeSelected,
    required this.onNodeMenu,
    required this.onShowNode,
    required this.onHideNode,
    this.onAddModule,
    required this.canvasController,
  });

  final double width;
  final List<WorkspaceNode> nodes;
  final Set<String> hiddenModuleIds;
  final Set<String> hiddenNodeIds;
  final String? selectedNodeId;
  final ValueChanged<WorkspaceNode> onWorkspaceNodeSelected;
  final void Function(WorkspaceNode node, Offset position) onNodeMenu;
  final ValueChanged<WorkspaceNode> onShowNode;
  final ValueChanged<WorkspaceNode> onHideNode;
  final ValueChanged<Offset>? onAddModule;
  final WorkspaceCanvasController canvasController;

  @override
  ConsumerState<_WorkspaceScenePane> createState() =>
      _WorkspaceScenePaneState();
}

class _WorkspaceScenePaneState extends ConsumerState<_WorkspaceScenePane> {
  final _search = TextEditingController();
  final _scroll = DesktopScrollController(debugLabel: 'scene collection');
  final _expandedNodeIds = <String>{};
  String _query = '';
  bool _collectionExpanded = true;
  final _collapsedGroups = <String>{};

  Future<void> _editGroup([WorkspaceSceneGroup? group]) => showDialog<void>(
    context: context,
    builder: (_) => WorkspaceGroupDialog(group: group),
  );

  Widget _groupRow(WorkspaceSceneGroup group, List<WorkspaceNode> matching) {
    final graph = ref.read(workspaceProvider);
    final hidden =
        group.nodeIds.isNotEmpty &&
        group.nodeIds.every(
          (id) =>
              graph.hiddenNodeIds.contains(id) ||
              graph.nodes.any(
                (node) =>
                    node.id == id &&
                    graph.hiddenModuleIds.contains(node.module.id),
              ),
        );
    final nodes = matching
        .where((node) => group.nodeIds.contains(node.id))
        .toList();
    final expanded =
        !_collapsedGroups.contains(group.id) || _query.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopHoverTile(
          key: ValueKey('scene group ${group.id}'),
          onTap: () => setState(() {
            if (!_collapsedGroups.remove(group.id)) {
              _collapsedGroups.add(group.id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
            child: Row(
              children: [
                Icon(
                  expanded ? AppIcons.caretDown : AppIcons.caretRight,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? AppIcons.folderOpen : AppIcons.folders,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${group.nodeIds.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.mutedText,
                  ),
                ),
                DesktopIconButton(
                  key: ValueKey('scene group visibility ${group.id}'),
                  icon: hidden ? AppIcons.eyeOff : AppIcons.eye,
                  tooltip: hidden
                      ? context.l10n.textShow232
                      : context.l10n.textHide231,
                  size: 26,
                  iconSize: 15,
                  onPressed: group.nodeIds.isEmpty
                      ? null
                      : () => ref
                            .read(workspaceProvider.notifier)
                            .setSceneGroupHidden(group.id, !hidden),
                ),
                DesktopMenuButton<String>(
                  key: ValueKey('scene group menu ${group.id}'),
                  tooltip: context.l10n.sceneEditGroup,
                  entries: [
                    DesktopMenuEntry(
                      value: 'visibility',
                      label: hidden
                          ? context.l10n.textShow232
                          : context.l10n.textHide231,
                      enabled: group.nodeIds.isNotEmpty,
                    ),
                    DesktopMenuEntry(
                      value: 'edit',
                      label: context.l10n.sceneEditGroup,
                    ),
                    DesktopMenuEntry(
                      value: 'remove',
                      label: context.l10n.sceneDissolveGroup,
                    ),
                  ],
                  onSelected: (action) {
                    if (action == 'edit') {
                      _editGroup(group);
                    } else if (action == 'visibility') {
                      ref
                          .read(workspaceProvider.notifier)
                          .setSceneGroupHidden(group.id, !hidden);
                    } else {
                      ref
                          .read(workspaceProvider.notifier)
                          .removeSceneGroup(group.id);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(AppIcons.more, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final node in nodes)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _nodeRow(node),
            ),
      ],
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<WorkspaceNode> _matchingNodes() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.nodes;
    final groupMembers = {
      for (final group in ref.read(workspaceProvider).activeProject.groups)
        if (group.name.toLowerCase().contains(query)) ...group.nodeIds,
    };
    return widget.nodes.where((node) {
      if (groupMembers.contains(node.id)) return true;
      final name = node.isLogic
          ? context.logicBlockLabel(node.logicType.name)
          : node.module.displayName(context);
      return '$name ${node.module.id} ${node.id}'.toLowerCase().contains(query);
    }).toList();
  }

  Widget _nodeRow(WorkspaceNode node) {
    final selected = ref.watch(selectionProvider).ids.contains(node.id);
    final expanded = _expandedNodeIds.contains(node.id);
    final hidden =
        widget.hiddenNodeIds.contains(node.id) ||
        widget.hiddenModuleIds.contains(node.module.id) ||
        node.fullyHidden;
    final title = node.isLogic
        ? context.logicBlockLabel(node.logicType.name)
        : node.module.displayName(context);
    final selectedFill = context.palette.hover;
    final selectedText = context.palette.text;
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            widget.onNodeMenu(node, details.globalPosition),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: hidden ? .52 : 1,
              child: DesktopHoverTile(
                key: ValueKey('scene collection node ${node.id}'),
                selected: selected,
                selectedColor: selectedFill,
                hoverColor: context.palette.hover,
                borderRadius: BorderRadius.circular(6),
                onTap: () => _selectSceneNode(node),
                label: title,
                child: SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      DesktopIconButton(
                        key: ValueKey(
                          'scene collection object toggle ${node.id}',
                        ),
                        icon: expanded
                            ? AppIcons.caretDown
                            : AppIcons.caretRight,
                        tooltip: expanded ? 'Collapse object' : 'Expand object',
                        size: 22,
                        iconSize: 15,
                        onPressed: () => setState(() {
                          if (expanded) {
                            _expandedNodeIds.remove(node.id);
                          } else {
                            _expandedNodeIds.add(node.id);
                            _selectSceneNode(node);
                          }
                        }),
                      ),
                      Icon(
                        AppIcons.resolve(
                          node.isLogic ? AppIcons.workflow : AppIcons.puzzle,
                          active: selected,
                        ),
                        size: 15,
                        color: selected
                            ? selectedText
                            : context.palette.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? selectedText
                                : context.palette.text,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      DesktopIconButton(
                        key: ValueKey('scene collection visibility ${node.id}'),
                        icon: hidden ? AppIcons.eyeOff : AppIcons.eye,
                        tooltip: hidden
                            ? context.l10n.textShow232
                            : context.l10n.textHide231,
                        size: 24,
                        iconSize: 16,
                        onPressed: () => hidden
                            ? widget.onShowNode(node)
                            : widget.onHideNode(node),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(43, 0, 12, 6),
                child: Text(
                  node.isLogic
                      ? node.logicType.name
                      : '${node.module.id} · ${node.id}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Selection is UI state owned by Riverpod, not by the canvas command
    // bridge. This keeps the scene collection and canvas on one state stream.
    ref.watch(selectionProvider);
    return _buildPane(context);
  }

  void _selectSceneNode(WorkspaceNode node) {
    final select = widget.canvasController.selectFromScene;
    if (select != null) {
      select(node, HardwareKeyboard.instance.isControlPressed);
    } else {
      widget.onWorkspaceNodeSelected(node);
    }
  }

  Widget _buildPane(BuildContext context) {
    final matchingNodes = _matchingNodes();
    final selectedNode = widget.nodes
        .where((node) => node.id == widget.selectedNodeId)
        .firstOrNull;
    final graph = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    return SizedBox(
      width: widget.width,
      child: ColoredBox(
        color: context.palette.background,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _collectionExpanded
                      ? math.min(260, constraints.maxHeight * .38)
                      : 52,
                  child: DesktopPane(
                    key: const ValueKey('scene objects block'),
                    color: context.palette.panel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 8, 7),
                          child: Row(
                            children: [
                              const Icon(AppIcons.workflow, size: 16),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  context.l10n.sceneSelection,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 1.15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Builder(
                                builder: (buttonContext) => DesktopIconButton(
                                  key: const ValueKey('scene add module'),
                                  icon: AppIcons.add,
                                  tooltip: context.l10n.textAddModule158,
                                  size: 26,
                                  iconSize: 17,
                                  onPressed: widget.onAddModule == null
                                      ? null
                                      : () {
                                          final box =
                                              buttonContext.findRenderObject()
                                                  as RenderBox;
                                          widget.onAddModule!(
                                            box.localToGlobal(
                                              Offset(0, box.size.height),
                                            ),
                                          );
                                        },
                                ),
                              ),
                              DesktopIconButton(
                                key: const ValueKey('scene create group'),
                                icon: AppIcons.folders,
                                tooltip: context.l10n.sceneCreateGroup,
                                size: 26,
                                iconSize: 17,
                                onPressed: () => _editGroup(),
                              ),
                              DesktopIconButton(
                                key: const ValueKey('scene collection toggle'),
                                icon: _collectionExpanded
                                    ? AppIcons.caretUp
                                    : AppIcons.caretDown,
                                tooltip: _collectionExpanded
                                    ? context.l10n.sceneCollapse
                                    : context.l10n.sceneExpand,
                                size: 26,
                                iconSize: 17,
                                onPressed: () => setState(
                                  () => _collectionExpanded =
                                      !_collectionExpanded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_collectionExpanded)
                          Expanded(
                            child: Scrollbar(
                              controller: _scroll,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_collectionExpanded) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          9,
                                          1,
                                          9,
                                          8,
                                        ),
                                        child: TextField(
                                          key: const ValueKey(
                                            'scene collection search',
                                          ),
                                          controller: _search,
                                          onChanged: (value) =>
                                              setState(() => _query = value),
                                          decoration: InputDecoration(
                                            hintText:
                                                context.l10n.textSearch367,
                                            prefixIcon: Icon(
                                              AppIcons.search,
                                              size: 17,
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      if (matchingNodes.isEmpty &&
                                          graph.activeProject.groups.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            6,
                                            14,
                                            14,
                                          ),
                                          child: Text(
                                            context.l10n.sceneNoObjects,
                                            style: TextStyle(
                                              color: context.palette.mutedText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else
                                        for (final group
                                            in graph.activeProject.groups)
                                          if (_query.trim().isEmpty ||
                                              group.name.toLowerCase().contains(
                                                _query.trim().toLowerCase(),
                                              ) ||
                                              matchingNodes.any(
                                                (node) => group.nodeIds
                                                    .contains(node.id),
                                              ))
                                            _groupRow(group, matchingNodes),
                                      for (final node in matchingNodes.where(
                                        (node) =>
                                            !graph.activeProject.groups.any(
                                              (group) => group.nodeIds.contains(
                                                node.id,
                                              ),
                                            ),
                                      ))
                                        _nodeRow(node),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: WorkspaceInspector(
                    key: ValueKey('scene inspector ${selectedNode?.id}'),
                    embedded: true,
                    node: selectedNode,
                    hidden:
                        selectedNode != null &&
                        (graph.hiddenNodeIds.contains(selectedNode.id) ||
                            graph.hiddenModuleIds.contains(
                              selectedNode.module.id,
                            ) ||
                            selectedNode.fullyHidden),
                    onVisibilityChanged: selectedNode == null
                        ? null
                        : (visible) {
                            if (selectedNode.fullyHidden) {
                              controller.setNodeFullyHidden(
                                selectedNode.id,
                                !visible,
                              );
                            } else {
                              controller.setNodeHidden(
                                selectedNode.id,
                                !visible,
                              );
                            }
                          },
                    onPositionChanged: selectedNode == null
                        ? null
                        : (position) =>
                              controller.moveNode(selectedNode.id, position),
                    onSizeChanged: selectedNode == null
                        ? null
                        : (size) =>
                              controller.resizeNode(selectedNode.id, size),
                    onClose: () {},
                    onChanged: selectedNode == null
                        ? null
                        : (key, value) => controller.setParameter(
                            selectedNode.id,
                            key,
                            value,
                          ),
                    links: graph.links,
                    onDisconnect: controller.disconnect,
                    onColorChanged: selectedNode == null
                        ? null
                        : (color) => controller.setNodeColors({
                            selectedNode.id,
                          }, color),
                    onPortColorChanged: (port, output, color) {
                      if (selectedNode != null) {
                        controller.setPortColor(
                          selectedNode.id,
                          port,
                          output,
                          color,
                        );
                      }
                    },
                    onOpen: selectedNode == null
                        ? null
                        : () =>
                              widget.canvasController.open?.call(selectedNode),
                    onDetach: selectedNode == null
                        ? null
                        : () => widget.canvasController.detach?.call(
                            selectedNode,
                          ),
                    onFullscreen: selectedNode == null
                        ? null
                        : () => widget.canvasController.fullscreen?.call(
                            selectedNode,
                          ),
                    activeNodes: const [],
                    onSelectNode: _selectSceneNode,
                    onAddModule: () =>
                        widget.canvasController.addModule?.call(),
                    onAddLogic: (type) =>
                        widget.canvasController.addLogic?.call(type),
                    canvasWidth: graph.canvasWidth,
                    canvasHeight: graph.canvasHeight,
                    onCanvasSizeChanged: (width, height) =>
                        controller.setCanvasSize(width: width, height: height),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    required this.modules,
    required this.entities,
    required this.extensions,
    required this.selectedExtensionId,
    required this.selectedEntity,
    required this.selectedModule,
    required this.onModuleSelected,
    required this.onModuleSettings,
    required this.onModuleActiveChanged,
    required this.hiddenModuleIds,
    required this.canvasModuleIds,
    required this.workspaceNodes,
    required this.selectedNodeId,
    required this.onWorkspaceNodeSelected,
    required this.onShowModule,
    this.onAddModule,
    this.onRemoveModule,
    this.onEditModule,
    this.onAddEntity,
    this.onRemoveEntity,
    this.onEditEntity,
    required this.onEntitySelected,
    required this.onExtensionSelected,
    required this.onExtensionNotification,
  });
  final double width;
  final List<NavSection> sections;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool showModuleActions;
  final bool showEntityActions;
  final bool showExtensionActions;
  final List<SystemModule> modules;
  final List<NeuralEntity> entities;
  final List<UserExtension> extensions;
  final String? selectedExtensionId;
  final NeuralEntity? selectedEntity;
  final SystemModule? selectedModule;
  final ValueChanged<SystemModule> onModuleSelected;
  final void Function(SystemModule module, Offset position) onModuleSettings;
  final void Function(SystemModule module, bool active) onModuleActiveChanged;
  final Set<String> hiddenModuleIds;
  final Set<String> canvasModuleIds;
  final List<WorkspaceNode> workspaceNodes;
  final String? selectedNodeId;
  final ValueChanged<WorkspaceNode> onWorkspaceNodeSelected;
  final ValueChanged<SystemModule> onShowModule;
  final ValueChanged<Offset>? onAddModule;
  final ValueChanged<SystemModule>? onRemoveModule;
  final ValueChanged<SystemModule>? onEditModule;
  final VoidCallback? onAddEntity;
  final ValueChanged<NeuralEntity>? onRemoveEntity;
  final ValueChanged<NeuralEntity>? onEditEntity;
  final ValueChanged<NeuralEntity> onEntitySelected;
  final ValueChanged<UserExtension> onExtensionSelected;
  final void Function(String title, String message, IconData icon)
  onExtensionNotification;

  @override
  State<_Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends State<_Explorer> {
  final ScrollController _moduleScrollController = DesktopScrollController(
    debugLabel: 'explorer modules',
  );
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
      return module.displayName(context).toLowerCase().contains(normalized) ||
          module.id.toLowerCase().contains(normalized) ||
          module.displayCategory(context).toLowerCase().contains(normalized) ||
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
        color: context.palette.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.showModuleActions
                          ? 'SCENE COLLECTION'
                          : context.l10n.textEXPLORER157,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.showModuleActions) ...[
                    Builder(
                      builder: (buttonContext) => _ExplorerActionButton(
                        icon: AppIcons.add,
                        tooltip: context.l10n.textAddModule158,
                        onPressed: () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox;
                          widget.onAddModule?.call(
                            box.localToGlobal(Offset(0, box.size.height)),
                          );
                        },
                      ),
                    ),
                    _ExplorerActionButton(
                      icon: AppIcons.minus,
                      tooltip: context.l10n.textRemoveModule159,
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
                      icon: AppIcons.pencil,
                      tooltip: context.l10n.textEditModule160,
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
                      icon: AppIcons.add,
                      tooltip: context.l10n.textAddEntity161,
                      onPressed: widget.onAddEntity,
                    ),
                    _ExplorerActionButton(
                      icon: AppIcons.minus,
                      tooltip: context.l10n.textRemoveEntity162,
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
                      icon: AppIcons.pencil,
                      tooltip: context.l10n.textEditEntity163,
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
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.dragged)) {
                      return context.palette.mutedText.withAlpha(155);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return context.palette.mutedText.withAlpha(125);
                    }
                    return context.palette.mutedText.withAlpha(70);
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
                          _WorkspaceSceneCollection(
                            nodes: widget.workspaceNodes,
                            modules: widget.modules,
                            selectedNodeId: widget.selectedNodeId,
                            onSelected: widget.onWorkspaceNodeSelected,
                            onModuleSettings: widget.onModuleSettings,
                          ),
                          const Divider(height: 9),
                        ],
                        if (widget.showModuleActions &&
                            widget.modules.isNotEmpty) ...[
                          DragTarget<SystemModule>(
                            key: const ValueKey('active modules drop target'),
                            onAcceptWithDetails: (details) => widget
                                .onModuleActiveChanged(details.data, true),
                            builder: (context, candidates, rejected) =>
                                ExplorerDisclosureSection(
                                  title: context.l10n.textACTIVEMODULES168,
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
                                      hintText: context
                                          .l10n
                                          .textSearchActiveModules169,
                                      query: _activeModuleQuery,
                                      onChanged: (value) => setState(
                                        () => _activeModuleQuery = value,
                                      ),
                                      onClear: () {
                                        _activeModuleController.clear();
                                        setState(() => _activeModuleQuery = '');
                                      },
                                    ),
                                    if (_activeModules.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          14,
                                          4,
                                          14,
                                          10,
                                        ),
                                        child: Text(
                                          context
                                              .l10n
                                              .textNoActiveModulesFound170,
                                          style: TextStyle(
                                            color: context.palette.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    for (final module in _activeModules)
                                      Draggable<SystemModule>(
                                        data: module,
                                        feedback: Material(
                                          color: context.palette.panel,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              module.displayName(context),
                                            ),
                                          ),
                                        ),
                                        child: _ModuleItem(
                                          module: module,
                                          onCanvas: widget.canvasModuleIds
                                              .contains(module.id),
                                          hidden: widget.hiddenModuleIds
                                              .contains(module.id),
                                          selected:
                                              widget.selectedModule?.id ==
                                              module.id,
                                          onTap: () =>
                                              widget.onModuleSelected(module),
                                          onSettings: (position) =>
                                              widget.onModuleSettings(
                                                module,
                                                position,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                          DragTarget<SystemModule>(
                            key: const ValueKey('inactive modules drop target'),
                            onAcceptWithDetails: (details) => widget
                                .onModuleActiveChanged(details.data, false),
                            builder: (context, candidates, rejected) =>
                                ExplorerDisclosureSection(
                                  title: context.l10n.textMODULECATALOG171,
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
                                      hintText:
                                          context.l10n.textSearchModules172,
                                      query: _catalogModuleQuery,
                                      onChanged: (value) => setState(
                                        () => _catalogModuleQuery = value,
                                      ),
                                      onClear: () {
                                        _catalogModuleController.clear();
                                        setState(
                                          () => _catalogModuleQuery = '',
                                        );
                                      },
                                    ),
                                    if (_catalogModules.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          14,
                                          4,
                                          14,
                                          10,
                                        ),
                                        child: Text(
                                          context.l10n.textNoModulesFound173,
                                          style: TextStyle(
                                            color: context.palette.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    for (final module in _catalogModules)
                                      Draggable<SystemModule>(
                                        data: module,
                                        feedback: Material(
                                          color: context.palette.panel,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              module.displayName(context),
                                            ),
                                          ),
                                        ),
                                        child: _ModuleItem(
                                          module: module,
                                          onCanvas: widget.canvasModuleIds
                                              .contains(module.id),
                                          catalog: true,
                                          hidden: widget.hiddenModuleIds
                                              .contains(module.id),
                                          selected:
                                              widget.selectedModule?.id ==
                                              module.id,
                                          onTap: () =>
                                              widget.onModuleSelected(module),
                                          onSettings: (position) =>
                                              widget.onModuleSettings(
                                                module,
                                                position,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                        ] else if (widget.showEntityActions) ...[
                          ExplorerSectionHeader(
                            title: context.l10n.textINSTALLEDENTITIES174,
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
                            title: context.l10n.textENTITYCATALOG175,
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
                            title: context.l10n.textInstalled176,
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
                            title: context.l10n.textRecommended177,
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
                          Padding(
                            padding: EdgeInsets.fromLTRB(14, 28, 14, 14),
                            child: Text(
                              context.l10n.textNoActiveWorkspaceItems178,
                              style: TextStyle(
                                color: context.palette.mutedText,
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
        prefixIcon: const Icon(AppIcons.search, size: 17),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.textClearModuleSearch179,
                icon: const Icon(AppIcons.close, size: 16),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: context.palette.searchField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 9),
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _WorkspaceSceneCollection extends StatefulWidget {
  const _WorkspaceSceneCollection({
    required this.nodes,
    required this.modules,
    required this.selectedNodeId,
    required this.onSelected,
    required this.onModuleSettings,
  });

  final List<WorkspaceNode> nodes;
  final List<SystemModule> modules;
  final String? selectedNodeId;
  final ValueChanged<WorkspaceNode> onSelected;
  final void Function(SystemModule module, Offset position) onModuleSettings;

  @override
  State<_WorkspaceSceneCollection> createState() =>
      _WorkspaceSceneCollectionState();
}

class _WorkspaceSceneCollectionState extends State<_WorkspaceSceneCollection> {
  final _search = TextEditingController();
  String _query = '';
  final bool _expanded = true;
  bool _modulesExpanded = true;
  bool _logicExpanded = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WorkspaceNode> _matching(List<WorkspaceNode> nodes) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return nodes;
    return nodes.where((node) {
      final name = node.isLogic
          ? context.logicBlockLabel(node.logicType.name)
          : node.module.displayName(context);
      return '$name ${node.module.id} ${node.id}'.toLowerCase().contains(query);
    }).toList();
  }

  Widget _nodeRow(
    WorkspaceNode node, {
    required int indent,
    bool selectable = true,
  }) {
    final selected = node.id == widget.selectedNodeId;
    final module = node.isLogic
        ? node.module
        : widget.modules
                  .where((item) => item.id == node.module.id)
                  .firstOrNull ??
              node.module;
    final title = node.isLogic
        ? context.logicBlockLabel(node.logicType.name)
        : module.displayName(context);
    return Padding(
      padding: EdgeInsets.only(left: 10.0 + indent * 16, right: 8),
      child: DesktopHoverTile(
        key: ValueKey('scene collection node ${node.id}'),
        selected: selected,
        selectedColor: context.palette.text.withAlpha(44),
        hoverColor: context.palette.text.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        onTap: selectable ? () => widget.onSelected(node) : null,
        label: title,
        child: SizedBox(
          height: 30,
          child: Row(
            children: [
              Icon(
                AppIcons.resolve(
                  node.isLogic ? AppIcons.workflow : AppIcons.puzzle,
                  active: selected,
                ),
                size: 15,
                color: selected
                    ? context.palette.text
                    : context.palette.mutedText,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? context.palette.text
                        : context.palette.mutedText,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (!node.isLogic && selectable)
                Builder(
                  builder: (buttonContext) => DesktopIconButton(
                    key: const ValueKey('module settings button'),
                    icon: AppIcons.more,
                    tooltip: context.l10n.textModuleSettings301,
                    size: 24,
                    iconSize: 16,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      widget.onModuleSettings(
                        module,
                        box.localToGlobal(Offset(0, box.size.height)),
                      );
                    },
                  ),
                ),
              if (selected)
                Icon(
                  AppIcons.circleFilled,
                  size: 6,
                  color: context.palette.text,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required List<WorkspaceNode> nodes,
  }) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExplorerSectionHeader(
          title: title,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          for (final node in nodes) _nodeRow(node, indent: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final matching = _matching(widget.nodes);
    final modules = matching.where((node) => !node.isLogic).toList();
    final logic = matching.where((node) => node.isLogic).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
            child: TextField(
              key: const ValueKey('scene collection search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search objects',
                prefixIcon: const Icon(AppIcons.search, size: 16),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(AppIcons.close, size: 15),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          _group(
            title: 'MODULES',
            expanded: _modulesExpanded,
            onToggle: () =>
                setState(() => _modulesExpanded = !_modulesExpanded),
            nodes: modules,
          ),
          _group(
            title: 'LOGIC',
            expanded: _logicExpanded,
            onToggle: () => setState(() => _logicExpanded = !_logicExpanded),
            nodes: logic,
          ),
          if (matching.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 14, 12),
              child: Text(
                'No objects found',
                style: TextStyle(
                  color: context.palette.mutedText,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ExplorerActionButton extends StatelessWidget {
  const _ExplorerActionButton({
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
    required this.onSettings,
    required this.onCanvas,
    this.hidden = false,
    this.catalog = false,
    this.selected = false,
  });
  final SystemModule module;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSettings;
  final bool onCanvas;
  final bool hidden;
  final bool catalog;
  final bool selected;

  @override
  State<_ModuleItem> createState() => _ModuleItemState();
}

class _ModuleItemState extends State<_ModuleItem> {
  bool _hovered = false;

  IconData get _icon {
    return switch (widget.module.category) {
      'acquisition' => AppIcons.bolt,
      'dsp' => AppIcons.layers,
      'feature' => AppIcons.cpu,
      'utility' => AppIcons.package,
      'output' => AppIcons.database,
      _ => AppIcons.puzzle,
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DesktopFocusableAction(
        onActivate: widget.onTap,
        label: widget.module.displayName(context),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapUp: (details) =>
              widget.onSettings(details.globalPosition),
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.hoverCurve,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: widget.selected
                  ? context.palette.text.withAlpha(45)
                  : _hovered
                  ? context.palette.hover
                  : context.palette.hover.withAlpha(0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Opacity(
              opacity: widget.hidden ? .58 : 1,
              child: Row(
                children: [
                  Icon(
                    _icon,
                    size: 17,
                    color: widget.catalog
                        ? context.palette.mutedText
                        : context.palette.text,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.module.displayName(context),
                      style: TextStyle(
                        color: context.palette.text,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: AppTheme.hoverDuration,
                    child: _hovered
                        ? DesktopIconButton(
                            key: const ValueKey('module settings button'),
                            icon: AppIcons.settings,
                            tooltip: context.l10n.textModuleSettings301,
                            onPressed: () {
                              final box =
                                  context.findRenderObject() as RenderBox;
                              widget.onSettings(
                                box.localToGlobal(Offset(0, box.size.height)),
                              );
                            },
                            size: 27,
                            iconSize: 16,
                          )
                        : widget.onCanvas
                        ? Icon(
                            AppIcons.circleFilled,
                            key: const ValueKey('module status dot'),
                            size: 6,
                            color: widget.module.active
                                ? context.palette.text
                                : context.palette.mutedText,
                          )
                        : const SizedBox(width: 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const actionSpace = 46.0;
      final explorerSpace = showExplorerToggle ? 38.0 : 0.0;
      final tabsFit =
          tabs.length * 205 + actionSpace <=
          constraints.maxWidth - explorerSpace;
      final tabWidgets = [
        for (final tab in tabs)
          _EditorTab(
            tab: tab,
            selected: active == tab.id,
            onSelect: () => onSelect(tab.id),
            onClose: () => onClose(tab.id),
          ),
      ];
      final createAction = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: _EditorTabAction(
          key: const ValueKey<String>('create new tab button'),
          icon: AppIcons.add,
          tooltip: context.l10n.textCreateNewTab180,
          onPressed: onCreate,
        ),
      );

      return Container(
        height: 44,
        color: context.palette.background,
        child: Row(
          children: [
            Expanded(
              child: tabsFit
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [...tabWidgets, createAction],
                      ),
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      children: tabWidgets,
                    ),
            ),
            if (!tabsFit) createAction,
            if (showExplorerToggle)
              _EditorTabAction(
                icon: explorerVisible
                    ? AppIcons.sidebarFilled
                    : AppIcons.sidebar,
                tooltip: explorerVisible
                    ? context.l10n.textHideExplorer181
                    : context.l10n.textShowExplorer182,
                onPressed: onToggleExplorer,
              ),
            const SizedBox(width: 8),
          ],
        ),
      );
    },
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
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: DesktopFocusableAction(
      onActivate: widget.onSelect,
      label: context.hostLabel(widget.tab.label),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.hoverCurve,
          width: 205,
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? context.palette.panel
                : _hovered && !_closeHovered
                ? context.palette.hover
                : context.palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.resolve(
                  _sectionIcon(widget.tab.id),
                  active: widget.selected,
                ),
                size: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.tab.id == SectionId.extensions &&
                          widget.tab.label != 'Marketplace'
                      ? widget.tab.label
                      : context.hostLabel(widget.tab.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _closeHovered = true),
                onExit: (_) => setState(() => _closeHovered = false),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DesktopIconButton(
                    icon: AppIcons.close,
                    tooltip: context.l10n.textCloseTab183,
                    onPressed: widget.onClose,
                    size: 22,
                    iconSize: 14,
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

class _EditorTabAction extends StatelessWidget {
  const _EditorTabAction({
    super.key,
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
    color: context.palette.background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.copy, size: 42, color: context.palette.mutedText),
          const SizedBox(height: 12),
          Text(
            context.l10n.textNoOpenTabs184,
            style: TextStyle(color: context.palette.text),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.textCreateANewTabToContinue185,
            style: TextStyle(color: context.palette.mutedText),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onCreate,
            icon: const Icon(AppIcons.add),
            label: Text(context.l10n.textCreateNewTab180),
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
  late final TextEditingController _coverImage;
  late final TextEditingController _uiSchema;
  String _coverPattern = 'waves';
  String _coverIcon = 'module';
  String _coverColor = '35576A';
  String? _schemaError;
  bool _initializedLocale = false;

  @override
  void initState() {
    super.initState();
    final module = widget.existing;
    _id = TextEditingController(
      text:
          module?.id ??
          'user.${AuthService.instance.currentUser!.id.substring(0, 8)}.module-${DateTime.now().microsecondsSinceEpoch}',
    );
    _name = TextEditingController(text: module?.name ?? 'New module');
    _category = TextEditingController(text: module?.category ?? 'utility');
    _description = TextEditingController(
      text: module?.description ?? 'Custom module description.',
    );
    final cover = module?.manifest['cover'] as Map? ?? {};
    _coverImage = TextEditingController(text: cover['image'] as String? ?? '');
    _coverPattern = cover['pattern'] as String? ?? 'waves';
    _coverIcon = cover['icon'] as String? ?? 'module';
    _coverColor = (cover['color'] as String? ?? '35576A').replaceFirst('#', '');
    _uiSchema = TextEditingController(
      text: const JsonEncoder.withIndent('  ')
          .convert(module?.manifest ?? {'parameters': [], 'ui': []}),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedLocale && widget.existing == null) {
      _name.text = context.hostLabel('New module');
      _description.text = context.hostLabel('Custom module description.');
    }
    _initializedLocale = true;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _coverImage.dispose();
    _uiSchema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? context.l10n.textAddModule158
          : context.l10n.textEditModule160,
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              decoration: InputDecoration(labelText: context.l10n.textID188),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.textName189),
            ),
            TextField(
              controller: _category,
              decoration: InputDecoration(
                labelText: context.l10n.textCategory190,
              ),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.textDescription191,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.textMarketplaceCover192,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CatalogCover(
                  color: Color(
                    0xFF000000 |
                        (int.tryParse(_coverColor, radix: 16) ?? 0x35576A),
                  ),
                  pattern: _coverPattern,
                  iconName: _coverIcon,
                  imageUrl: _coverImage.text.trim().isEmpty
                      ? null
                      : _coverImage.text.trim(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _coverImage,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.textYourImageURLHTTPSOptional193,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DesktopSelectField<String>(
                    valueLabel: context.hostLabel(
                      ['waves', 'contours', 'grid'].contains(_coverPattern)
                          ? _coverPattern
                          : 'waves',
                    ),
                    label: context.l10n.textBackgroundContour194,
                    entries: [
                      for (final pattern in ['waves', 'contours', 'grid'])
                        DesktopMenuEntry(
                          value: pattern,
                          label: context.hostLabel(pattern),
                        ),
                    ],
                    onSelected: (value) =>
                        setState(() => _coverPattern = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DesktopSelectField<String>(
                    valueLabel: context.hostLabel(
                      [
                            'module',
                            'signal',
                            'brain',
                            'terrain',
                            'notes',
                            'chart',
                            'moon',
                            'sun',
                          ].contains(_coverIcon)
                          ? _coverIcon
                          : 'module',
                    ),
                    label: context.l10n.textCenterIcon195,
                    entries: [
                      for (final icon in [
                        'module',
                        'signal',
                        'brain',
                        'terrain',
                        'notes',
                        'chart',
                        'moon',
                        'sun',
                      ])
                        DesktopMenuEntry(
                          value: icon,
                          label: context.hostLabel(icon),
                        ),
                    ],
                    onSelected: (value) => setState(() => _coverIcon = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (final color in [
                  '35576A',
                  '555070',
                  '3C665A',
                  '7A5B42',
                  '46505C',
                ])
                  DesktopFocusableAction(
                    onActivate: () => setState(() => _coverColor = color),
                    label: '#$color',
                    child: GestureDetector(
                      onTap: () => setState(() => _coverColor = color),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(
                            0xFF000000 | int.parse(color, radix: 16),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: color == _coverColor
                            ? const Icon(
                                AppIcons.check,
                                size: 17,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uiSchema,
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: InputDecoration(
                labelText: context.l10n.textDeclarativeManifestUISchemaJSON196,
                errorText: _schemaError,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.l10n.textCoverAndUIMetadataAreSavedLocally197,
              style: TextStyle(
                color: context.palette.mutedText,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.textCancel198),
      ),
      FilledButton(
        onPressed: () {
          final old = widget.existing;
          Map<String, dynamic> manifest;
          try {
            manifest = Map<String, dynamic>.from(
              jsonDecode(_uiSchema.text) as Map,
            );
            for (final key in ['parameters', 'ui']) {
              if (manifest[key] != null && manifest[key] is! List) {
                throw FormatException('$key must be an array');
              }
            }
            if (_coverImage.text.trim().isNotEmpty &&
                Uri.tryParse(_coverImage.text.trim())?.scheme != 'https') {
              throw const FormatException('Cover image must use HTTPS');
            }
          } catch (error) {
            setState(() => _schemaError = 'Invalid schema: $error');
            return;
          }
          manifest['cover'] = {
            'color': '#$_coverColor',
            'pattern': _coverPattern,
            'icon': _coverIcon,
            if (_coverImage.text.trim().isNotEmpty)
              'image': _coverImage.text.trim(),
          };
          final slug = _id.text
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9.-]+'), '-')
              .replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
          Navigator.pop(
            context,
            SystemModule(
              id: slug.isEmpty
                  ? 'user.module-${DateTime.now().microsecondsSinceEpoch}'
                  : slug,
              name: _name.text.trim().isEmpty
                  ? 'New module'
                  : _name.text.trim(),
              category: _category.text.trim().isEmpty
                  ? 'utility'
                  : _category.text.trim(),
              description: _description.text.trim(),
              summary: old?.summary ?? '',
              databaseId: old?.databaseId,
              authorId: old?.authorId,
              reviewState: old?.reviewState ?? 'draft',
              version: old?.version ?? '0.1.0',
              active: old?.active ?? false,
              stage: old?.stage ?? 'Custom',
              manifest: manifest,
            ),
          );
        },
        child: Text(context.l10n.textSave203),
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
    title: Text(
      widget.existing == null
          ? context.l10n.textAddEntity161
          : context.l10n.textEditEntity163,
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              decoration: InputDecoration(labelText: context.l10n.textID188),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.textName189),
            ),
            TextField(
              controller: _framework,
              decoration: InputDecoration(
                labelText: context.l10n.textFramework206,
              ),
            ),
            TextField(
              controller: _version,
              decoration: InputDecoration(
                labelText: context.l10n.textVersion207,
              ),
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.textDescription191,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.textCancel198),
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
        child: Text(context.l10n.textSave203),
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
    icon: AppIcons.network,
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
    child: DesktopHoverTile(
      onTap: onTap,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(AppIcons.resolve(extension.icon, active: selected), size: 17),
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
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (extension.downloaded)
              DesktopContextMenu(
                tooltip: context.l10n.textExtensionSettings209,
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
                onSelected: (action) {
                  logI(LogSource.extension, '${extension.name}: $action');
                  onNotification(
                    'Extension changed',
                    context.l10n.textArg0Arg1Selected408(
                      extension.name,
                      action,
                    ),
                    AppIcons.grid,
                  );
                },
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    AppIcons.settings,
                    size: 16,
                    color: context.palette.mutedText,
                  ),
                ),
              ),
          ],
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
    child: DesktopHoverTile(
      onTap: onTap,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              AppIcons.resolve(icon, active: selected),
              size: 17,
              color: context.palette.text,
            ),
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
                    style: TextStyle(
                      color: context.palette.mutedText,
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
    color: context.palette.background,
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        context.l10n.textTERMINAL219,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!compact)
                    Text(
                      context.l10n.textOUTPUT220,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.mutedText,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey<String>('terminal panel toggle'),
                    onPressed: onToggle,
                    icon: Icon(
                      open ? AppIcons.caretDown : AppIcons.caretUp,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 3, 10, 8),
              child: SelectableText(
                'engine ~/project % npm run build\n> engine@0.2.2 build\n> Compiling core modules...\n[BUILD] core-renderer v2.4kb  ✓\n[BUILD] physics-engine v8.1kb  ✓\n[BUILD] Done in 1.34s ✓',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  // Terminal output keeps its green accent in both
                  // appearances, just tuned per brightness for contrast.
                  color: context.palette.isDark
                      ? const Color(0xFF7DCB9B)
                      : const Color(0xFF2F7D5B),
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
    super.key,
    required this.section,
    required this.onOpenMarketplace,
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
    required this.explorerVisible,
    required this.onToggleExplorer,
    required this.onToggleInspector,
    required this.onSelectedModule,
    required this.selectedNodeId,
    required this.onSelectedNode,
    required this.onSelectExtension,
    this.canvasFullscreen = false,
    this.onToggleCanvasFullscreen,
    this.workspaceNotice,
    this.canvasController,
  });
  final SectionId section;
  final VoidCallback onOpenMarketplace;
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
  final bool explorerVisible;
  final VoidCallback onToggleExplorer;
  final VoidCallback onToggleInspector;
  final ValueChanged<SystemModule?> onSelectedModule;
  final String? selectedNodeId;
  final ValueChanged<String?> onSelectedNode;
  final ValueChanged<UserExtension> onSelectExtension;
  final bool canvasFullscreen;
  final VoidCallback? onToggleCanvasFullscreen;
  final String? workspaceNotice;
  final WorkspaceCanvasController? canvasController;
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
          explorerVisible: explorerVisible,
          onToggleExplorer: onToggleExplorer,
          onSelectedModule: onSelectedModule,
          selectedNodeId: selectedNodeId,
          onSelectedNode: onSelectedNode,
          onMarketplace: onOpenMarketplace,
          canvasFullscreen: canvasFullscreen,
          onToggleCanvasFullscreen: onToggleCanvasFullscreen,
          workspaceNotice: workspaceNotice,
          canvasController: canvasController,
        );
      case SectionId.entity:
        return EntityWorkspace(
          entity: selectedEntity,
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
