import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../state/engine_state.dart';

/// Settings workspace styled as a dedicated, two-column preferences panel.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.onBack, this.initialItem = 'General'});

  final VoidCallback? onBack;
  final String initialItem;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool workspaceAccess = true;
  bool fullAccess = true;
  bool keepAwake = false;
  bool bottomPanel = false;
  late String selectedItem = widget.initialItem;

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItem != widget.initialItem) {
      selectedItem = widget.initialItem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionLabelProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: compact ? 210 : 280,
              child: _PreferencesSidebar(
                selected: selectedItem,
                onSelected: (value) => setState(() => selectedItem = value),
                onBack: widget.onBack,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _PreferencesContent(
                version: version,
                selectedItem: selectedItem,
                workspaceAccess: workspaceAccess,
                fullAccess: fullAccess,
                keepAwake: keepAwake,
                bottomPanel: bottomPanel,
                onWorkspaceAccessChanged: (value) =>
                    setState(() => workspaceAccess = value),
                onFullAccessChanged: (value) =>
                    setState(() => fullAccess = value),
                onKeepAwakeChanged: (value) =>
                    setState(() => keepAwake = value),
                onBottomPanelChanged: (value) =>
                    setState(() => bottomPanel = value),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreferencesSidebar extends StatelessWidget {
  const _PreferencesSidebar({
    required this.selected,
    required this.onSelected,
    this.onBack,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback? onBack;

  static const _personal = [
    ('General', Icons.settings_outlined),
    ('Import', Icons.download_outlined),
    ('Appearance', Icons.wb_sunny_outlined),
    ('Voice', Icons.mic_none_outlined),
    ('Configuration', Icons.verified_user_outlined),
    ('Personalization', Icons.history_outlined),
    ('Pets', Icons.more_horiz),
    ('Keyboard shortcuts', Icons.keyboard_alt_outlined),
    ('Account', Icons.account_circle_outlined),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.background,
    child: ScrollConfiguration(
      behavior: const _NoGlow(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 28),
        children: [
          _SidebarBackButton(onPressed: onBack),
          const SizedBox(height: 14),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Search',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SidebarGroup(
            title: 'Personal',
            items: _personal,
            selected: selected,
            onSelected: onSelected,
          ),
          const SizedBox(height: 18),
          const Text('Archived', style: TextStyle(color: AppTheme.mutedText)),
        ],
      ),
    ),
  );
}

class _SidebarBackButton extends StatelessWidget {
  const _SidebarBackButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _PreferenceNavButton(
    label: 'Back to app',
    icon: Icons.arrow_back,
    onTap: onPressed,
  );
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<(String, IconData)> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
        child: Text(title, style: const TextStyle(color: AppTheme.mutedText)),
      ),
      for (final item in items)
        _PreferenceNavButton(
          label: item.$1,
          icon: item.$2,
          selected: selected == item.$1,
          trailing: item.$1 == 'Account'
              ? const Icon(
                  Icons.north_east,
                  size: 15,
                  color: AppTheme.mutedText,
                )
              : null,
          onTap: () => onSelected(item.$1),
        ),
    ],
  );
}

class _PreferencesContent extends StatelessWidget {
  const _PreferencesContent({
    required this.version,
    required this.selectedItem,
    required this.workspaceAccess,
    required this.fullAccess,
    required this.keepAwake,
    required this.bottomPanel,
    required this.onWorkspaceAccessChanged,
    required this.onFullAccessChanged,
    required this.onKeepAwakeChanged,
    required this.onBottomPanelChanged,
  });

  final String version;
  final String selectedItem;
  final bool workspaceAccess;
  final bool fullAccess;
  final bool keepAwake;
  final bool bottomPanel;
  final ValueChanged<bool> onWorkspaceAccessChanged;
  final ValueChanged<bool> onFullAccessChanged;
  final ValueChanged<bool> onKeepAwakeChanged;
  final ValueChanged<bool> onBottomPanelChanged;

