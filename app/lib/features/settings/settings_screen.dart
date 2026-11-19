import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';

import 'package:flutter/material.dart';

import 'dart:io';

import '../common/desktop_focus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../../core/privacy/privacy_preferences.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/render/render_preferences.dart';
import '../../state/render_preferences.dart';
import 'keyboard_shortcuts_panel.dart';
import '../../l10n/locale_controller.dart';
import '../../state/engine_provider.dart';
import '../../core/auth/auth_service.dart';
import '../common/widgets.dart';

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
  bool crashReports = false;
  bool metrics = false;
  bool externalData = false;
  bool _privacyLoaded = false;
  late String selectedItem = widget.initialItem;

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItem != widget.initialItem) {
      selectedItem = widget.initialItem;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    final privacy = PrivacyPreferences.instance;
    try {
      await privacy.load();
    } catch (_) {
      logW(LogSource.settings, 'не удалось загрузить настройки приватности');
      return;
    }
    if (!mounted) return;
    setState(() {
      crashReports = privacy.crashReports;
      metrics = privacy.metrics;
      externalData = privacy.externalData;
      _privacyLoaded = true;
    });
  }

  Future<void> _savePrivacy(Future<void> Function() save) async {
    if (!_privacyLoaded) return;
    setState(() => _privacyLoaded = false);
    try {
      await save();
    } catch (_) {
      logW(LogSource.settings, 'не удалось сохранить настройки приватности');
    } finally {
      if (mounted) {
        final privacy = PrivacyPreferences.instance;
        setState(() {
          crashReports = privacy.crashReports;
          metrics = privacy.metrics;
          externalData = privacy.externalData;
          _privacyLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final version = context.l10n.versionLabel(
      AppInfo.appName,
      AppInfo.version,
      engine.coreVersion.isEmpty ? '—' : engine.coreVersion,
      engine.abiVersion,
    );
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
                onSelected: (value) {
                  setState(() => selectedItem = value);
                  logI(LogSource.settings, 'страница настроек: $value');
                },
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
                crashReports: crashReports,
                metrics: metrics,
                externalData: externalData,
                privacyLoaded: _privacyLoaded,
                onWorkspaceAccessChanged: (value) {
                  setState(() => workspaceAccess = value);
                  logI(
                    LogSource.settings,
                    'доступ к рабочему пространству: ${value ? 'вкл' : 'выкл'}',
                  );
                },
                onFullAccessChanged: (value) {
                  setState(() => fullAccess = value);
                  logI(
                    LogSource.settings,
                    'полный доступ: ${value ? 'вкл' : 'выкл'}',
                  );
                },
                onKeepAwakeChanged: (value) {
                  setState(() => keepAwake = value);
                  logI(
                    LogSource.settings,
                    'не выключать экран: ${value ? 'вкл' : 'выкл'}',
                  );
                },
                onBottomPanelChanged: (value) {
                  setState(() => bottomPanel = value);
                  logI(
                    LogSource.settings,
                    'нижняя панель: ${value ? 'вкл' : 'выкл'}',
                  );
                },
                onCrashReportsChanged: (value) => _savePrivacy(
                  () => PrivacyPreferences.instance.setCrashReports(value),
                ),
                onMetricsChanged: (value) => _savePrivacy(
                  () => PrivacyPreferences.instance.setMetrics(value),
                ),
                onExternalDataChanged: (value) => _savePrivacy(() async {
                  await PrivacyPreferences.instance.setExternalData(value);
                  if (value) {
                    try {
                      await AuthService.instance.initialize();
                      if (mounted) ref.invalidate(authUserProvider);
                    } catch (_) {
                      logW(
                        LogSource.settings,
                        'внешние интеграции не запущены',
                      );
                    }
                  }
                }),
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
    ('General', AppIcons.settings),
    ('Import', AppIcons.download),
    ('Appearance', AppIcons.sun),
    ('Language', AppIcons.globe),
    ('Voice', AppIcons.microphone),
    ('Configuration', AppIcons.shieldCheck),
    ('Privacy', AppIcons.shieldCheck),
    ('Personalization', AppIcons.history),
    ('Navigation', AppIcons.cursor),
    ('Performance', AppIcons.cpu),
    ('Account', AppIcons.userCircle),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.background,
    child: ScrollConfiguration(
      behavior: const _NoGlow(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 28),
        children: [
          _SidebarBackButton(onPressed: onBack),
          const SizedBox(height: 16),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.palette.panel,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.search, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration.collapsed(
                      hintText: context.l10n.textSearch367,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SidebarGroup(
            title: context.l10n.textPersonal368,
            items: _personal,
            selected: selected,
            onSelected: onSelected,
          ),
          const SizedBox(height: 22),
          Text(
            context.l10n.textArchived369,
            style: TextStyle(color: context.palette.mutedText),
          ),
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
    label: context.l10n.textBackToApp370,
    icon: AppIcons.arrowBack,
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
        child: Text(title, style: TextStyle(color: context.palette.mutedText)),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _PreferenceNavButton(
            label: item.$1,
            icon: item.$2,
            selected: selected == item.$1,
            trailing: item.$1 == 'Account'
                ? Icon(
                    AppIcons.arrowUpRight,
                    size: 15,
                    color: context.palette.mutedText,
                  )
                : null,
            onTap: () => onSelected(item.$1),
          ),
        ),
    ],
  );
}

class _PreferencesContent extends ConsumerWidget {
  const _PreferencesContent({
    required this.version,
    required this.selectedItem,
    required this.workspaceAccess,
    required this.fullAccess,
    required this.keepAwake,
    required this.bottomPanel,
    required this.crashReports,
    required this.metrics,
    required this.externalData,
    required this.privacyLoaded,
    required this.onWorkspaceAccessChanged,
    required this.onFullAccessChanged,
    required this.onKeepAwakeChanged,
    required this.onBottomPanelChanged,
    required this.onCrashReportsChanged,
    required this.onMetricsChanged,
    required this.onExternalDataChanged,
  });

  final String version;
  final String selectedItem;
  final bool workspaceAccess;
  final bool fullAccess;
  final bool keepAwake;
  final bool bottomPanel;
  final bool crashReports;
  final bool metrics;
  final bool externalData;
  final bool privacyLoaded;
  final ValueChanged<bool> onWorkspaceAccessChanged;
  final ValueChanged<bool> onFullAccessChanged;
  final ValueChanged<bool> onKeepAwakeChanged;
  final ValueChanged<bool> onBottomPanelChanged;
  final ValueChanged<bool> onCrashReportsChanged;
  final ValueChanged<bool> onMetricsChanged;
  final ValueChanged<bool> onExternalDataChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedItem == 'Language') {
      final language =
          ref.watch(localeProvider)?.languageCode ??
          Localizations.localeOf(context).languageCode;
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(context.l10n.textLanguage382, style: TextStyle(fontSize: 30)),
          const SizedBox(height: 16),
          Text(context.l10n.chooseLanguage),
          const SizedBox(height: 24),
          DesktopPane(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final item in [
                    ('ru', context.l10n.russianLanguage),
                    ('en', context.l10n.englishLanguage),
                  ])
                    DesktopHoverTile(
                      key: ValueKey('language ${item.$1}'),
                      onTap: () =>
                          ref.read(localeProvider.notifier).select(item.$1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(AppIcons.globe, size: 18),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.$2)),
                            if (language == item.$1)
                              const Icon(AppIcons.check, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (selectedItem == 'Navigation') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 38),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: KeyboardShortcutsPanel(key: ValueKey(selectedItem)),
        ),
      );
    }
    if (selectedItem == 'Privacy') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 80),
        children: [
          Text(
            context.l10n.privacyDataTitle,
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.privacyDataDescription,
            style: TextStyle(color: context.palette.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _SettingsCard(
            children: [
              _PreferenceRow(
                title: context.l10n.privacyCrashReports,
                description: context.l10n.privacyCrashReportsDescription,
                control: DesktopToggle(
                  value: privacyLoaded && crashReports,
                  onChanged: privacyLoaded ? onCrashReportsChanged : null,
                ),
              ),
              _PreferenceRow(
                title: context.l10n.privacyMetrics,
                description: context.l10n.privacyMetricsDescription,
                control: DesktopToggle(
                  value: privacyLoaded && metrics,
                  onChanged: privacyLoaded ? onMetricsChanged : null,
                ),
              ),
              _PreferenceRow(
                title: context.l10n.privacyExternalData,
                description: context.l10n.privacyExternalDataDescription,
                control: DesktopToggle(
                  value: privacyLoaded && externalData,
                  onChanged: privacyLoaded ? onExternalDataChanged : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DesktopPane(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.info, color: context.palette.mutedText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.privacyOutboundLog,
                      style: TextStyle(color: context.palette.mutedText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (selectedItem == 'Performance') {
      final render = ref.watch(renderPreferencesProvider);
      final controller = ref.read(renderPreferencesProvider.notifier);
      return ListView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 80),
        children: [
          Text(
            context.hostLabel('Performance'),
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.renderDescription,
            style: TextStyle(color: context.palette.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _SettingsCard(
            children: [
              if (Platform.isLinux)
                _PreferenceRow(
                  title: context.l10n.renderBackend,
                  description: context.l10n.renderBackendDescription,
                  extra: Text(context.l10n.renderRestart),
                  control: _PreferenceDropdown<RenderBackend>(
                    value: render.backend,
                    values: RenderBackend.values,
                    label: (value) => switch (value) {
                      RenderBackend.auto => context.l10n.renderAuto,
                      RenderBackend.skia => 'Skia',
                      RenderBackend.impeller => 'Impeller',
                    },
                    onChanged: (value) => controller.update(backend: value),
                  ),
                ),
              _PreferenceRow(
                title: context.l10n.renderQuality,
                description: context.l10n.renderQualityDescription,
                control: _PreferenceDropdown<RenderQuality>(
                  value: render.quality,
                  values: RenderQuality.values,
                  label: (value) => switch (value) {
                    RenderQuality.low => context.hostLabel('Performance'),
                    RenderQuality.balanced => context.l10n.renderBalanced,
                    RenderQuality.high => context.l10n.renderHigh,
                  },
                  onChanged: (value) => controller.update(quality: value),
                ),
              ),
              _PreferenceRow(
                title: context.l10n.renderFrameRate,
                description: context.l10n.renderFrameRateDescription,
                control: _PreferenceDropdown<int>(
                  value: render.frameRate,
                  values: const [0, 30, 60, 90, 120, 144, 165, 240],
                  label: (value) =>
                      value == 0 ? context.l10n.renderAuto : '$value FPS',
                  onChanged: (value) => controller.update(frameRate: value),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (selectedItem != 'General') {
      return Center(
        child: Text(
          '${context.hostLabel(selectedItem)} 1',
          style: TextStyle(fontSize: 30, color: context.palette.text),
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
                Text(
                  context.l10n.textGeneral68,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 54),
                Text(
                  context.l10n.textPermissions371,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 22),
                _SettingsCard(
                  children: [
                    _PreferenceRow(
                      title: context.l10n.textDefaultPermissions372,
                      description:
                          context.l10n.textByDefaultAyakiroCanReadAndEdit373,
                      control: DesktopToggle(
                        value: workspaceAccess,
                        onChanged: onWorkspaceAccessChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textFullAccess374,
                      description:
                          context.l10n.textWhenAyakiroRunsWithFullAccessIt375,
                      extra: Text(
                        context.l10n.textLearnMoreAboutElevatedRisks376,
                        style: TextStyle(color: context.palette.text),
                      ),
                      control: DesktopToggle(
                        value: fullAccess,
                        onChanged: onFullAccessChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 66),
                Text(
                  context.l10n.textGeneral68,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 22),
                _SettingsCard(
                  children: [
                    _PreferenceRow(
                      title: context.l10n.textProjectlessTaskFolder377,
                      description: context
                          .l10n
                          .textTheLocationWhereTasksStartedOutsideOf378,
                      control: _ActionButton(
                        label: '/home/ayakiro...uments/Codex',
                        action: context.l10n.textChange379,
                      ),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textDefaultFileOpenDestination380,
                      description:
                          context.l10n.textWhereFilesAndFoldersOpenByDefault381,
                      control: _DropButton(label: 'Zed'),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textLanguage382,
                      description: context.l10n.textLanguageForTheAppUI383,
                      control: DesktopMenuButton<String>(
                        tooltip: context.l10n.textLanguage382,
                        onSelected: (code) =>
                            ref.read(localeProvider.notifier).select(code),
                        entries: [
                          DesktopMenuEntry(
                            value: 'ru',
                            label: context.l10n.russianLanguage,
                          ),
                          DesktopMenuEntry(
                            value: 'en',
                            label: context.l10n.englishLanguage,
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            (ref.watch(localeProvider)?.languageCode ??
                                        Localizations.localeOf(context)
                                            .languageCode) ==
                                    'ru'
                                ? context.l10n.russianLanguage
                                : context.l10n.englishLanguage,
                          ),
                        ),
                      ),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textBottomPanel385,
                      description:
                          context.l10n.textShowTheBottomPanelControlInThe386,
                      control: DesktopToggle(
                        value: bottomPanel,
                        onChanged: onBottomPanelChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textPreventSleepWhileRunning387,
                      description: context
                          .l10n
                          .textKeepYourComputerAwakeWhileAyakiroIs388,
                      control: DesktopToggle(
                        value: keepAwake,
                        onChanged: onKeepAwakeChanged,
                      ),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textOpenSourceLicenses389,
                      description: context
                          .l10n
                          .textThirdPartySoftwareUsedByAyakiroBCI390,
                      control: _DropButton(label: context.l10n.textView62),
                    ),
                    _PreferenceRow(
                      title: context.l10n.textVersion207,
                      description: context.l10n.textCurrentApplicationBuild391,
                      control: Text(
                        version,
                        style: TextStyle(color: context.palette.mutedText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text(
                  context.l10n.textArg0LocalOfflineFirstMode392(
                    (AppInfo.appName).toString(),
                  ),
                  style: TextStyle(color: context.palette.mutedText),
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
    child: DesktopFocusableAction(
      onActivate: widget.onTap,
      label: context.hostLabel(widget.label),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.hoverCurve,
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? context.palette.hover
                : _hovered
                ? context.palette.hover.withAlpha(130)
                : context.palette.hover.withAlpha(0),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.resolve(widget.icon, active: widget.selected),
                size: 18,
                color: context.palette.text,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.hostLabel(widget.label),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
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
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(16),
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
            style: TextStyle(color: context.palette.mutedText, fontSize: 13),
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
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: control,
                    ),
                  ),
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
    icon: const Icon(AppIcons.caretsUpDown, size: 17),
    label: Text(label),
  );
}

class _PreferenceDropdown<T> extends StatelessWidget {
  const _PreferenceDropdown({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DesktopMenuButton<T>(
    tooltip: label(value),
    entries: [
      for (final item in values)
        DesktopMenuEntry<T>(value: item, label: label(item)),
    ],
    onSelected: onChanged,
    child: _DropButton(label: label(value)),
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
          style: TextStyle(
            color: context.palette.mutedText,
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
