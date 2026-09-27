import 'package:flutter/material.dart';

import '../../core/modules/module_registry.dart';
import '../../core/theme/app_theme.dart';

/// Module workspace with an optional inspector on the right.
class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
    required this.modules,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<SystemModule> modules;
  final VoidCallback onAdd;
  final ValueChanged<SystemModule> onEdit;
  final ValueChanged<SystemModule> onRemove;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  SystemModule? _selected;
  bool _rightSidebarOpen = false;

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.modules.where((module) => module.active).length;
    final selected = widget.modules.any((module) => module.id == _selected?.id)
        ? widget.modules.firstWhere((module) => module.id == _selected!.id)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: AppTheme.background,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Modules',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _ModuleToolbarButton(
                      icon: Icons.add,
                      tooltip: 'Add module',
                      onPressed: widget.onAdd,
                    ),
                    _ModuleToolbarButton(
                      icon: Icons.view_sidebar_outlined,
                      tooltip: _rightSidebarOpen
                          ? 'Hide module inspector'
                          : 'Show module inspector',
                      onPressed: () => setState(
                        () => _rightSidebarOpen = !_rightSidebarOpen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '$activeCount active · ${widget.modules.length - activeCount} planned',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                for (final module in widget.modules)
                  _ModuleCard(
                    module: module,
                    selected: selected?.id == module.id,
                    onTap: () => setState(() => _selected = module),
                    onEdit: () => widget.onEdit(module),
                    onRemove: () => widget.onRemove(module),
                  ),
                const SizedBox(height: 12),
                const _ModuleContractCard(),
              ],
            ),
          ),
        ),
        if (_rightSidebarOpen)
          SizedBox(
            width: 260,
            child: _ModuleInspector(
              module: selected,
              onEdit: selected == null ? null : () => widget.onEdit(selected),
              onRemove: selected == null
                  ? null
                  : () => widget.onRemove(selected),
            ),
          ),
      ],
    );
  }
}

class _ModuleToolbarButton extends StatelessWidget {
  const _ModuleToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: AppTheme.mutedText,
      hoverColor: AppTheme.border,
      splashRadius: 17,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
    ),
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  final SystemModule module;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected ? AppTheme.panel : const Color(0xFF181818),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.border,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 9, 13),
          child: Row(
            children: [
              Icon(
                module.active ? Icons.extension_outlined : Icons.schedule,
                color: AppTheme.text,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: const TextStyle(color: AppTheme.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${module.id} · ${module.category} · ${module.stage}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Edit module',
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: AppTheme.mutedText,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              Tooltip(
                message: 'Remove module',
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove, size: 17),
                  color: AppTheme.mutedText,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModuleInspector extends StatelessWidget {
  const _ModuleInspector({required this.module, this.onEdit, this.onRemove});

  final SystemModule? module;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.panel,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: module == null
          ? const Center(
              child: Text(
                'Select a module',
                style: TextStyle(color: AppTheme.mutedText),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MODULE INSPECTOR',
                  style: TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  module!.name,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  module!.description,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'ID  ${module!.id}',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Version  ${module!.version}',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Stage  ${module!.stage}',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit module'),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove module'),
                ),
              ],
            ),
    ),
  );
}

class _ModuleContractCard extends StatelessWidget {
  const _ModuleContractCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Module contract',
          style: TextStyle(color: AppTheme.text, fontSize: 15),
        ),
        SizedBox(height: 7),
        Text(
          'User modules will be loaded from the sandbox. Each module provides a manifest, permissions, initialization and processing blocks.',
          style: TextStyle(
            color: AppTheme.mutedText,
            height: 1.4,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
