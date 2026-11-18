import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/module_registry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_model.dart';
import '../../core/workspace/workspace_project.dart';
import '../../state/workspace_state.dart';
import '../../state/workspace_providers.dart';
import '../common/widgets.dart';
import '../common/desktop_menu.dart';
import 'module_ui.dart';
import 'workspace_colors.dart';
import 'workspace_grid.dart';
import 'workspace_connections.dart';
import 'active_module_view.dart';
import '../common/desktop_focus.dart';
import '../../core/modules/module_window_session.dart';
import '../../core/workspace/workspace_id.dart';
import '../../core/workspace/workspace_eraser.dart';
import '../../core/workspace/workspace_fragment.dart';
import '../common/navigation_bindings.dart';
import 'workspace_manager.dart';
import '../../core/logic/logic_blocks.dart';
import 'logic_block_editor.dart';
import 'workspace_canvas_controller.dart';
import 'canvas/render/workspace_annotation_layer.dart';
import 'canvas/render/workspace_node_layer.dart';

// Kept as a source-compatible alias for integrations and tests that imported
// the painter from this screen before the canvas layers were split out.
typedef WorkspaceAnnotationPainter = WorkspaceAnnotationLayerPainter;

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
    this.selectedNodeId,
    this.onSelectedNode,
    this.onMarketplace,
    this.canvasFullscreen = false,
    this.onToggleCanvasFullscreen,
    this.workspaceNotice,
    this.canvasController,
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
  final String? selectedNodeId;
  final ValueChanged<String?>? onSelectedNode;
  final VoidCallback? onMarketplace;
  final bool canvasFullscreen;
  final VoidCallback? onToggleCanvasFullscreen;
  final String? workspaceNotice;
  final WorkspaceCanvasController? canvasController;
  @override
  ConsumerState<ModulesScreen> createState() => _ModulesScreenState();
}

class _PortRef {
  const _PortRef(this.node, this.port, this.output);
  final String node;
  final String port;
  final bool output;
}

enum _CanvasTool { select, pencil, eraser, cut, branch }

const _canvasRulerExtent = 22.0;
const _nodePortHitInset = 16.0;

/// Let EditableText's native shortcuts reach the application Shortcuts above
/// this canvas instead of interpreting text edits as graph edits.
class _CanvasActivator extends SingleActivator {
  const _CanvasActivator(super.trigger, {super.control, super.shift});

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    final editing =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>() !=
        null;
    return !editing && super.accepts(event, state);
  }
}

class _ModulesScreenState extends ConsumerState<ModulesScreen> {
  final _transform = TransformationController(
    Matrix4.identity()..translateByDouble(-4800, -4800, 0, 1),
  );
  final _viewportKey = GlobalKey();
  final _captureKey = GlobalKey();
  bool _capturingCanvas = false;
  final _focus = FocusNode(debugLabel: 'workspace canvas');
  String? _selectedId;
  String? _movableJunctionId;
  final Set<String> _selection = {};
  WorkspaceNodeColor? _colorFilter;
  bool _menuOpen = false;
  bool _pickerOpen = false;
  String? _openedId;
  bool _inspector = false;
  bool _snapToGrid = false;
  bool _toolRailVisible = true;
  bool _canvasHintsVisible = true;
  _CanvasTool _canvasTool = _CanvasTool.select;
  int? _annotationPointer;
  List<Offset> _annotationPoints = const [];
  List<WorkspaceAnnotation>? _eraserPreview;
  Color? _brushColor;
  double _brushDiameter = 3;
  double _eraserDiameter = 24;
  Offset? _drawingCursor;
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
  Offset? _nodeDragGlobalStart;
  Map<String, Offset> _nodeDragStartPositions = const {};
  String? _activeNodeId;
  bool _activeNodeResize = false;
  bool _nodeInteracting = false;
  int _interactionGeneration = 0;
  double _lastCanvasWidth = WorkspaceProject.defaultCanvasWidth;
  double _lastCanvasHeight = WorkspaceProject.defaultCanvasHeight;

  double get _canvasWidth => ref.read(workspaceProvider).canvasWidth;
  double get _canvasHeight => ref.read(workspaceProvider).canvasHeight;
  double get _canvasOriginX =>
      _canvasWidth == WorkspaceProject.defaultCanvasWidth
      ? 4800
      : _canvasWidth / 2;
  double get _canvasOriginY =>
      _canvasHeight == WorkspaceProject.defaultCanvasHeight
      ? 4800
      : _canvasHeight / 2;

  @override
  void initState() {
    super.initState();
    _bindCanvasController();
    ref.listenManual(workspaceProvider.select((s) => s.activeProjectId), (
      previous,
      next,
    ) {
      if (previous == next || !mounted) return;
      setState(() {
        _selection.clear();
        _selectedId = null;
        _movableJunctionId = null;
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
          ..translateByDouble(-_canvasOriginX, -_canvasOriginY, 0, 1);
      });
    });
    ref.listenManual(workspaceProvider, (_, next) {
      if (next.canvasWidth != _lastCanvasWidth ||
          next.canvasHeight != _lastCanvasHeight) {
        _lastCanvasWidth = next.canvasWidth;
        _lastCanvasHeight = next.canvasHeight;
        _transform.value = Matrix4.identity()
          ..translateByDouble(
            next.canvasWidth == WorkspaceProject.defaultCanvasWidth
                ? -4800
                : -next.canvasWidth / 2,
            next.canvasHeight == WorkspaceProject.defaultCanvasHeight
                ? -4800
                : -next.canvasHeight / 2,
            0,
            1,
          );
      }
      final interactive = next.nodes
          .where(
            (node) =>
                !next.hiddenNodeIds.contains(node.id) &&
                !next.hiddenModuleIds.contains(node.module.id) &&
                !node.fullyHidden &&
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
      _publishSelectionAfterFrame();
    });
    ref.listenManual(selectionProvider, (_, next) {
      if (!mounted || setEquals(next.ids, _selection)) return;
      setState(() {
        _selection
          ..clear()
          ..addAll(next.ids);
        _selectedId = next.primaryId ?? _selection.lastOrNull;
      });
    });
  }

  @override
  void didUpdateWidget(covariant ModulesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasController != widget.canvasController) {
      oldWidget.canvasController?.clear();
      _bindCanvasController();
    }
    if (widget.selectedNodeId != oldWidget.selectedNodeId) {
      _publishSelectionAfterFrame();
      if (widget.selectedNodeId == null) {
        _selection.clear();
        _selectedId = null;
        return;
      }
      final node = ref
          .read(workspaceProvider)
          .nodes
          .where((item) => item.id == widget.selectedNodeId)
          .firstOrNull;
      if (node != null && node.id != _selectedId) {
        setState(() {
          _selection
            ..clear()
            ..addAll(
              _visibleNodes
                  .where((item) => item.id == node.id)
                  .map((item) => item.id),
            );
          _selectedId = node.id;
          _inspector = widget.canvasController == null;
        });
      }
    }
  }

  void _bindCanvasController() {
    final controller = widget.canvasController;
    if (controller == null) return;
    controller.addModule = () => _onCanvas(() => _pick());
    controller.addLogic = (type) {
      _onCanvas(() {
        _select(
          _controller.addLogicBlock(type, _center - const Offset(120, 80)),
        );
      });
    };
    controller.open = (node) => setState(() => _openedId = node.id);
    controller.detach = _detach;
    controller.fullscreen = _fullscreen;
    controller.selectFromScene = (node, toggle) {
      setState(() {
        if (!toggle) _selection.clear();
        if (!toggle || !_selection.remove(node.id)) _selection.add(node.id);
        _selectedId = _selection.contains(node.id)
            ? node.id
            : _selection.lastOrNull;
        _movableJunctionId = null;
      });
      _notifySelection();
    };
    controller.copy = (node) {
      if (!_selection.contains(node.id)) _select(node);
      _copySelection();
    };
    controller.cut = (node) {
      if (!_selection.contains(node.id)) _select(node);
      _copySelection(cut: true);
    };
  }

