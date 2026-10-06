import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/workspace/workspace_project.dart';
import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_repository.dart';
import '../../l10n/app_strings.dart';
import '../../state/workspace_state.dart';
import '../common/desktop_menu.dart';
import '../common/widgets.dart';

Future<void> editWorkspace(
  BuildContext context,
  WidgetRef ref, {
  WorkspaceProject? project,
}) async {
  final value = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _WorkspaceEditor(project: project),
  );
  if (value == null || !context.mounted) return;
  final controller = ref.read(workspaceProvider.notifier);
  if (project == null) {
    controller.createProject(value.$1, description: value.$2);
  } else {
    controller.editProject(project.id, value.$1, value.$2);
  }
}

Future<void> showWorkspaceManager(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _WorkspaceManager(),
);

/// Moving instances never installs a package or creates cross-project wires.
Future<void> moveWorkspaceNodes(
  BuildContext context,
  WidgetRef ref,
  Set<String> ids,
  String projectId,
) async {
  final graph = ref.read(workspaceProvider);
  final crossing = graph.links.any(
    (link) => ids.contains(link.source) != ids.contains(link.target),
  );
  if (crossing) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.moduleMoveToWorkspace),
        content: SizedBox(
          width: 440,
          child: Text(context.l10n.moduleMoveConnectionsWarning),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.textCancel198),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.workspaceContinue),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(workspaceProvider).activeProjectId != graph.activeProjectId) {
      return;
    }
  }
  try {
    ref.read(workspaceProvider.notifier).moveNodesToProject(ids, projectId);
  } on FormatException catch (error) {
    if (context.mounted) {
      await _message(
        context,
        context.l10n.workspaceOperationFailed,
        error.message,
      );
    }
  }
}

Future<void> _message(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(child: Text(message)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.textClose110),
          ),
        ],
      ),
    );

Future<void> installWorkspace(
  BuildContext context,
  WidgetRef ref,
  WorkspaceProject project,
) async {
  final resolved = await resolveWorkspaceModules(
    project,
    ref.read(workspaceProvider).library,
  );
  if (!context.mounted) return;
  ref.read(workspaceProvider.notifier).importProject(project, resolved);
}

class _WorkspaceManager extends ConsumerStatefulWidget {
  const _WorkspaceManager();
  @override
  ConsumerState<_WorkspaceManager> createState() => _WorkspaceManagerState();
}

