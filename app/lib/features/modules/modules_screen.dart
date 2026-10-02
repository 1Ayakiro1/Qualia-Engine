import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';

import 'dart:math' as math;

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
    this.onMarketplace,
  });
  final List<SystemModule> modules;
  final VoidCallback onAdd;
  final ValueChanged<SystemModule> onEdit;
  final ValueChanged<SystemModule> onRemove;
  final SystemModule? selectedModule;
  final bool inspectorOpen;
  final VoidCallback? onToggleInspector;
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
  String? _openedId;
  bool _inspector = false;
  _PortRef? _pendingPort;
  Offset? _wireEnd;
  Offset? _middlePosition;
  Offset? _nodeDragPosition;
  bool _nodeInteracting = false;
  int _interactionGeneration = 0;

  void _setNodeInteraction(bool active) {
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
  void _select(WorkspaceNode node) {
    setState(() {
      if (!HardwareKeyboard.instance.isShiftPressed &&
          !_selection.contains(node.id)) {
        _selection.clear();
      }
      _selection.add(node.id);
      _selectedId = node.id;
      _inspector = true;
    });
    _focus.requestFocus();
  }

  void _clearSelection() => setState(() {
    _selection.clear();
    _selectedId = null;
  });

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
        setState(() => _inspector = !_inspector);
    }
  }

  Future<void> _pick({Offset? position, WorkspaceNode? replace}) async {
    final module = await showDialog<SystemModule>(
      context: context,
      builder: (context) => _ModulePicker(
        modules: widget.modules,
        replacing: replace != null,
        onMarketplace: widget.onMarketplace,
      ),
    );
    if (module == null || !mounted) return;
    if (replace != null) {
      _controller.replaceNode(replace.id, module);
    } else {
      final node = _controller.addNode(
        module,
        position ?? _center - const Offset(120, 80),
      );
      _select(node);
    }
  }

  Future<void> _menu(Offset global, {WorkspaceNode? node}) async {
    final scene = _sceneAt(global);
    final action = await showDesktopMenu<String>(
      context: context,
      position: global,
      entries: [
        if (node == null)
          DesktopMenuEntry(value: 'add', label: context.l10n.textAdd294)
        else ...[
          DesktopMenuEntry(value: 'open', label: context.l10n.textOpen309),
          DesktopMenuEntry(
            value: 'replace',
            label: context.l10n.textReplaceModule295,
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
    if (action == 'add') _pick(position: scene);
    if (action == 'open' && node != null) setState(() => _openedId = node.id);
    if (action == 'replace') _pick(replace: node);
    if (action == 'delete' && node != null) {
      _controller.removeNode(node.id);
      setState(() {
        _selection.remove(node.id);
        _selectedId = null;
        _openedId = null;
        _pendingPort = null;
      });
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
  Widget build(BuildContext context) {
    final graph = ref.watch(workspaceProvider);
    final opened = graph.nodes
        .where((node) => node.id == _openedId)
        .firstOrNull;
    final selected = graph.nodes
        .where((node) => node.id == _selectedId)
        .firstOrNull;
    final inspector = (_inspector || widget.inspectorOpen) && opened == null;
    if (opened != null) {
      return _ActiveModuleArea(
        node: opened,
        onBack: () => setState(() => _openedId = null),
        onChanged: (key, value) =>
            _controller.setParameter(opened.id, key, value),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => setState(() {
          _pendingPort = null;
          _wireEnd = null;
        }),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          _deleteSelection();
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            setState(() {
              _selection.addAll(graph.nodes.map((node) => node.id));
            }),
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _viewAction('in', graph.nodes),
        const SingleActivator(
          LogicalKeyboardKey.equal,
          control: true,
          shift: true,
        ): () =>
            _viewAction('in', graph.nodes),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _viewAction('out', graph.nodes),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
            _zoom(1),
        const SingleActivator(LogicalKeyboardKey.keyF): () => _fit(graph.nodes),
      },
      child: Focus(
        focusNode: _focus,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 50,
                    color: context.palette.panel,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 18),
                        const SizedBox(width: 9),
                        Text(
                          context.l10n.workspace,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                                  tooltip:
                                      context.l10n.textAddModuleToCanvas299,
                                  entries: [
                                    DesktopMenuEntry(
                                      value: 'module',
                                      label: context.l10n.textAddModule158,
                                    ),
                                    DesktopMenuEntry(
                                      value: 'marketplace',
                                      label: context.hostLabel('Marketplace'),
                                      enabled: widget.onMarketplace != null,
                                    ),
                                  ],
                                  onSelected: (action) {
                                    if (action == 'module') {
                                      _pick();
                                    } else {
                                      widget.onMarketplace?.call();
                                    }
                                  },
                                  child: _toolbarLabel(context.l10n.textAdd294),
                                ),
                                const SizedBox(width: 6),
                                DesktopMenuButton<String>(
                                  key: const ValueKey('workspace select menu'),
                                  tooltip: context.l10n.workspaceSelectHint,
                                  entries: [
                                    DesktopMenuEntry(
                                      value: 'all',
                                      label: context.l10n.workspaceSelectAll,
                                      shortcut: 'Ctrl+A',
                                      enabled: graph.nodes.isNotEmpty,
                                    ),
                                    DesktopMenuEntry(
                                      value: 'none',
                                      label: context.l10n.workspaceDeselect,
                                      enabled: _selection.isNotEmpty,
                                    ),
                                    DesktopMenuEntry(
                                      value: 'delete',
                                      label:
                                          context.l10n.workspaceDeleteSelected,
                                      shortcut: 'Del',
                                      dividerBefore: true,
                                      enabled: _selection.isNotEmpty,
                                    ),
                                  ],
                                  onSelected: (action) {
                                    if (action == 'all') {
                                      setState(() {
                                        _selection.addAll(
                                          graph.nodes.map((node) => node.id),
                                        );
                                      });
                                    }
                                    if (action == 'none') _clearSelection();
                                    if (action == 'delete') _deleteSelection();
                                  },
                                  child: _toolbarLabel(
                                    context.l10n.workspaceSelect,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                DesktopMenuButton<String>(
                                  key: const ValueKey('workspace view menu'),
                                  width: 280,
                                  tooltip: context.l10n.textView62,
                                  entries: [
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
                                      label: context.l10n.workspaceActualSize,
                                      shortcut: 'Ctrl+0',
                                    ),
                                    DesktopMenuEntry(
                                      value: 'fit',
                                      label: context.l10n.textFrameAllF300,
                                      dividerBefore: true,
                                    ),
                                    DesktopMenuEntry(
                                      value: 'selected',
                                      label:
                                          context.l10n.workspaceFrameSelection,
                                      enabled: _selection.isNotEmpty,
                                    ),
                                    DesktopMenuEntry(
                                      value: 'inspector',
                                      label: context.l10n.textModuleSettings301,
                                      dividerBefore: true,
                                    ),
                                  ],
                                  onSelected: (action) =>
                                      _viewAction(action, graph.nodes),
                                  child: _toolbarLabel(context.l10n.textView62),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: ColoredBox(
                        color: context.palette.background,
                        child: DragTarget<SystemModule>(
                          onAcceptWithDetails: (details) => _select(
                            _controller.addNode(
                              details.data,
                              _sceneAt(details.offset),
                            ),
                          ),
                          builder: (context, candidates, rejected) => Listener(
                            onPointerDown: (event) {
                              if (event.buttons == kMiddleMouseButton) {
                                _middlePosition = event.position;
                              }
                            },
                            onPointerMove: (event) {
                              if (_middlePosition != null) {
                                final delta = event.position - _middlePosition!;
                                final matrix = _transform.value.clone();
                                matrix.setTranslationRaw(
                                  matrix.storage[12] + delta.dx,
                                  matrix.storage[13] + delta.dy,
                                  0,
                                );
                                _transform.value = matrix;
                                _middlePosition = event.position;
                              }
                            },
                            onPointerUp: (_) => _middlePosition = null,
                            child: MouseRegion(
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
                                        builder: (context, _) => CustomPaint(
                                          painter: _GridPainter(
                                            transform: _transform.value.clone(),
                                            color: context.palette.mutedText,
                                            background: context.palette.panel,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InteractiveViewer(
                                    key: _viewportKey,
                                    transformationController: _transform,
                                    constrained: false,
                                    boundaryMargin: const EdgeInsets.all(1000),
                                    minScale: .25,
                                    maxScale: 2,
                                    panEnabled: !_nodeInteracting,
                                    scaleEnabled: !_nodeInteracting,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _focus.requestFocus();
                                        setState(() {
                                          _selectedId = null;
                                          _selection.clear();
                                          _pendingPort = null;
                                          _wireEnd = null;
                                        });
                                      },
                                      onSecondaryTapDown: (details) =>
                                          _menu(details.globalPosition),
                                      child: SizedBox(
                                        width: _sceneSize,
                                        height: _sceneSize,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _GraphPainter(
                                                    nodes: graph.nodes,
                                                    links: graph.links,
                                                    pending: _pendingPort,
                                                    wireEnd: _wireEnd,
                                                    color: context
                                                        .palette
                                                        .mutedText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            for (final node in graph.nodes)
                                              _WorkspaceNodeView(
                                                node: node,
                                                selected: _selection.contains(
                                                  node.id,
                                                ),
                                                onSelect: () => _select(node),
                                                onInteraction: _setNodeInteraction,
                                                onDragStart: (details) =>
                                                    _nodeDragPosition =
                                                        details.globalPosition,
                                                onMove: (details) {
                                                  final delta =
                                                      _sceneAt(
                                                        details.globalPosition,
                                                      ) -
                                                      _sceneAt(
                                                        _nodeDragPosition ??
                                                            details
                                                                .globalPosition,
                                                      );
                                                  _nodeDragPosition =
                                                      details.globalPosition;
                                                  for (final item
                                                      in graph.nodes.where(
                                                        (item) => _selection
                                                            .contains(item.id),
                                                      )) {
                                                    _controller.moveNode(
                                                      item.id,
                                                      item.position + delta,
                                                    );
                                                  }
                                                },
                                                onResize: (details) {
                                                  final delta =
                                                      _sceneAt(
                                                        details.globalPosition,
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
                                                onMenu: (position) =>
                                                    _menu(position, node: node),
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
                                                      () => _pendingPort = port,
                                                    );
                                                  }
                                                },
                                                onConnect: _connect,
                                                onDragPort: (port, position) =>
                                                    setState(() {
                                                      _pendingPort = port;
                                                      _wireEnd = _sceneAt(
                                                        position,
                                                      );
                                                    }),
                                                onDragEnd: () => setState(() {
                                                  _pendingPort = null;
                                                  _wireEnd = null;
                                                }),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (graph.nodes.isEmpty)
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
                                                  color:
                                                      context.palette.mutedText,
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
                                            transform: _transform.value.clone(),
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
                                          final nearby = graph.nodes.any(
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
                                          final wiresNearby = graph.links.any((
                                            link,
                                          ) {
                                            final source = graph.nodes
                                                .where(
                                                  (node) =>
                                                      node.id == link.source,
                                                )
                                                .firstOrNull;
                                            final target = graph.nodes
                                                .where(
                                                  (node) =>
                                                      node.id == link.target,
                                                )
                                                .firstOrNull;
                                            if (source == null ||
                                                target == null) {
                                              return false;
                                            }
                                            final from = source.portPosition(
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
                                                  wire.getBounds().inflate(2),
                                                );
                                          });
                                          if (graph.nodes.isEmpty ||
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
                                                      _fit(graph.nodes),
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
                                              tooltip:
                                                  context.l10n.workspaceZoomOut,
                                              onPressed: () => _viewAction(
                                                'out',
                                                graph.nodes,
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
                                              tooltip:
                                                  context.l10n.workspaceZoomIn,
                                              onPressed: () => _viewAction(
                                                'in',
                                                graph.nodes,
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
                width: 260,
                child: _WorkspaceInspector(
                  key: ValueKey(selected?.id),
                  node: selected,
                  onClose: () => setState(() => _inspector = false),
                  onChanged: selected == null
                      ? null
                      : (key, value) =>
                            _controller.setParameter(selected.id, key, value),
                  links: graph.links,
                  onDisconnect: _controller.disconnect,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarLabel(String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        const Icon(Icons.expand_more, size: 16),
      ],
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
    required this.onMenu,
    required this.onAddPort,
    required this.onPort,
    required this.onConnect,
    required this.onDragPort,
    required this.onDragEnd,
  });
  final WorkspaceNode node;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<DragUpdateDetails> onMove;
  final ValueChanged<DragUpdateDetails> onResize;
  final ValueChanged<DragStartDetails> onDragStart;
  final ValueChanged<bool> onInteraction;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final ValueChanged<bool> onAddPort;
  final ValueChanged<_PortRef> onPort;
  final void Function(_PortRef a, _PortRef b) onConnect;
  final void Function(_PortRef port, Offset position) onDragPort;
  final VoidCallback onDragEnd;
  @override
  Widget build(BuildContext context) => Positioned(
    left: node.position.dx,
    top: node.position.dy,
    child: Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryMouseButton) onInteraction(true);
      },
      onPointerUp: (_) => onInteraction(false),
      onPointerCancel: (_) => onInteraction(false),
      child: GestureDetector(
        onTap: onSelect,
        onSecondaryTapDown: (details) => onMenu(details.globalPosition),
        child: Container(
          key: ValueKey('workspace node ${node.id}'),
          width: node.width,
          height: node.height,
          decoration: BoxDecoration(
            color: context.palette.panel,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(35),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: selected
                  ? context.palette.text.withAlpha(150)
                  : context.palette.hover,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Listener(
                    onPointerDown: (event) {
                      if (event.buttons != kPrimaryMouseButton) return;
                      onSelect();
                      onDragStart(
                        DragStartDetails(globalPosition: event.position),
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
                        height: WorkspaceNode.headerHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.extension_outlined,
                              size: 18,
                              color: context.palette.text,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                node.module.displayName(context),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                  Container(
                    height: WorkspaceNode.categoryHeight,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${node.module.displayCategory(context)} · ${node.module.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  for (
                    var index = 0;
                    index < math.max(node.inputs.length, node.outputs.length);
                    index++
                  )
                    SizedBox(
                      height: WorkspaceNode.portRowHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: index < node.inputs.length
                                ? _PortView(
                                    ref: _PortRef(
                                      node.id,
                                      node.inputs[index],
                                      false,
                                    ),
                                    onTap: onPort,
                                    onConnect: onConnect,
                                    onDrag: onDragPort,
                                    onDragEnd: onDragEnd,
                                  )
                                : const SizedBox(),
                          ),
                          Expanded(
                            child: index < node.outputs.length
                                ? _PortView(
                                    ref: _PortRef(
                                      node.id,
                                      node.outputs[index],
                                      true,
                                    ),
                                    onTap: onPort,
                                    onConnect: onConnect,
                                    onDrag: onDragPort,
                                    onDragEnd: onDragEnd,
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
                          onPressed: () => onAddPort(false),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          child: Text(context.l10n.textInput307),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onAddPort(true),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          child: Text(context.l10n.textOutput308),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 3, 28, 12),
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: onOpen,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: Text(
                          context.l10n.textOpen309,
                          style: TextStyle(fontSize: 14),
                        ),
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
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: Listener(
                      key: ValueKey('workspace resize ${node.id}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (event.buttons != kPrimaryMouseButton) return;
                        onSelect();
                        onDragStart(
                          DragStartDetails(globalPosition: event.position),
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
  );
}

class _PortView extends StatelessWidget {
  const _PortView({
    required this.ref,
    required this.onTap,
    required this.onConnect,
    required this.onDrag,
    required this.onDragEnd,
  });
  final _PortRef ref;
  final ValueChanged<_PortRef> onTap;
  final void Function(_PortRef a, _PortRef b) onConnect;
  final void Function(_PortRef port, Offset position) onDrag;
  final VoidCallback onDragEnd;
  @override
  Widget build(BuildContext context) => DragTarget<_PortRef>(
    onWillAcceptWithDetails: (details) => details.data.output != ref.output,
    onAcceptWithDetails: (details) => onConnect(details.data, ref),
    builder: (context, candidates, rejected) => Draggable<_PortRef>(
      data: ref,
      feedback: const SizedBox(width: 10, height: 10),
      onDragUpdate: (details) => onDrag(ref, details.globalPosition),
      onDragEnd: (_) => onDragEnd(),
      child: GestureDetector(
        onTap: () => onTap(ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
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
                      ref.port,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.mutedText,
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
                      : context.palette.mutedText,
                  shape: BoxShape.circle,
                ),
              ),
              if (!ref.output)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      ref.port,
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
  });
  final Matrix4 transform;
  final Color color;
  final Color background;
  final bool rulersOnly;
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
    // Keep density and dot radius readable at every zoom level.
    final step = scale < .5
        ? 96.0
        : scale < 1
        ? 48.0
        : 24.0;
    final dots = Paint()..color = color.withAlpha(85);
    if (!rulersOnly) {
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
          canvas.drawCircle(
            MatrixUtils.transformPoint(transform, Offset(x, y)),
            1,
            dots,
          );
        }
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
      oldDelegate.rulersOnly != rulersOnly;
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.nodes,
    required this.links,
    required this.pending,
    required this.wireEnd,
    required this.color,
  });
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final _PortRef? pending;
  final Offset? wireEnd;
  final Color color;
  void _wire(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = math.max(60.0, (to.dx - from.dx).abs() * .45);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx + dx, from.dy, to.dx - dx, to.dy, to.dx, to.dy),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final link in links) {
      final source = nodes.where((node) => node.id == link.source).firstOrNull;
      final target = nodes.where((node) => node.id == link.target).firstOrNull;
      if (source != null && target != null) {
        _wire(
          canvas,
          source.portPosition(link.output, true),
          target.portPosition(link.input, false),
          paint,
        );
      }
    }
    if (pending != null && wireEnd != null) {
      final node = nodes.where((node) => node.id == pending!.node).firstOrNull;
      if (node != null) {
        final port = node.portPosition(pending!.port, pending!.output);
        _wire(
          canvas,
          pending!.output ? port : wireEnd!,
          pending!.output ? wireEnd! : port,
          paint..color = color.withAlpha(130),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
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

class _WorkspaceInspector extends StatelessWidget {
  const _WorkspaceInspector({
    super.key,
    required this.node,
    required this.onClose,
    required this.onChanged,
    required this.links,
    required this.onDisconnect,
  });
  final WorkspaceNode? node;
  final VoidCallback onClose;
  final void Function(String key, dynamic value)? onChanged;
  final List<WorkspaceLink> links;
  final ValueChanged<WorkspaceLink> onDisconnect;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.panel,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.textMODULESETTINGS310,
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DesktopIconButton(
              icon: Icons.close,
              tooltip: context.l10n.textCloseModuleSettings311,
              onPressed: onClose,
              size: 24,
              iconSize: 14,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (node == null)
          Text(
            context.l10n.textSelectAModuleOnTheCanvas312,
            style: TextStyle(color: context.palette.mutedText, fontSize: 14),
          )
        else ...[
          Text(
            node!.module.displayName(context),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            node!.module.displayDescription(context),
            style: TextStyle(
              color: context.palette.mutedText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
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
            values: node!.settings,
            onChanged: onChanged!,
          ),
          if (node!.module.manifest['parameters'] is List)
            ModuleControls(
              localizePreview: node!.module.isLocalPreview,
              schema: node!.module.manifest['parameters'] as List,
              values: node!.settings,
              onChanged: onChanged!,
            )
          else
            Text(
              context.l10n.textNoAdditionalSettingsHaveBeenDeclaredBy313,
              style: TextStyle(
                color: context.palette.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          const Divider(height: 28),
          Text(
            context.l10n.textConnections314,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final link in links.where(
            (link) => link.source == node!.id || link.target == node!.id,
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
                  onPressed: () => onDisconnect(link),
                  size: 26,
                  iconSize: 15,
                ),
              ],
            ),
          if (!links.any(
            (link) => link.source == node!.id || link.target == node!.id,
          ))
            Text(
              context.l10n.textNoConnections316,
              style: TextStyle(color: context.palette.mutedText, fontSize: 14),
            ),
        ],
      ],
    ),
  );
}

class _ModulePicker extends StatefulWidget {
  const _ModulePicker({
    required this.modules,
    required this.replacing,
    this.onMarketplace,
  });
  final List<SystemModule> modules;
  final bool replacing;
  final VoidCallback? onMarketplace;
  @override
  State<_ModulePicker> createState() => _ModulePickerState();
}

class _ModulePickerState extends State<_ModulePicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final modules = widget.modules
        .where(
          (module) =>
              '${module.displayName(context)} ${module.displayCategory(context)}'
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Text(
        widget.replacing
            ? context.l10n.textReplaceModule295
            : context.l10n.textAddModule158,
      ),
      content: SizedBox(
        width: 420,
        height: 340,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('workspace module search'),
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: context.l10n.textSearchAvailableModules317,
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: modules.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.textNoAvailableModulesAddADraftOr318,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: modules.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.extension_outlined, size: 18),
                        title: Text(
                          modules[index].displayName(context),
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          modules[index].displayCategory(context),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(context, modules[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onMarketplace != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onMarketplace!();
            },
            child: Text(context.l10n.textMarketplace54),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.textCancel198),
        ),
      ],
    );
  }
}

class _ActiveModuleArea extends StatelessWidget {
  const _ActiveModuleArea({
    required this.node,
    required this.onBack,
    required this.onChanged,
  });
  final WorkspaceNode node;
  final VoidCallback onBack;
  final void Function(String key, dynamic value) onChanged;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: context.palette.panel,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(context.l10n.textBack233),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  node.module.displayName(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                node.module.displayName(context),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                node.module.displayDescription(context),
                style: TextStyle(color: context.palette.mutedText, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (node.module.manifest['ui'] is List)
                ModuleControls(
                  localizePreview: node.module.isLocalPreview,
                  schema: node.module.manifest['ui'] as List,
                  values: node.settings,
                  onChanged: onChanged,
                )
              else
                InfoCard(
                  title: context.l10n.textModuleInterface319,
                  children: [
                    Text(
                      context.l10n.textThisModuleHasNotDeclaredAnActive320,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.textModuleIDArg0321(
                        (node.module.id).toString(),
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                context
                    .l10n
                    .textGraphEditingIsAvailableExecutingExternalPackages322,
                style: TextStyle(
                  color: context.palette.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
