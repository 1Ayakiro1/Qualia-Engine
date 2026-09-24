import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/engine_provider.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../common/signal_gen.dart';
import '../common/widgets.dart';

class _SessionRecord {
  const _SessionRecord({
    required this.startedAt,
    required this.duration,
    required this.frames,
    required this.avgRms,
    required this.viaCore,
  });

  final DateTime startedAt;
  final Duration duration;
  final int frames;
  final double avgRms;
  final bool viaCore;
}

/// Live session with metrics; routes data through the C++ core when online.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final List<_SessionRecord> _history = <_SessionRecord>[];
  final SyntheticSignal _signal = SyntheticSignal();

  Timer? _timer;
  bool _running = false;
  DateTime? _startedAt;
  int _frames = 0;
  double _rms = 0;
  double _peakHz = 0;
  double _quality = 0;
  double _rmsSum = 0;
  int _metricSamples = 0;

  static const int _blockFrames = 64;
  static const int _popWindow = 256;
  Pointer<Float>? _inBuffer;
  Pointer<Float>? _outBuffer;

  bool get _coreOnline => ref.read(engineProvider).isOnline;

  @override
  void dispose() {
    _stopTimer();
    _freeBuffers();
    super.dispose();
  }

  void _freeBuffers() {
    final EngineController controller = ref.read(engineProvider.notifier);
    if (_inBuffer != null) {
      controller.freeSamples(_inBuffer!);
      _inBuffer = null;
    }
    if (_outBuffer != null) {
      controller.freeSamples(_outBuffer!);
      _outBuffer = null;
    }
  }

  void _start() {
    final bool viaCore = _coreOnline;
    if (viaCore) {
      final int? code =
          ref.read(engineProvider.notifier).start(sampleRate: 256, channels: 1);
      if (code == null || code != 0) {
        AppLogger.instance.log('session', 'старт не удался (код ${code ?? 'null'})',
            level: LogLevel.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Не удалось запустить ядро (код ${code ?? 'null'})')),
        );
        return;
      }
      final EngineController controller = ref.read(engineProvider.notifier);
      _inBuffer = controller.allocateSamples(_blockFrames);
      _outBuffer = controller.allocateSamples(_popWindow);
    } else {
      AppLogger.instance
          .log('session', 'сессия стартовала в Dart-симуляции (ядро офлайн)');
    }

    _signal.reset();
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
      _frames = 0;
      _rms = 0;
      _peakHz = 0;
      _quality = 0;
      _rmsSum = 0;
      _metricSamples = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _tick() {
    if (!_running) {
      return;
    }
    final List<double> block = _signal.take(_blockFrames);

    if (_coreOnline && _inBuffer != null && _outBuffer != null) {
      for (int i = 0; i < block.length; i++) {
        _inBuffer![i] = block[i];
      }
      final EngineController controller = ref.read(engineProvider.notifier);
      controller.pushSamples(_inBuffer!, _blockFrames, 1);
      final int? popped = controller.popSamplesInto(_outBuffer!, _popWindow, 1);
      final List<double>? metrics = controller.metrics();
      if (!mounted) {
        return;
      }
      setState(() {
        if (popped != null && popped > 0) {
          _frames += popped;
        }
        if (metrics != null) {
          _rms = metrics[0];
          _peakHz = metrics[1];
          _quality = metrics[2];
          _rmsSum += metrics[0];
          _metricSamples++;
        }
      });
    } else {
      double sum = 0;
      for (final double v in block) {
        sum += v * v;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _frames += block.length;
        _rms = math.sqrt(sum / block.length);
        _quality = _rms > 1e-4 ? 0.75 : 0.2;
      });
    }
  }

  void _stop() {
    final DateTime startedAt = _startedAt ?? DateTime.now();
    final bool wasCore = _coreOnline && _inBuffer != null;
    _history.insert(
      0,
      _SessionRecord(
        startedAt: startedAt,
        duration: DateTime.now().difference(startedAt),
        frames: _frames,
        avgRms: _metricSamples > 0 ? _rmsSum / _metricSamples : 0,
        viaCore: wasCore,
      ),
    );
    AppLogger.instance.log('session',
        'сессия завершена: $_frames кадров за ${DateTime.now().difference(startedAt).inSeconds} с (RMS ${(_metricSamples > 0 ? _rmsSum / _metricSamples : 0).toStringAsFixed(3)})');
    if (_coreOnline) {
      ref.read(engineProvider.notifier).stop();
    }
    _stopTimer();
    _freeBuffers();
    if (mounted) {
      setState(() => _running = false);
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _elapsed() {
    final DateTime? started = _startedAt;
    if (!_running || started == null) {
      return '00:00';
    }
    final Duration d = DateTime.now().difference(started);
    final String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool viaCore = _coreOnline;

    return ListView(
      children: [
        ScreenHeader(
          title: 'Сессия',
          subtitle: viaCore
              ? 'Поток идёт через C++-ядро (push → pipeline → pop)'
              : 'Ядро офлайн — локальная симуляция в Dart',
        ),
        InfoCard(
          title: _running ? 'Сессия идёт' : 'Тестовая сессия',
          headerIcon: Icons.monitor_heart_outlined,
          trailing: StatusChip(
            label: viaCore ? 'через ядро' : 'Dart-симуляция',
            color:
                viaCore ? theme.colorScheme.primary : theme.colorScheme.outline,
            icon: viaCore ? Icons.memory : Icons.timer,
          ),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MetricTile(label: 'Время', value: _elapsed()),
                MetricTile(label: 'Кадров', value: '$_frames'),
                MetricTile(label: 'RMS', value: _rms.toStringAsFixed(4)),
                MetricTile(label: 'Пик, Гц', value: _peakHz.toStringAsFixed(1)),
                MetricTile(
                    label: 'Качество', value: _quality.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!_running)
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Старт'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Стоп'),
                  ),
                const SizedBox(width: 12),
                Text(
                  'Симулятор 256 Гц · 1 канал · блок $_blockFrames кадров',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        InfoCard(
          title: 'История сессий (в памяти, v0.1)',
          headerIcon: Icons.history,
          children: [
            if (_history.isEmpty)
              Text(
                'Пока пусто — запустите сессию.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final _SessionRecord r in _history)
                KeyValue(
                  keyLabel:
                      '${r.startedAt.day.toString().padLeft(2, '0')}.${r.startedAt.month.toString().padLeft(2, '0')} '
                      '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
                  value:
                      '${r.viaCore ? 'ядро' : 'Dart'} · ${r.duration.inSeconds} c · '
                      '${r.frames} кадров · RMS ${r.avgRms.toStringAsFixed(3)}',
                ),
          ],
        ),
      ],
    );
  }
}

