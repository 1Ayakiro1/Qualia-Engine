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
      description: 'Встроенный генератор сигнала (256 Гц, 8 каналов). '
          'Используется для разработки без железа.',
    ),
    _DeviceEntry(
      name: 'ADS1299-совместимая плата',
      kind: 'serial',
      available: false,
      description: 'Первый реальный HAL-драйвер (USB/serial). Требуется '
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
        const ScreenHeader(
          title: 'Устройства',
          subtitle: 'Hardware Abstraction Layer · v0.1 — виртуальные источники',
        ),
        for (final _DeviceEntry entry in _entries)
          Card(
            child: SwitchListTile(
              value: _connected[entry.name] ?? false,
              onChanged: entry.available
                  ? (bool value) => setState(() => _connected[entry.name] = value)
                  : null,
              title: Text(entry.name),
              subtitle: Text('${entry.kind} · ${entry.description}'),
              secondary: Icon(switch (entry.kind) {
                'virtual' => Icons.memory,
                'serial' => Icons.usb,
                _ => Icons.sensors,
              }),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Планы HAL (v0.2)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const KeyValue(keyLabel: 'Нормализация', value: 'сырой сигнал → μV, масштаб платы'),
                const KeyValue(keyLabel: 'Импеданс', value: 'процедура калибровки контактов'),
                const KeyValue(keyLabel: 'Hot-plug', value: 'детекция подключения/отключения'),
                const KeyValue(keyLabel: 'Частота/каналы', value: 'управление конфигурацией платы'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
