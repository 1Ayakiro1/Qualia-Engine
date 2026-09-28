import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../common/widgets.dart';

enum ExtensionSection { installed, recommended }

class UserExtension {
  const UserExtension({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.downloaded,
    required this.active,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final bool downloaded;
  final bool active;
  final IconData icon;
}

const List<UserExtension> kUserExtensions = <UserExtension>[
  UserExtension(
    id: 'signal-tools',
    name: 'Signal Tools',
    description: 'Filters and signal inspection helpers for live sessions.',
    category: 'Signal',
    downloaded: true,
    active: true,
    icon: Icons.graphic_eq,
  ),
  UserExtension(
    id: 'session-notes',
    name: 'Session Notes',
    description: 'Add structured notes and markers while recording a session.',
    category: 'Workflow',
    downloaded: true,
    active: false,
    icon: Icons.sticky_note_2_outlined,
  ),
  UserExtension(
    id: 'neuro-dashboard',
    name: 'Neuro Dashboard',
    description: 'A compact dashboard for custom BCI metrics and signals.',
    category: 'Visualization',
    downloaded: false,
    active: false,
    icon: Icons.dashboard_customize_outlined,
  ),
  UserExtension(
    id: 'export-kit',
    name: 'Export Kit',
    description: 'Export recordings and derived data to common formats.',
    category: 'Data',
    downloaded: false,
    active: false,
    icon: Icons.file_download_outlined,
  ),
];

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({
    super.key,
    this.selectedExtensionId,
    this.onSelectExtension,
    this.onNotification,
    this.inspectorOpen = false,
    this.onToggleInspector,
  });

  final String? selectedExtensionId;
  final ValueChanged<UserExtension>? onSelectExtension;
  final void Function(String title, String message, IconData icon)?
  onNotification;
  final bool inspectorOpen;
  final VoidCallback? onToggleInspector;

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  String? _activeExtensionId;
  final List<UserExtension> _tabs = <UserExtension>[];

  @override
  void initState() {
    super.initState();
    final selectedId = widget.selectedExtensionId;
    if (selectedId == null) return;
    for (final extension in kUserExtensions) {
      if (extension.id == selectedId) {
        _activeExtensionId = extension.id;
        _tabs.add(extension);
        break;
      }
    }
  }

  @override
  void didUpdateWidget(covariant ExtensionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedId = widget.selectedExtensionId;
    if (selectedId != null && selectedId != _activeExtensionId) {
      final extension = kUserExtensions.firstWhere(
        (item) => item.id == selectedId,
        orElse: () => kUserExtensions.first,
      );
      _openExtension(extension, notifyParent: false);
    }
  }

  UserExtension? get _activeExtension {
    for (final extension in _tabs) {
      if (extension.id == _activeExtensionId) return extension;
    }
    return null;
  }

  void _openExtension(UserExtension extension, {bool notifyParent = true}) {
    setState(() {
      if (!_tabs.any((tab) => tab.id == extension.id)) {
        _tabs.add(extension);
      }
      _activeExtensionId = extension.id;
    });
    if (notifyParent) widget.onSelectExtension?.call(extension);
  }

  void _closeExtension(UserExtension extension) {
    setState(() {
      final index = _tabs.indexWhere((tab) => tab.id == extension.id);
      if (index < 0) return;
      _tabs.removeAt(index);
      if (_activeExtensionId == extension.id) {
        _activeExtensionId = _tabs.isEmpty
            ? null
            : _tabs[index < _tabs.length ? index : _tabs.length - 1].id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeExtension;
    return ColoredBox(
      color: AppTheme.background,
      child: Column(
        children: [
          _ExtensionTabs(
            tabs: _tabs,
            activeId: _activeExtensionId,
            onSelected: _openExtension,
            onClosed: _closeExtension,
            onCreate:
                kUserExtensions
                    .where((extension) => extension.downloaded)
                    .isEmpty
                ? null
                : () => _openExtension(
                    kUserExtensions.firstWhere(
                      (extension) => extension.downloaded,
                    ),
                  ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: active == null
                      ? const _EmptyExtensions()
                      : _ExtensionDetails(
                          extension: active,
                          onAction: (action) => widget.onNotification?.call(
                            'Extension changed',
                            '${active.name}: $action selected.',
                            Icons.auto_awesome_mosaic_outlined,
                          ),
                        ),
                ),
                if (widget.inspectorOpen)
                  SizedBox(
                    width: 260,
                    child: DesktopPane(
                      child: _ExtensionInspector(extension: active),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionInspector extends StatelessWidget {
  const _ExtensionInspector({required this.extension});

  final UserExtension? extension;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.panel,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'EXTENSION INSPECTOR',
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          if (extension == null)
            const Expanded(
              child: Center(
                child: Text(
                  'Select an extension',
                  style: TextStyle(color: AppTheme.mutedText),
                ),
              ),
            )
          else ...[
            Icon(extension!.icon, size: 26, color: AppTheme.text),
            const SizedBox(height: 12),
            Text(
              extension!.name,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              extension!.description,
              style: const TextStyle(color: AppTheme.mutedText, height: 1.4),
            ),
            const Spacer(),
            Text(
              'ID  ${extension!.id}',
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
            ),
            Text(
              'Category  ${extension!.category}',
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ExtensionTabs extends StatelessWidget {
  const _ExtensionTabs({
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.onClosed,
    required this.onCreate,
  });

  final List<UserExtension> tabs;
  final String? activeId;
  final ValueChanged<UserExtension> onSelected;
  final ValueChanged<UserExtension> onClosed;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Container(
    height: 35,
    color: AppTheme.background,
    child: Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              for (final extension in tabs)
                _ExtensionTab(
                  extension: extension,
                  selected: extension.id == activeId,
                  onSelected: () => onSelected(extension),
                  onClosed: () => onClosed(extension),
                ),
              DesktopIconButton(
                icon: Icons.add,
                tooltip: 'Create extension tab',
                onPressed: onCreate,
                size: 30,
                iconSize: 17,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExtensionTab extends StatelessWidget {
  const _ExtensionTab({
    required this.extension,
    required this.selected,
    required this.onSelected,
    required this.onClosed,
  });

  final UserExtension extension;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppTheme.panel : AppTheme.background,
    child: InkWell(
      onTap: onSelected,
      hoverColor: AppTheme.border,
      child: SizedBox(
        width: 205,
        height: 35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(extension.icon, size: 15),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  extension.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.all(4),
                child: DesktopIconButton(
                  icon: Icons.close,
                  tooltip: 'Close tab',
                  onPressed: onClosed,
                  size: 22,
                  iconSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExtensionDetails extends StatelessWidget {
  const _ExtensionDetails({required this.extension, required this.onAction});

  final UserExtension extension;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(34, 30, 34, 60),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(extension.icon, size: 28, color: AppTheme.text),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  extension.name,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (extension.downloaded)
                const Icon(
                  Icons.download_done_outlined,
                  color: AppTheme.mutedText,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            extension.description,
            style: const TextStyle(color: AppTheme.mutedText, height: 1.45),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExtensionAction(
                label: extension.active ? 'Disable' : 'Enable',
                icon: extension.active ? Icons.pause : Icons.play_arrow,
                onPressed: () =>
                    onAction(extension.active ? 'Disable' : 'Enable'),
              ),
              _ExtensionAction(
                label: 'Settings',
                icon: Icons.settings_outlined,
                onPressed: () => onAction('Settings'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Extension details',
            style: TextStyle(color: AppTheme.text, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'ID  ${extension.id}',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
          Text(
            'Category  ${extension.category}',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ExtensionAction extends StatelessWidget {
  const _ExtensionAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label),
  );
}

class _EmptyExtensions extends StatelessWidget {
  const _EmptyExtensions();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 80 || constraints.maxHeight < 100) {
        return const SizedBox.shrink();
      }
      final narrow = constraints.maxWidth < 260;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.extension_outlined,
                size: 40,
                color: AppTheme.mutedText,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select an extension',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.text),
              ),
              if (!narrow) ...[
                const SizedBox(height: 5),
                const Text(
                  'Choose an extension from the sidebar to open a tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedText),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
