import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/engine_provider.dart';
import '../../core/native/engine_bindings.dart';
import '../../state/lsl_source.dart';

import 'dart:isolate';

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
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final Map<String, bool> _connected = <String, bool>{};
  List<LslStreamDescriptor> _lslStreams = const <LslStreamDescriptor>[];
  bool _lslChecked = false;
  bool _busy = false;
  String? _lslError;

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
  void initState() {
    super.initState();
    // Discovery is explicit: opening this page must not scan the network.
  }

  Future<void> _discoverLsl() async {
    if (_busy) return;
    final bindings = ref.read(engineProvider.notifier).bindings;
    if (bindings == null || !bindings.lslAvailable) {
      if (mounted) {
        setState(() {
          _lslChecked = true;
          _lslError = context.l10n.lslUnavailable;
        });
      }
      return;
    }
    setState(() {
      _busy = true;
      _lslError = null;
    });
    try {
      final path = bindings.path;
      final streams = await _discoverStreams(path);
      if (mounted) {
        setState(() {
          _lslStreams = streams;
          _lslChecked = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _lslChecked = true;
          _lslError = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLsl(LslStreamDescriptor stream, bool enabled) async {
    final source = ref.read(lslSourceProvider);
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await source.stop();
        if (!await source.start(stream) && mounted) {
          setState(
            () => _lslError = source.lastError ?? context.l10n.lslOpenFailed,
          );
        }
      } else {
        await source.stop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lslError ??
                            (_busy
                                ? context.l10n.lslSearching
                                : _lslChecked
                                ? context.l10n.lslFound(_lslStreams.length)
                                : context.l10n.lslDiscoveryHint),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _discoverLsl,
                      child: Text(context.l10n.lslDiscover),
                    ),
                  ],
                ),
                for (final stream in _lslStreams)
                  ListTile(
                    title: Text(stream.name),
                    subtitle: Text(
                      '${stream.type} · ${stream.channels} ch · '
                      '${stream.nominalRate} Hz · ${stream.sourceId}',
                    ),
                    trailing: DesktopToggle(
                      value:
                          ref.read(lslSourceProvider)?.active?.sourceId ==
                          stream.sourceId,
                      onChanged:
                          _busy ||
                              stream.sourceId.isEmpty ||
                              stream.channels < 1 ||
                              stream.channels > 256 ||
                              stream.nominalRate <= 0
                          ? null
                          : (value) => _toggleLsl(stream, value),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<List<LslStreamDescriptor>> _discoverStreams(String path) =>
    Isolate.run(() => CoreBindings.open(path).discoverLsl());
