import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
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
  UserExtension? get _activeExtension {
    final selectedId = widget.selectedExtensionId;
    if (selectedId == null) return null;
    for (final extension in kUserExtensions) {
      if (extension.id == selectedId) return extension;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeExtension;
    return ColoredBox(
      color: context.palette.background,
      child: Column(
        children: [
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
                            context.hostLabel('Extension changed'),
                            context.l10n.textArg0Arg1Selected408(
                              active.name,
                              action,
                            ),
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
    color: context.palette.panel,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.textEXTENSIONINSPECTOR409,
            style: TextStyle(
              color: context.palette.mutedText,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          if (extension == null)
            Expanded(
              child: Center(
                child: Text(
                  context.l10n.textSelectAnExtension410,
                  style: TextStyle(color: context.palette.mutedText),
                ),
              ),
            )
          else ...[
            Icon(extension!.icon, size: 26, color: context.palette.text),
            const SizedBox(height: 12),
            Text(
              extension!.name,
              style: TextStyle(
                color: context.palette.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.hostLabel(extension!.description),
              style: TextStyle(color: context.palette.mutedText, height: 1.4),
            ),
            const Spacer(),
            Text(
              'ID  ${extension!.id}',
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
            Text(
              context.l10n.textCategoryArg0411(
                (extension!.category).toString(),
              ),
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
          ],
        ],
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
              Icon(extension.icon, size: 28, color: context.palette.text),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  extension.name,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (extension.downloaded)
                Icon(
                  Icons.download_done_outlined,
                  color: context.palette.mutedText,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.hostLabel(extension.description),
            style: TextStyle(color: context.palette.mutedText, height: 1.45),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExtensionAction(
                label: extension.active
                    ? context.l10n.textDisable412
                    : context.l10n.textEnable413,
                icon: extension.active ? Icons.pause : Icons.play_arrow,
                onPressed: () =>
                    onAction(extension.active ? 'Disable' : 'Enable'),
              ),
              _ExtensionAction(
                label: context.l10n.textSettings414,
                icon: Icons.settings_outlined,
                onPressed: () => onAction('Settings'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            context.l10n.textExtensionDetails415,
            style: TextStyle(color: context.palette.text, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'ID  ${extension.id}',
            style: TextStyle(color: context.palette.mutedText, fontSize: 12),
          ),
          Text(
            context.l10n.textCategoryArg0416((extension.category).toString()),
            style: TextStyle(color: context.palette.mutedText, fontSize: 12),
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
      final narrow = constraints.maxWidth < 260 || constraints.maxHeight < 200;
      final compactHeight = constraints.maxHeight < 200;
      return Center(
        child: Padding(
          padding: EdgeInsets.all(compactHeight ? 8 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension_outlined,
                size: compactHeight ? 30 : 40,
                color: context.palette.mutedText,
              ),
              SizedBox(height: compactHeight ? 6 : 12),
              Text(
                context.l10n.textSelectAnExtension410,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.text),
              ),
              if (!narrow) ...[
                const SizedBox(height: 5),
                Text(
                  context.l10n.textChooseAnExtensionFromTheSidebarTo417,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.mutedText),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
