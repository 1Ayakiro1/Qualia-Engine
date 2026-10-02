import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../core/theme/app_palette.dart';
import '../common/widgets.dart';

class NeuralEntity {
  const NeuralEntity({
    required this.id,
    required this.name,
    required this.framework,
    required this.version,
    required this.description,
    this.installed = false,
  });

  final String id;
  final String name;
  final String framework;
  final String version;
  final String description;
  final bool installed;

  NeuralEntity copyWith({bool? installed}) => NeuralEntity(
    id: id,
    name: name,
    framework: framework,
    version: version,
    description: description,
    installed: installed ?? this.installed,
  );
}

const List<NeuralEntity> kNeuralEntities = [
  NeuralEntity(
    id: 'qualia.motor-imagery',
    name: 'Motor Imagery Classifier',
    framework: 'ONNX Runtime',
    version: '1.2.0',
    description: 'Classifies left- and right-hand motor imagery from EEG.',
    installed: true,
  ),
  NeuralEntity(
    id: 'qualia.focus-estimator',
    name: 'Focus Estimator',
    framework: 'TensorFlow Lite',
    version: '0.8.1',
    description: 'Estimates attention and focus from live signal windows.',
    installed: true,
  ),
  NeuralEntity(
    id: 'qualia.artifact-detector',
    name: 'Artifact Detector',
    framework: 'ONNX Runtime',
    version: '1.0.0',
    description: 'Detects common eye-blink and muscle artifacts in EEG.',
  ),
];

class EntityScreen extends StatefulWidget {
  const EntityScreen({
    super.key,
    required this.entities,
    required this.selectedEntity,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onToggleInstalled,
  });

  final List<NeuralEntity> entities;
  final NeuralEntity? selectedEntity;
  final VoidCallback onAdd;
  final ValueChanged<NeuralEntity> onEdit;
  final ValueChanged<NeuralEntity> onRemove;
  final ValueChanged<NeuralEntity> onToggleInstalled;

  @override
  State<EntityScreen> createState() => _EntityScreenState();
}

/// Entity details workspace. Entity selection and navigation live in the
/// shared shell Explorer, so this pane intentionally contains no sidebar.
class EntityWorkspace extends StatelessWidget {
  const EntityWorkspace({
    super.key,
    required this.entity,
    required this.onEdit,
    required this.onRemove,
    required this.onToggleInstalled,
  });

  final NeuralEntity? entity;
  final ValueChanged<NeuralEntity> onEdit;
  final ValueChanged<NeuralEntity> onRemove;
  final ValueChanged<NeuralEntity> onToggleInstalled;

  @override
  Widget build(BuildContext context) {
    final selected = entity;
    if (selected == null) {
      return Center(
        child: Text(
          context.l10n.textSelectANeuralEntity421,
          style: TextStyle(color: context.palette.mutedText),
        ),
      );
    }
    final details = SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DesktopIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: context.l10n.textEditEntity163,
                  onPressed: () => onEdit(selected),
                ),
                DesktopIconButton(
                  icon: Icons.delete_outline,
                  tooltip: context.l10n.textRemoveEntity162,
                  onPressed: () => onRemove(selected),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              kNeuralEntities.any(
                    (entry) =>
                        entry.id == selected.id &&
                        entry.description == selected.description,
                  )
                  ? context.hostLabel(selected.description)
                  : selected.description,
              style: TextStyle(color: context.palette.mutedText, height: 1.4),
            ),
            const SizedBox(height: 22),
            _EntityProperty(label: context.l10n.textID188, value: selected.id),
            _EntityProperty(
              label: context.l10n.textFramework206,
              value: selected.framework,
            ),
            _EntityProperty(
              label: context.l10n.textVersion207,
              value: selected.version,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => onToggleInstalled(selected),
              icon: Icon(
                selected.installed
                    ? Icons.delete_outline
                    : Icons.download_outlined,
              ),
              label: Text(
                selected.installed
                    ? context.l10n.textUninstall212
                    : context.l10n.textInstall422,
              ),
            ),
          ],
        ),
      ),
    );
    return details;
  }
}