class _WorkspaceManagerState extends ConsumerState<_WorkspaceManager> {
  bool _busy = false;
  Future<void> _operation(Future<void> Function() run) async {
    setState(() => _busy = true);
    try {
      await run();
    } on WorkspaceDependencyException catch (error) {
      if (mounted) {
        await _message(
          context,
          context.l10n.workspaceDependenciesUnavailable,
          error.missing.join('\n'),
        );
      }
    } catch (error) {
      if (mounted) {
        await _message(
          context,
          context.l10n.workspaceOperationFailed,
          '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() => _operation(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Qualia Workspace',
          extensions: ['qualia-workspace', 'json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('Workspace package exceeds 2 MiB.');
    }
    final project = WorkspaceProject.fromPackage(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    if (!mounted) return;
    await installWorkspace(context, ref, project);
  });
  Future<void> _export(WorkspaceProject project) => _operation(() async {
    final confirmed = await _confirm(
      context.l10n.workspaceExport,
      context.l10n.workspaceShareWarning,
    );
    if (!confirmed || !mounted) return;
    final location = await getSaveLocation(
      suggestedName:
          '${project.name.replaceAll(RegExp(r'[^a-zA-Z0-9_а-яА-Я-]'), '_')}.qualia-workspace',
    );
    if (location == null) return;
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(project.toPackage()),
    );
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
    ).saveTo(location.path);
  });
  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 440, child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.textCancel198),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.workspaceContinue),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _submit(WorkspaceProject project) => _operation(() async {
    final license = await showDialog<String>(
      context: context,
      builder: (_) => const _PublishWorkspaceDialog(),
    );
    if (license == null || !mounted) return;
    await WorkspaceRepository().submit(project, license: license);
    if (mounted) {
      await _message(
        context,
        context.l10n.workspaceSubmit,
        context.l10n.workspaceSubmitted,
      );
    }
  });
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    return AlertDialog(
      title: Text(context.l10n.workspaceManager),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          children: [
            Row(
              children: [
                DesktopIconButton(
                  icon: Icons.add,
                  tooltip: context.l10n.workspaceCreate,
                  label: context.l10n.workspaceCreate,
                  onPressed: _busy ? null : () => editWorkspace(context, ref),
                  size: 34,
                ),
                const SizedBox(width: 8),
                DesktopIconButton(
                  icon: Icons.file_open_outlined,
                  tooltip: context.l10n.workspaceImport,
                  label: context.l10n.workspaceImport,
                  onPressed: _busy ? null : _import,
                  size: 34,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  for (final project in state.projects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DesktopPane(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (project.description.isNotEmpty)
                                      Text(
                                        project.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      context.l10n.workspaceGraphSummary(
                                        project.nodes.length,
                                        project.links.length,
                                      ),
                                      style: TextStyle(
                                        color: context.palette.mutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DesktopIconButton(
                                icon: state.activeProjectId == project.id
                                    ? Icons.check
                                    : Icons.folder_open,
                                tooltip: context.l10n.textOpen309,
                                onPressed: _busy
                                    ? null
                                    : () {
                                        ref
                                            .read(workspaceProvider.notifier)
                                            .switchProject(project.id);
                                        Navigator.pop(context);
                                      },
                                size: 34,
                              ),
                              DesktopMenuButton<String>(
                                tooltip: context.l10n.workspaceProjectActions,
                                entries: [
                                  DesktopMenuEntry(
                                    value: 'edit',
                                    label: context.l10n.workspaceEdit,
                                    enabled: !_busy,
                                  ),
                                  DesktopMenuEntry(
                                    value: 'export',
                                    label: context.l10n.workspaceExport,
                                    enabled: !_busy,
                                  ),
                                  DesktopMenuEntry(
                                    value: 'publish',
                                    label: context.l10n.workspaceSubmit,
                                    enabled: !_busy,
                                  ),
                                  DesktopMenuEntry(
                                    value: 'delete',
                                    label: context.l10n.workspaceDelete,
                                    dividerBefore: true,
                                    enabled: !_busy,
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await editWorkspace(
                                      context,
                                      ref,
                                      project: project,
                                    );
                                  } else if (action == 'export') {
                                    await _export(project);
                                  } else if (action == 'publish') {
                                    await _submit(project);
                                  } else if (action == 'delete' &&
                                      await _confirm(
                                        context.l10n.workspaceDelete,
                                        context.l10n.workspaceDeleteConfirm(
                                          project.name,
                                        ),
                                      )) {
                                    if (!mounted) return;
                                    ref
                                        .read(workspaceProvider.notifier)
                                        .deleteProject(project.id);
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.more_horiz, size: 18),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.textClose110),
        ),
      ],
    );
  }
}

class _WorkspaceEditor extends StatefulWidget {
  const _WorkspaceEditor({this.project});
  final WorkspaceProject? project;
  @override
  State<_WorkspaceEditor> createState() => _WorkspaceEditorState();
}

class _WorkspaceEditorState extends State<_WorkspaceEditor> {
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.project == null
          ? context.l10n.workspaceCreate
          : context.l10n.workspaceEdit,
    ),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: context.l10n.workspaceProjectName,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 4000,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.l10n.workspaceProjectDescription,
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
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                _name.text.trim(),
                _description.text.trim(),
              )),
        child: Text(context.l10n.workspacePortSave),
      ),
    ],
  );
}

class _PublishWorkspaceDialog extends StatefulWidget {
  const _PublishWorkspaceDialog();
  @override
  State<_PublishWorkspaceDialog> createState() =>
      _PublishWorkspaceDialogState();
}

class _PublishWorkspaceDialogState extends State<_PublishWorkspaceDialog> {
  String _license = 'CC-BY-4.0';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.workspaceSubmit),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.workspaceShareWarning),
          const SizedBox(height: 12),
          Text(context.l10n.workspaceReviewNotice),
          const SizedBox(height: 16),
          DesktopSelectField<String>(
            label: context.l10n.textLicense103,
            valueLabel: _license,
            entries: [
              for (final license in ['CC0-1.0', 'CC-BY-4.0', 'CC-BY-SA-4.0'])
                DesktopMenuEntry(value: license, label: license),
            ],
            onSelected: (value) => setState(() => _license = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.textCancel198),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _license),
        child: Text(context.l10n.workspaceSubmit),
      ),
    ],
  );
}
