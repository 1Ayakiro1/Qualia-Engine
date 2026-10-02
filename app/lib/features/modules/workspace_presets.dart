import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/modules/module_registry.dart';
import '../../core/workspace/workspace_model.dart';

Future<WorkspacePreset?> showWorkspacePresetEditor(
  BuildContext context,
  List<SystemModule> modules,
) => showDialog<WorkspacePreset>(
  context: context,
  builder: (_) => _PresetEditor(modules: modules),
);

Future<WorkspacePreset?> importWorkspacePreset() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Workspace preset', extensions: ['json']),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 1048576) {
    throw const FormatException('Preset file is too large.');
  }
  return WorkspacePreset.fromJson(
    Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
  );
}

Future<void> exportWorkspacePreset(WorkspacePreset preset) async {
  final destination = await getSaveLocation(
    suggestedName:
        '${preset.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-')}.workspace.json',
  );
  if (destination != null) {
    await File(destination.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(preset.toJson()),
    );
  }
}

class _PresetEditor extends StatefulWidget {
  const _PresetEditor({required this.modules});
  final List<SystemModule> modules;
  @override
  State<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends State<_PresetEditor> {
  final _name = TextEditingController();
  final _ids = TextEditingController();
  final _selected = <String>{};
  @override
  void dispose() {
    _name.dispose();
    _ids.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.textAddWorkspacePreset124),
    content: SizedBox(
      width: 440,
      height: 380,
      child: Column(
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.textPresetName325,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ids,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.l10n.textAdditionalMarketplaceModuleIDs326,
              hintText: context.l10n.textOneIDPerLineOrSeparatedBy327,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final module in widget.modules)
                  CheckboxListTile(
                    dense: true,
                    title: Text(module.displayName(context)),
                    subtitle: Text(
                      module.id,
                      style: const TextStyle(fontSize: 10),
                    ),
                    value: _selected.contains(module.id),
                    onChanged: (value) => setState(() {
                      value!
                          ? _selected.add(module.id)
                          : _selected.remove(module.id);
                    }),
                  ),
                if (widget.modules.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      context.l10n.textYouCanCreateAnEmptyPresetOr328,
                      style: TextStyle(fontSize: 12),
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
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.textCancel198),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                WorkspacePreset(
                  id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
                  name: _name.text.trim(),
                  moduleIds: {
                    ..._selected,
                    ..._ids.text
                        .split(RegExp(r'[,\n]'))
                        .map((id) => id.trim())
                        .where((id) => id.isNotEmpty),
                  }.toList(),
                ),
              ),
        child: Text(context.l10n.textSave203),
      ),
    ],
  );
}