class _EntityScreenState extends State<EntityScreen> {
  NeuralEntity? _selected;
  bool _installedExpanded = true;
  bool _catalogExpanded = true;

  @override
  Widget build(BuildContext context) {
    final currentSelection = widget.selectedEntity ?? _selected;
    final selected = widget.entities.where((e) => e.id == currentSelection?.id);
    final entity = selected.isEmpty ? null : selected.first;
    final installed = widget.entities.where((e) => e.installed).toList();
    final catalog = widget.entities.where((e) => !e.installed).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = constraints.maxWidth < 260
            ? constraints.maxWidth * .42
            : (constraints.maxWidth * .36).clamp(
                180.0,
                math.min(310.0, constraints.maxWidth - 180).toDouble(),
              );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: ColoredBox(
                color: context.palette.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.textENTITY423,
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DesktopIconButton(
                            icon: Icons.add,
                            tooltip: context.l10n.textAddEntity161,
                            onPressed: widget.onAdd,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        children: [
                          ExplorerDisclosureSection(
                            title: context.l10n.textInstalled176,
                            expanded: _installedExpanded,
                            onToggle: () => setState(
                              () => _installedExpanded = !_installedExpanded,
                            ),
                            children: [
                              for (final item in installed)
                                _EntityItem(
                                  entity: item,
                                  selected: item.id == entity?.id,
                                  onTap: () => setState(() => _selected = item),
                                ),
                            ],
                          ),
                          ExplorerDisclosureSection(
                            title: context.l10n.textCatalog424,
                            expanded: _catalogExpanded,
                            onToggle: () => setState(
                              () => _catalogExpanded = !_catalogExpanded,
                            ),
                            showDivider: false,
                            children: [
                              for (final item in catalog)
                                _EntityItem(
                                  entity: item,
                                  selected: item.id == entity?.id,
                                  onTap: () => setState(() => _selected = item),
                                ),
                            ],
                          ),
                          if (widget.entities.isEmpty)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                context.l10n.textNoEntitiesYet425,
                                style: TextStyle(
                                  color: context.palette.mutedText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ColoredBox(
                color: context.palette.background,
                child: entity == null
                    ? Center(
                        child: Text(
                          context.l10n.textSelectANeuralEntity421,
                          style: TextStyle(color: context.palette.mutedText),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.hub_outlined, size: 27),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entity.name,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DesktopIconButton(
                                    icon: Icons.edit_outlined,
                                    tooltip: context.l10n.textEditEntity163,
                                    onPressed: () => widget.onEdit(entity),
                                  ),
                                  DesktopIconButton(
                                    icon: Icons.delete_outline,
                                    tooltip: context.l10n.textRemoveEntity162,
                                    onPressed: () => widget.onRemove(entity),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                kNeuralEntities.any(
                                      (entry) =>
                                          entry.id == entity.id &&
                                          entry.description ==
                                              entity.description,
                                    )
                                    ? context.hostLabel(entity.description)
                                    : entity.description,
                                style: TextStyle(
                                  color: context.palette.mutedText,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _EntityProperty(
                                label: context.l10n.textID188,
                                value: entity.id,
                              ),
                              _EntityProperty(
                                label: context.l10n.textFramework206,
                                value: entity.framework,
                              ),
                              _EntityProperty(
                                label: context.l10n.textVersion207,
                                value: entity.version,
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: () =>
                                    widget.onToggleInstalled(entity),
                                icon: Icon(
                                  entity.installed
                                      ? Icons.delete_outline
                                      : Icons.download_outlined,
                                ),
                                label: Text(
                                  entity.installed
                                      ? context.l10n.textUninstall212
                                      : context.l10n.textInstall422,
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
      },
    );
  }
}

class _EntityItem extends StatelessWidget {
  const _EntityItem({
    required this.entity,
    required this.selected,
    required this.onTap,
  });

  final NeuralEntity entity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: DesktopHoverTile(
      onTap: onTap,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entity.name, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${entity.framework} · v${entity.version}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 10,
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

class _EntityProperty extends StatelessWidget {
  const _EntityProperty({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: context.palette.mutedText),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
