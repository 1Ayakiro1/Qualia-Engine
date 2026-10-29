import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/module_registry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_model.dart';
import '../../state/workspace_state.dart';
import '../common/widgets.dart';
import '../common/desktop_menu.dart';
import 'module_ui.dart';
import 'workspace_colors.dart';
import 'workspace_grid.dart';
import 'workspace_connections.dart';
import 'active_module_view.dart';
import '../common/desktop_focus.dart';
import '../../core/modules/module_window_session.dart';
import '../common/navigation_bindings.dart';
import 'workspace_manager.dart';
import '../../core/logic/logic_blocks.dart';
import 'logic_block_editor.dart';

class ModulesScreen extends ConsumerStatefulWidget {
  const ModulesScreen({
    super.key,
    required this.modules,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    this.selectedModule,
    this.inspectorOpen = false,
    this.onToggleInspector,
    this.explorerVisible = true,
    this.onToggleExplorer,
    this.onSelectedModule,
    this.onMarketplace,
  });
  final List<SystemModule> modules;
  final VoidCallback onAdd;
  final ValueChanged<SystemModule> onEdit;
  final ValueChanged<SystemModule> onRemove;
  final SystemModule? selectedModule;
  final bool inspectorOpen;
  final VoidCallback? onToggleInspector;
  final bool explorerVisible;
  final VoidCallback? onToggleExplorer;
  final ValueChanged<SystemModule?>? onSelectedModule;
  final VoidCallback? onMarketplace;
  @override
  ConsumerState<ModulesScreen> createState() => _ModulesScreenState();
}

class _PortRef {
  const _PortRef(this.node, this.port, this.output);
  final String node;
  final String port;
  final bool output;
}

