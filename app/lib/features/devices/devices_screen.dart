import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';

import '../common/widgets.dart';

class _DeviceEntry {
  const _DeviceEntry({
    required this.name,
    required this.kind,
    required this.available,
    required this.description,
  });

  final String name;
  final String kind;
  final bool available;
  final String description;
}

/// HAL/devices screen: virtual sources now, real boards via HAL later.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final Map<String, bool> _connected = <String, bool>{};

  static const List<_DeviceEntry> _entries = <_DeviceEntry>[
    _DeviceEntry(
      name: 'Симулятор ЭЭГ',
      kind: 'virtual',
      available: true,
      description:
          'Встроенный генератор сигнала (256 Гц, 8 каналов). '
          'Используется для разработки без железа.',
    ),
    _DeviceEntry(
      name: 'ADS1299-совместимая плата',
      kind: 'serial',
      available: false,
      description:
          'Первый реальный HAL-драйвер (USB/serial). Требуется '
          'прошивка с потоковой передачей.',
    ),
    _DeviceEntry(
      name: 'LSL-источник',
      kind: 'lsl',
      available: false,
      description: 'Подключение к любому Lab Streaming Layer-потоку в сети.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        ScreenHeader(
          title: context.l10n.textDevices38,
          subtitle:
              context.l10n.textHardwareAbstractionLayerV01VirtualSources262,
        ),
        for (final _DeviceEntry entry in _entries)
          Card(
            child: ListTile(
              trailing: DesktopToggle(
                value: _connected[entry.name] ?? false,
                onChanged: entry.available
                    ? (bool value) =>
                          setState(() => _connected[entry.name] = value)
                    : null,
              ),
              title: Text(context.hostLabel(entry.name)),
              subtitle: Text(
                '${entry.kind} · ${entry.kind == 'virtual'
                    ? context.l10n.deviceSimulatorDescription
                    : entry.kind == 'serial'
                    ? context.l10n.deviceBoardDescription
                    : context.hostLabel(entry.description)}',
              ),
              leading: Icon(switch (entry.kind) {
                'virtual' => AppIcons.cpu,
                'serial' => AppIcons.usb,
                _ => AppIcons.signal,
              }),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.textHALRoadmapV02263,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                KeyValue(
                  keyLabel: context.hostLabel('Нормализация'),
                  value: context.hostLabel('сырой сигнал → μV, масштаб платы'),
                ),
                KeyValue(
                  keyLabel: context.hostLabel('Импеданс'),
                  value: context.hostLabel('процедура калибровки контактов'),
                ),
                KeyValue(
                  keyLabel: context.hostLabel('Hot-plug'),
                  value: context.hostLabel('детекция подключения/отключения'),
                ),
                KeyValue(
                  keyLabel: context.hostLabel('Частота/каналы'),
                  value: context.hostLabel('управление конфигурацией платы'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
