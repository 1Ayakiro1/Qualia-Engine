import '../../l10n/app_strings.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_state.dart';
import '../../l10n/module_strings.dart';
import '../../state/workspace_state.dart';
import '../../core/theme/app_palette.dart';
import 'nav_registry.dart';
import '../../core/modules/module_registry.dart';
import '../modules/module_ui.dart';
import '../common/widgets.dart';

class RailConfiguration {
  const RailConfiguration({
    this.visible = true,
    this.sections = const {
      SectionId.profile,
      SectionId.extensions,
      SectionId.modules,
      SectionId.entity,
      SectionId.bugReport,
      SectionId.settings,
    },
    this.extensions = const {},
  });
  final bool visible;
  final Set<SectionId> sections;
  final Set<String> extensions;
}

class RailController extends Notifier<RailConfiguration> {
  bool _disposed = false;
  @override
  RailConfiguration build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const RailConfiguration();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('qualia.rail.v1');
      if (raw == null || _disposed) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = RailConfiguration(
        visible: json['visible'] != false,
        sections: SectionId.values
            .where((id) => (json['sections'] as List).contains(id.name))
            .toSet(),
        extensions: Set<String>.from(json['extensions'] as List? ?? []),
      );
    } catch (_) {
      /* Retain safe defaults if preferences are unavailable. */
    }
  }

  Future<void> _save() async {
    try {
      final raw = jsonEncode({
        'visible': state.visible,
        'sections': state.sections.map((id) => id.name).toList(),
        'extensions': state.extensions.toList(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qualia.rail.v1', raw);
    } catch (_) {
      /* In-memory settings still work. */
    }
  }

  void setVisible(bool value) {
    state = RailConfiguration(
      visible: value,
      sections: state.sections,
      extensions: state.extensions,
    );
    unawaited(_save());
  }

  void setSection(SectionId id, bool enabled) {
    final sections = {...state.sections};
    enabled ? sections.add(id) : sections.remove(id);
    state = RailConfiguration(
      visible: state.visible,
      sections: sections,
      extensions: state.extensions,
    );
    unawaited(_save());
  }

  void setExtension(String id, bool enabled) {
    final extensions = {...state.extensions};
    enabled ? extensions.add(id) : extensions.remove(id);
    state = RailConfiguration(
      visible: state.visible,
      sections: state.sections,
      extensions: extensions,
    );
    unawaited(_save());
  }
}

final railProvider = NotifierProvider<RailController, RailConfiguration>(
  RailController.new,
);

Future<void> showRailSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const RailSettingsDialog(),
);

class RailSettingsDialog extends ConsumerWidget {
  const RailSettingsDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(railProvider);
    final controller = ref.read(railProvider.notifier);
    final extensions = ref
        .watch(workspaceProvider)
        .library
        .where(
          (module) =>
              module.manifest['kind'] == 'extension' &&
              module.manifest['rail'] is Map,
        )
        .toList();
    return Dialog(
      backgroundColor: context.palette.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (MediaQuery.sizeOf(context).width * .6).clamp(
          600,
          double.infinity,
        ),
        height: (MediaQuery.sizeOf(context).height * .8).clamp(480, 850),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.textRailSettings129,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DesktopIconButton(
                    icon: Icons.close,
                    tooltip: context.l10n.textCloseRailSettings221,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('rail settings scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  _block(context, context.l10n.textVisibility222, [
                    _setting(
                      context,
                      context.l10n.textShowRail223,
                      Icons.view_sidebar_outlined,
                      config.visible,
                      () => controller.setVisible(!config.visible),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Text(
                        context.l10n.textWhenHiddenContentUsesTheFullWidth224,
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _block(context, context.l10n.textSections225, [
                    _setting(
                      context,
                      context.l10n.textProfile75,
                      Icons.account_circle_outlined,
                      config.sections.contains(SectionId.profile),
                      () => controller.setSection(
                        SectionId.profile,
                        !config.sections.contains(SectionId.profile),
                      ),
                    ),
                    for (final section in kNavSections)
                      _setting(
                        context,
                        context.hostLabel(section.label),
                        section.icon,
                        config.sections.contains(section.id),
                        () => controller.setSection(
                          section.id,
                          !config.sections.contains(section.id),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _block(context, context.l10n.textExtensionSections226, [
                    if (extensions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          context.l10n.textAddAnExtensionFromTheCatalogTo227,
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    for (final module in extensions)
                      _setting(
                        context,
                        module.displayName(context),
                        extensionRailIcon(module),
                        config.extensions.contains(module.id),
                        () => controller.setExtension(
                          module.id,
                          !config.extensions.contains(module.id),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.textChangesAreSavedAutomatically228,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: DesktopIconButton(
                      icon: Icons.check,
                      tooltip: context.l10n.textDone229,
                      label: context.l10n.textDone229,
                      size: 34,
                      active: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, String title, List<Widget> children) =>
      DesktopPane(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      );

  Widget _setting(
    BuildContext context,
    String label,
    IconData icon,
    bool enabled,
    VoidCallback toggle,
  ) => Semantics(
    label: label,
    toggled: enabled,
    child: DesktopHoverTile(
      key: ValueKey('rail setting $label'),
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.palette.mutedText),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            DesktopIconButton(
              icon: enabled ? Icons.check : Icons.add,
              tooltip: context.l10n.textArg0Arg1230(
                context.hostLabel(enabled ? 'Hide' : 'Show'),
                label,
              ),
              active: enabled,
              onPressed: toggle,
              size: 34,
              iconSize: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Icon names are allowlisted rather than constructing fonts from remote data.
IconData extensionRailIcon(SystemModule module) {
  final rail = module.manifest['rail'] as Map?;
  return switch (rail?['icon']) {
    'chart' => Icons.multiline_chart,
    'notes' => Icons.sticky_note_2_outlined,
    'signal' => Icons.graphic_eq,
    'folder' => Icons.folder_open_outlined,
    'brain' => Icons.psychology_outlined,
    _ => Icons.widgets_outlined,
  };
}

class ExtensionRailPage extends StatefulWidget {
  const ExtensionRailPage({
    super.key,
    required this.module,
    required this.onBack,
  });
  final SystemModule module;
  final VoidCallback onBack;
  @override
  State<ExtensionRailPage> createState() => _ExtensionRailPageState();
}

class _ExtensionRailPageState extends State<ExtensionRailPage> {
  final _values = <String, dynamic>{};
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.background,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            DesktopIconButton(
              icon: Icons.arrow_back,
              tooltip: context.l10n.textBack233,
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 10),
            Text(
              widget.module.displayName(context),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(widget.module.displayDescription(context)),
        const SizedBox(height: 20),
        ModuleControls(
          localizePreview: widget.module.isLocalPreview,
          schema: widget.module.manifest['ui'] is List
              ? widget.module.manifest['ui'] as List
              : const [],
          values: _values,
          onChanged: (key, value) => setState(() => _values[key] = value),
        ),
      ],
    ),
  );
}
