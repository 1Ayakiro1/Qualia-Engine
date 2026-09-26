import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/log_window.dart';
import '../../core/modules/module_registry.dart';
import '../../state/app_state.dart';
import '../../state/engine_provider.dart';
import '../../state/engine_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../datasets/datasets_screen.dart';
import '../developer/developer_screen.dart';
import '../devices/devices_screen.dart';
import '../models/models_screen.dart';
import '../modules/modules_screen.dart';
import '../pipeline/pipeline_screen.dart';
import '../session/session_screen.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_screen.dart';
import 'nav_registry.dart';

IconData _phosphorFor(SectionId id) {
  switch (id) {
    case SectionId.dashboard:
      return Icons.grid_view_outlined;
    case SectionId.devices:
      return Icons.usb_outlined;
    case SectionId.session:
      return Icons.radio_button_checked_outlined;
    case SectionId.pipeline:
      return Icons.account_tree_outlined;
    case SectionId.spectrogram:
      return Icons.graphic_eq;
    case SectionId.modules:
      return Icons.extension_outlined;
    case SectionId.datasets:
      return Icons.folder_open_outlined;
    case SectionId.models:
      return Icons.psychology_outlined;
    case SectionId.developer:
      return Icons.terminal;
    case SectionId.settings:
      return Icons.settings_outlined;
  }
}

/// Desktop IDE-like shell. Navigation is deliberately split into a compact
/// activity rail and an Explorer pane so the work area stays uncluttered.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool terminalOpen = true;
  bool modeSwitcherOpen = false;

  Future<void> _openDebugConsole(BuildContext context) async {
    try {
      await openLogConsole();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть консоль: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final section = ref.watch(navSectionProvider);
    final engine = ref.watch(engineProvider);
    final sections = visibleSections(mode);
    final selected = sections.indexWhere((item) => item.id == section);
    final active = selected < 0 ? sections.first : sections[selected];

    return Scaffold(
      body: Column(
        children: [
          _TitleBar(
            mode: mode,
            engine: engine,
            onModeChanged: (value) =>
                ref.read(appModeProvider.notifier).setMode(value),
            onRun: () =>
                ref.read(navSectionProvider.notifier).select(SectionId.session),
            onOpenDebugConsole: () => _openDebugConsole(context),
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    _ActivityRail(
                      sections: sections,
                      selected: selected < 0 ? 0 : selected,
                      modeSwitcherOpen: modeSwitcherOpen,
                      onSelected: (index) => ref
                          .read(navSectionProvider.notifier)
                          .select(sections[index].id),
                      onModeSwitcher: () =>
                          setState(() => modeSwitcherOpen = !modeSwitcherOpen),
                    ),
                    _Explorer(
                      sections: sections,
                      selected: selected < 0 ? 0 : selected,
                      onSelected: (index) => ref
                          .read(navSectionProvider.notifier)
                          .select(sections[index].id),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _EditorTabs(active: active),
                          Expanded(child: _SectionBody(section: active.id)),
                          _TerminalPanel(
                            open: terminalOpen,
                            onToggle: () =>
                                setState(() => terminalOpen = !terminalOpen),
                            onOpenWindow: () => _openDebugConsole(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (modeSwitcherOpen)
                  Positioned(
                    left: 56,
                    bottom: 54,
                    child: _ModeSwitcherPanel(
                      current: mode,
                      onSelected: (value) {
                        ref.read(appModeProvider.notifier).setMode(value);
                        setState(() => modeSwitcherOpen = false);
                      },
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

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.mode,
    required this.engine,
    required this.onModeChanged,
    required this.onRun,
    required this.onOpenDebugConsole,
  });
  final AppMode mode;
  final EngineState engine;
  final ValueChanged<AppMode> onModeChanged;
  final VoidCallback onRun;
  final VoidCallback onOpenDebugConsole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 1100;
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF3A3A3A))),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 0,
            height: 0,
            child: Text('Ayakiro BCI Engine'),
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Image.asset('assets/icons/bci_engine_64.png'),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: const Color(0xFF3C3C3C)),
          const SizedBox(width: 8),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'ENGINE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (!compact) ...[
            const Spacer(),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TopMenuItem(label: 'File'),
                  _TopMenuItem(label: 'Edit'),
                  _TopMenuItem(label: 'View'),
                  _TopMenuItem(label: 'Build'),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 320,
              height: 26,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search files, symbols...  (Ctrl+P)',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  filled: true,
                  fillColor: const Color(0xFF3C3C3C),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF555555)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF61B5FF)),
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onOpenDebugConsole,
              tooltip: 'Открыть терминал отладки',
              icon: const Icon(Icons.bug_report_outlined, size: 17),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2D2D2D),
                foregroundColor: Colors.white70,
                minimumSize: const Size(28, 28),
                maximumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Spacer(),
          ] else
            const Spacer(),
          Icon(
            Icons.circle,
            size: 8,
            color: engine.isOnline ? Colors.tealAccent : Colors.orange,
          ),
          const SizedBox(width: 7),
          Text(
            engine.isOnline ? 'Engine online' : 'Engine offline',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          PopupMenuButton<AppMode>(
            tooltip: 'Режим приложения',
            onSelected: onModeChanged,
            itemBuilder: (_) => [
              for (final item in AppMode.values)
                PopupMenuItem(value: item, child: Text(item.label)),
            ],
            child: Chip(
              label: Text(mode.label),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onRun,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Run'),
            style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TopMenuItem extends StatelessWidget {
  const _TopMenuItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Colors.white60),
      ),
    ),
  );
}

