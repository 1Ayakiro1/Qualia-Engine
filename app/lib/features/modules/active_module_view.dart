import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_model.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';
import '../common/widgets.dart';
import 'module_ui.dart';
import 'module_custom_ui.dart';
import 'logic_block_editor.dart';
import '../common/navigation_bindings.dart';

/// Same declarative module surface in the workspace, fullscreen and child window.
class ActiveModuleView extends StatelessWidget {
  const ActiveModuleView({
    super.key,
    required this.node,
    required this.onBack,
    required this.onChanged,
    required this.onFullscreen,
    this.onDetach,
    this.fullscreen = false,
  });
  final WorkspaceNode node;
  final VoidCallback onBack;
  final void Function(String key, dynamic value) onChanged;
  final VoidCallback onFullscreen;
  final VoidCallback? onDetach;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          NavigationBindings.instance.matches(
            NavigationAction.dismiss,
            event,
          )) {
        onBack();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          NavigationBindings.instance.matches(
            NavigationAction.fullscreen,
            event,
          )) {
        onFullscreen();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ColoredBox(
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
                    autofocus: true,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(context.l10n.textBack233),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      node.isLogic
                          ? context.logicBlockLabel(node.logicType.name)
                          : node.module.displayName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onDetach != null)
                    DesktopIconButton(
                      key: const ValueKey('active module detach'),
                      icon: Icons.open_in_new,
                      tooltip: context.l10n.moduleOpenWindow,
                      onPressed: onDetach,
                    ),
                  DesktopIconButton(
                    key: const ValueKey('active module fullscreen'),
                    icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    tooltip: fullscreen
                        ? context.l10n.moduleExitFullscreen
                        : context.l10n.moduleFullscreen,
                    onPressed: onFullscreen,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    node.isLogic
                        ? context.logicBlockLabel(node.logicType.name)
                        : node.module.displayName(context),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    node.module.displayDescription(context),
                    style: TextStyle(
                      color: context.palette.mutedText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DesktopPane(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: node.isLogic
                          ? LogicBlockEditor(
                              key: ValueKey(node.id),
                              node: node,
                              onChanged: onChanged,
                            )
                          : node.module.manifest['uiLayout'] is Map
                          ? ModuleCustomUi(
                              schema: Map<String, dynamic>.from(
                                node.module.manifest['uiLayout'] as Map,
                              ),
                              values: {...node.settings, ...node.runtimeValues},
                              history: node.runtimeHistory,
                              onChanged: onChanged,
                            )
                          : node.module.manifest['ui'] is List
                          ? ModuleControls(
                              localizePreview: node.module.isLocalPreview,
                              schema: node.module.manifest['ui'] as List,
                              values: {...node.settings, ...node.runtimeValues},
                              onChanged: onChanged,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.textModuleInterface319,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context
                                      .l10n
                                      .textThisModuleHasNotDeclaredAnActive320,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.l10n.textModuleIDArg0321(
                                    node.module.id,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    node.isLogic
                        ? '${node.runtimeStatus ?? "idle"} · host-logic-v1'
                        : node.module.isLocal
                        ? '${node.runtimeStatus ?? "stopped"} · ${node.module.manifest['runtime']}'
                        : context
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
      ),
    ),
  );
}

/// Native fullscreen is scoped to this route and restores the previous state.
/// The route is on the root navigator, outside the scaled shell and sidebars.
Future<void> showModuleFullscreen(
  BuildContext context,
  WidgetBuilder builder,
) async {
  bool wasFullscreen = false;
  bool nativeAvailable = false;
  try {
    wasFullscreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(true);
    nativeAvailable = true;
  } catch (_) {}
  if (!context.mounted) {
    if (nativeAvailable && !wasFullscreen) {
      await windowManager.setFullScreen(false);
    }
    return;
  }
  try {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(fullscreenDialog: true, builder: builder));
  } finally {
    if (nativeAvailable && !wasFullscreen) {
      try {
        await windowManager.setFullScreen(false);
      } catch (_) {}
    }
  }
}