class _ModulesScreenState extends ConsumerState<ModulesScreen> {
  static const _sceneSize = 10000.0;
  final _transform = TransformationController(
    Matrix4.identity()..translateByDouble(-4800, -4800, 0, 1),
  );
  final _viewportKey = GlobalKey();
  final _focus = FocusNode(debugLabel: 'workspace canvas');
  String? _selectedId;
  final Set<String> _selection = {};
  WorkspaceNodeColor? _colorFilter;
  bool _menuOpen = false;
  bool _pickerOpen = false;
  String? _openedId;
  bool _inspector = false;
  bool _snapToGrid = false;
  _PortRef? _pendingPort;
  Offset? _wireEnd;
  Offset? _wireGlobal;
  Offset? _panPosition;
  int? _panPointer;
  bool _panModifier = false;
  Offset? _trackpadFocal;
  Offset? _trackpadScene;
  double _trackpadScale = 1;
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  int? _marqueePointer;
  Set<String> _marqueeBase = {};
  Set<String> _marqueePrevious = {};
  Offset? _nodeDragPosition;
  bool _nodeInteracting = false;
  int _interactionGeneration = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(workspaceProvider.select((s) => s.activeProjectId), (
      previous,
      next,
    ) {
      if (previous == next || !mounted) return;
      setState(() {
        _selection.clear();
        _selectedId = null;
        _openedId = null;
        _pendingPort = null;
        _wireEnd = null;
        _colorFilter = null;
        _panPosition = null;
        _panPointer = null;
        _marqueeStart = null;
        _marqueeEnd = null;
        _marqueePointer = null;
        _transform.value = Matrix4.identity()
          ..translateByDouble(-4800, -4800, 0, 1);
      });
    });
    ref.listenManual(workspaceProvider, (_, next) {
      final interactive = next.nodes
          .where(
            (node) =>
                !next.hiddenModuleIds.contains(node.module.id) &&
                (node.isLogic ? next.showLogicBlocks : next.showModuleBlocks),
          )
          .map((node) => node.id)
          .toSet();
      _selection.retainAll(interactive);
      if (!interactive.contains(_selectedId)) _selectedId = null;
      if (_pendingPort != null && !interactive.contains(_pendingPort!.node)) {
        _pendingPort = null;
        _wireEnd = null;
      }
    });
  }

  bool get _panKeyPressed =>
      HardwareKeyboard.instance.isAltPressed ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.space,
      );

  void _setInspector(bool open) {
    setState(() => _inspector = widget.onToggleInspector == null && open);
    if (widget.onToggleInspector != null && widget.inspectorOpen != open) {
      widget.onToggleInspector!();
    }
  }

  void _startMarquee(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton ||
        _panKeyPressed ||
        _panPointer != null) {
      return;
    }
    _focus.requestFocus();
    if (_pendingPort != null) {
      _pick(
        position: _sceneAt(event.position),
        global: event.position,
        fromPort: _pendingPort,
      );
      return;
    }
    setState(() {
      _marqueePointer = event.pointer;
      _marqueeStart = _sceneAt(event.position);
      _marqueeEnd = _marqueeStart;
      _marqueePrevious = {..._selection};
      _marqueeBase = HardwareKeyboard.instance.isShiftPressed
          ? {..._selection}
          : {};
      _selection
        ..clear()
        ..addAll(_marqueeBase);
      _selectedId = _selection.firstOrNull;
      _pendingPort = null;
      _wireEnd = null;
    });
  }

  void _updateMarquee(PointerMoveEvent event) {
    if (event.pointer != _marqueePointer) return;
    setState(() {
      _marqueeEnd = _sceneAt(event.position);
      final area = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
      _selection
        ..clear()
        ..addAll(_marqueeBase);
      if (area.longestSide > 3 / _transform.value.getMaxScaleOnAxis()) {
        _selection.addAll(
          _visibleNodes
              .where(
                (node) => area.overlaps(
                  node.position & Size(node.width, node.height),
                ),
              )
              .map((node) => node.id),
        );
      }
      _selectedId = _selection.firstOrNull;
    });
  }

  void _endMarquee({bool cancel = false}) {
    if (_marqueePointer == null) return;
    setState(() {
      if (cancel) {
        _selection
          ..clear()
          ..addAll(_marqueePrevious);
        _selectedId = _selection.firstOrNull;
      }
      _marqueePointer = null;
      _marqueeStart = null;
      _marqueeEnd = null;
    });
  }

  void _endPan(int pointer) {
    if (pointer != _panPointer) return;
    setState(() {
      _panPosition = null;
      _panPointer = null;
    });
  }

  bool get _navigationBusy =>
      _nodeInteracting || _marqueePointer != null || _panPointer != null;

  Offset _viewportAt(Offset global) =>
      (_viewportKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(global);

  Offset _viewportDelta(Offset position, Offset delta) =>
      _viewportAt(position + delta) - _viewportAt(position);

  void _panBy(Offset delta) {
    final matrix = _transform.value.clone();
    matrix.setTranslationRaw(
      matrix.storage[12] + delta.dx,
      matrix.storage[13] + delta.dy,
      0,
    );
    _transform.value = matrix;
  }

  void _scaleAt(Offset global, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final focal = _viewportAt(global);
    final scene = _transform.toScene(focal);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      .25,
      2.0,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        focal.dx - scene.dx * scale,
        focal.dy - scene.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent && event is! PointerScaleEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (_navigationBusy) return;
      if (resolved is PointerScrollEvent) {
        // Linux touchpads may report two-finger scrolling as mouse events.
        // Use the same pan behavior for both, with Ctrl reserved for zoom.
        if (HardwareKeyboard.instance.isControlPressed) {
          _scaleAt(resolved.position, math.exp(-resolved.scrollDelta.dy / 200));
        } else {
          _panBy(-_viewportDelta(resolved.position, resolved.scrollDelta));
        }
      } else if (resolved is PointerScaleEvent) {
        _scaleAt(resolved.position, resolved.scale);
      }
    });
  }

  void _trackpadStart(PointerPanZoomStartEvent event) {
    if (_navigationBusy) return;
    _trackpadFocal = _viewportAt(event.position);
    _trackpadScene = _transform.toScene(_trackpadFocal!);
    _trackpadScale = _transform.value.getMaxScaleOnAxis();
  }

  void _trackpadUpdate(PointerPanZoomUpdateEvent event) {
    if (_trackpadFocal == null || _navigationBusy) return;
    if (!event.scale.isFinite || event.scale <= 0) return;
    final focal = _trackpadFocal! + _viewportDelta(event.position, event.pan);
    final scene = _trackpadScene!;
    final scale = (_trackpadScale * event.scale).clamp(.25, 2.0);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        focal.dx - scene.dx * scale,
        focal.dy - scene.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _setNodeInteraction(bool active) {
    if (active) {
      _controller.beginHistoryGroup();
    } else {
      _controller.endHistoryGroup();
    }
    final generation = ++_interactionGeneration;
    if (active) {
      setState(() => _nodeInteracting = true);
    } else {
      // Keep viewer gestures disabled until its recognizers process pointer-up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _interactionGeneration) {
          setState(() => _nodeInteracting = false);
        }
      });
    }
  }

  WorkspaceController get _controller => ref.read(workspaceProvider.notifier);

  List<WorkspaceNode> get _visibleNodes => ref
      .read(workspaceProvider)
      .nodes
      .where(
        (node) => node.isLogic
            ? ref.read(workspaceProvider).showLogicBlocks
            : ref.read(workspaceProvider).showModuleBlocks,
      )
      .where((node) => _colorFilter == null || node.headerColor == _colorFilter)
      .where(
        (node) => !ref
            .read(workspaceProvider)
            .hiddenModuleIds
            .contains(node.module.id),
      )
      .toList();

  void _filterColor(WorkspaceNodeColor? color) => setState(() {
    _colorFilter = color;
    _selection.clear();
    _selectedId = null;
    _pendingPort = null;
    _wireEnd = null;
  });

  void _selectColor(WorkspaceNodeColor color) {
    final graph = ref.read(workspaceProvider);
    final nodes = graph.nodes
        .where(
          (node) =>
              !graph.hiddenModuleIds.contains(node.module.id) &&
              (node.isLogic ? graph.showLogicBlocks : graph.showModuleBlocks),
        )
        .where((node) => node.headerColor == color)
        .toList();
    setState(() {
      _colorFilter = null;
      _selection
        ..clear()
        ..addAll(nodes.map((node) => node.id));
      _selectedId = nodes.firstOrNull?.id;
    });
    _fit(nodes);
    _focus.requestFocus();
  }

  WorkspaceNode _addAt(SystemModule module, Offset position) {
    final node = _controller.addNode(module, position);
    if (_colorFilter != null) {
      _controller.setNodeColors({node.id}, _colorFilter!);
    }
    return node;
  }

  WorkspaceNode? _nodeAt(Offset global) {
    final scene = _sceneAt(global);
    return _visibleNodes.reversed
        .where(
          (node) =>
              (node.position & Size(node.width, node.height)).contains(scene),
        )
        .firstOrNull;
  }

  @override
  void dispose() {
    _transform.dispose();
    _focus.dispose();
    super.dispose();
  }

  Offset _sceneAt(Offset global) => _transform.toScene(
    (_viewportKey.currentContext!.findRenderObject() as RenderBox)
        .globalToLocal(global),
  );
  Offset get _center => _transform.toScene(
    (_viewportKey.currentContext!.findRenderObject() as RenderBox).size.center(
      Offset.zero,
    ),
  );
  void _select(WorkspaceNode node, {bool focusCanvas = true}) {
    if (_panKeyPressed || _panPointer != null) return;
    setState(() {
      if (!HardwareKeyboard.instance.isShiftPressed &&
          !_selection.contains(node.id)) {
        _selection.clear();
      }
      _selection.add(node.id);
      _selectedId = node.id;
      _inspector = true;
    });
    widget.onSelectedModule?.call(node.isLogic ? null : node.module);
    if (focusCanvas) _focus.requestFocus();
  }

  void _clearSelection() => setState(() {
    _selection.clear();
    _selectedId = null;
    widget.onSelectedModule?.call(null);
  });

  void _hideModule(WorkspaceNode node) {
    if (node.isLogic) return;
    _controller.setModuleHidden(node.module.id, true);
    _clearSelection();
  }

  static const double _snapSpacing = 24;

  bool _overlapsAny(Set<String> moving, Map<String, Offset> positions) {
    final nodes = ref.read(workspaceProvider).nodes;
    for (final node in nodes.where((item) => moving.contains(item.id))) {
      final position = positions[node.id] ?? node.position;
      final rect = position & Size(node.width, node.height);
      for (final other in nodes.where((item) => !moving.contains(item.id))) {
        final otherPosition = positions[other.id] ?? other.position;
        if (rect.overlaps(otherPosition & Size(other.width, other.height))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Apply the optional magnetic grid and avoid dropping a node on another
  /// node. The canvas remains a finite, stable scene; only movement is
  /// clamped at its edges.
  Offset _moveDelta(Set<String> ids, Offset requested) {
    // Keep the existing free-move behaviour unless the magnetic control is
    // explicitly enabled. This also preserves sub-grid pointer movement.
    if (!_snapToGrid) return requested;
    final nodes = ref
        .read(workspaceProvider)
        .nodes
        .where((node) => ids.contains(node.id))
        .toList();
    if (nodes.isEmpty) return requested;
    var delta = requested;
    if (_snapToGrid) {
      final anchor = nodes.first;
      final target = anchor.position + requested;
      delta = Offset(
        (target.dx / _snapSpacing).round() * _snapSpacing - anchor.position.dx,
        (target.dy / _snapSpacing).round() * _snapSpacing - anchor.position.dy,
      );
      // Once the cursor is close to another module, prefer its edges over a
      // nearby grid line. This keeps ports aligned without allowing cards to
      // land on top of one another.
      const edgeThreshold = 12.0;
      final others = ref
          .read(workspaceProvider)
          .nodes
          .where((item) => !ids.contains(item.id));
      final proposed = anchor.position + delta;
      final xEdges = <double>[];
      final yEdges = <double>[];
      for (final other in others) {
        xEdges
          ..add(other.position.dx)
          ..add(other.position.dx + other.width)
          ..add(other.position.dx - anchor.width)
          ..add(other.position.dx + other.width - anchor.width);
        yEdges
          ..add(other.position.dy)
          ..add(other.position.dy + other.height)
          ..add(other.position.dy - anchor.height)
          ..add(other.position.dy + other.height - anchor.height);
      }
      double snapEdge(double value, List<double> edges) {
        final closest = edges.fold<double?>(null, (best, edge) {
          if ((edge - value).abs() > edgeThreshold) return best;
          return best == null || (edge - value).abs() < (best - value).abs()
              ? edge
              : best;
        });
        return closest ?? value;
      }

      final snapped = Offset(
        snapEdge(proposed.dx, xEdges),
        snapEdge(proposed.dy, yEdges),
      );
      delta = snapped - anchor.position;
    }
    final positions = <String, Offset>{};
    for (final node in nodes) {
      final position = node.position + delta;
      positions[node.id] = Offset(
        position.dx.clamp(0, _sceneSize - node.width).toDouble(),
        position.dy.clamp(0, _sceneSize - node.height).toDouble(),
      );
    }
    delta = positions[nodes.first.id]! - nodes.first.position;
    if (!_overlapsAny(ids, positions)) return delta;
    for (final alternative in [Offset(delta.dx, 0), Offset(0, delta.dy)]) {
      final alternativePositions = {
        for (final node in nodes) node.id: node.position + alternative,
      };
      if (!_overlapsAny(ids, alternativePositions)) return alternative;
    }
    return Offset.zero;
  }

  void _deleteSelection() {
    _controller.removeNodes(_selection);
    setState(() {
      _selection.clear();
      _selectedId = null;
      _pendingPort = null;
      _wireEnd = null;
    });
  }

  void _zoom(double scale) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final scene = _transform.toScene(center);
    scale = scale.clamp(.25, 2);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * scale,
        center.dy - scene.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _viewAction(String action, List<WorkspaceNode> nodes) {
    switch (action) {
      case 'in':
        _zoom(_transform.value.getMaxScaleOnAxis() * 1.2);
      case 'out':
        _zoom(_transform.value.getMaxScaleOnAxis() / 1.2);
      case 'actual':
        _zoom(1);
      case 'fit':
        _fit(nodes);
      case 'selected':
        _fit(nodes.where((node) => _selection.contains(node.id)).toList());
      case 'inspector':
        _setInspector(!(_inspector || widget.inspectorOpen));
    }
  }

  Future<void> _pick({
    Offset? position,
    Offset? global,
    WorkspaceNode? replace,
    _PortRef? fromPort,
  }) async {
    if (_pickerOpen) return;
    _pickerOpen = true;
    final projectId = ref.read(workspaceProvider).activeProjectId;
    final box = _viewportKey.currentContext!.findRenderObject() as RenderBox;
    final anchor = global ?? box.localToGlobal(const Offset(24, 12));
    final scene = position ?? _center - const Offset(120, 80);
    final modules = {for (final m in widget.modules) m.id: m}.values.where((m) {
      if (fromPort == null) return true;
      final ports = m.manifest['ports'];
      final opposite = ports is Map
          ? ports[fromPort.output ? 'inputs' : 'outputs']
          : null;
      // Absent declarations use the normal default input/output.
      return opposite is! List ||
          opposite.whereType<String>().any((p) => p.trim().isNotEmpty);
    }).toList();
    List<DesktopMenuEntry<String>> entries(String query) => modules
        .where(
          (m) =>
              '${m.displayName(context)} ${m.displayCategory(context)} ${m.id}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
        )
        .map(
          (m) => DesktopMenuEntry(value: m.id, label: m.displayName(context)),
        )
        .toList();
    try {
      final id = await showDesktopMenu<String>(
        context: context,
        position: anchor,
        width: 280,
        itemHeight: 38,
        entries: entries(''),
        search: DesktopMenuSearch(
          hint: context.l10n.textSearchAvailableModules317,
          emptyLabel: context.l10n.workspaceNoSearchResults,
          results: entries,
        ),
      );
      if (!mounted ||
          id == null ||
          ref.read(workspaceProvider).activeProjectId != projectId) {
        return;
      }
      final module = modules.where((m) => m.id == id).firstOrNull;
      if (module == null) return;
      if (replace != null) {
        _controller.replaceNode(replace.id, module);
      } else {
        if (fromPort != null &&
            !ref
                .read(workspaceProvider)
                .nodes
                .any(
                  (n) =>
                      n.id == fromPort.node &&
                      (fromPort.output ? n.outputs : n.inputs).contains(
                        fromPort.port,
                      ),
                )) {
          return;
        }
        _controller.beginHistoryGroup();
        try {
          final node = _addAt(module, scene);
          if (fromPort != null) {
            final ports = fromPort.output ? node.inputs : node.outputs;
            if (ports.isNotEmpty) {
              _connect(
                fromPort,
                _PortRef(node.id, ports.first, !fromPort.output),
              );
            }
          }
          _select(node);
        } finally {
          _controller.endHistoryGroup();
        }
      }
    } finally {
      _pickerOpen = false;
      if (mounted) {
        setState(() {
          _pendingPort = null;
          _wireEnd = null;
          _wireGlobal = null;
        });
        _focus.requestFocus();
      }
    }
  }

  void _finishPortDrag(DraggableDetails details) {
    final port = _pendingPort;
    final global = _wireGlobal;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (!details.wasAccepted &&
        port != null &&
        global != null &&
        box != null &&
        (Offset.zero & box.size).contains(box.globalToLocal(global)) &&
        _nodeAt(global) == null) {
      _pick(position: _sceneAt(global), global: global, fromPort: port);
    } else {
      setState(() {
        _pendingPort = null;
        _wireEnd = null;
        _wireGlobal = null;
      });
    }
  }

  void _menuAtFocus() {
    final node = ref
        .read(workspaceProvider)
        .nodes
        .where((item) => item.id == _selectedId)
        .firstOrNull;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      _menu(box.localToGlobal(box.size.center(Offset.zero)), node: node);
    }
  }

  Future<void> _menu(Offset global, {WorkspaceNode? node}) async {
    if (_menuOpen) return;
    _menuOpen = true;
    final scene = _sceneAt(global);
    final modules = {for (final module in widget.modules) module.id: module}
        .values
        .toList();
    try {
      final action = await showDesktopMenu<String>(
        context: context,
        position: global,
        width: node == null ? 340 : 280,
        search: node == null
            ? DesktopMenuSearch<String>(
                hint: context.l10n.textSearchAvailableModules317,
                emptyLabel: context.l10n.workspaceNoSearchResults,
                results: (query) => modules
                    .where(
                      (module) =>
                          '${module.displayName(context)} ${module.displayCategory(context)} ${module.id}'
                              .toLowerCase()
                              .contains(query.trim().toLowerCase()),
                    )
                    .map(
                      (module) => DesktopMenuEntry(
                        value: 'module:${module.id}',
                        label: module.displayName(context),
                      ),
                    )
                    .toList(),
              )
            : null,
        entries: [
          if (node == null)
            DesktopMenuEntry(
              value: 'logic',
              label: context.l10n.logicAdd,
              submenu: [
                for (final type in LogicBlockType.values)
                  DesktopMenuEntry(
                    value: 'logic:${type.name}',
                    label: context.logicBlockLabel(type.name),
                  ),
              ],
            ),
          if (node == null)
            DesktopMenuEntry(value: 'add', label: context.l10n.textAdd294)
          else ...[
            DesktopMenuEntry(value: 'open', label: context.l10n.textOpen309),
            DesktopMenuEntry(
              value: 'window',
              label: context.l10n.moduleOpenWindow,
            ),
            DesktopMenuEntry(
              value: 'fullscreen',
              label: context.l10n.moduleFullscreen,
            ),
            DesktopMenuEntry(
              value: 'replace',
              label: context.l10n.textReplaceModule295,
              enabled: !node.isLogic,
            ),
            DesktopMenuEntry(
              value: 'color',
              label: context.l10n.workspaceHeaderColor,
              submenu: workspaceColorEntries(context, 'color:'),
            ),
            DesktopMenuEntry(
              value: 'sameColor',
              label: context.l10n.workspaceSelectSameColor,
            ),
            DesktopMenuEntry(value: 'hide', label: context.l10n.textHide231),
            DesktopMenuEntry(
              value: 'move',
              label: context.l10n.moduleMoveToWorkspace,
              enabled: ref.read(workspaceProvider).projects.length > 1,
              submenu: [
                for (final project in ref.read(workspaceProvider).projects)
                  if (project.id != ref.read(workspaceProvider).activeProjectId)
                    DesktopMenuEntry(
                      value: 'move:${project.id}',
                      label: project.name,
                    ),
              ],
            ),
            DesktopMenuEntry(
              value: 'delete',
              label: context.l10n.textDelete296,
              dividerBefore: true,
            ),
          ],
        ],
      );
      if (!mounted) return;
      if (action != null && action.startsWith('logic:')) {
        _select(
          _controller.addLogicBlock(
            LogicBlockType.values.firstWhere(
              (t) => t.name == action.substring(6),
            ),
            scene,
          ),
        );
        return;
      }
      if (node != null && action != null && action.startsWith('move:')) {
        await moveWorkspaceNodes(
          context,
          ref,
          _selection.contains(node.id) ? {..._selection} : {node.id},
          action.substring(5),
        );
        if (mounted) {
          setState(() {
            _selection.removeWhere(
              (id) => !ref.read(workspaceProvider).nodes.any((n) => n.id == id),
            );
            if (!_selection.contains(_selectedId)) _selectedId = null;
          });
        }
        return;
      }
      if (action != null && action.startsWith('module:')) {
        final module = modules
            .where((module) => module.id == action.substring(7))
            .firstOrNull;
        if (module != null) _select(_addAt(module, scene));
      }
      if (node != null && action != null && action.startsWith('color:')) {
        _controller.setNodeColors({
          node.id,
        }, WorkspaceNodeColor.fromJson(action.substring(6)));
        if (_colorFilter != null && node.headerColor != _colorFilter) {
          _filterColor(null);
        }
      }
      if (node != null && action == 'sameColor') _selectColor(node.headerColor);
      if (action == 'add') _pick(position: scene, global: global);
      if (action == 'open' && node != null) setState(() => _openedId = node.id);
      if (action == 'window' && node != null) await _detach(node);
      if (action == 'fullscreen' && node != null) await _fullscreen(node);
      if (action == 'replace') _pick(replace: node, global: global);
      if (action == 'hide' && node != null && !node.isLogic) {
        _hideModule(node);
      }
      if (action == 'delete' && node != null) {
        _controller.removeNode(node.id);
        setState(() {
          _selection.remove(node.id);
          _selectedId = null;
          _openedId = null;
          _pendingPort = null;
        });
      }
    } finally {
      _menuOpen = false;
    }
  }

  Future<void> _detach(WorkspaceNode node) async {
    if (ref.read(workspaceProvider).hiddenModuleIds.contains(node.module.id)) {
      return;
    }
    final opened = await ref
        .read(moduleWindowSessionsProvider)
        .open(
          node,
          locale: context.l10n.localeName,
          light: !context.palette.isDark,
        );
    if (!opened && mounted) _message(context.l10n.moduleWindowFailed);
  }

  bool _fullscreenOpen = false;
  Future<void> _fullscreen(WorkspaceNode node) async {
    if (_fullscreenOpen ||
        ref.read(workspaceProvider).hiddenModuleIds.contains(node.module.id)) {
      return;
    }
    _fullscreenOpen = true;
    try {
      await showModuleFullscreen(
        context,
        (routeContext) => Consumer(
          builder: (context, ref, _) {
            final workspace = ref.watch(workspaceProvider);
            final current = workspace.nodes
                .where(
                  (item) =>
                      item.id == node.id &&
                      !workspace.hiddenModuleIds.contains(item.module.id),
                )
                .firstOrNull;
            if (current == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              });
              return const SizedBox.shrink();
            }
            return Scaffold(
              body: ActiveModuleView(
                node: current,
                fullscreen: true,
                onBack: () => Navigator.of(routeContext).pop(),
                onFullscreen: () => Navigator.of(routeContext).pop(),
                onDetach: () => _detach(current),
                onChanged: (key, value) =>
                    _controller.setParameter(current.id, key, value),
              ),
            );
          },
        ),
      );
    } finally {
      _fullscreenOpen = false;
    }
  }

  void _connect(_PortRef a, _PortRef b) {
    if (a.output == b.output) {
      _message(context.l10n.textConnectAnOutputToAnInput297);
      return;
    }
    final from = a.output ? a : b;
    final to = a.output ? b : a;
    final error = _controller.connect(
      WorkspaceLink(
        source: from.node,
        output: from.port,
        target: to.node,
        input: to.port,
      ),
    );
    if (error != null) _message(context.hostLabel(error));
    setState(() {
      _pendingPort = null;
      _wireEnd = null;
    });
  }

  Future<void> _portMenu(_PortRef port, Offset position) async {
    if (_menuOpen) return;
    _menuOpen = true;
    try {
      final value = await showDesktopMenu<String>(
        context: context,
        position: position,
        entries: [
          DesktopMenuEntry(
            value: 'rename',
            label: context.l10n.workspacePortName,
          ),
          DesktopMenuEntry(
            value: 'type',
            label: context.l10n.workspacePortValue,
            submenu: [
              for (final type in WorkspacePortType.values)
                DesktopMenuEntry(
                  value: 'type:${type.name}',
                  label: _portTypeLabel(context, type),
                ),
            ],
          ),
          DesktopMenuEntry(
            value: 'color',
            label: context.l10n.workspacePortColor,
            submenu: workspaceColorEntries(context, 'color:'),
          ),
        ],
      );
      if (mounted && value != null) {
        if (value == 'rename') {
          await _renamePort(port);
        } else if (value.startsWith('type:')) {
          _controller.setPortType(
            port.node,
            port.port,
            port.output,
            WorkspacePortType.fromJson(value.substring(5)),
          );
        } else if (value.startsWith('color:')) {
          _controller.setPortColor(
            port.node,
            port.port,
            port.output,
            WorkspaceNodeColor.fromJson(value.substring(6)),
          );
        }
      }
    } finally {
      _menuOpen = false;
    }
  }

  Future<void> _renamePort(_PortRef port) async {
    final node = ref
        .read(workspaceProvider)
        .nodes
        .where((node) => node.id == port.node)
        .firstOrNull;
    if (node == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenamePortDialog(label: node.portLabel(port.port, port.output)),
    );
    if (mounted && name != null) {
      _controller.setPortLabel(port.node, port.port, port.output, name);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  void _fit(List<WorkspaceNode> nodes) {
    if (nodes.isEmpty) {
      _transform.value = Matrix4.identity()
        ..translateByDouble(-4800, -4800, 0, 1);
      return;
    }
    final size =
        (_viewportKey.currentContext!.findRenderObject() as RenderBox).size;
    final left = nodes.map((node) => node.position.dx).reduce(math.min) - 60;
    final top = nodes.map((node) => node.position.dy).reduce(math.min) - 60;
    final right =
        nodes.map((node) => node.position.dx + node.width).reduce(math.max) +
        60;
    final bottom =
        nodes.map((node) => node.position.dy + node.height).reduce(math.max) +
        60;
    final scale = math
        .min(size.width / (right - left), size.height / (bottom - top))
        .clamp(.25, 1.4)
        .toDouble();
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (size.width - (right - left) * scale) / 2 - left * scale,
        (size.height - (bottom - top) * scale) / 2 - top * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => _buildWorkspace(context),
  );

  Widget _buildWorkspace(BuildContext context) {
    final graph = ref.watch(workspaceProvider);
    final visibleNodes = graph.nodes
        .where(
          (node) =>
              node.isLogic ? graph.showLogicBlocks : graph.showModuleBlocks,
        )
        .where(
          (node) => _colorFilter == null || node.headerColor == _colorFilter,
        )
        .toList();
    final opened = graph.nodes
        .where(
          (node) =>
              node.id == _openedId &&
              !graph.hiddenModuleIds.contains(node.module.id),
        )
        .firstOrNull;
    final selected = graph.nodes
        .where((node) => node.id == _selectedId)
        .firstOrNull;
    final inspector = (_inspector || widget.inspectorOpen) && opened == null;
    if (opened != null) {
      return ActiveModuleView(
        node: opened,
        onBack: () => setState(() => _openedId = null),
        onChanged: (key, value) =>
            _controller.setParameter(opened.id, key, value),
        onFullscreen: () => _fullscreen(opened),
        onDetach: () => _detach(opened),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redo,
        ...NavigationBindings.instance.callbacks({
          NavigationAction.dismiss: () {
            _endMarquee(cancel: true);
            setState(() {
              _pendingPort = null;
              _wireEnd = null;
            });
          },
          NavigationAction.contextMenu: _menuAtFocus,
          NavigationAction.findModule: () => _pick(),
          NavigationAction.scaleUp: () => _viewAction('in', visibleNodes),
          NavigationAction.scaleDown: () => _viewAction('out', visibleNodes),
          NavigationAction.scaleReset: () => _zoom(1),
        }),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          _deleteSelection();
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            setState(() {
              _selection.addAll(_visibleNodes.map((node) => node.id));
            }),
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            _fit(visibleNodes),
      },
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Focus(
          focusNode: _focus,
          onFocusChange: (focused) {
            if (!focused && _panModifier) setState(() => _panModifier = false);
          },
          onKeyEvent: (_, event) {
            if (_focus.hasPrimaryFocus &&
                (event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.altLeft ||
                    event.logicalKey == LogicalKeyboardKey.altRight)) {
              setState(() => _panModifier = _panKeyPressed);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 60,
                      color: context.palette.panel,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: LayoutBuilder(
                        builder: (context, bounds) => Row(
                          children: [
                            SizedBox(
                              width: math.max(
                                0,
                                math.min(240, bounds.maxWidth - 190),
                              ),
                              child: ClipRect(
                                child: DesktopMenuButton<String>(
                                  key: const ValueKey('workspace project menu'),
                                  tooltip: context.l10n.workspaceProjectActions,
                                  width: 320,
                                  entries: [
                                    for (final project in graph.projects)
                                      DesktopMenuEntry(
                                        value: project.id,
                                        label: project.name,
                                        markerColor:
                                            project.id == graph.activeProjectId
                                            ? context.palette.text
                                            : null,
                                      ),
                                    DesktopMenuEntry(
                                      value: '__create',
                                      label: context.l10n.workspaceCreate,
                                      dividerBefore: true,
                                    ),
                                    DesktopMenuEntry(
                                      value: '__manage',
                                      label: context.l10n.workspaceManager,
                                    ),
                                  ],
                                  onSelected: (id) {
                                    if (id == '__create') {
                                      editWorkspace(context, ref);
                                    } else if (id == '__manage') {
                                      showWorkspaceManager(context);
                                    } else {
                                      _controller.switchProject(id);
                                    }
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, childBounds) {
                                      final compact =
                                          childBounds.maxWidth < 120;
                                      return SizedBox(
                                        width: double.infinity,
                                        height: 40,
                                        child: compact
                                            ? const Center(
                                                child: Icon(
                                                  Icons.account_tree_outlined,
                                                  size: 18,
                                                ),
                                              )
                                            : Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .account_tree_outlined,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 9),
                                                    Expanded(
                                                      child: Text(
                                                        graph
                                                            .activeProject
                                                            .name,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.expand_more,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    DesktopMenuButton<String>(
                                      key: const ValueKey('workspace add menu'),
                                      width: 320,
                                      itemHeight: 48,
                                      tooltip:
                                          context.l10n.textAddModuleToCanvas299,
                                      entries: [
                                        DesktopMenuEntry(
                                          value: 'logic',
                                          label: context.l10n.logicAdd,
                                          submenu: [
                                            for (final type
                                                in LogicBlockType.values)
                                              DesktopMenuEntry(
                                                value: 'logic:${type.name}',
                                                label: context.logicBlockLabel(
                                                  type.name,
                                                ),
                                              ),
                                          ],
                                        ),
                                        DesktopMenuEntry(
                                          value: 'module',
                                          label: context.l10n.textAddModule158,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'marketplace',
                                          label: context.hostLabel(
                                            'Marketplace',
                                          ),
                                          enabled: widget.onMarketplace != null,
                                        ),
                                      ],
                                      onSelected: (action) {
                                        if (action.startsWith('logic:')) {
                                          _select(
                                            _controller.addLogicBlock(
                                              LogicBlockType.values.firstWhere(
                                                (t) =>
                                                    t.name ==
                                                    action.substring(6),
                                              ),
                                              _center - const Offset(120, 80),
                                            ),
                                          );
                                          return;
                                        }
                                        if (action == 'module') {
                                          _pick();
                                        } else {
                                          widget.onMarketplace?.call();
                                        }
                                      },
                                      child: _toolbarLabel(
                                        context.l10n.textAdd294,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    DesktopMenuButton<String>(
                                      key: const ValueKey(
                                        'workspace select menu',
                                      ),
                                      width: 340,
                                      itemHeight: 48,
                                      tooltip: context.l10n.workspaceSelectHint,
                                      entries: [
                                        DesktopMenuEntry(
                                          value: 'all',
                                          label:
                                              context.l10n.workspaceSelectAll,
                                          shortcut: 'Ctrl+A',
                                          enabled: visibleNodes.isNotEmpty,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'none',
                                          label: context.l10n.workspaceDeselect,
                                          enabled: _selection.isNotEmpty,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'selectColor',
                                          label: context
                                              .l10n
                                              .workspaceSelectByColor,
                                          submenu: workspaceColorEntries(
                                            context,
                                            'selectColor:',
                                          ),
                                        ),
                                        DesktopMenuEntry(
                                          value: 'color',
                                          label: context
                                              .l10n
                                              .workspaceColorSelected,
                                          enabled: _selection.isNotEmpty,
                                          submenu: workspaceColorEntries(
                                            context,
                                            'color:',
                                          ),
                                        ),
                                        DesktopMenuEntry(
                                          value: 'delete',
                                          label: context
                                              .l10n
                                              .workspaceDeleteSelected,
                                          shortcut: 'Del',
                                          dividerBefore: true,
                                          enabled: _selection.isNotEmpty,
                                        ),
                                      ],
                                      onSelected: (action) {
                                        if (action == 'all') {
                                          setState(() {
                                            _selection.addAll(
                                              _visibleNodes.map(
                                                (node) => node.id,
                                              ),
                                            );
                                          });
                                        }
                                        if (action == 'none') _clearSelection();
                                        if (action == 'delete') {
                                          _deleteSelection();
                                        }
                                        if (action.startsWith('selectColor:')) {
                                          _selectColor(
                                            WorkspaceNodeColor.fromJson(
                                              action.substring(12),
                                            ),
                                          );
                                        }
                                        if (action.startsWith('color:')) {
                                          _controller.setNodeColors(
                                            {..._selection},
                                            WorkspaceNodeColor.fromJson(
                                              action.substring(6),
                                            ),
                                          );
                                          if (_colorFilter != null) {
                                            _filterColor(null);
                                          }
                                        }
                                      },
                                      child: _toolbarLabel(
                                        context.l10n.workspaceSelect,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    DesktopMenuButton<String>(
                                      key: const ValueKey(
                                        'workspace view menu',
                                      ),
                                      width: 360,
                                      itemHeight: 48,
                                      tooltip: context.l10n.textView62,
                                      entries: [
                                        DesktopMenuEntry(
                                          value: 'showLogic',
                                          label: graph.showLogicBlocks
                                              ? context.l10n.logicHide
                                              : context.l10n.logicShow,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'showModules',
                                          label: graph.showModuleBlocks
                                              ? context.l10n.moduleBlocksHide
                                              : context.l10n.moduleBlocksShow,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'in',
                                          label: context.l10n.workspaceZoomIn,
                                          shortcut: 'Ctrl+Plus',
                                        ),
                                        DesktopMenuEntry(
                                          value: 'out',
                                          label: context.l10n.workspaceZoomOut,
                                          shortcut: 'Ctrl+Minus',
                                        ),
                                        DesktopMenuEntry(
                                          value: 'actual',
                                          label:
                                              context.l10n.workspaceActualSize,
                                          shortcut: 'Ctrl+0',
                                        ),
                                        DesktopMenuEntry(
                                          value: 'fit',
                                          label: context.l10n.textFrameAllF300,
                                          dividerBefore: true,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'selected',
                                          label: context
                                              .l10n
                                              .workspaceFrameSelection,
                                          enabled: _selection.isNotEmpty,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'filterColor',
                                          label: _colorFilter == null
                                              ? context
                                                    .l10n
                                                    .workspaceFilterByColor
                                              : '${context.l10n.workspaceFilterByColor}: ${_colorFilter!.label(context)}',
                                          submenu: [
                                            DesktopMenuEntry(
                                              value: 'filterAll',
                                              label: context
                                                  .l10n
                                                  .workspaceAllColors,
                                            ),
                                            ...workspaceColorEntries(
                                              context,
                                              'filterColor:',
                                            ),
                                          ],
                                        ),
                                        DesktopMenuEntry(
                                          value: 'inspector',
                                          label: context
                                              .l10n
                                              .textModuleSettings301,
                                          dividerBefore: true,
                                        ),
                                      ],
                                      onSelected: (action) {
                                        if (action == 'showLogic' ||
                                            action == 'showModules') {
                                          _controller.setBlockVisibility(
                                            logic: action == 'showLogic'
                                                ? !graph.showLogicBlocks
                                                : null,
                                            modules: action == 'showModules'
                                                ? !graph.showModuleBlocks
                                                : null,
                                          );
                                          _clearSelection();
                                          return;
                                        }
                                        if (action == 'filterAll') {
                                          _filterColor(null);
                                        } else if (action.startsWith(
                                          'filterColor:',
                                        )) {
                                          _filterColor(
                                            WorkspaceNodeColor.fromJson(
                                              action.substring(12),
                                            ),
                                          );
                                        } else {
                                          _viewAction(action, visibleNodes);
                                        }
                                      },
                                      child: _toolbarLabel(
                                        _colorFilter == null
                                            ? context.l10n.textView62
                                            : '${context.l10n.textView62} · ${_colorFilter!.label(context)}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(width: 6),
                            DesktopIconButton(
                              key: const ValueKey('workspace toggle explorer'),
                              icon: widget.explorerVisible
                                  ? Icons.view_sidebar_outlined
                                  : Icons.view_sidebar,
                              tooltip: widget.explorerVisible
                                  ? context.l10n.textHideExplorer181
                                  : context.l10n.textShowExplorer182,
                              size: 42,
                              iconSize: 21,
                              onPressed: widget.onToggleExplorer,
                            ),
                            const SizedBox(width: 6),
                            DesktopIconButton(
                              key: const ValueKey('workspace toggle snap'),
                              icon: Icons.grid_4x4,
                              tooltip: context.hostLabel('Snap to grid'),
                              size: 42,
                              iconSize: 21,
                              active: _snapToGrid,
                              onPressed: () =>
                                  setState(() => _snapToGrid = !_snapToGrid),
                            ),
                            const SizedBox(width: 6),
                            DesktopIconButton(
                              key: const ValueKey('workspace toggle inspector'),
                              icon: Icons.view_sidebar_outlined,
                              tooltip: inspector
                                  ? context.l10n.workspaceHideSidebar
                                  : context.l10n.workspaceShowSidebar,
                              size: 42,
                              iconSize: 22,
                              onPressed: () => _setInspector(!inspector),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: ColoredBox(
                          color: context.palette.background,
                          child: DragTarget<Object>(
                            key: const ValueKey('workspace canvas drop target'),
                            onWillAcceptWithDetails: (details) =>
                                details.data is SystemModule ||
                                details.data is LogicBlockType,
                            onAcceptWithDetails: (details) {
                              final position = _sceneAt(details.offset);
                              final data = details.data;
                              _select(
                                data is LogicBlockType
                                    ? _controller.addLogicBlock(data, position)
                                    : _addAt(data as SystemModule, position),
                              );
                            },
                            builder: (context, candidates, rejected) => Listener(
                              onPointerSignal: _pointerSignal,
                              onPointerPanZoomStart: _trackpadStart,
                              onPointerPanZoomUpdate: _trackpadUpdate,
                              onPointerPanZoomEnd: (_) {
                                _trackpadFocal = null;
                                _trackpadScene = null;
                              },
                              onPointerDown: (event) {
                                if (event.buttons == kSecondaryMouseButton &&
                                    _nodeAt(event.position) == null) {
                                  _menu(event.position);
                                  return;
                                }
                                if (event.buttons == kMiddleMouseButton ||
                                    (event.buttons == kPrimaryMouseButton &&
                                        _panKeyPressed)) {
                                  _focus.requestFocus();
                                  setState(() {
                                    _panPosition = event.position;
                                    _panPointer = event.pointer;
                                  });
                                }
                              },
                              onPointerMove: (event) {
                                if (_panPosition != null &&
                                    event.pointer == _panPointer) {
                                  _panBy(
                                    _viewportAt(event.position) -
                                        _viewportAt(_panPosition!),
                                  );
                                  _panPosition = event.position;
                                }
                              },
                              onPointerUp: (event) => _endPan(event.pointer),
                              onPointerCancel: (event) =>
                                  _endPan(event.pointer),
                              child: MouseRegion(
                                onEnter: (_) {
                                  if (!_menuOpen && _openedId == null) {
                                    _focus.requestFocus();
                                  }
                                },
                                onExit: (_) {
                                  if (!_menuOpen && _focus.hasPrimaryFocus) {
                                    _focus.unfocus(
                                      disposition: UnfocusDisposition
                                          .previouslyFocusedChild,
                                    );
                                  }
                                },
                                cursor: _panPointer != null
                                    ? SystemMouseCursors.grabbing
                                    : _panModifier
                                    ? SystemMouseCursors.grab
                                    : MouseCursor.defer,
                                onHover: (event) {
                                  if (_pendingPort != null) {
                                    setState(
                                      () => _wireEnd = _sceneAt(event.position),
                                    );
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _transform,
                                          builder: (context, _) => RepaintBoundary(
                                            child: TweenAnimationBuilder<double>(
                                              key: const ValueKey(
                                                'workspace grid fade',
                                              ),
                                              tween: Tween<double>(
                                                begin: _transform.value
                                                    .getMaxScaleOnAxis(),
                                                end: _transform.value
                                                    .getMaxScaleOnAxis(),
                                              ),
                                              duration:
                                                  MediaQuery.disableAnimationsOf(
                                                    context,
                                                  )
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 120,
                                                    ),
                                              curve: Curves.easeOut,
                                              builder:
                                                  (context, fadeScale, _) =>
                                                      CustomPaint(
                                                        painter: _GridPainter(
                                                          transform: _transform
                                                              .value
                                                              .clone(),
                                                          fadeScale: fadeScale,
                                                          color: context
                                                              .palette
                                                              .mutedText,
                                                          background: context
                                                              .palette
                                                              .panel,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    InteractiveViewer(
                                      key: _viewportKey,
                                      transformationController: _transform,
                                      constrained: false,
                                      boundaryMargin: const EdgeInsets.all(
                                        1000,
                                      ),
                                      minScale: .25,
                                      maxScale: 2,
                                      panEnabled: false,
                                      // Navigation is handled above for consistent
                                      // Linux wheel and native trackpad events.
                                      scaleEnabled: false,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        child: SizedBox(
                                          width: _sceneSize,
                                          height: _sceneSize,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned.fill(
                                                child: Listener(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onPointerDown: _startMarquee,
                                                  onPointerMove: _updateMarquee,
                                                  onPointerUp: (event) {
                                                    if (event.pointer ==
                                                        _marqueePointer) {
                                                      _endMarquee();
                                                    }
                                                  },
                                                  onPointerCancel: (event) {
                                                    if (event.pointer ==
                                                        _marqueePointer) {
                                                      _endMarquee(cancel: true);
                                                    }
                                                  },
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: CustomPaint(
                                                    painter: WorkspaceConnectionsPainter(
                                                      nodes: visibleNodes,
                                                      links: graph.links,
                                                      pendingNode:
                                                          _pendingPort?.node,
                                                      pendingPort:
                                                          _pendingPort?.port,
                                                      pendingOutput:
                                                          _pendingPort
                                                              ?.output ??
                                                          false,
                                                      wireEnd: _wireEnd,
                                                      neutral: context
                                                          .palette
                                                          .mutedText,
                                                      dimmedModuleIds: graph
                                                          .hiddenModuleIds
                                                          .union({
                                                            for (final entry
                                                                in graph
                                                                    .moduleActiveOverrides
                                                                    .entries)
                                                              if (!entry.value)
                                                                entry.key,
                                                          }),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              for (final node in visibleNodes)
                                                _WorkspaceNodeView(
                                                  node: node,
                                                  hidden: graph.hiddenModuleIds
                                                      .contains(node.module.id),
                                                  dimmed:
                                                      graph.hiddenModuleIds
                                                          .contains(
                                                            node.module.id,
                                                          ) ||
                                                      graph.moduleActiveOverrides[node
                                                              .module
                                                              .id] ==
                                                          false,
                                                  ignorePointer:
                                                      graph.hiddenModuleIds
                                                          .contains(
                                                            node.module.id,
                                                          ) ||
                                                      _panModifier ||
                                                      _panPointer != null,
                                                  selected: _selection.contains(
                                                    node.id,
                                                  ),
                                                  onSelect: () => _select(
                                                    node,
                                                    focusCanvas: false,
                                                  ),
                                                  onInteraction:
                                                      _setNodeInteraction,
                                                  onDragStart: (details) =>
                                                      _nodeDragPosition =
                                                          details
                                                              .globalPosition,
                                                  onMove: (details) {
                                                    if (_panKeyPressed ||
                                                        _panPointer != null) {
                                                      return;
                                                    }
                                                    final delta =
                                                        _sceneAt(
                                                          details
                                                              .globalPosition,
                                                        ) -
                                                        _sceneAt(
                                                          _nodeDragPosition ??
                                                              details
                                                                  .globalPosition,
                                                        );
                                                    _nodeDragPosition =
                                                        details.globalPosition;
                                                    _controller.moveNodes(
                                                      _selection,
                                                      _moveDelta(
                                                        _selection,
                                                        delta,
                                                      ),
                                                    );
                                                  },
                                                  onResize: (details) {
                                                    if (_panKeyPressed ||
                                                        _panPointer != null) {
                                                      return;
                                                    }
                                                    final delta =
                                                        _sceneAt(
                                                          details
                                                              .globalPosition,
                                                        ) -
                                                        _sceneAt(
                                                          _nodeDragPosition ??
                                                              details
                                                                  .globalPosition,
                                                        );
                                                    _nodeDragPosition =
                                                        details.globalPosition;
                                                    _controller.resizeNode(
                                                      node.id,
                                                      Size(
                                                        node.width + delta.dx,
                                                        node.height + delta.dy,
                                                      ),
                                                    );
                                                  },
                                                  onOpen: () => setState(
                                                    () => _openedId = node.id,
                                                  ),
                                                  onDetach: () => _detach(node),
                                                  onHide: () =>
                                                      _hideModule(node),
                                                  onMenu: (position) => _menu(
                                                    position,
                                                    node: node,
                                                  ),
                                                  onAddPort: (output) =>
                                                      _controller.addPort(
                                                        node.id,
                                                        output,
                                                      ),
                                                  onPort: (port) {
                                                    if (_pendingPort != null) {
                                                      _connect(
                                                        _pendingPort!,
                                                        port,
                                                      );
                                                    } else {
                                                      setState(
                                                        () =>
                                                            _pendingPort = port,
                                                      );
                                                    }
                                                  },
                                                  onConnect: _connect,
                                                  onPortMenu: _portMenu,
                                                  onDragPort:
                                                      (port, position) =>
                                                          setState(() {
                                                            _pendingPort = port;
                                                            _wireGlobal =
                                                                position;
                                                            _wireEnd = _sceneAt(
                                                              position,
                                                            );
                                                          }),
                                                  onDragEnd: _finishPortDrag,
                                                ),
                                              if (_marqueeStart != null &&
                                                  _marqueeEnd != null)
                                                Positioned.fromRect(
                                                  rect: Rect.fromPoints(
                                                    _marqueeStart!,
                                                    _marqueeEnd!,
                                                  ),
                                                  child: IgnorePointer(
                                                    child: DecoratedBox(
                                                      key: const ValueKey(
                                                        'workspace selection area',
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: context
                                                            .palette
                                                            .text
                                                            .withAlpha(20),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: context
                                                              .palette
                                                              .text
                                                              .withAlpha(150),
                                                          width:
                                                              1 /
                                                              _transform.value
                                                                  .getMaxScaleOnAxis(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (visibleNodes.isEmpty &&
                                        candidates.isEmpty)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.account_tree_outlined,
                                                    size: 42,
                                                    color: context
                                                        .palette
                                                        .mutedText,
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Text(
                                                    context
                                                        .l10n
                                                        .textBuildYourWorkspace302,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    context
                                                        .l10n
                                                        .textDragAModuleFromExplorerOrRight303,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: context
                                                          .palette
                                                          .mutedText,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _transform,
                                          builder: (context, _) => CustomPaint(
                                            painter: _GridPainter(
                                              transform: _transform.value
                                                  .clone(),
                                              color: context.palette.mutedText,
                                              background: context.palette.panel,
                                              rulersOnly: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _transform,
                                        builder: (context, _) => LayoutBuilder(
                                          builder: (context, bounds) {
                                            final visible = Rect.fromPoints(
                                              _transform.toScene(Offset.zero),
                                              _transform.toScene(
                                                Offset(
                                                  bounds.maxWidth,
                                                  bounds.maxHeight,
                                                ),
                                              ),
                                            );
                                            final margin =
                                                100 /
                                                _transform.value
                                                    .getMaxScaleOnAxis();
                                            final nearby = visibleNodes.any(
                                              (node) => visible
                                                  .inflate(margin)
                                                  .overlaps(
                                                    Rect.fromLTWH(
                                                      node.position.dx,
                                                      node.position.dy,
                                                      node.width,
                                                      node.height,
                                                    ),
                                                  ),
                                            );
                                            final wiresNearby = graph.links.any(
                                              (link) {
                                                final source = visibleNodes
                                                    .where(
                                                      (node) =>
                                                          node.id ==
                                                          link.source,
                                                    )
                                                    .firstOrNull;
                                                final target = visibleNodes
                                                    .where(
                                                      (node) =>
                                                          node.id ==
                                                          link.target,
                                                    )
                                                    .firstOrNull;
                                                if (source == null ||
                                                    target == null) {
                                                  return false;
                                                }
                                                final from = source
                                                    .portPosition(
                                                      link.output,
                                                      true,
                                                    );
                                                final to = target.portPosition(
                                                  link.input,
                                                  false,
                                                );
                                                final bend = math.max(
                                                  60.0,
                                                  (to.dx - from.dx).abs() * .45,
                                                );
                                                final wire = Path()
                                                  ..moveTo(from.dx, from.dy)
                                                  ..cubicTo(
                                                    from.dx + bend,
                                                    from.dy,
                                                    to.dx - bend,
                                                    to.dy,
                                                    to.dx,
                                                    to.dy,
                                                  );
                                                return visible
                                                    .inflate(margin)
                                                    .overlaps(
                                                      wire.getBounds().inflate(
                                                        2,
                                                      ),
                                                    );
                                              },
                                            );
                                            if (visibleNodes.isEmpty ||
                                                nearby ||
                                                wiresNearby) {
                                              return const SizedBox.shrink();
                                            }
                                            return Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 48,
                                                ),
                                                child: SizedBox(
                                                  width: 190,
                                                  child: DesktopIconButton(
                                                    key: const ValueKey(
                                                      'return to workspace',
                                                    ),
                                                    icon: Icons.fit_screen,
                                                    tooltip: context
                                                        .l10n
                                                        .textReturnToModules304,
                                                    label: context
                                                        .l10n
                                                        .textReturnToModules304,
                                                    size: 36,
                                                    active: true,
                                                    onPressed: () =>
                                                        _fit(visibleNodes),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 14,
                                      bottom: 12,
                                      child: IgnorePointer(
                                        child: _CanvasLabel(
                                          text: _pendingPort == null
                                              ? context
                                                    .l10n
                                                    .textMMBDragToPanWheelToZoom305
                                              : context
                                                    .l10n
                                                    .textSelectAnOppositePortEscToCancel306,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 12,
                                      bottom: 12,
                                      child: AnimatedBuilder(
                                        animation: _transform,
                                        builder: (context, _) => Container(
                                          decoration: BoxDecoration(
                                            color: context.palette.panel,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DesktopIconButton(
                                                key: const ValueKey(
                                                  'workspace zoom out',
                                                ),
                                                icon: Icons.remove,
                                                tooltip: context
                                                    .l10n
                                                    .workspaceZoomOut,
                                                onPressed: () => _viewAction(
                                                  'out',
                                                  visibleNodes,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 58,
                                                child: Center(
                                                  child: Text(
                                                    '${(_transform.value.getMaxScaleOnAxis() * 100).round()}%',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DesktopIconButton(
                                                key: const ValueKey(
                                                  'workspace zoom in',
                                                ),
                                                icon: Icons.add,
                                                tooltip: context
                                                    .l10n
                                                    .workspaceZoomIn,
                                                onPressed: () => _viewAction(
                                                  'in',
                                                  visibleNodes,
                                                ),
                                              ),
                                            ],
                                          ),
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
                  ],
                ),
              ),
              if (inspector)
                SizedBox(
                  width: 300,
                  child: _WorkspaceInspector(
                    key: ValueKey(selected?.id),
                    node: selected,
                    onClose: () => _setInspector(false),
                    onChanged: selected == null
                        ? null
                        : (key, value) =>
                              _controller.setParameter(selected.id, key, value),
                    links: graph.links,
                    onDisconnect: _controller.disconnect,
                    onColorChanged: selected == null
                        ? null
                        : (color) {
                            _controller.setNodeColors({selected.id}, color);
                            if (_colorFilter != null &&
                                selected.headerColor != _colorFilter) {
                              _filterColor(null);
                            }
                          },
                    onPortColorChanged: (port, output, color) {
                      if (selected != null) {
                        _controller.setPortColor(
                          selected.id,
                          port,
                          output,
                          color,
                        );
                      }
                    },
                    onOpen: selected == null
                        ? null
                        : () => setState(() => _openedId = selected.id),
                    onDetach: selected == null ? null : () => _detach(selected),
                    onFullscreen: selected == null
                        ? null
                        : () => _fullscreen(selected),
                    activeNodes: graph.nodes
                        .where((node) => !node.isLogic)
                        .toList(),
                    onSelectNode: (node) => _select(node, focusCanvas: false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarLabel(String label) => SizedBox(
    height: 40,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );
}

class _WorkspaceNodeView extends StatelessWidget {
  const _WorkspaceNodeView({
    required this.node,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
    required this.onDragStart,
    required this.onInteraction,
    required this.onOpen,
    required this.onDetach,
    required this.onHide,
    required this.onMenu,
    required this.onAddPort,
    required this.onPort,
    required this.onConnect,
    required this.onDragPort,
    required this.onDragEnd,
    required this.onPortMenu,
    this.ignorePointer = false,
    this.dimmed = false,
    this.hidden = false,
  });
  final WorkspaceNode node;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<DragUpdateDetails> onMove;
  final ValueChanged<DragUpdateDetails> onResize;
  final ValueChanged<DragStartDetails> onDragStart;
  final ValueChanged<bool> onInteraction;
  final VoidCallback onOpen;
  final VoidCallback onDetach;
  final VoidCallback onHide;
  final ValueChanged<Offset> onMenu;
  final ValueChanged<bool> onAddPort;
  final ValueChanged<_PortRef> onPort;
  final void Function(_PortRef a, _PortRef b) onConnect;
  final void Function(_PortRef port, Offset position) onDragPort;
  final ValueChanged<DraggableDetails> onDragEnd;
  final void Function(_PortRef port, Offset position) onPortMenu;
  final bool ignorePointer;
  final bool dimmed;
  final bool hidden;
  @override
  Widget build(BuildContext context) => Positioned(
    left: node.position.dx,
    top: node.position.dy,
    child: IgnorePointer(
      ignoring: ignorePointer || hidden,
      child: ExcludeFocus(
        excluding: hidden,
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == kPrimaryMouseButton) {
              onSelect();
              onInteraction(true);
            }
          },
          onPointerUp: (_) => onInteraction(false),
          onPointerCancel: (_) => onInteraction(false),
          child: DesktopFocusableAction(
            onActivate: hidden ? null : onOpen,
            onFocus: onSelect,
            onContextMenu: () {
              final box = context.findRenderObject() as RenderBox;
              onMenu(box.localToGlobal(const Offset(24, 24)));
            },
            label: node.module.displayName(context),
            child: Semantics(
              key: ValueKey('workspace selection ${node.id}'),
              selected: selected,
              child: GestureDetector(
                onTap: onSelect,
                onSecondaryTapUp: (details) => onMenu(details.globalPosition),
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: dimmed || node.settings['enabled'] == false
                        ? .58
                        : 1,
                    child: Container(
                      key: ValueKey('workspace node ${node.id}'),
                      width: node.width,
                      height: node.height,
                      decoration: BoxDecoration(
                        color: context.palette.panel,
                        borderRadius: BorderRadius.circular(10),
                        // Keep the one-pixel content inset used by port geometry.
                        border: Border.all(color: context.palette.hover),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(35),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      // Selection is document interaction state, not keyboard
                      // focus. Paint above the opaque header and controls.
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? context.palette.text.withAlpha(150)
                              : context.palette.hover,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Listener(
                                onPointerDown: (event) {
                                  if (event.buttons != kPrimaryMouseButton) {
                                    return;
                                  }
                                  onSelect();
                                  onDragStart(
                                    DragStartDetails(
                                      globalPosition: event.position,
                                    ),
                                  );
                                  onInteraction(true);
                                },
                                onPointerMove: (event) {
                                  if (event.buttons == kPrimaryMouseButton) {
                                    onMove(
                                      DragUpdateDetails(
                                        globalPosition: event.position,
                                        delta: event.delta,
                                      ),
                                    );
                                  }
                                },
                                onPointerUp: (_) => onInteraction(false),
                                onPointerCancel: (_) => onInteraction(false),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.move,
                                  child: Container(
                                    key: ValueKey(
                                      'workspace header ${node.id}',
                                    ),
                                    height: WorkspaceNode.headerHeight,
                                    decoration: BoxDecoration(
                                      color: node.headerColor.headerBackground(
                                        context,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(9),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          node.isLogic
                                              ? Icons.account_tree_outlined
                                              : Icons.extension_outlined,
                                          size: 18,
                                          color: context.palette.text,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            node.isLogic
                                                ? context.logicBlockLabel(
                                                    node.logicType.name,
                                                  )
                                                : node.module.displayName(
                                                    context,
                                                  ),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (hidden)
                                          Icon(
                                            Icons.visibility_off_outlined,
                                            size: 15,
                                            color: context.palette.mutedText,
                                          ),
                                        if (!hidden && !node.isLogic)
                                          DesktopIconButton(
                                            key: ValueKey(
                                              'workspace hide ${node.id}',
                                            ),
                                            icon: Icons.visibility_off_outlined,
                                            tooltip: context.l10n.textHide231,
                                            onPressed: onHide,
                                            size: 24,
                                            iconSize: 15,
                                          ),
                                        Icon(
                                          Icons.drag_indicator,
                                          size: 15,
                                          color: context.palette.mutedText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: WorkspaceNode.portsTopPadding,
                              ),
                              for (
                                var index = 0;
                                index <
                                    math.max(
                                      node.inputs.length,
                                      node.outputs.length,
                                    );
                                index++
                              )
                                SizedBox(
                                  height: WorkspaceNode.portRowHeight,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: index < node.inputs.length
                                            ? _PortView(
                                                label: node.portLabel(
                                                  node.inputs[index],
                                                  false,
                                                ),
                                                type: node.portType(
                                                  node.inputs[index],
                                                  false,
                                                ),
                                                ref: _PortRef(
                                                  node.id,
                                                  node.inputs[index],
                                                  false,
                                                ),
                                                onTap: onPort,
                                                onConnect: onConnect,
                                                onDrag: onDragPort,
                                                onDragEnd: onDragEnd,
                                                color: node.portColor(
                                                  node.inputs[index],
                                                  false,
                                                ),
                                                onMenu: onPortMenu,
                                              )
                                            : const SizedBox(),
                                      ),
                                      Expanded(
                                        child: index < node.outputs.length
                                            ? _PortView(
                                                label: node.portLabel(
                                                  node.outputs[index],
                                                  true,
                                                ),
                                                type: node.portType(
                                                  node.outputs[index],
                                                  true,
                                                ),
                                                ref: _PortRef(
                                                  node.id,
                                                  node.outputs[index],
                                                  true,
                                                ),
                                                onTap: onPort,
                                                onConnect: onConnect,
                                                onDrag: onDragPort,
                                                onDragEnd: onDragEnd,
                                                color: node.portColor(
                                                  node.outputs[index],
                                                  true,
                                                ),
                                                onMenu: onPortMenu,
                                              )
                                            : const SizedBox(),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                height: 34,
                                child: Row(
                                  children: [
                                    TextButton(
                                      onPressed: node.isLogic
                                          ? null
                                          : () => onAddPort(false),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(72, 28),
                                        backgroundColor: context.palette.hover,
                                        foregroundColor: context.palette.text,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Text(context.l10n.textInput307),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: node.isLogic
                                          ? null
                                          : () => onAddPort(true),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(72, 28),
                                        backgroundColor: context.palette.hover,
                                        foregroundColor: context.palette.text,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Text(context.l10n.textOutput308),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  3,
                                  28,
                                  12,
                                ),
                                child: SizedBox(
                                  height: 34,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: hidden ? null : onOpen,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 13,
                                          ),
                                          label: Text(
                                            context.l10n.textOpen309,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      DesktopIconButton(
                                        key: ValueKey(
                                          'workspace detach ${node.id}',
                                        ),
                                        icon: Icons.open_in_new,
                                        tooltip: context.l10n.moduleOpenWindow,
                                        onPressed: hidden ? null : onDetach,
                                        size: 34,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: DesktopTooltip(
                              message: context.l10n.workspaceResizeNode,
                              child: MouseRegion(
                                cursor:
                                    SystemMouseCursors.resizeUpLeftDownRight,
                                child: Listener(
                                  key: ValueKey('workspace resize ${node.id}'),
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (event) {
                                    if (event.buttons != kPrimaryMouseButton) {
                                      return;
                                    }
                                    onSelect();
                                    onDragStart(
                                      DragStartDetails(
                                        globalPosition: event.position,
                                      ),
                                    );
                                    onInteraction(true);
                                  },
                                  onPointerMove: (event) {
                                    if (event.buttons == kPrimaryMouseButton) {
                                      onResize(
                                        DragUpdateDetails(
                                          globalPosition: event.position,
                                          delta: event.delta,
                                        ),
                                      );
                                    }
                                  },
                                  onPointerUp: (_) => onInteraction(false),
                                  onPointerCancel: (_) => onInteraction(false),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Icon(
                                      Icons.south_east,
                                      size: 14,
                                      color: context.palette.mutedText,
                                    ),
                                  ),
                                ),
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
      ),
    ),
  );
}

class _PortView extends StatelessWidget {
  const _PortView({
    required this.ref,
    required this.onTap,
    required this.onConnect,
    required this.onDrag,
    required this.onDragEnd,
    required this.color,
    required this.onMenu,
    required this.label,
    required this.type,
  });
  final _PortRef ref;
  final String label;
  final WorkspacePortType type;
  final ValueChanged<_PortRef> onTap;
  final void Function(_PortRef a, _PortRef b) onConnect;
  final void Function(_PortRef port, Offset position) onDrag;
  final ValueChanged<DraggableDetails> onDragEnd;
  final WorkspaceNodeColor color;
  final void Function(_PortRef port, Offset position) onMenu;
  @override
  Widget build(BuildContext context) => DragTarget<_PortRef>(
    onWillAcceptWithDetails: (details) => details.data.output != ref.output,
    onAcceptWithDetails: (details) => onConnect(details.data, ref),
    builder: (context, candidates, rejected) => Draggable<_PortRef>(
      data: ref,
      feedback: const SizedBox(width: 10, height: 10),
      onDragUpdate: (details) => onDrag(ref, details.globalPosition),
      onDragEnd: onDragEnd,
      child: DesktopFocusableAction(
        onActivate: () => onTap(ref),
        label: '$label · ${_portTypeLabel(context, type)}',
        onContextMenu: () {
          final box = context.findRenderObject() as RenderBox;
          onMenu(ref, box.localToGlobal(const Offset(8, 8)));
        },
        child: GestureDetector(
          key: ValueKey('workspace port ${ref.node} ${ref.output} ${ref.port}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(ref),
          onSecondaryTapUp: (details) => onMenu(ref, details.globalPosition),
          child: SizedBox(
            height: WorkspaceNode.portRowHeight,
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: ref.output
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (ref.output)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.tint ?? context.palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? context.palette.text
                        : color.tint ?? context.palette.mutedText,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (!ref.output)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.tint ?? context.palette.mutedText,
                          fontSize: 14,
                        ),
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

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.transform,
    required this.color,
    required this.background,
    this.rulersOnly = false,
    this.fadeScale,
  });
  final Matrix4 transform;
  final Color color;
  final Color background;
  final bool rulersOnly;
  final double? fadeScale;
  @override
  void paint(Canvas canvas, Size size) {
    final inverse = Matrix4.inverted(transform);
    final visible = Rect.fromPoints(
      MatrixUtils.transformPoint(inverse, Offset.zero),
      MatrixUtils.transformPoint(inverse, size.bottomRight(Offset.zero)),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = transform.getMaxScaleOnAxis();
    if (!rulersOnly) {
      for (final level in WorkspaceGridLevel.levels) {
        final alpha = (85 * level.opacity(fadeScale ?? scale)).round();
        if (alpha == 0) continue;
        final step = level.spacing;
        final points = <Offset>[];
        for (
          var x = (visible.left / step).floor() * step;
          x <= visible.right;
          x += step
        ) {
          for (
            var y = (visible.top / step).floor() * step;
            y <= visible.bottom;
            y += step
          ) {
            // Coarser dots are painted once, at constant opacity.
            if (step < 96 && x % (step * 2) == 0 && y % (step * 2) == 0) {
              continue;
            }
            points.add(MatrixUtils.transformPoint(transform, Offset(x, y)));
          }
        }
        canvas.drawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = color.withAlpha(alpha)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
      return;
    }
    // Screen-space rulers never cross the scene or overlap the empty state.
    const ruler = 22.0;
    final surface = Paint()..color = background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, ruler), surface);
    canvas.drawRect(Rect.fromLTWH(0, 0, ruler, size.height), surface);
    final ticks = Paint()..color = color.withAlpha(90);
    final tickStep = (120 / scale / 24).ceil() * 24.0;
    void label(String value, Offset position) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: color, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, position);
      text.dispose();
    }

    for (
      var x = (visible.left / tickStep).ceil() * tickStep;
      x <= visible.right;
      x += tickStep
    ) {
      final dx = MatrixUtils.transformPoint(transform, Offset(x, 0)).dx;
      if (dx < ruler) continue;
      canvas.drawLine(Offset(dx, ruler - 4), Offset(dx, ruler), ticks);
      label('${(x - 5000).round()}', Offset(dx + 4, 4));
    }
    for (
      var y = (visible.top / tickStep).ceil() * tickStep;
      y <= visible.bottom;
      y += tickStep
    ) {
      final dy = MatrixUtils.transformPoint(transform, Offset(0, y)).dy;
      if (dy < ruler) continue;
      canvas.drawLine(Offset(ruler - 4, dy), Offset(ruler, dy), ticks);
      canvas.save();
      canvas.translate(4, dy - 4);
      canvas.rotate(-math.pi / 2);
      label('${(y - 5000).round()}', Offset.zero);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.transform != transform ||
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.fadeScale != fadeScale ||
      oldDelegate.rulersOnly != rulersOnly;
}

String _portTypeLabel(BuildContext context, WorkspacePortType type) =>
    switch (type) {
      WorkspacePortType.any => context.l10n.workspacePortAny,
      WorkspacePortType.string => context.l10n.workspacePortString,
      WorkspacePortType.number => context.l10n.workspacePortNumber,
      WorkspacePortType.boolean => context.l10n.workspacePortBoolean,
      WorkspacePortType.list => context.l10n.workspacePortList,
      WorkspacePortType.object => context.l10n.workspacePortObject,
    };

class _RenamePortDialog extends StatefulWidget {
  const _RenamePortDialog({required this.label});
  final String label;
  @override
  State<_RenamePortDialog> createState() => _RenamePortDialogState();
}

class _RenamePortDialogState extends State<_RenamePortDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.label,
  );
  @override
  void initState() {
    super.initState();
    _name.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _name.text.length,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _name.text.trim());
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.workspacePortRename),
    content: SizedBox(
      width: 360,
      child: TextField(
        key: const ValueKey('workspace port name field'),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: context.l10n.workspacePortName,
          helperText: context.l10n.workspacePortNameHint,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.textCancel198),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(context.l10n.workspacePortSave),
      ),
    ],
  );
}

class _CanvasLabel extends StatelessWidget {
  const _CanvasLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: context.palette.panel.withAlpha(220),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: context.palette.mutedText, fontSize: 14),
    ),
  );
}

class _WorkspaceInspector extends StatefulWidget {
  const _WorkspaceInspector({
    super.key,
    required this.node,
    required this.onClose,
    required this.onChanged,
    required this.links,
    required this.onDisconnect,
    required this.onColorChanged,
    required this.onPortColorChanged,
    required this.onOpen,
    required this.onDetach,
    required this.onFullscreen,
    required this.activeNodes,
    required this.onSelectNode,
  });
  final WorkspaceNode? node;
  final VoidCallback onClose;
  final void Function(String key, dynamic value)? onChanged;
  final List<WorkspaceLink> links;
  final ValueChanged<WorkspaceLink> onDisconnect;
  final ValueChanged<WorkspaceNodeColor>? onColorChanged;
  final void Function(String port, bool output, WorkspaceNodeColor color)
  onPortColorChanged;
  final VoidCallback? onOpen;
  final VoidCallback? onDetach;
  final VoidCallback? onFullscreen;
  final List<WorkspaceNode> activeNodes;
  final ValueChanged<WorkspaceNode> onSelectNode;

  @override
  State<_WorkspaceInspector> createState() => _WorkspaceInspectorState();
}

class _WorkspaceInspectorState extends State<_WorkspaceInspector> {
  final Set<String> _collapsed = {};
  WorkspaceNode? get node => widget.node;
  void Function(String, dynamic)? get onChanged => widget.onChanged;
  List<WorkspaceLink> get links => widget.links;

  Widget _section(String id, String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ExplorerDisclosureSection(
      title: title,
      expanded: !_collapsed.contains(id),
      showDivider: false,
      onToggle: () => setState(() {
        if (!_collapsed.remove(id)) _collapsed.add(id);
      }),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: WidgetOrderTraversalPolicy(),
    child: DesktopPane(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: DesktopPane(
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.textMODULESETTINGS310,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DesktopIconButton(
                      icon: Icons.close,
                      tooltip: context.l10n.textCloseModuleSettings311,
                      onPressed: widget.onClose,
                      size: 24,
                      iconSize: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: DesktopPane(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Text(
                      context.hostLabel('Active modules'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.activeNodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Text(
                        context.hostLabel('No active modules'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.mutedText,
                        ),
                      ),
                    )
                  else
                    for (final activeNode in widget.activeNodes)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: DesktopHoverTile(
                          selected: activeNode.id == node?.id,
                          onTap: () => widget.onSelectNode(activeNode),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.extension_outlined,
                                  size: 15,
                                  color: context.palette.mutedText,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    activeNode.module.displayName(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              children: [
                if (node == null)
                  DesktopPane(
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.l10n.textSelectAModuleOnTheCanvas312,
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else ...[
                  DesktopPane(
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            node!.module.displayName(context),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${context.hostLabel(node!.module.category)} · ${node!.module.version}',
                            style: TextStyle(
                              color: context.palette.mutedText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            key: const ValueKey('workspace inspector actions'),
                            children: [
                              Expanded(
                                child: DesktopIconButton(
                                  onPressed: widget.onOpen,
                                  icon: Icons.launch,
                                  label: context.l10n.textOpen309,
                                  tooltip: context.l10n.textOpen309,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 6),
                              DesktopIconButton(
                                icon: Icons.open_in_new,
                                tooltip: context.l10n.moduleOpenWindow,
                                onPressed: widget.onDetach,
                                size: 30,
                              ),
                              const SizedBox(width: 6),
                              DesktopIconButton(
                                icon: Icons.fullscreen,
                                tooltip: context.l10n.moduleFullscreen,
                                onPressed: widget.onFullscreen,
                                size: 30,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section('instance', context.l10n.workspaceInstance, [
                    ModuleControls(
                      schema: [
                        {
                          'id': 'enabled',
                          'label': context.hostLabel('Enabled'),
                          'type': 'toggle',
                          'default': true,
                        },
                        {
                          'id': 'label',
                          'label': context.hostLabel('Instance label'),
                          'type': 'text',
                        },
                      ],
                      values: {...node!.settings, ...node!.runtimeValues},
                      onChanged: onChanged!,
                    ),
                  ]),
                  _section('parameters', context.l10n.workspaceParameters, [
                    if (node!.isLogic)
                      LogicBlockEditor(
                        key: ValueKey(node!.id),
                        node: node!,
                        onChanged: onChanged!,
                      )
                    else if (node!.module.manifest['parameters'] is List ||
                        (node!.module.isLocal &&
                            node!.module.manifest['ui'] is List))
                      ModuleControls(
                        localizePreview: node!.module.isLocalPreview,
                        schema:
                            (node!.module.manifest['parameters'] ??
                                    node!.module.manifest['ui'])
                                as List,
                        values: {...node!.settings, ...node!.runtimeValues},
                        onChanged: onChanged!,
                      )
                    else
                      Text(
                        context
                            .l10n
                            .textNoAdditionalSettingsHaveBeenDeclaredBy313,
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                  ]),
                  _section('appearance', context.l10n.workspaceAppearance, [
                    DesktopSelectField<String>(
                      label: context.l10n.workspaceHeaderColor,
                      valueLabel: node!.headerColor.label(context),
                      entries: workspaceColorEntries(context, ''),
                      onSelected: (value) => widget.onColorChanged?.call(
                        WorkspaceNodeColor.fromJson(value),
                      ),
                    ),
                  ]),
                  _section('ports', context.l10n.workspacePorts, [
                    for (final output in [false, true])
                      for (final port
                          in output ? node!.outputs : node!.inputs) ...[
                        DesktopSelectField<String>(
                          key: ValueKey(
                            'workspace port color ${node!.id} $output $port',
                          ),
                          label:
                              '${output ? context.l10n.workspaceOutputColor : context.l10n.workspaceInputColor} · ${node!.portLabel(port, output)}',
                          valueLabel: node!
                              .portColor(port, output)
                              .label(context),
                          entries: workspaceColorEntries(context, ''),
                          onSelected: (value) => widget.onPortColorChanged(
                            port,
                            output,
                            WorkspaceNodeColor.fromJson(value),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                  ]),
                  _section('connections', context.l10n.textConnections314, [
                    for (final link in links.where(
                      (link) =>
                          link.source == node!.id || link.target == node!.id,
                    ))
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${link.output} → ${link.input}',
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DesktopIconButton(
                            icon: Icons.link_off,
                            tooltip: context.l10n.textDisconnectPorts315,
                            onPressed: () => widget.onDisconnect(link),
                            size: 26,
                            iconSize: 15,
                          ),
                        ],
                      ),
                    if (!links.any(
                      (link) =>
                          link.source == node!.id || link.target == node!.id,
                    ))
                      Text(
                        context.l10n.textNoConnections316,
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
