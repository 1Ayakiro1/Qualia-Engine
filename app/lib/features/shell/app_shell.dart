import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'top_bar.dart';

/// App window shell: navigation rail + top bar + active screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppMode mode = ref.watch(appModeProvider);
    final SectionId section = ref.watch(navSectionProvider);
    final EngineState engine = ref.watch(engineProvider);
    final List<NavSection> sections = visibleSections(mode);
    final int selectedIndex = sections.indexWhere((NavSection s) => s.id == section);
    final bool wide = MediaQuery.of(context).size.width >= 1500;

    return Scaffold(
      appBar: ShellTopBar(mode: mode, engine: engine),
      body: Row(
        children: [
          ScrollConfiguration(
            behavior: const _NoGlowScrollBehavior(),
            child: NavigationRail(
              extended: wide,
              minExtendedWidth: 216,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) {
                ref.read(navSectionProvider.notifier).select(sections[index].id);
              },
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Image.asset(
                  'assets/icons/bci_engine_64.png',
                  width: 40,
                  height: 40,
                ),
              ),
              destinations: <NavigationRailDestination>[
                for (final NavSection s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    selectedIcon: Icon(s.icon),
                    label: Text(s.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _SectionBody(section: section)),
        ],
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
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
