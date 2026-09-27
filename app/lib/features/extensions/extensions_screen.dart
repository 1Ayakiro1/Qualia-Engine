import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum ExtensionFilter { downloaded, active, all }

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
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  ExtensionFilter _filter = ExtensionFilter.all;
  String? _activeExtensionId;
  bool _rightSidebarOpen = false;
  final List<UserExtension> _tabs = <UserExtension>[];

  List<UserExtension> get _visibleExtensions {
    return kUserExtensions.where((extension) {
      switch (_filter) {
        case ExtensionFilter.downloaded:
          return extension.downloaded;
        case ExtensionFilter.active:
          return extension.active;
        case ExtensionFilter.all:
          return true;
      }
    }).toList();
  }

  UserExtension? get _activeExtension {
    for (final extension in _tabs) {
      if (extension.id == _activeExtensionId) return extension;
    }
    return null;
  }

  void _openExtension(UserExtension extension) {
    setState(() {
      if (!_tabs.any((tab) => tab.id == extension.id)) {
        _tabs.add(extension);
      }
      _activeExtensionId = extension.id;
    });
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: _ExtensionExplorer(
            filter: _filter,
            extensions: _visibleExtensions,
            activeId: _activeExtensionId,
            rightSidebarOpen: _rightSidebarOpen,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onSelected: _openExtension,
            onToggleSidebar: () =>
                setState(() => _rightSidebarOpen = !_rightSidebarOpen),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              _ExtensionTabs(
                tabs: _tabs,
                activeId: _activeExtensionId,
                onSelected: _openExtension,
                onClosed: _closeExtension,
                onCreate: _visibleExtensions.isEmpty
                    ? null
                    : () => _openExtension(_visibleExtensions.first),
              ),
              Expanded(
                child: active == null
                    ? const _EmptyExtensions()
                    : _ExtensionDetails(extension: active),
              ),
            ],
          ),
        ),
        if (_rightSidebarOpen) ...[
          const VerticalDivider(width: 1),
          SizedBox(width: 250, child: _ExtensionInspector(extension: active)),
        ],
      ],
    );
  }
}

class _ExtensionExplorer extends StatelessWidget {
  const _ExtensionExplorer({
    required this.filter,
    required this.extensions,
    required this.activeId,
    required this.rightSidebarOpen,
    required this.onFilterChanged,
    required this.onSelected,
    required this.onToggleSidebar,
  });

  final ExtensionFilter filter;
  final List<UserExtension> extensions;
  final String? activeId;
  final bool rightSidebarOpen;
  final ValueChanged<ExtensionFilter> onFilterChanged;
  final ValueChanged<UserExtension> onSelected;
  final VoidCallback onToggleSidebar;

  String _filterLabel(ExtensionFilter value) {
    switch (value) {
      case ExtensionFilter.downloaded:
        return 'Downloaded';
      case ExtensionFilter.active:
        return 'Active';
      case ExtensionFilter.all:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
          child: Row(
            children: [
              const Text(
                'EXPLORER',
                style: TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: rightSidebarOpen
                    ? 'Hide extension inspector'
                    : 'Show extension inspector',
                child: IconButton(
                  key: const ValueKey<String>('toggle extension inspector'),
                  onPressed: onToggleSidebar,
                  icon: Icon(
                    rightSidebarOpen
                        ? Icons.view_sidebar
                        : Icons.view_sidebar_outlined,
                    size: 17,
                  ),
                  color: AppTheme.mutedText,
                  hoverColor: AppTheme.border,
                  constraints: const BoxConstraints.tightFor(
                    width: 27,
                    height: 27,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final value in ExtensionFilter.values)
                _ExtensionFilterButton(
                  label: _filterLabel(value),
                  selected: filter == value,
                  onPressed: () => onFilterChanged(value),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final extension in extensions)
                _ExtensionListItem(
                  extension: extension,
                  selected: extension.id == activeId,
                  onTap: () => onSelected(extension),
                ),
              if (extensions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No extensions found',
                    style: TextStyle(color: AppTheme.mutedText),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExtensionFilterButton extends StatelessWidget {
  const _ExtensionFilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: selected ? AppTheme.text : AppTheme.mutedText,
      backgroundColor: selected ? AppTheme.panel : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}

class _ExtensionListItem extends StatelessWidget {
  const _ExtensionListItem({
    required this.extension,
    required this.selected,
    required this.onTap,
  });

  final UserExtension extension;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Material(
      color: selected ? AppTheme.panel : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.border,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 5, 9),
          child: Row(
            children: [
              Icon(extension.icon, size: 17, color: AppTheme.text),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extension.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      extension.category,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (extension.downloaded)
                const Tooltip(
                  message: 'Downloaded',
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.download_done_outlined,
                      size: 16,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
              Tooltip(
                message: 'Create extension tab',
                child: IconButton(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add, size: 17),
                  color: AppTheme.mutedText,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
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
              Tooltip(
                message: 'Close tab',
                child: InkWell(
                  onTap: onClosed,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ID  ${extension!.id}',
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Category  ${extension!.category}',
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(
                      extension!.active ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      extension!.active
                          ? 'Disable extension'
                          : 'Enable extension',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Extension settings'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _ExtensionDetails extends StatelessWidget {
  const _ExtensionDetails({required this.extension});

  final UserExtension extension;

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
              ),
              _ExtensionAction(
                label: 'Settings',
                icon: Icons.settings_outlined,
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
  const _ExtensionAction({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () {},
    icon: Icon(icon, size: 16),
    label: Text(label),
  );
}

class _EmptyExtensions extends StatelessWidget {
  const _EmptyExtensions();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.extension_outlined, size: 40, color: AppTheme.mutedText),
        SizedBox(height: 12),
        Text('Select an extension', style: TextStyle(color: AppTheme.text)),
        SizedBox(height: 5),
        Text(
          'Choose an extension from the sidebar to open a tab.',
          style: TextStyle(color: AppTheme.mutedText),
        ),
      ],
    ),
  );
}