class _ActivityRail extends StatelessWidget {
  const _ActivityRail({
    required this.sections,
    required this.selected,
    required this.modeSwitcherOpen,
    required this.onSelected,
    required this.onModeSwitcher,
  });
  final List<NavSection> sections;
  final int selected;
  final bool modeSwitcherOpen;
  final ValueChanged<int> onSelected;
  final VoidCallback onModeSwitcher;

  @override
  Widget build(BuildContext context) {
    const railItems = <NavSection>[
      NavSection(
        id: SectionId.dashboard,
        label: 'Обзор',
        icon: Icons.folder_open_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.devices,
        label: 'Устройства',
        icon: Icons.search,
        modes: {},
      ),
      NavSection(
        id: SectionId.modules,
        label: 'Модули',
        icon: Icons.extension_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.pipeline,
        label: 'Конвейер',
        icon: Icons.account_tree_outlined,
        modes: {},
      ),
      NavSection(
        id: SectionId.developer,
        label: 'Разработчик',
        icon: Icons.bug_report_outlined,
        modes: {},
      ),
    ];

    void select(SectionId id) {
      final index = sections.indexWhere((item) => item.id == id);
      if (index >= 0) onSelected(index);
    }

    return Container(
      width: 48,
      color: const Color(0xFF202020),
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final item in railItems)
            _RailButton(
              item: item,
              active: item.id == sections[selected].id,
              enabled: sections.any((section) => section.id == item.id),
              onTap: () => select(item.id),
            ),
          const Spacer(),
          _RailButton(
            item: const NavSection(
              id: SectionId.session,
              label: 'Режим пользователя',
              icon: Icons.person_outline,
              modes: {},
            ),
            active: modeSwitcherOpen,
            enabled: true,
            onTap: onModeSwitcher,
          ),
          const SizedBox(height: 2),
          _RailButton(
            item: const NavSection(
              id: SectionId.settings,
              label: 'Настройки',
              icon: Icons.settings_outlined,
              modes: {},
            ),
            active: sections[selected].id == SectionId.settings,
            enabled: true,
            onTap: () => select(SectionId.settings),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.enabled,
    required this.onTap,
  });
  final NavSection item;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: item.label,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2D2D2D) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: active
              ? const Border(
                  left: BorderSide(color: Color(0xFF61B5FF), width: 2),
                )
              : null,
        ),
        child: Center(
          child: Icon(
            item.icon,
            size: 20,
            color: active
                ? const Color(0xFF61B5FF)
                : enabled
                ? Colors.white54
                : Colors.white24,
          ),
        ),
      ),
    ),
  );
}

