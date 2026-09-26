import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../state/engine_state.dart';

/// Settings page intentionally follows the dense, desktop-first reference UI.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool workspaceAccess = true;
  bool fullAccess = true;
  bool keepAwake = false;
  bool bottomPanel = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = ref.watch(versionLabelProvider);
    return ScrollConfiguration(
      behavior: const _NoGlow(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 34, 34, 70),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройки',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 42),
                _Group(
                  title: 'Разрешения',
                  children: [
                    _SettingRow(
                      title: 'Разрешения по умолчанию',
                      description: 'По умолчанию NerveGears может читать и изменять файлы в рабочей области.',
                      control: Switch(
                        value: workspaceAccess,
                        onChanged: (v) => setState(() => workspaceAccess = v),
                      ),
                    ),
                    _SettingRow(
                      title: 'Полный доступ',
                      description: 'Разрешает движку изменять любые файлы и запускать команды без дополнительного запроса.',
                      extra: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Риск зависит от источника задачи. ',
                            ),
                            TextSpan(
                              text: 'Подробнее',
                              style: TextStyle(color: AppTheme.text),
                            ),
                          ],
                        ),
                      ),
                      control: Switch(
                        value: fullAccess,
                        onChanged: (v) => setState(() => fullAccess = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 42),
                _Group(
                  title: 'Основные',
                  children: [
                    _SettingRow(
                      title: 'Папка задач вне проектов',
                      description: 'Место, где хранятся данные задач, запущенных вне проектов.',
                      trailing: _ActionButton(
                        label: '/home/ayakiro/Documents/Projects',
                        action: 'Изменить',
                      ),
                    ),
                    _SettingRow(
                      title: 'Назначение открытия файлов',
                      description: 'Приложение, в котором по умолчанию открываются файлы и папки.',
                      trailing: _DropButton(label: 'Системное'),
                    ),
                    _SettingRow(
                      title: 'Язык',
                      description: 'Язык интерфейса приложения',
                      trailing: _DropButton(label: 'Русский'),
                    ),
                    _SettingRow(
                      title: 'Нижняя панель',
                      description: 'Показывать управление нижней панелью в заголовке приложения.',
                      control: Switch(
                        value: bottomPanel,
                        onChanged: (v) => setState(() => bottomPanel = v),
                      ),
                    ),
                    _SettingRow(
                      title: 'Не выключать экран во время работы',
                      description: 'Не переводить компьютер в спящий режим во время выполнения задачи.',
                      control: Switch(
                        value: keepAwake,
                        onChanged: (v) => setState(() => keepAwake = v),
                      ),
                    ),
                    _SettingRow(
                      title: 'Версия приложения',
                      description: 'Текущая сборка движка',
                      trailing: Text(
                        version,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 42),
                _Group(
                  title: 'О приложении',
                  children: [
                    _SettingRow(
                      title: 'Лицензии и данные',
                      description:
                          '${AppInfo.appName} · локальный offline-first режим',
                      trailing: _DropButton(label: 'Просмотреть'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF383838)),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.description,
    this.control,
    this.trailing,
    this.extra,
  });
  final String title, description;
  final Widget? control, trailing, extra;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              if (extra != null) ...[const SizedBox(height: 3), extra!],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        if (control != null) ...[const SizedBox(width: 14), control!],
      ],
    ),
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
  final String label, action;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(color: Colors.white54, fontFamily: 'monospace'),
      ),
      const SizedBox(width: 12),
      OutlinedButton(onPressed: () {}, child: Text(action)),
    ],
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