  @override
  Widget build(BuildContext context) {
    if (selectedItem != 'General') {
      return Center(
        child: Text(
          '$selectedItem 1',
          style: const TextStyle(fontSize: 30, color: AppTheme.text),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: const _NoGlow(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 80),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'General',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 54),
                const Text('Permissions', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 22),
                _SettingsCard(
                  children: [
                    _PreferenceRow(
                      title: 'Default permissions',
                      description: 'By default, Ayakiro can read and edit files in its workspace. It can ask for additional access when needed',
                      control: Switch(
                        value: workspaceAccess,
                        onChanged: onWorkspaceAccessChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: 'Full access',
                      description: 'When Ayakiro runs with full access, it can edit any file on your computer and run commands with network, without your approval. This significantly increases the risk of data loss, leaks, or unexpected behavior.',
                      extra: const Text(
                        'Learn more about elevated risks.',
                        style: TextStyle(color: AppTheme.text),
                      ),
                      control: Switch(
                        value: fullAccess,
                        onChanged: onFullAccessChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 66),
                const Text('General', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 22),
                _SettingsCard(
                  children: [
                    _PreferenceRow(
                      title: 'Projectless task folder',
                      description: 'The location where tasks started outside of projects store their data by default.',
                      control: _ActionButton(
                        label: '/home/ayakiro...uments/Codex',
                        action: 'Change',
                      ),
                    ),
                    _PreferenceRow(
                      title: 'Default file open destination',
                      description: 'Where files and folders open by default',
                      control: _DropButton(label: 'Zed'),
                    ),
                    _PreferenceRow(
                      title: 'Language',
                      description: 'Language for the app UI',
                      control: _DropButton(label: 'Auto detect'),
                    ),
                    _PreferenceRow(
                      title: 'Bottom panel',
                      description:
                          'Show the bottom panel control in the app header',
                      control: Switch(
                        value: bottomPanel,
                        onChanged: onBottomPanelChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: 'Prevent sleep while running',
                      description: 'Keep your computer awake while Ayakiro is running a task',
                      control: Switch(
                        value: keepAwake,
                        onChanged: onKeepAwakeChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: 'Open source licenses',
                      description:
                          'Third-party software used by Ayakiro BCI Engine',
                      control: _DropButton(label: 'View'),
                    ),
                    _PreferenceRow(
                      title: 'Version',
                      description: 'Current application build',
                      control: Text(
                        version,
                        style: const TextStyle(color: AppTheme.mutedText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text(
                  '${AppInfo.appName} · local offline-first mode',
                  style: const TextStyle(color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceNavButton extends StatefulWidget {
  const _PreferenceNavButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;

  @override
  State<_PreferenceNavButton> createState() => _PreferenceNavButtonState();
}

class _PreferenceNavButtonState extends State<_PreferenceNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 39,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _hovered || widget.selected
              ? AppTheme.border
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: AppTheme.text),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: children),
  );
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.title,
    required this.description,
    required this.control,
    this.extra,
  });

  final String title;
  final String description;
  final Widget control;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 620;
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 13),
          ),
          if (extra != null) ...[const SizedBox(height: 3), extra!],
        ],
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 12), control],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  control,
                ],
              ),
      );
    },
  );
}

class _DropButton extends StatelessWidget {
  const _DropButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () {},
    icon: const Icon(Icons.unfold_more, size: 17),
    label: Text(label),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.action});
  final String label;
  final String action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 360;
      final path = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: narrow ? 180 : 210),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.mutedText,
            fontFamily: 'monospace',
          ),
        ),
      );
      return narrow
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: path),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: Text(action)),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                path,
                const SizedBox(width: 12),
                OutlinedButton(onPressed: () {}, child: Text(action)),
              ],
            );
    },
  );
}

class _NoGlow extends ScrollBehavior {
  const _NoGlow();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