  void _onCanvas(VoidCallback action) {
    if (_openedId == null) {
      action();
      return;
    }
    setState(() => _openedId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  bool get _panKeyPressed => HardwareKeyboard.instance.logicalKeysPressed
      .contains(LogicalKeyboardKey.space);

  bool get _additiveSelection =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isAltPressed;

  void _setInspector(bool open) {
    if (widget.canvasController != null) {
      if (widget.explorerVisible != open) widget.onToggleExplorer?.call();
      return;
    }
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
    if (_movableJunctionId != null) {
      setState(() => _movableJunctionId = null);
    }
    if (_isCanvasDrawingTool) {
      _startCanvasTool(event);
      return;
    }
    if (_canvasTool == _CanvasTool.branch) {
      _focus.requestFocus();
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
      _marqueeBase = _additiveSelection ? {..._selection} : {};
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
    _notifySelection();
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
          setState(() {
            _nodeInteracting = false;
            _nodeDragPosition = null;
            _nodeDragGlobalStart = null;
            _nodeDragStartPositions = const {};
            _activeNodeId = null;
            _activeNodeResize = false;
          });
        }
      });
    }
  }

  WorkspaceController get _controller => ref.read(workspaceProvider.notifier);

  void _startNodeDrag(
    DragStartDetails details,
    String nodeId, {
    bool resize = false,
  }) {
    final graph = ref.read(workspaceProvider);
    _nodeDragStartPositions = {
      for (final node in graph.nodes)
        if (_selection.contains(node.id) || node.id == nodeId)
          node.id: node.position,
    };
    if (!_selection.contains(nodeId)) {
      _selection.add(nodeId);
    }
    _nodeDragPosition = details.globalPosition;
    _nodeDragGlobalStart = details.globalPosition;
    _activeNodeId = nodeId;
    _activeNodeResize = resize;
  }

  void _moveActiveNode(DragUpdateDetails details) {
    if (_panKeyPressed || _panPointer != null || _activeNodeId == null) {
      return;
    }
    final previousGlobal = _nodeDragPosition ?? details.globalPosition;
    final frameDelta =
        _sceneAt(details.globalPosition) - _sceneAt(previousGlobal);
    _nodeDragPosition = details.globalPosition;
    final move = _snapToGrid
        ? _moveDelta(
            _selection,
            _sceneAt(details.globalPosition) -
                _sceneAt(_nodeDragGlobalStart ?? previousGlobal),
          )
        : frameDelta;
    _controller.moveNodes(_selection, move);
  }

  void _resizeActiveNode(DragUpdateDetails details) {
    if (_panKeyPressed || _panPointer != null || _activeNodeId == null) {
      return;
    }
    final previousGlobal = _nodeDragPosition ?? details.globalPosition;
    final delta = _sceneAt(details.globalPosition) - _sceneAt(previousGlobal);
    _nodeDragPosition = details.globalPosition;
    final node = ref
        .read(workspaceProvider)
        .nodes
        .where((item) => item.id == _activeNodeId)
        .firstOrNull;
    if (node == null) return;
    _controller.resizeNode(
      node.id,
      Size(node.width + delta.dx, node.height + delta.dy),
    );
  }

  List<WorkspaceNode> get _visibleNodes => ref
      .read(workspaceProvider)
      .nodes
      .where(
        (node) => node.isLogic
            ? ref.read(workspaceProvider).showLogicBlocks
            : ref.read(workspaceProvider).showModuleBlocks,
      )
      .where((node) => _colorFilter == null || node.headerColor == _colorFilter)
      .where((node) {
        final graph = ref.read(workspaceProvider);
        return !graph.hiddenNodeIds.contains(node.id) &&
            !graph.hiddenModuleIds.contains(node.module.id) &&
            !node.fullyHidden;
      })
      .toList();

  void _filterColor(WorkspaceNodeColor? color) {
    setState(() {
      _colorFilter = color;
      _selection.clear();
      _selectedId = null;
      _pendingPort = null;
      _wireEnd = null;
    });
    _notifySelection();
  }

  void _selectColor(WorkspaceNodeColor color) {
    final graph = ref.read(workspaceProvider);
    final nodes = graph.nodes
        .where(
          (node) =>
              !graph.hiddenNodeIds.contains(node.id) &&
              !graph.hiddenModuleIds.contains(node.module.id) &&
              !node.fullyHidden &&
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
    _notifySelection();
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

  WorkspaceNode? _nodeAt(Offset global, {bool includePartiallyHidden = false}) {
    final scene = _sceneAt(global);
    final graph = ref.read(workspaceProvider);
    final nodes = includePartiallyHidden
        ? graph.nodes.where(
            (node) =>
                !node.fullyHidden &&
                (node.isLogic
                    ? graph.showLogicBlocks
                    : graph.showModuleBlocks) &&
                (_colorFilter == null || node.headerColor == _colorFilter),
          )
        : _visibleNodes;
    return nodes
        .toList()
        .reversed
        .where(
          (node) =>
              (node.position & Size(node.width, node.height)).contains(scene),
        )
        .firstOrNull;
  }

  @override
  void dispose() {
    widget.canvasController?.clear();
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
      if (!_additiveSelection && !_selection.contains(node.id)) {
        _selection.clear();
      }
      _selection.add(node.id);
      if (_movableJunctionId != node.id) _movableJunctionId = null;
      _selectedId = node.id;
      _inspector = widget.canvasController == null;
    });
    widget.onSelectedModule?.call(node.isLogic ? null : node.module);
    widget.onSelectedNode?.call(node.id);
    _publishSelection();
    if (focusCanvas) _focus.requestFocus();
  }

  void _notifySelection() {
    _publishSelection();
    final node = ref
        .read(workspaceProvider)
        .nodes
        .where((node) => node.id == _selectedId)
        .firstOrNull;
    widget.onSelectedModule?.call(
      node == null || node.isLogic ? null : node.module,
    );
    widget.onSelectedNode?.call(node?.id);
  }

  void _publishSelection() {
    final current = ref.read(selectionProvider).ids;
    if (!setEquals(current, _selection) ||
        ref.read(selectionProvider).primaryId != _selectedId) {
      ref
          .read(selectionProvider.notifier)
          .replace(_selection, primaryId: _selectedId);
    }
  }

  void _publishSelectionAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishSelection();
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
      _selectedId = null;
    });
    _notifySelection();
  }

  void _setCanvasTool(_CanvasTool tool) {
    setState(() {
      _canvasTool = tool;
      _annotationPointer = null;
      _annotationPoints = const [];
      _eraserPreview = null;
      _drawingCursor = null;
      if (tool != _CanvasTool.branch) {
        _pendingPort = null;
        _wireEnd = null;
      }
    });
  }

  bool get _isCanvasDrawingTool =>
      _canvasTool == _CanvasTool.pencil ||
      _canvasTool == _CanvasTool.eraser ||
      _canvasTool == _CanvasTool.cut ||
      _canvasTool == _CanvasTool.branch;

  void _startCanvasTool(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton || _panKeyPressed) return;
    final point = _sceneAt(event.position);
    if (_canvasTool == _CanvasTool.pencil ||
        _canvasTool == _CanvasTool.eraser) {
      setState(() {
        _annotationPointer = event.pointer;
        _annotationPoints = [point];
        _drawingCursor = point;
        if (_canvasTool == _CanvasTool.eraser) {
          _eraserPreview = eraseWorkspaceAnnotations(
            ref.read(workspaceProvider).annotations,
            point,
            point,
            _eraserDiameter,
          );
        }
      });
    } else if (_canvasTool == _CanvasTool.cut ||
        _canvasTool == _CanvasTool.branch) {
      setState(() {
        _annotationPointer = event.pointer;
        _annotationPoints = [point];
      });
    }
  }

  void _updateCanvasTool(PointerMoveEvent event) {
    if (event.pointer != _annotationPointer) return;
    final point = _sceneAt(event.position);
    if (_canvasTool == _CanvasTool.eraser) {
      setState(() {
        _eraserPreview = eraseWorkspaceAnnotations(
          _eraserPreview ?? ref.read(workspaceProvider).annotations,
          _annotationPoints.last,
          point,
          _eraserDiameter,
        );
        _annotationPoints = [point];
        _drawingCursor = point;
      });
      return;
    }
    if (_annotationPoints.isEmpty ||
        (point - _annotationPoints.last).distance > .5) {
      setState(() {
        if (_annotationPoints.length < 10000) {
          _annotationPoints = [..._annotationPoints, point];
        }
        _drawingCursor = point;
      });
    }
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final delta = end - start;
    final lengthSquared = delta.distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final t =
        ((point - start).dx * delta.dx + (point - start).dy * delta.dy) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    return (point - (start + delta * clamped)).distance;
  }

  bool _linkNearPath(
    WorkspaceLink link,
    List<WorkspaceNode> nodes,
    List<Offset> stroke,
  ) {
    final source = nodes.where((node) => node.id == link.source).firstOrNull;
    final target = nodes.where((node) => node.id == link.target).firstOrNull;
    if (source == null || target == null) return false;
    final from = source.portPosition(link.output, true);
    final to = target.portPosition(link.input, false);
    var previous = from;
    final cutWidth = 14 / _transform.value.getMaxScaleOnAxis();
    final direction = to.dx >= from.dx ? 1.0 : -1.0;
    final dx = math.max(60.0, (to.dx - from.dx).abs() * .45);
    for (var index = 1; index <= 20; index++) {
      final t = index / 20;
      final inverse = 1 - t;
      final next = Offset(
        inverse * inverse * inverse * from.dx +
            3 * inverse * inverse * t * (from.dx + direction * dx) +
            3 * inverse * t * t * (to.dx - direction * dx) +
            t * t * t * to.dx,
        inverse * inverse * inverse * from.dy +
            3 * inverse * inverse * t * from.dy +
            3 * inverse * t * t * to.dy +
            t * t * t * to.dy,
      );
      for (final point in stroke) {
        if (_distanceToSegment(point, previous, next) < cutWidth) return true;
      }
      previous = next;
    }
    return false;
  }

  void _finishCanvasTool(PointerEvent event, {bool cancel = false}) {
    if (event.pointer != _annotationPointer) return;
    if (!cancel) {
      _updateCanvasTool(
        PointerMoveEvent(pointer: event.pointer, position: event.position),
      );
    }
    final points = _annotationPoints;
    final erased = _eraserPreview;
    setState(() {
      _annotationPointer = null;
      _annotationPoints = const [];
      _eraserPreview = null;
    });
    if (cancel) return;
    if (_canvasTool == _CanvasTool.pencil && points.isNotEmpty) {
      _controller.addAnnotation(
        WorkspaceAnnotation(
          id: WorkspaceId.create('annotation'),
          points: points,
          color: (_brushColor ?? context.palette.text).toARGB32(),
          width: _brushDiameter,
        ),
      );
    } else if (_canvasTool == _CanvasTool.eraser && erased != null) {
      _controller.replaceAnnotations(erased);
    } else if (_canvasTool == _CanvasTool.cut && points.isNotEmpty) {
      final graph = ref.read(workspaceProvider);
      for (final link in graph.links) {
        if (_linkNearPath(link, graph.nodes, points)) {
          _controller.disconnect(link);
        }
      }
    } else if (_canvasTool == _CanvasTool.branch && points.length > 1) {
      final graph = ref.read(workspaceProvider);
      final candidates = [
        for (final link in graph.links)
          if (_linkNearPath(link, graph.nodes, points)) link,
      ];
      if (candidates.isNotEmpty) {
        _controller.beginHistoryGroup();
        try {
          for (final link in candidates) {
            final source = graph.nodes
                .where((n) => n.id == link.source)
                .firstOrNull;
            final target = graph.nodes
                .where((n) => n.id == link.target)
                .firstOrNull;
            if (source == null || target == null) continue;
            final from = source.portPosition(link.output, true);
            final to = target.portPosition(link.input, false);
            final midpoint = _bezierPoint(from, to, .5);
            _controller.insertJunction(link, midpoint - const Offset(14, 14));
          }
        } finally {
          _controller.endHistoryGroup();
        }
      }
    }
  }

  Offset _bezierPoint(Offset from, Offset to, double t) {
    final direction = to.dx >= from.dx ? 1.0 : -1.0;
    final bend = math.max(60.0, (to.dx - from.dx).abs() * .45);
    final c1 = Offset(from.dx + direction * bend, from.dy);
    final c2 = Offset(to.dx - direction * bend, to.dy);
    final inverse = 1 - t;
    return Offset(
      inverse * inverse * inverse * from.dx +
          3 * inverse * inverse * t * c1.dx +
          3 * inverse * t * t * c2.dx +
          t * t * t * to.dx,
      inverse * inverse * inverse * from.dy +
          3 * inverse * inverse * t * c1.dy +
          3 * inverse * t * t * c2.dy +
          t * t * t * to.dy,
    );
  }

  void _hideModule(WorkspaceNode node) {
    _controller.setNodesHidden(
      _selection.contains(node.id) ? {..._selection} : {node.id},
      true,
    );
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
  /// node. `requested` is the total movement since pointer-down, not the last
  /// pointer-event delta. Snapping the accumulated movement prevents the
  /// initial jump caused by rounding an already arbitrary node coordinate.
  Offset _moveDelta(Set<String> ids, Offset requested) {
    final nodes = ref
        .read(workspaceProvider)
        .nodes
        .where((node) => ids.contains(node.id))
        .toList();
    if (nodes.isEmpty) return requested;
    final anchor = nodes.first;
    final start = _nodeDragStartPositions[anchor.id] ?? anchor.position;
    var desiredDelta = _snapToGrid
        ? Offset(
            (requested.dx / _snapSpacing).round() * _snapSpacing,
            (requested.dy / _snapSpacing).round() * _snapSpacing,
          )
        : requested;

    // Once the cursor is close to another module, prefer its edges over a
    // nearby grid line. This keeps ports aligned without allowing cards to
    // land on top of one another. Edge snapping is based on the original
    // drag position, so it cannot accumulate an offset from frame to frame.
    if (_snapToGrid) {
      const edgeThreshold = 12.0;
      final others = ref
          .read(workspaceProvider)
          .nodes
          .where((item) => !ids.contains(item.id));
      final proposed = start + desiredDelta;
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
      desiredDelta = snapped - start;
    }

    // `moveNodes` accepts an incremental delta, while snapping is calculated
    // from the original pointer-down position.
    var delta = desiredDelta - (anchor.position - start);
    final positions = <String, Offset>{};
    for (final node in nodes) {
      final nodeStart = _nodeDragStartPositions[node.id] ?? node.position;
      final position = nodeStart + desiredDelta;
      positions[node.id] = Offset(
        position.dx.clamp(0, _canvasWidth - node.width).toDouble(),
        position.dy.clamp(0, _canvasHeight - node.height).toDouble(),
      );
    }
    delta = positions[anchor.id]! - anchor.position;
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
    _notifySelection();
  }

  Future<void> _copySelection({bool cut = false}) async {
    final graph = ref.read(workspaceProvider);
    final ids = {..._selection};
    if (ids.isEmpty) return;
    final fragment = WorkspaceFragment.capture(graph.nodes, graph.links, ids);
    if (fragment.project.nodes.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: fragment.encode()));
      if (cut &&
          mounted &&
          ref.read(workspaceProvider).activeProjectId ==
              graph.activeProjectId) {
        _controller.removeNodes(ids);
        _clearSelection();
      }
    } catch (_) {
      if (mounted) _message(context.l10n.workspaceClipboardFailed);
    }
  }

  Future<void> _pasteSelection([Offset? position]) async {
    final projectId = ref.read(workspaceProvider).activeProjectId;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted ||
          ref.read(workspaceProvider).activeProjectId != projectId) {
        return;
      }
      final fragment = WorkspaceFragment.decode(data?.text);
      if (fragment == null) return;
      final nodes = _controller.pasteFragment(
        fragment,
        position ?? _center - const Offset(120, 80),
        availableModules: widget.modules,
      );
      setState(() {
        _colorFilter = null;
        _selection
          ..clear()
          ..addAll(nodes.map((node) => node.id));
        _selectedId = nodes.firstOrNull?.id;
        _pendingPort = null;
        _wireEnd = null;
      });
      _notifySelection();
      _focus.requestFocus();
    } catch (_) {
      if (mounted) _message(context.l10n.workspaceClipboardFailed);
    }
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
      case 'canvasFullscreen':
        widget.onToggleCanvasFullscreen?.call();
      case 'canvasScreenshot':
        _saveCanvasScreenshot();
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
        _setInspector(
          !(widget.canvasController != null
              ? widget.explorerVisible
              : _inspector || widget.inspectorOpen),
        );
    }
  }

  Future<void> _saveCanvasScreenshot() async {
    if (_capturingCanvas) return;
    _capturingCanvas = true;
    try {
      // Finish any menu dismissal/selection repaint before reading the layer.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return;
      // Bound memory use on high-DPI/large windows; never rasterize the entire
      // 100,000px document for a screenshot of the visible canvas.
      final ratio = math.min(
        MediaQuery.devicePixelRatioOf(context),
        4096 / math.max(boundary.size.width, boundary.size.height),
      );
      final image = await boundary.toImage(pixelRatio: ratio);
      late final ByteData? data;
      try {
        data = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (data == null || !mounted) return;
      final name = ref
          .read(workspaceProvider)
          .activeProject
          .name
          .replaceAll(RegExp(r'[^a-zA-Z0-9_а-яА-Я-]'), '_');
      final destination = await getSaveLocation(
        suggestedName: '$name-canvas.png',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PNG', extensions: ['png']),
        ],
      );
      if (destination == null) return;
      await XFile.fromData(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: 'image/png',
      ).saveTo(destination.path);
      if (mounted) _message(context.l10n.canvasScreenshotSaved);
    } catch (_) {
      if (mounted) _message(context.l10n.canvasScreenshotFailed);
    } finally {
      _capturingCanvas = false;
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
    } else if (details.wasAccepted &&
        _canvasTool == _CanvasTool.branch &&
        port != null &&
        port.output) {
      setState(() {
        _pendingPort = port;
        _wireEnd = null;
        _wireGlobal = null;
      });
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
    if (node != null && !_selection.contains(node.id)) _select(node);
    _menuOpen = true;
    final graph = ref.read(workspaceProvider);
    final hidden =
        node != null &&
        (node.fullyHidden ||
            graph.hiddenNodeIds.contains(node.id) ||
            graph.hiddenModuleIds.contains(node.module.id));
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
          DesktopMenuEntry(
            value: 'paste',
            label: context.l10n.workspacePaste,
            shortcut: 'Ctrl+V',
          ),
          if (node == null)
            DesktopMenuEntry(
              value: 'logic',
              label: context.l10n.logicAdd,
              submenu: [
                for (final type in LogicBlockType.values.where(
                  (type) => type != LogicBlockType.junction,
                ))
                  DesktopMenuEntry(
                    value: 'logic:${type.name}',
                    label: context.logicBlockLabel(type.name),
                  ),
              ],
            ),
          if (node == null)
            DesktopMenuEntry(value: 'add', label: context.l10n.textAdd294)
          else ...[
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
            if (node.isJunction)
              DesktopMenuEntry(
                value: 'moveJunction',
                label: context.l10n.workspaceMoveJunction,
              ),
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
            DesktopMenuEntry(
              value: hidden ? 'show' : 'hide',
              label: hidden
                  ? context.l10n.textShow232
                  : context.l10n.textHide231,
            ),
            if (!node.fullyHidden && !node.isLogic)
              DesktopMenuEntry(
                value: 'hideFully',
                label: context.l10n.workspaceHideFully,
              ),
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
      if (action == 'copy') await _copySelection();
      if (action == 'cut') await _copySelection(cut: true);
      if (action == 'paste') await _pasteSelection(scene);
      if (!mounted) return;
      if (action == 'moveJunction' && node != null) {
        setState(() => _movableJunctionId = node.id);
      }
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
        _controller.setNodeColors(
          _selection.contains(node.id) ? {..._selection} : {node.id},
          WorkspaceNodeColor.fromJson(action.substring(6)),
        );
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
      if (action == 'hide' && node != null) {
        _hideModule(node);
      }
      if (action == 'show' && node != null) {
        if (node.fullyHidden) {
          _controller.setNodeFullyHidden(node.id, false);
        } else {
          _controller.setNodeHidden(node.id, false);
        }
      }
      if (action == 'hideFully' && node != null) {
        _controller.setNodeFullyHidden(node.id, true);
        _clearSelection();
      }
      if (action == 'delete' && node != null) {
        _controller.removeNodes(
          _selection.contains(node.id) ? {..._selection} : {node.id},
        );
        setState(() {
          _selection.clear();
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
    final graph = ref.read(workspaceProvider);
    if (graph.hiddenNodeIds.contains(node.id) ||
        graph.hiddenModuleIds.contains(node.module.id)) {
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
    final graph = ref.read(workspaceProvider);
    if (_fullscreenOpen ||
        graph.hiddenNodeIds.contains(node.id) ||
        graph.hiddenModuleIds.contains(node.module.id)) {
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
                      !workspace.hiddenNodeIds.contains(item.id) &&
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
    final branch = _canvasTool == _CanvasTool.branch;
    setState(() {
      _pendingPort = branch && from.output ? from : null;
      _wireEnd = null;
    });
  }

  Future<void> _portMenu(_PortRef port, Offset position) async {
    final node = ref
        .read(workspaceProvider)
        .nodes
        .where((node) => node.id == port.node)
        .firstOrNull;
    if (node?.isJunction == true) {
      await _menu(position, node: node);
      return;
    }
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
        ..translateByDouble(-_canvasOriginX, -_canvasOriginY, 0, 1);
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
    final renderNodes = graph.nodes
        .where(
          (node) =>
              node.isLogic ? graph.showLogicBlocks : graph.showModuleBlocks,
        )
        .where(
          (node) => _colorFilter == null || node.headerColor == _colorFilter,
        )
        .where((node) => !node.fullyHidden)
        .toList();
    final visibleNodes = graph.nodes
        .where(
          (node) =>
              !graph.hiddenNodeIds.contains(node.id) &&
              !graph.hiddenModuleIds.contains(node.module.id) &&
              !node.fullyHidden &&
              (node.isLogic ? graph.showLogicBlocks : graph.showModuleBlocks),
        )
        .where(
          (node) => _colorFilter == null || node.headerColor == _colorFilter,
        )
        .toList();
    final opened = graph.nodes
        .where(
          (node) =>
              node.id == _openedId &&
              !graph.hiddenNodeIds.contains(node.id) &&
              !graph.hiddenModuleIds.contains(node.module.id) &&
              !node.fullyHidden,
        )
        .firstOrNull;
    final selected = graph.nodes
        .where((node) => node.id == _selectedId)
        .firstOrNull;
    final inspector =
        widget.canvasController == null &&
        !widget.canvasFullscreen &&
        (_inspector || widget.inspectorOpen) &&
        opened == null;
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
        const SingleActivator(LogicalKeyboardKey.f12, control: true):
            _saveCanvasScreenshot,
        const _CanvasActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const _CanvasActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
        const _CanvasActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redo,
        const _CanvasActivator(LogicalKeyboardKey.keyC, control: true): () =>
            _copySelection(),
        const _CanvasActivator(LogicalKeyboardKey.keyX, control: true): () =>
            _copySelection(cut: true),
        const _CanvasActivator(LogicalKeyboardKey.keyV, control: true): () =>
            _pasteSelection(),
        ...NavigationBindings.instance.callbacks({
          NavigationAction.fullscreen: () =>
              widget.onToggleCanvasFullscreen?.call(),
          NavigationAction.dismiss: () {
            if (widget.canvasFullscreen) {
              widget.onToggleCanvasFullscreen?.call();
              return;
            }
            _endMarquee(cancel: true);
            setState(() {
              _pendingPort = null;
              _wireEnd = null;
              _movableJunctionId = null;
            });
          },
          NavigationAction.contextMenu: _menuAtFocus,
          NavigationAction.findModule: () => _pick(),
          NavigationAction.scaleUp: () => _viewAction('in', visibleNodes),
          NavigationAction.scaleDown: () => _viewAction('out', visibleNodes),
          NavigationAction.scaleReset: () => _zoom(1),
        }),
        const _CanvasActivator(LogicalKeyboardKey.delete): () {
          _deleteSelection();
        },
        const _CanvasActivator(LogicalKeyboardKey.keyA, control: true): () =>
            setState(() {
              _selection.addAll(_visibleNodes.map((node) => node.id));
              _publishSelectionAfterFrame();
            }),
        const _CanvasActivator(LogicalKeyboardKey.keyF): () =>
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
                event.logicalKey == LogicalKeyboardKey.space) {
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
                                                  AppIcons.workflow,
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
                                                      AppIcons.workflow,
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
                                                      AppIcons.caretDown,
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
                                                in LogicBlockType.values.where(
                                                  (type) =>
                                                      type !=
                                                      LogicBlockType.junction,
                                                ))
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
                                          value: 'copy',
                                          label: context.l10n.workspaceCopy,
                                          shortcut: 'Ctrl+C',
                                          enabled: _selection.isNotEmpty,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'cut',
                                          label: context.l10n.workspaceCut,
                                          shortcut: 'Ctrl+X',
                                          enabled: _selection.isNotEmpty,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'paste',
                                          label: context.l10n.workspacePaste,
                                          shortcut: 'Ctrl+V',
                                        ),
                                        DesktopMenuEntry(
                                          value: 'hide',
                                          label: context.l10n.textHide231,
                                          enabled: _selection.isNotEmpty,
                                        ),
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
                                        if (action == 'copy') _copySelection();
                                        if (action == 'cut') {
                                          _copySelection(cut: true);
                                        }
                                        if (action == 'paste') {
                                          _pasteSelection();
                                        }
                                        if (action == 'hide') {
                                          _controller.setNodesHidden({
                                            ..._selection,
                                          }, true);
                                          _clearSelection();
                                        }
                                        if (action == 'all') {
                                          setState(() {
                                            _selection.addAll(
                                              _visibleNodes.map(
                                                (node) => node.id,
                                              ),
                                            );
                                            _publishSelectionAfterFrame();
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
                                          value: 'canvasFullscreen',
                                          label: widget.canvasFullscreen
                                              ? context
                                                    .l10n
                                                    .canvasExitFullscreen
                                              : context.l10n.canvasFullscreen,
                                          shortcut: NavigationBindings.instance
                                              .label(
                                                NavigationAction.fullscreen,
                                              ),
                                          enabled:
                                              widget.onToggleCanvasFullscreen !=
                                              null,
                                        ),
                                        DesktopMenuEntry(
                                          value: 'canvasScreenshot',
                                          label: context.l10n.canvasScreenshot,
                                          shortcut: 'Ctrl+F12',
                                        ),
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
                                        DesktopMenuEntry(
                                          value: 'canvasHints',
                                          label:
                                              context.l10n.workspaceCanvasHints,
                                          shortcut: _canvasHintsVisible
                                              ? '✓'
                                              : null,
                                        ),
                                      ],
                                      onSelected: (action) {
                                        if (action == 'canvasHints') {
                                          setState(
                                            () => _canvasHintsVisible =
                                                !_canvasHintsVisible,
                                          );
                                          return;
                                        }
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
                            DesktopIconButton(
                              key: const ValueKey('workspace toggle snap'),
                              icon: AppIcons.magnet,
                              tooltip: context.hostLabel('Magnetic alignment'),
                              size: 42,
                              iconSize: 21,
                              active: _snapToGrid,
                              onPressed: () =>
                                  setState(() => _snapToGrid = !_snapToGrid),
                            ),
                            const SizedBox(width: 6),
                            DesktopIconButton(
                              key: const ValueKey(
                                'workspace toggle canvas tools',
                              ),
                              icon: _toolRailVisible
                                  ? AppIcons.caretsLeft
                                  : AppIcons.caretsRight,
                              active: _toolRailVisible,
                              tooltip: _toolRailVisible
                                  ? context.hostLabel('Hide canvas tools')
                                  : context.hostLabel('Show canvas tools'),
                              size: 42,
                              iconSize: 21,
                              onPressed: () => setState(
                                () => _toolRailVisible = !_toolRailVisible,
                              ),
                            ),
                            const SizedBox(width: 6),
                            DesktopIconButton(
                              key: const ValueKey('workspace toggle inspector'),
                              icon: AppIcons.sidebar,
                              active: widget.canvasController != null
                                  ? widget.explorerVisible
                                  : inspector,
                              tooltip:
                                  (widget.canvasController != null
                                      ? widget.explorerVisible
                                      : inspector)
                                  ? context.l10n.workspaceHideSidebar
                                  : context.l10n.workspaceShowSidebar,
                              size: 42,
                              iconSize: 22,
                              onPressed: () => _setInspector(
                                !(widget.canvasController != null
                                    ? widget.explorerVisible
                                    : inspector),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: ClipRect(
                          child: ColoredBox(
                            color: context.palette.background,
                            child: DragTarget<Object>(
                              key: const ValueKey(
                                'workspace canvas drop target',
                              ),
                              onWillAcceptWithDetails: (details) =>
                                  details.data is SystemModule ||
                                  details.data is LogicBlockType,
                              onAcceptWithDetails: (details) {
                                final position = _sceneAt(details.offset);
                                final data = details.data;
                                _select(
                                  data is LogicBlockType
                                      ? _controller.addLogicBlock(
                                          data,
                                          position,
                                        )
                                      : _addAt(data as SystemModule, position),
                                );
                              },
                              builder: (context, candidates, rejected) => Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerSignal: _pointerSignal,
                                onPointerPanZoomStart: _trackpadStart,
                                onPointerPanZoomUpdate: _trackpadUpdate,
                                onPointerPanZoomEnd: (_) {
                                  _trackpadFocal = null;
                                  _trackpadScene = null;
                                },
                                onPointerDown: (event) {
                                  if (event.buttons == kSecondaryMouseButton &&
                                      _nodeAt(
                                            event.position,
                                            includePartiallyHidden: true,
                                          ) ==
                                          null) {
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
                                  } else if (_activeNodeId != null) {
                                    if (_activeNodeResize) {
                                      _resizeActiveNode(
                                        DragUpdateDetails(
                                          globalPosition: event.position,
                                          delta: event.delta,
                                        ),
                                      );
                                    } else {
                                      _moveActiveNode(
                                        DragUpdateDetails(
                                          globalPosition: event.position,
                                          delta: event.delta,
                                        ),
                                      );
                                    }
                                  }
                                },
                                onPointerUp: (event) {
                                  _endPan(event.pointer);
                                  if (_activeNodeId != null) {
                                    _setNodeInteraction(false);
                                  }
                                },
                                onPointerCancel: (event) {
                                  _endPan(event.pointer);
                                  if (_activeNodeId != null) {
                                    _setNodeInteraction(false);
                                  }
                                },
                                child: MouseRegion(
                                  onEnter: (_) {
                                    if (!_menuOpen && _openedId == null) {
                                      _focus.requestFocus();
                                    }
                                  },
                                  onExit: (_) {
                                    if (_drawingCursor != null) {
                                      setState(() => _drawingCursor = null);
                                    }
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
                                      : _canvasTool == _CanvasTool.pencil ||
                                            _canvasTool == _CanvasTool.eraser
                                      ? SystemMouseCursors.precise
                                      : MouseCursor.defer,
                                  onHover: (event) {
                                    if (_canvasTool == _CanvasTool.pencil ||
                                        _canvasTool == _CanvasTool.eraser) {
                                      setState(
                                        () => _drawingCursor = _sceneAt(
                                          event.position,
                                        ),
                                      );
                                    }
                                    if (_pendingPort != null) {
                                      setState(
                                        () =>
                                            _wireEnd = _sceneAt(event.position),
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
                                                    (
                                                      context,
                                                      fadeScale,
                                                      _,
                                                    ) => CustomPaint(
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
                                            width: _canvasWidth,
                                            height: _canvasHeight,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Positioned.fill(
                                                  child: Listener(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onPointerDown:
                                                        _startMarquee,
                                                    onPointerMove: (event) {
                                                      if (_isCanvasDrawingTool) {
                                                        _updateCanvasTool(
                                                          event,
                                                        );
                                                      } else {
                                                        _updateMarquee(event);
                                                      }
                                                    },
                                                    onPointerUp: (event) {
                                                      if (_isCanvasDrawingTool) {
                                                        _finishCanvasTool(
                                                          event,
                                                        );
                                                      } else if (event
                                                              .pointer ==
                                                          _marqueePointer) {
                                                        _endMarquee();
                                                      }
                                                    },
                                                    onPointerCancel: (event) {
                                                      if (_isCanvasDrawingTool) {
                                                        _finishCanvasTool(
                                                          event,
                                                          cancel: true,
                                                        );
                                                      } else if (event
                                                              .pointer ==
                                                          _marqueePointer) {
                                                        _endMarquee(
                                                          cancel: true,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: CustomPaint(
                                                      painter: WorkspaceAnnotationLayerPainter(
                                                        annotations:
                                                            _eraserPreview ??
                                                            ref.watch(
                                                              annotationProvider,
                                                            ),
                                                        activePoints:
                                                            _canvasTool ==
                                                                _CanvasTool
                                                                    .eraser
                                                            ? const []
                                                            : _annotationPoints,
                                                        activeColor:
                                                            _brushColor ??
                                                            context
                                                                .palette
                                                                .text,
                                                        activeWidth:
                                                            _canvasTool ==
                                                                _CanvasTool
                                                                    .pencil
                                                            ? _brushDiameter
                                                            : 3,
                                                        cursor: _drawingCursor,
                                                        cursorDiameter:
                                                            _canvasTool ==
                                                                _CanvasTool
                                                                    .eraser
                                                            ? _eraserDiameter
                                                            : _brushDiameter,
                                                        cursorColor: context
                                                            .palette
                                                            .text,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: CustomPaint(
                                                      painter: WorkspaceConnectionsPainter(
                                                        nodes: renderNodes,
                                                        dimmedNodeIds:
                                                            graph.hiddenNodeIds,
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
                                                                if (!entry
                                                                    .value)
                                                                  entry.key,
                                                            }),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                WorkspaceNodeLayer(
                                                  nodes: renderNodes,
                                                  builder: (context, node) => _WorkspaceNodeView(
                                                    node: node,
                                                    hidden:
                                                        graph.hiddenNodeIds
                                                            .contains(
                                                              node.id,
                                                            ) ||
                                                        graph.hiddenModuleIds
                                                            .contains(
                                                              node.module.id,
                                                            ),
                                                    dimmed:
                                                        graph.hiddenNodeIds
                                                            .contains(
                                                              node.id,
                                                            ) ||
                                                        graph.hiddenModuleIds
                                                            .contains(
                                                              node.module.id,
                                                            ) ||
                                                        graph.moduleActiveOverrides[node
                                                                .module
                                                                .id] ==
                                                            false ||
                                                        node.fullyHidden,
                                                    ignorePointer:
                                                        _isCanvasDrawingTool ||
                                                        _panModifier ||
                                                        _panPointer != null,
                                                    selected: _selection
                                                        .contains(node.id),
                                                    junctionMovable:
                                                        _movableJunctionId ==
                                                        node.id,
                                                    onJunctionMove: (details) {
                                                      _select(node);
                                                      setState(() {
                                                        _movableJunctionId =
                                                            node.id;
                                                        _pendingPort = null;
                                                        _wireEnd = null;
                                                      });
                                                      _setNodeInteraction(true);
                                                      _startNodeDrag(
                                                        DragStartDetails(
                                                          globalPosition: details
                                                              .globalPosition,
                                                        ),
                                                        node.id,
                                                      );
                                                    },
                                                    onSelect: () =>
                                                        _select(node),
                                                    onInteraction:
                                                        _setNodeInteraction,
                                                    onDragStart: (details) =>
                                                        _startNodeDrag(
                                                          details,
                                                          node.id,
                                                        ),
                                                    onResizeStart: (details) =>
                                                        _startNodeDrag(
                                                          details,
                                                          node.id,
                                                          resize: true,
                                                        ),
                                                    onMove: (_) {},
                                                    onResize: (_) {},
                                                    onOpen: () => setState(
                                                      () => _openedId = node.id,
                                                    ),
                                                    onDetach: () =>
                                                        _detach(node),
                                                    onHiddenActivate: () =>
                                                        _select(node),
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
                                                      if (_canvasTool ==
                                                              _CanvasTool
                                                                  .branch &&
                                                          _pendingPort ==
                                                              null &&
                                                          port.output) {
                                                        setState(() {
                                                          _pendingPort = port;
                                                        });
                                                      } else if (_pendingPort !=
                                                          null) {
                                                        _connect(
                                                          _pendingPort!,
                                                          port,
                                                        );
                                                      } else {
                                                        setState(
                                                          () => _pendingPort =
                                                              port,
                                                        );
                                                      }
                                                    },
                                                    onConnect: _connect,
                                                    onPortMenu: _portMenu,
                                                    onDragPort:
                                                        (
                                                          port,
                                                          position,
                                                        ) => setState(() {
                                                          _pendingPort = port;
                                                          _wireGlobal =
                                                              position;
                                                          _wireEnd = _sceneAt(
                                                            position,
                                                          );
                                                        }),
                                                    onDragEnd: _finishPortDrag,
                                                  ),
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
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      AppIcons.workflow,
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
                                                      textAlign:
                                                          TextAlign.center,
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
                                            builder: (context, _) =>
                                                CustomPaint(
                                                  painter: _GridPainter(
                                                    transform: _transform.value
                                                        .clone(),
                                                    color: context
                                                        .palette
                                                        .mutedText,
                                                    background:
                                                        context.palette.panel,
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
                                              final wiresNearby = graph.links
                                                  .any((link) {
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
                                                    final to = target
                                                        .portPosition(
                                                          link.input,
                                                          false,
                                                        );
                                                    final direction =
                                                        to.dx >= from.dx
                                                        ? 1.0
                                                        : -1.0;
                                                    final bend = math.max(
                                                      60.0,
                                                      (to.dx - from.dx).abs() *
                                                          .45,
                                                    );
                                                    final wire = Path()
                                                      ..moveTo(from.dx, from.dy)
                                                      ..cubicTo(
                                                        from.dx +
                                                            direction * bend,
                                                        from.dy,
                                                        to.dx -
                                                            direction * bend,
                                                        to.dy,
                                                        to.dx,
                                                        to.dy,
                                                      );
                                                    return visible
                                                        .inflate(margin)
                                                        .overlaps(
                                                          wire
                                                              .getBounds()
                                                              .inflate(2),
                                                        );
                                                  });
                                              if (visibleNodes.isEmpty ||
                                                  nearby ||
                                                  wiresNearby) {
                                                return const SizedBox.shrink();
                                              }
                                              return Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 48,
                                                      ),
                                                  child: SizedBox(
                                                    width: 220,
                                                    child: DesktopIconButton(
                                                      key: const ValueKey(
                                                        'return to workspace',
                                                      ),
                                                      icon: AppIcons.fitCanvas,
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
                                      if (_toolRailVisible)
                                        Positioned(
                                          left: _canvasRulerExtent + 12,
                                          top: 84,
                                          child: _CanvasToolRail(
                                            key: const ValueKey(
                                              'workspace canvas tool rail',
                                            ),
                                            tool: _canvasTool,
                                            onSelected: _setCanvasTool,
                                            onClearAnnotations: () =>
                                                _controller.clearAnnotations(),
                                          ),
                                        ),
                                      if (_toolRailVisible &&
                                          (_canvasTool == _CanvasTool.pencil ||
                                              _canvasTool ==
                                                  _CanvasTool.eraser))
                                        Positioned(
                                          left: _canvasRulerExtent + 64,
                                          top: 84,
                                          child: _CanvasDrawingOptions(
                                            eraser:
                                                _canvasTool ==
                                                _CanvasTool.eraser,
                                            color:
                                                _brushColor ??
                                                context.palette.text,
                                            diameter:
                                                _canvasTool ==
                                                    _CanvasTool.eraser
                                                ? _eraserDiameter
                                                : _brushDiameter,
                                            onColor: (color) => setState(
                                              () => _brushColor = color,
                                            ),
                                            onDiameter: (value) => setState(() {
                                              if (_canvasTool ==
                                                  _CanvasTool.eraser) {
                                                _eraserDiameter = value;
                                              } else {
                                                _brushDiameter = value;
                                              }
                                            }),
                                          ),
                                        ),
                                      if (_canvasHintsVisible ||
                                          _pendingPort != null)
                                        Positioned(
                                          left: _canvasRulerExtent + 12,
                                          right: 160,
                                          bottom: 12,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Dismissible(
                                              key: ValueKey(
                                                'workspace canvas hint ${_pendingPort != null}',
                                              ),
                                              direction: _pendingPort == null
                                                  ? DismissDirection.horizontal
                                                  : DismissDirection.none,
                                              onDismissed: (_) => setState(
                                                () =>
                                                    _canvasHintsVisible = false,
                                              ),
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
                                        ),
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: AnimatedBuilder(
                                          animation: _transform,
                                          builder: (context, _) => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (widget.workspaceNotice !=
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color:
                                                          context.palette.panel,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 9,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            AppIcons
                                                                .checkCircle,
                                                            size: 16,
                                                            color: context
                                                                .palette
                                                                .mutedText,
                                                          ),
                                                          const SizedBox(
                                                            width: 7,
                                                          ),
                                                          Text(
                                                            widget
                                                                .workspaceNotice!,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: context.palette.panel,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    DesktopIconButton(
                                                      key: const ValueKey(
                                                        'workspace zoom out',
                                                      ),
                                                      icon: AppIcons.minus,
                                                      tooltip: context
                                                          .l10n
                                                          .workspaceZoomOut,
                                                      onPressed: () =>
                                                          _viewAction(
                                                            'out',
                                                            visibleNodes,
                                                          ),
                                                    ),
                                                    SizedBox(
                                                      width: 58,
                                                      child: Center(
                                                        child: Text(
                                                          '${(_transform.value.getMaxScaleOnAxis() * 100).round()}%',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    DesktopIconButton(
                                                      key: const ValueKey(
                                                        'workspace zoom in',
                                                      ),
                                                      icon: AppIcons.add,
                                                      tooltip: context
                                                          .l10n
                                                          .workspaceZoomIn,
                                                      onPressed: () =>
                                                          _viewAction(
                                                            'in',
                                                            visibleNodes,
                                                          ),
                                                    ),
                                                  ],
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
                  ],
                ),
              ),
              if (inspector)
                SizedBox(
                  width: 300,
                  child: WorkspaceInspector(
                    key: ValueKey(selected?.id),
                    node: selected,
                    hidden:
                        selected != null &&
                        (graph.hiddenNodeIds.contains(selected.id) ||
                            graph.hiddenModuleIds.contains(
                              selected.module.id,
                            ) ||
                            selected.fullyHidden),
                    onVisibilityChanged: selected == null
                        ? null
                        : (visible) {
                            if (selected.fullyHidden) {
                              _controller.setNodeFullyHidden(
                                selected.id,
                                !visible,
                              );
                            } else {
                              _controller.setNodeHidden(selected.id, !visible);
                            }
                          },
                    onPositionChanged: selected == null
                        ? null
                        : (position) =>
                              _controller.moveNode(selected.id, position),
                    onSizeChanged: selected == null
                        ? null
                        : (size) => _controller.resizeNode(selected.id, size),
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
                    onAddModule: () => _pick(),
                    onAddLogic: (type) => _select(
                      _controller.addLogicBlock(
                        type,
                        _center - const Offset(120, 80),
                      ),
                    ),
                    canvasWidth: graph.canvasWidth,
                    canvasHeight: graph.canvasHeight,
                    onCanvasSizeChanged: (width, height) =>
                        _controller.setCanvasSize(width: width, height: height),
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
          const Icon(AppIcons.caretDown, size: 16),
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
    required this.onResizeStart,
    required this.onInteraction,
    required this.onOpen,
    required this.onDetach,
    required this.onHiddenActivate,
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
    this.junctionMovable = false,
    required this.onJunctionMove,
  });
  final WorkspaceNode node;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<DragUpdateDetails> onMove;
  final ValueChanged<DragUpdateDetails> onResize;
  final ValueChanged<DragStartDetails> onDragStart;
  final ValueChanged<DragStartDetails> onResizeStart;
  final ValueChanged<bool> onInteraction;
  final VoidCallback onOpen;
  final VoidCallback onDetach;
  final VoidCallback onHiddenActivate;
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
  final bool junctionMovable;
  final ValueChanged<TapDownDetails> onJunctionMove;
  @override
  Widget build(BuildContext context) => node.isJunction
      ? _buildJunction(context)
      : Positioned(
          left: node.position.dx - _nodePortHitInset,
          top: node.position.dy,
          child: IgnorePointer(
            ignoring: ignorePointer || (hidden && node.isLogic),
            child: ExcludeFocus(
              excluding: hidden,
              child: Listener(
                onPointerDown: (event) {
                  if (!hidden && event.buttons == kPrimaryMouseButton) {
                    onSelect();
                    onInteraction(true);
                  }
                },
                onPointerUp: (_) => onInteraction(false),
                onPointerCancel: (_) => onInteraction(false),
                child: DesktopFocusableAction(
                  onActivate: hidden ? null : onOpen,
                  onFocus: hidden ? null : onSelect,
                  onContextMenu: () {
                    final box = context.findRenderObject() as RenderBox;
                    onMenu(box.localToGlobal(const Offset(24, 24)));
                  },
                  label: node.module.displayName(context),
                  child: Semantics(
                    key: ValueKey('workspace selection ${node.id}'),
                    selected: selected,
                    child: GestureDetector(
                      onTap: hidden ? null : onSelect,
                      onDoubleTap: hidden && !node.fullyHidden
                          ? onHiddenActivate
                          : null,
                      onSecondaryTapUp: (details) =>
                          onMenu(details.globalPosition),
                      child: RepaintBoundary(
                        child: Opacity(
                          opacity: hidden && !dimmed
                              ? 0
                              : dimmed || node.settings['enabled'] == false
                              ? .58
                              : 1,
                          child: SizedBox(
                            width: node.width + _nodePortHitInset * 2,
                            height: node.height,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: _nodePortHitInset,
                                  width: node.width,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    key: ValueKey('workspace node ${node.id}'),
                                    width: node.width,
                                    height: node.height,
                                    decoration: BoxDecoration(
                                      color: context.palette.panel,
                                      borderRadius: BorderRadius.circular(10),
                                      // Keep the one-pixel content inset used by port geometry.
                                      border: Border.all(
                                        color: selected
                                            ? context.palette.text.withAlpha(
                                                150,
                                              )
                                            : context.palette.hover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        if (!node.isJunction)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Listener(
                                                onPointerDown: (event) {
                                                  if (hidden) return;
                                                  if (event.buttons !=
                                                      kPrimaryMouseButton) {
                                                    return;
                                                  }
                                                  onSelect();
                                                  onDragStart(
                                                    DragStartDetails(
                                                      globalPosition:
                                                          event.position,
                                                    ),
                                                  );
                                                  onInteraction(true);
                                                },
                                                onPointerUp: (_) =>
                                                    onInteraction(false),
                                                onPointerCancel: (_) =>
                                                    onInteraction(false),
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.move,
                                                  child: Container(
                                                    key: ValueKey(
                                                      'workspace header ${node.id}',
                                                    ),
                                                    height: WorkspaceNode
                                                        .headerHeight,
                                                    decoration: BoxDecoration(
                                                      color: node.headerColor
                                                          .headerBackground(
                                                            context,
                                                          ),
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  9,
                                                                ),
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          node.isLogic
                                                              ? AppIcons
                                                                    .workflow
                                                              : AppIcons.puzzle,
                                                          size: 18,
                                                          color: context
                                                              .palette
                                                              .text,
                                                        ),
                                                        const SizedBox(
                                                          width: 9,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            node.isLogic
                                                                ? context.logicBlockLabel(
                                                                    node
                                                                        .logicType
                                                                        .name,
                                                                  )
                                                                : node.module
                                                                      .displayName(
                                                                        context,
                                                                      ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        Icon(
                                                          AppIcons.dragHandle,
                                                          size: 15,
                                                          color: context
                                                              .palette
                                                              .mutedText,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: WorkspaceNode
                                                    .portsTopPadding,
                                              ),
                                              SizedBox(
                                                height:
                                                    WorkspaceNode
                                                        .portRowHeight *
                                                    math.max(
                                                      node.inputs.length,
                                                      node.outputs.length,
                                                    ),
                                              ),
                                              SizedBox(
                                                height: 34,
                                                child: Row(
                                                  children: [
                                                    TextButton(
                                                      onPressed:
                                                          node.isLogic || hidden
                                                          ? null
                                                          : () => onAddPort(
                                                              false,
                                                            ),
                                                      style: TextButton.styleFrom(
                                                        minimumSize: const Size(
                                                          72,
                                                          28,
                                                        ),
                                                        backgroundColor: context
                                                            .palette
                                                            .hover,
                                                        foregroundColor: context
                                                            .palette
                                                            .text,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                            ),
                                                        textStyle:
                                                            const TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        context
                                                            .l10n
                                                            .textInput307,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    TextButton(
                                                      onPressed:
                                                          node.isLogic || hidden
                                                          ? null
                                                          : () =>
                                                                onAddPort(true),
                                                      style: TextButton.styleFrom(
                                                        minimumSize: const Size(
                                                          72,
                                                          28,
                                                        ),
                                                        backgroundColor: context
                                                            .palette
                                                            .hover,
                                                        foregroundColor: context
                                                            .palette
                                                            .text,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                            ),
                                                        textStyle:
                                                            const TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        context
                                                            .l10n
                                                            .textOutput308,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
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
                                                          onPressed: hidden
                                                              ? null
                                                              : onOpen,
                                                          style: OutlinedButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                ),
                                                          ),
                                                          icon: const Icon(
                                                            AppIcons
                                                                .externalLink,
                                                            size: 13,
                                                          ),
                                                          label: Text(
                                                            context
                                                                .l10n
                                                                .textOpen309,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      DesktopIconButton(
                                                        key: ValueKey(
                                                          'workspace detach ${node.id}',
                                                        ),
                                                        icon: AppIcons
                                                            .externalLink,
                                                        tooltip: context
                                                            .l10n
                                                            .moduleOpenWindow,
                                                        onPressed: hidden
                                                            ? null
                                                            : onDetach,
                                                        size: 34,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (!node.isJunction)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: DesktopTooltip(
                                              message: context
                                                  .l10n
                                                  .workspaceResizeNode,
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors
                                                    .resizeUpLeftDownRight,
                                                child: Listener(
                                                  key: ValueKey(
                                                    'workspace resize ${node.id}',
                                                  ),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onPointerDown: (event) {
                                                    if (!hidden &&
                                                        event.buttons ==
                                                            kPrimaryMouseButton) {
                                                      onSelect();
                                                      onResizeStart(
                                                        DragStartDetails(
                                                          globalPosition:
                                                              event.position,
                                                        ),
                                                      );
                                                      onInteraction(true);
                                                    }
                                                  },
                                                  onPointerUp: (_) =>
                                                      onInteraction(false),
                                                  onPointerCancel: (_) =>
                                                      onInteraction(false),
                                                  child: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Icon(
                                                      AppIcons.arrowDownRight,
                                                      size: 14,
                                                      color: context
                                                          .palette
                                                          .mutedText,
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
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top:
                                      1 +
                                      WorkspaceNode.headerHeight +
                                      WorkspaceNode.portsTopPadding,
                                  child: IgnorePointer(
                                    ignoring: hidden,
                                    child: _buildPorts(),
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

  Widget _buildPorts() => Column(
    children: [
      for (
        var index = 0;
        index < math.max(node.inputs.length, node.outputs.length);
        index++
      )
        SizedBox(
          height: WorkspaceNode.portRowHeight,
          child: Row(
            children: [
              for (final output in [false, true])
                Expanded(
                  child: index < (output ? node.outputs : node.inputs).length
                      ? _buildPort(
                          (output ? node.outputs : node.inputs)[index],
                          output,
                        )
                      : const SizedBox(),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _buildPort(String port, bool output) => _PortView(
    label: node.portLabel(port, output),
    type: node.portType(port, output),
    ref: _PortRef(node.id, port, output),
    onTap: onPort,
    onConnect: onConnect,
    onDrag: onDragPort,
    onDragEnd: onDragEnd,
    color: node.portColor(port, output),
    onMenu: onPortMenu,
  );

  Widget _buildJunction(BuildContext context) => Positioned(
    left: node.position.dx,
    top: node.position.dy,
    child: IgnorePointer(
      ignoring: ignorePointer || hidden,
      child: Semantics(
        key: ValueKey('workspace selection ${node.id}'),
        selected: selected,
        child: GestureDetector(
          onSecondaryTapUp: (details) => onMenu(details.globalPosition),
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons == kPrimaryMouseButton) {
                onSelect();
                if (junctionMovable) {
                  onInteraction(true);
                  onDragStart(DragStartDetails(globalPosition: event.position));
                }
              }
            },
            onPointerUp: (_) => onInteraction(false),
            onPointerCancel: (_) => onInteraction(false),
            child: SizedBox(
              key: ValueKey('workspace node ${node.id}'),
              width: node.width,
              height: node.height,
              child: Opacity(
                opacity: hidden
                    ? 0
                    : dimmed
                    ? .58
                    : 1,
                child: Stack(
                  children: [
                    if (junctionMovable)
                      Positioned.fill(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.move,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onSelect,
                            onSecondaryTapUp: (details) =>
                                onMenu(details.globalPosition),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          for (final output in [false, true])
                            Expanded(
                              child: _PortView(
                                compact: true,
                                showDot: false,
                                label: '',
                                type: node.portType(
                                  output ? 'output' : 'input',
                                  output,
                                ),
                                ref: _PortRef(
                                  node.id,
                                  output ? 'output' : 'input',
                                  output,
                                ),
                                onTap: onPort,
                                onConnect: onConnect,
                                onDrag: onDragPort,
                                onDragEnd: onDragEnd,
                                color: node.portColor(
                                  output ? 'output' : 'input',
                                  output,
                                ),
                                onMenu: onPortMenu,
                                onDoubleTapDown: onJunctionMove,
                              ),
                            ),
                        ],
                      ),
                    Center(
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: 1.4,
                          child: _PortDot(
                            key: ValueKey('workspace junction dot ${node.id}'),
                            selected: selected,
                            color:
                                node.headerColor.tint ??
                                node.portColor('output', true).tint ??
                                context.palette.mutedText,
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
  );
}

class _PortDot extends StatelessWidget {
  const _PortDot({super.key, required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? context.palette.text : context.palette.background,
        width: 1.5,
      ),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 3)],
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
    this.compact = false,
    this.showDot = true,
    this.onDoubleTapDown,
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
  final bool compact;
  final bool showDot;
  final ValueChanged<TapDownDetails>? onDoubleTapDown;
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
          onDoubleTapDown: onDoubleTapDown,
          onDoubleTap: onDoubleTapDown == null ? null : () {},
          onSecondaryTapUp: (details) => onMenu(ref, details.globalPosition),
          child: !showDot
              ? const SizedBox.expand()
              : SizedBox(
                  height: compact ? 28 : WorkspaceNode.portRowHeight,
                  width: compact ? 10 : double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.start
                        : ref.output
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (ref.output && !compact)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 1),
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
                      SizedBox(
                        // Include both halves of the dot in the layout and hit
                        // bounds, rather than translating paint out of a card.
                        width: compact ? 10 : _nodePortHitInset * 2,
                        child: Center(
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: Transform.scale(
                              scale: 1.4,
                              child: _PortDot(
                                color: candidates.isNotEmpty
                                    ? context.palette.text
                                    : color.tint ?? context.palette.mutedText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!ref.output && !compact)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 1),
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
    const ruler = _canvasRulerExtent;
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

class _CanvasDrawingOptions extends StatelessWidget {
  const _CanvasDrawingOptions({
    required this.eraser,
    required this.color,
    required this.diameter,
    required this.onColor,
    required this.onDiameter,
  });

  final bool eraser;
  final Color color;
  final double diameter;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onDiameter;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('workspace drawing options'),
    width: 230,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.palette.panel.withAlpha(235),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.palette.hover),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(30),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eraser ? context.l10n.canvasEraser : context.l10n.canvasBrush),
        if (!eraser) ...[
          const SizedBox(height: 8),
          DesktopMenuButton<int>(
            key: const ValueKey('workspace brush color'),
            tooltip: context.l10n.canvasBrushColor,
            entries: [
              DesktopMenuEntry(
                value: 0xFFFFFFFF,
                label: context.l10n.canvasColorWhite,
                markerColor: Colors.white,
              ),
              DesktopMenuEntry(
                value: 0xFF202020,
                label: context.l10n.canvasColorBlack,
                markerColor: const Color(0xFF202020),
              ),
              for (final value in WorkspaceNodeColor.values.where(
                (value) => value.tint != null,
              ))
                DesktopMenuEntry(
                  value: value.tint!.toARGB32(),
                  label: value.label(context),
                  markerColor: value.tint,
                ),
            ],
            onSelected: (value) => onColor(Color(value)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(AppIcons.palette, size: 19, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.l10n.canvasBrushColor)),
                  const Icon(AppIcons.caretDown, size: 16),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${context.l10n.canvasDiameter}: ${diameter.round()} px',
          style: TextStyle(fontSize: 12, color: context.palette.mutedText),
        ),
        Slider(
          key: ValueKey(
            eraser ? 'workspace eraser diameter' : 'workspace brush diameter',
          ),
          value: diameter,
          min: 1,
          max: eraser ? 128 : 32,
          divisions: eraser ? 127 : 31,
          label: '${diameter.round()} px',
          onChanged: onDiameter,
        ),
      ],
    ),
  );
}

class _CanvasToolRail extends StatelessWidget {
  const _CanvasToolRail({
    super.key,
    required this.tool,
    required this.onSelected,
    required this.onClearAnnotations,
  });

  final _CanvasTool tool;
  final ValueChanged<_CanvasTool> onSelected;
  final VoidCallback onClearAnnotations;

  @override
  Widget build(BuildContext context) {
    Widget button(_CanvasTool value, IconData icon, String label) =>
        DesktopIconButton(
          key: ValueKey('workspace canvas tool ${value.name}'),
          icon: icon,
          tooltip: label,
          active: tool == value,
          size: 36,
          iconSize: 19,
          onPressed: () => onSelected(value),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.panel.withAlpha(235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.palette.hover),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            _CanvasTool.select,
            AppIcons.cursor,
            context.hostLabel('Select'),
          ),
          const SizedBox(height: 4),
          button(
            _CanvasTool.pencil,
            AppIcons.pencil,
            context.hostLabel('Draw annotation'),
          ),
          const SizedBox(height: 4),
          button(
            _CanvasTool.eraser,
            AppIcons.eraser,
            context.l10n.canvasEraser,
          ),
          const SizedBox(height: 4),
          button(
            _CanvasTool.cut,
            AppIcons.scissors,
            context.hostLabel('Cut connection'),
          ),
          const SizedBox(height: 4),
          button(
            _CanvasTool.branch,
            AppIcons.branch,
            context.hostLabel('Branch route'),
          ),
          const SizedBox(height: 4),
          DesktopIconButton(
            key: const ValueKey('workspace clear annotations'),
            icon: AppIcons.trash,
            tooltip: context.hostLabel('Clear annotations'),
            size: 36,
            iconSize: 18,
            onPressed: onClearAnnotations,
          ),
        ],
      ),
    );
  }
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

class _WorkspaceCanvasSizeEditor extends StatefulWidget {
  const _WorkspaceCanvasSizeEditor({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  final double width, height;
  final void Function(double width, double height) onChanged;

  @override
  State<_WorkspaceCanvasSizeEditor> createState() =>
      _WorkspaceCanvasSizeEditorState();
}

class _WorkspaceCanvasSizeEditorState
    extends State<_WorkspaceCanvasSizeEditor> {
  late final TextEditingController _width = TextEditingController(
    text: widget.width.round().toString(),
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.height.round().toString(),
  );

  @override
  void didUpdateWidget(covariant _WorkspaceCanvasSizeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width &&
        double.tryParse(_width.text) != widget.width) {
      _width.text = widget.width.round().toString();
    }
    if (oldWidget.height != widget.height &&
        double.tryParse(_height.text) != widget.height) {
      _height.text = widget.height.round().toString();
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _apply() {
    final width = double.tryParse(_width.text.trim());
    final height = double.tryParse(_height.text.trim());
    if (width == null || height == null) return;
    widget.onChanged(width, height);
  }

  @override
  Widget build(BuildContext context) => DesktopPane(
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.hostLabel('Canvas size'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.hostLabel(
              'Stored per workspace; empty space adds almost no file size.',
            ),
            style: TextStyle(fontSize: 11, color: context.palette.mutedText),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('workspace canvas width'),
                  controller: _width,
                  decoration: const InputDecoration(labelText: 'Width'),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('workspace canvas height'),
                  controller: _height,
                  decoration: const InputDecoration(labelText: 'Height'),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DesktopIconButton(
            icon: AppIcons.check,
            label: context.hostLabel('Apply'),
            tooltip: context.hostLabel('Apply canvas size'),
            onPressed: _apply,
            size: 34,
          ),
          const SizedBox(height: 4),
          Text(
            context.hostLabel('Limits: 2,000–100,000 px'),
            style: TextStyle(fontSize: 11, color: context.palette.mutedText),
          ),
        ],
      ),
    ),
  );
}

/// Shared instance controls, embedded in the scene pane in the desktop shell.
class WorkspaceInspector extends StatefulWidget {
  const WorkspaceInspector({
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
    required this.onAddModule,
    required this.onAddLogic,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onCanvasSizeChanged,
    this.embedded = false,
    this.hidden = false,
    this.onVisibilityChanged,
    this.onPositionChanged,
    this.onSizeChanged,
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
  final VoidCallback onAddModule;
  final ValueChanged<LogicBlockType> onAddLogic;
  final double canvasWidth, canvasHeight;
  final void Function(double width, double height) onCanvasSizeChanged;
  final bool embedded;
  final bool hidden;
  final ValueChanged<bool>? onVisibilityChanged;
  final ValueChanged<Offset>? onPositionChanged;
  final ValueChanged<Size>? onSizeChanged;

  @override
  State<WorkspaceInspector> createState() => _WorkspaceInspectorState();
}

class _WorkspaceInspectorState extends State<WorkspaceInspector> {
  final Set<String> _collapsed = {'geometry'};
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
          if (!widget.embedded)
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
                        icon: AppIcons.close,
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
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                    child: DesktopMenuButton<String>(
                      key: const ValueKey('workspace inspector add'),
                      tooltip: context.hostLabel('Add to canvas'),
                      width: 250,
                      itemHeight: 38,
                      entries: [
                        DesktopMenuEntry(
                          value: 'module',
                          label: context.l10n.textAddModule158,
                        ),
                        DesktopMenuEntry(
                          value: 'logic',
                          label: context.l10n.logicAdd,
                          submenu: [
                            for (final type in LogicBlockType.values.where(
                              (type) => type != LogicBlockType.junction,
                            ))
                              DesktopMenuEntry(
                                value: type.name,
                                label: context.logicBlockLabel(type.name),
                              ),
                          ],
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'module') {
                          widget.onAddModule();
                        } else {
                          final type = LogicBlockType.values
                              .where((item) => item.name == value)
                              .firstOrNull;
                          if (type != null) widget.onAddLogic(type);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(AppIcons.add, size: 17),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                context.hostLabel('Add to canvas'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!widget.embedded)
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
                  if (!widget.embedded && widget.activeNodes.isEmpty)
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
                  else if (!widget.embedded)
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
                                  AppIcons.puzzle,
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
                                  icon: AppIcons.externalLink,
                                  label: context.l10n.textOpen309,
                                  tooltip: context.l10n.textOpen309,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 6),
                              DesktopIconButton(
                                icon: AppIcons.externalLink,
                                tooltip: context.l10n.moduleOpenWindow,
                                onPressed: widget.onDetach,
                                size: 30,
                              ),
                              const SizedBox(width: 6),
                              DesktopIconButton(
                                icon: AppIcons.expand,
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
                    if (widget.onVisibilityChanged != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(context.l10n.workspaceObjectVisible),
                            ),
                            DesktopToggle(
                              key: const ValueKey(
                                'workspace object visibility',
                              ),
                              value: !widget.hidden,
                              onChanged: widget.onVisibilityChanged!,
                            ),
                          ],
                        ),
                      ),
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
                  if (widget.onPositionChanged != null ||
                      widget.onSizeChanged != null)
                    _section('geometry', context.l10n.workspaceObjectGeometry, [
                      ModuleControls(
                        schema: [
                          {'id': 'x', 'label': 'X', 'type': 'number'},
                          {'id': 'y', 'label': 'Y', 'type': 'number'},
                          if (!node!.isJunction) ...[
                            {
                              'id': 'width',
                              'label': context.hostLabel('Width'),
                              'type': 'number',
                            },
                            {
                              'id': 'height',
                              'label': context.hostLabel('Height'),
                              'type': 'number',
                            },
                          ],
                        ],
                        values: {
                          'x': node!.position.dx,
                          'y': node!.position.dy,
                          'width': node!.width,
                          'height': node!.height,
                        },
                        onChanged: (key, value) {
                          if (value is! num || !value.isFinite) return;
                          final number = value.toDouble();
                          if (key == 'x' || key == 'y') {
                            widget.onPositionChanged?.call(
                              Offset(
                                key == 'x' ? number : node!.position.dx,
                                key == 'y' ? number : node!.position.dy,
                              ),
                            );
                          } else {
                            widget.onSizeChanged?.call(
                              Size(
                                key == 'width' ? number : node!.width,
                                key == 'height' ? number : node!.height,
                              ),
                            );
                          }
                        },
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
                            icon: AppIcons.linkOff,
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
                _WorkspaceCanvasSizeEditor(
                  width: widget.canvasWidth,
                  height: widget.canvasHeight,
                  onChanged: widget.onCanvasSizeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
