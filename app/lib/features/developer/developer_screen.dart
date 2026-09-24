import 'dart:ffi';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/engine_provider.dart';
import '../../state/engine_state.dart';
import '../common/widgets.dart';

/// FFI playground: direct calls into libbci_engine_core.
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  final List<String> _log = <String>[];

  void _say(String line) {
    setState(() {
      _log.add(line);
      if (_log.length > 200) {
        _log.removeAt(0);
      }
    });
  }

  EngineController get _controller => ref.read(engineProvider.notifier);

  void _version() {
    final bool online = ref.read(engineProvider).isOnline;
    if (!online) {
      _say('ядро не загружено');
      return;
    }
    _say('core ${_controller.bindings!.coreVersion} · ABI ${_controller.bindings!.abiVersion}');
  }

  void _create() {
    final EngineState? result = _controller.createEngine();
    _say(result != null ? 'engine создан' : 'create не удался');
  }

  void _start() {
    final int? code = _controller.start(sampleRate: 256, channels: 1);
    _say(code == 0 ? 'engine стартовал (256 Гц × 1)' : 'start → код $code');
  }

  void _stop() {
    final int? code = _controller.stop();
    _say(code == null ? 'ядра нет' : 'stop → код $code');
  }

  Future<void> _echo() async {
    if (_controller.bindings == null) {
      _say('ядро не загружено');
      return;
    }
    _controller.createEngine();
    if (!_controller.hasEngineHandle) {
      _say('engine не создан');
      return;
    }
    _controller.stop();  // reset if a previous session is still running
    final int? startCode = _controller.start(sampleRate: 256, channels: 1);
    if (startCode == null || startCode != 0) {
      _say('start → код $startCode');
      return;
    }

    const int frames = 64;
    final Pointer<Float> buffer = _controller.allocateSamples(frames);
    final math.Random rng = math.Random();
    try {
      for (int block = 0; block < 4; block++) {
        for (int i = 0; i < frames; i++) {
          buffer[i] =
              math.sin(2 * math.pi * 10 * i / 256) + rng.nextDouble() * 0.05;
        }
        _controller.pushSamples(buffer, frames, 1);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final Pointer<Float> out = _controller.allocateSamples(256);
      try {
        int popped = 0;
        for (int attempt = 0; attempt < 50 && popped == 0; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          popped = _controller.popSamplesInto(out, 256, 1) ?? 0;
        }
        double sum = 0;
        for (int i = 0; i < popped; i++) {
          sum += out[i] * out[i];
        }
        final double rms = popped > 0 ? math.sqrt(sum / popped) : 0;
        _say('echo: popped=$popped rms=${rms.toStringAsFixed(4)}');
      } finally {
        _controller.freeSamples(out);
      }
      final List<double>? metrics = _controller.metrics();
      if (metrics != null) {
        _say('metrics: rms=${metrics[0].toStringAsFixed(4)} '
            'peak=${metrics[1].toStringAsFixed(1)} Hz '
            'quality=${metrics[2].toStringAsFixed(2)}');
      }
      _controller.stop();
    } finally {
      _controller.freeSamples(buffer);
    }
  }

  void _modules() {
    final List<String> jsons = _controller.moduleJsons();
    if (jsons.isEmpty) {
      _say('модули недоступны (нужен запущенный engine)');
      return;
    }
    for (final String json in jsons) {
      _say(json);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final EngineState engine = ref.watch(engineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Разработчик',
          subtitle: 'FFI-консоль ядра · bci_engine_* C API',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: _version, child: const Text('Версия ядра')),
              OutlinedButton(onPressed: _create, child: const Text('Создать engine')),
              OutlinedButton(onPressed: _start, child: const Text('Старт')),
              OutlinedButton(onPressed: _stop, child: const Text('Стоп')),
              OutlinedButton(onPressed: _echo, child: const Text('Echo-тест')),
              OutlinedButton(onPressed: _modules, child: const Text('Модули (JSON)')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            engine.isOnline
                ? 'Библиотека: ${engine.libraryPath}'
                : 'Библиотека ядра не найдена — соберите ядро (scripts/build.sh).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (BuildContext context, int index) => SelectableText(
                    _log[index],
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
