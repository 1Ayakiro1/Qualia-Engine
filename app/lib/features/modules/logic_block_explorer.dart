import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic_blocks.dart';
import '../../core/theme/app_palette.dart';
import '../../l10n/app_strings.dart';
import '../../state/workspace_state.dart';
import '../common/widgets.dart';

class LogicBlockExplorer extends ConsumerStatefulWidget {
  const LogicBlockExplorer({super.key});
  @override
  ConsumerState<LogicBlockExplorer> createState() => _LogicBlockExplorerState();
}

class _LogicBlockExplorerState extends ConsumerState<LogicBlockExplorer> {
  bool _expanded = true;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    return ExplorerDisclosureSection(
      title: context.l10n.logicBlocks.toUpperCase(),
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: TextField(
            onChanged: (text) => setState(() => _query = text),
            decoration: InputDecoration(
              hintText: context.l10n.logicBlocks,
              prefixIcon: const Icon(Icons.search, size: 17),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
            ),
            icon: Icon(
              graph.showLogicBlocks
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
            ),
            onPressed: () =>
                controller.setBlockVisibility(logic: !graph.showLogicBlocks),
            label: Text(
              graph.showLogicBlocks
                  ? context.l10n.logicHide
                  : context.l10n.logicShow,
            ),
          ),
        ),
        for (final type in LogicBlockType.values)
          if (context
              .logicBlockLabel(type.name)
              .toLowerCase()
              .contains(_query.trim().toLowerCase()))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Draggable<LogicBlockType>(
                data: type,
                feedback: Material(
                  color: context.palette.panel,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(context.logicBlockLabel(type.name)),
                  ),
                ),
                child: DesktopHoverTile(
                  onTap: () =>
                      controller.addLogicBlock(type, const Offset(4820, 4820)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 16,
                          color: context.palette.mutedText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.logicBlockLabel(type.name),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
