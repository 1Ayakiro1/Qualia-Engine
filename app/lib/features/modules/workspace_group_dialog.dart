import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/workspace/workspace_project.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';
import '../../state/workspace_state.dart';

/// Scene folders organize instances only; they never change execution or links.
class WorkspaceGroupDialog extends ConsumerStatefulWidget {
  const WorkspaceGroupDialog({super.key, this.group, this.initialNodeId});
  final WorkspaceSceneGroup? group;
  final String? initialNodeId;

  @override
  ConsumerState<WorkspaceGroupDialog> createState() =>
      _WorkspaceGroupDialogState();
}

class _WorkspaceGroupDialogState extends ConsumerState<WorkspaceGroupDialog> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _members = <String>{
    ...widget.group?.nodeIds ?? [],
    if (widget.initialNodeId != null) widget.initialNodeId!,
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(workspaceProvider);
    final valid = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(
        widget.group == null
            ? context.l10n.sceneCreateGroup
            : context.l10n.sceneEditGroup,
      ),
      content: SizedBox(
        width: 420,
        height: 340,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('scene group name'),
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.l10n.sceneGroupName,
              ),
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final node in graph.nodes)
                    CheckboxListTile(
                      key: ValueKey('scene group member ${node.id}'),
                      dense: true,
                      title: Text(node.module.displayName(context)),
                      subtitle: Text(
                        node.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _members.contains(node.id),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _members.add(node.id);
                        } else {
                          _members.remove(node.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.textCancel198),
        ),
        TextButton(
          key: const ValueKey('scene group save'),
          onPressed: !valid
              ? null
              : () {
                  final controller = ref.read(workspaceProvider.notifier);
                  final group = widget.group;
                  if (group == null) {
                    controller.createSceneGroup(_name.text, nodeIds: _members);
                  } else {
                    controller.beginHistoryGroup();
                    try {
                      controller.renameSceneGroup(group.id, _name.text);
                      controller.moveToSceneGroup(group.nodeIds.toSet(), null);
                      controller.moveToSceneGroup(_members, group.id);
                    } finally {
                      controller.endHistoryGroup();
                    }
                  }
                  Navigator.pop(context);
                },
          child: Text(context.l10n.textSave203),
        ),
      ],
    );
  }
}
