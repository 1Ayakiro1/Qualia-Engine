import '../../core/theme/app_icons.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/workspace/workspace_archive.dart';
import '../../core/workspace/workspace_project.dart';
import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_repository.dart';
import '../../l10n/app_strings.dart';
import '../../state/workspace_state.dart';
import '../common/desktop_menu.dart';
import '../common/widgets.dart';

/// A deliberate checkpoint, independent from automatic crash recovery.
Future<bool> saveWorkspaceProgress(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(workspaceProvider.notifier);
  // Saving a draft/checkpoint must never create or rename a workspace. New
  // workspaces are named explicitly through File -> New workspace; Ctrl+S and
  // the close guard only persist the current document.
  try {
    await controller.saveProgress();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.workspaceSaveFailed)));
    }
    return false;
  }
}

Future<bool> confirmWorkspaceClose(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(workspaceProvider.notifier);
  if (!controller.hasUnsavedChanges) {
    try {
      await controller.flushRecovery();
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.workspaceSaveFailed)),
        );
      }
      return false;
    }
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.workspaceUnsavedTitle),
      content: SizedBox(
        width: 420,
        child: Text(context.l10n.workspaceUnsavedMessage),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.textCancel198),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: Text(context.l10n.workspaceDiscard),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'save'),
          child: Text(context.l10n.workspaceSave),
        ),
      ],
    ),
  );
  if (!context.mounted || choice == null) return false;
  if (choice == 'save') return saveWorkspaceProgress(context, ref);
  try {
    await controller.discardProgress();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.workspaceSaveFailed)));
    }
    return false;
  }
}

Future<void> editWorkspace(
  BuildContext context,
  WidgetRef ref, {
  WorkspaceProject? project,
  bool naming = false,
}) async {
  final value = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _WorkspaceEditor(project: project, naming: naming),
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
  WorkspaceArchiveContents contents,
) async {
  final project = contents.project;
  final resolved = await resolveWorkspaceModules(
    project,
    ref.read(workspaceProvider).library,
  );
  if (!context.mounted) return;
  ref
      .read(workspaceProvider.notifier)
      .importProject(
        project,
        resolved,
        hiddenNodeIds: contents.hiddenNodeIds,
        hiddenModuleIds: contents.hiddenModuleIds,
        moduleActiveOverrides: contents.moduleActiveOverrides,
        removedModuleIds: contents.removedModuleIds,
        showLogicBlocks: contents.showLogicBlocks,
        showModuleBlocks: contents.showModuleBlocks,
      );
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
           extensions: ['qwork', 'qualia-workspace', 'zip', 'json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('Workspace package exceeds 2 MiB.');
    }
    final bytes = await file.readAsBytes();
    WorkspaceArchiveContents contents;
    if (WorkspaceArchive.looksLikeArchive(bytes)) {
       contents = await WorkspaceArchive.decodeAsync(bytes);
    } else {
      // Keep old JSON packages importable for existing users.
      contents = WorkspaceArchiveContents(
        project: WorkspaceProject.fromPackage(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        ),
      );
    }
    if (!mounted) return;
    await installWorkspace(context, ref, contents);
  });
  Future<void> _importDirectory() => _operation(() async {
    final path = await getDirectoryPath(confirmButtonText: 'Open workspace');
    if (path == null) return;
    final contents = await WorkspaceArchive.decodeDirectoryContents(
      Directory(path),
    );
    if (!mounted) return;
    await installWorkspace(context, ref, contents);
  });
  Future<void> _export(WorkspaceProject project) => _operation(() async {
    final confirmed = await _confirm(
      context.l10n.workspaceExport,
      context.l10n.workspaceShareWarning,
    );
    if (!confirmed || !mounted) return;
    final location = await getSaveLocation(
       suggestedName:
           '${project.name.replaceAll(RegExp(r'[^a-zA-Z0-9_а-яА-Я-]'), '_')}.qwork',
    );
    if (location == null) return;
    final current = ref.read(workspaceProvider);
     final bytes = await WorkspaceArchive.encodeAsync(
      project,
      hiddenNodeIds: current.hiddenNodeIds,
      hiddenModuleIds: current.hiddenModuleIds,
      moduleActiveOverrides: current.moduleActiveOverrides,
      removedModuleIds: current.removedModuleIds,
      showLogicBlocks: current.showLogicBlocks,
      showModuleBlocks: current.showModuleBlocks,
    );
    await XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'application/zip',
    ).saveTo(location.path);
  });
  Future<void> _exportDirectory(WorkspaceProject project) =>
      _operation(() async {
        final parent = await getDirectoryPath(
          confirmButtonText: 'Save workspace',
        );
        if (parent == null) return;
        final safeName = project.name.replaceAll(
          RegExp(r'[^a-zA-Z0-9_а-яА-Я-]'),
          '_',
        );
        final destination = p.join(parent, '$safeName.qualia-workspace');
        final current = ref.read(workspaceProvider);
        if (project.id == current.activeProjectId) {
          await ref
              .read(workspaceProvider.notifier)
              .saveWorkspaceDirectory(destination);
        } else {
          await WorkspaceArchive.writeDirectory(
            Directory(destination),
            project,
            hiddenNodeIds: current.hiddenNodeIds,
            hiddenModuleIds: current.hiddenModuleIds,
            moduleActiveOverrides: current.moduleActiveOverrides,
            removedModuleIds: current.removedModuleIds,
            showLogicBlocks: current.showLogicBlocks,
            showModuleBlocks: current.showModuleBlocks,
          );
        }
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DesktopIconButton(
                  icon: AppIcons.add,
                  tooltip: context.l10n.workspaceCreate,
                  label: context.l10n.workspaceCreate,
                  onPressed: _busy ? null : () => editWorkspace(context, ref),
                  size: 34,
                ),
                DesktopIconButton(
                  icon: AppIcons.fileOpen,
                  tooltip: context.l10n.workspaceImport,
                  label: context.l10n.workspaceImport,
                  onPressed: _busy ? null : _import,
                  size: 34,
                ),
                DesktopIconButton(
                  icon: AppIcons.folderOpen,
                  tooltip: context.l10n.workspaceImport,
                  label: context.l10n.workspaceImport,
                  onPressed: _busy ? null : _importDirectory,
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
                                    ? AppIcons.check
                                    : AppIcons.folderOpen,
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
                                    value: 'export_directory',
                                    label:
                                        '${context.l10n.workspaceExport} (folder)',
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
                                  } else if (action == 'export_directory') {
                                    await _exportDirectory(project);
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
                                  child: Icon(AppIcons.more, size: 18),
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
  const _WorkspaceEditor({this.project, this.naming = false});
  final WorkspaceProject? project;
  final bool naming;
  @override
  State<_WorkspaceEditor> createState() => _WorkspaceEditorState();
}

class _WorkspaceEditorState extends State<_WorkspaceEditor> {
  late final _name = TextEditingController(
    text: widget.naming ? '' : widget.project?.name,
  );
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
      widget.naming
          ? context.l10n.workspaceSave
          : widget.project == null
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