class _Explorer extends StatelessWidget {
  const _Explorer({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });
  final List<NavSection> sections;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: ColoredBox(
        color: const Color(0xFF252526),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
              child: Row(
                children: [
                  Text(
                    'EXPLORER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.add, size: 17),
                  const SizedBox(width: 7),
                  const Icon(Icons.create_new_folder_outlined, size: 17),
                  const SizedBox(width: 7),
                  const Icon(Icons.refresh, size: 16),
                  const SizedBox(width: 7),
                  const Icon(Icons.more_horiz, size: 18),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExplorerHeading(
                      title: 'ACTIVE MODULES',
                      icon: Icons.expand_more,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search modules...',
                          prefixIcon: const Icon(Icons.search, size: 17),
                          filled: true,
                          fillColor: const Color(0xFF3C3C3C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    for (final module
                        in kSystemModules.where((item) => item.active).take(8))
                      _ModuleItem(module: module),
                    const Divider(height: 18),
                    _ExplorerHeading(
                      title: 'MODULE CATALOG',
                      icon: Icons.expand_more,
                    ),
                    for (final module
                        in kSystemModules.where((item) => !item.active).take(4))
                      _ModuleItem(module: module, catalog: true),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'NerveGears Engine 0.2.2',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerHeading extends StatelessWidget {
  const _ExplorerHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 3),
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: .8,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    ),
  );
}

class _ModuleItem extends StatelessWidget {
  const _ModuleItem({required this.module, this.catalog = false});
  final SystemModule module;
  final bool catalog;

  IconData get _icon {
    if (catalog) {
      return switch (module.category) {
        'feature' => Icons.auto_graph_outlined,
        'inference' => Icons.psychology_outlined,
        _ => Icons.extension_outlined,
      };
    }
    return switch (module.category) {
      'acquisition' => Icons.bolt_outlined,
      'dsp' => Icons.layers_outlined,
      'feature' => Icons.memory_outlined,
      'utility' => Icons.inventory_2_outlined,
      'output' => Icons.storage_outlined,
      _ => Icons.extension_outlined,
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
    child: SizedBox(
      height: 28,
      child: Row(
        children: [
          Icon(
            _icon,
            size: 14,
            color: catalog ? Colors.white38 : const Color(0xFF4EC9B0),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              module.name,
              style: TextStyle(
                color: catalog ? Colors.white54 : Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!catalog)
            Icon(
              Icons.circle,
              size: 6,
              color: module.active ? const Color(0xFF4EC9B0) : Colors.white24,
            ),
          if (catalog)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF094771),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'v${module.version}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CDCFE)),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ModeSwitcherPanel extends StatelessWidget {
  const _ModeSwitcherPanel({required this.current, required this.onSelected});

  final AppMode current;
  final ValueChanged<AppMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border.all(color: const Color(0xFF3C3C3C)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'change mode',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            for (final mode in AppMode.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Tooltip(
                  message: '${mode.label}: ${mode.hint}',
                  child: InkWell(
                    onTap: () => onSelected(mode),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: current == mode
                            ? const Color(0xFF303030)
                            : const Color(0xFF292929),
                        borderRadius: BorderRadius.circular(12),
                        border: current == mode
                            ? Border.all(color: const Color(0xFF61B5FF))
                            : null,
                      ),
                      child: Icon(
                        switch (mode) {
                          AppMode.consumer => Icons.person_outline,
                          AppMode.researcher => Icons.science_outlined,
                          AppMode.developer => Icons.code_outlined,
                        },
                        size: 27,
                        color: current == mode
                            ? const Color(0xFF61B5FF)
                            : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({required this.active});
  final NavSection active;
  @override
  Widget build(BuildContext context) => Container(
    height: 35,
    color: const Color(0xFF202020),
    child: Row(
      children: [
        Container(
          width: 205,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF292929),
            border: Border(top: BorderSide(color: Color(0xFF61B5FF))),
          ),
          child: Row(
            children: [
              Icon(
                _phosphorFor(active.id),
                size: 15,
                color: const Color(0xFF8ABEFF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(active.label, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.close, size: 14, color: Colors.white38),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.view_sidebar_outlined,
            size: 17,
            color: Colors.white54,
          ),
        ),
      ],
    ),
  );
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.open,
    required this.onToggle,
    required this.onOpenWindow,
  });
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpenWindow;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: open ? 200 : 32,
    color: const Color(0xFF1E1E1E),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              InkWell(
                onTap: onToggle,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'TERMINAL',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Text(
                'OUTPUT',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenWindow,
                tooltip: 'Открыть отдельное окно',
                icon: const Icon(Icons.open_in_new, size: 16),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        if (open)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(15, 3, 10, 8),
              child: SelectableText(
                'engine ~/project % npm run build\n> engine@0.2.2 build\n> Compiling core modules...\n[BUILD] core-renderer v2.4kb  ✓\n[BUILD] physics-engine v8.1kb  ✓\n[BUILD] Done in 1.34s ✓',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF7DCB9B),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final SectionId section;
  @override
  Widget build(BuildContext context) {
    switch (section) {
      case SectionId.dashboard:
        return const DashboardScreen();
      case SectionId.devices:
        return const DevicesScreen();
      case SectionId.session:
        return const SessionScreen();
      case SectionId.pipeline:
        return const PipelineScreen();
      case SectionId.spectrogram:
        return const SpectrogramScreen();
      case SectionId.modules:
        return const ModulesScreen();
      case SectionId.datasets:
        return const DatasetsScreen();
      case SectionId.models:
        return const ModelsScreen();
      case SectionId.developer:
        return const DeveloperScreen();
      case SectionId.settings:
        return const SettingsScreen();
    }
  }
}
