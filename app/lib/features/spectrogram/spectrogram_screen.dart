import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/runtime/runtime_events.dart';
import '../common/widgets.dart';
import 'spectro_model.dart';
import 'spectro_painter.dart';

/// Real-time scrolling spectrogram (Dart STFT demo; native core later).
class SpectrogramScreen extends StatefulWidget {
  const SpectrogramScreen({super.key});

  @override
  State<SpectrogramScreen> createState() => _SpectrogramScreenState();
}

class _SpectrogramScreenState extends State<SpectrogramScreen> {
  final SpectroModel _model = SpectroModel();
  StreamSubscription<RuntimeSignalBlock>? _signals;
  StreamSubscription<RuntimeFrame>? _frames;
  final List<List<double>> _pendingBlocks = <List<double>>[];

  @override
  void initState() {
    super.initState();
    _signals = RuntimeEventHub.instance.signals.listen((block) {
      if (mounted) _pendingBlocks.add(block.samples);
    });
    _frames = RuntimeEventHub.instance.frames.listen((_) {
      if (!mounted || _pendingBlocks.isEmpty) return;
      final blocks = List<List<double>>.of(_pendingBlocks);
      _pendingBlocks.clear();
      for (final block in blocks) {
        _model.push(block);
      }
    });
  }

  @override
  void dispose() {
    _signals?.cancel();
    _frames?.cancel();
    _pendingBlocks.clear();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: context.l10n.textSpectrogram44,
          subtitle: context.l10n.textSTFT256Hop32Simulator256Hz329,
          actions: [
            IconButton(
              tooltip: _model.paused
                  ? context.l10n.textResume14
                  : context.l10n.textPause15,
              onPressed: () => setState(() {
                _model.setPaused(!_model.paused);
              }),
              icon: Icon(_model.paused ? AppIcons.play : AppIcons.pause),
            ),
            IconButton(
              tooltip: context.l10n.textAddMarker330,
              onPressed: () => setState(_model.addMarker),
              icon: const Icon(AppIcons.flag),
            ),
            IconButton(
              tooltip: context.l10n.textClear331,
              onPressed: () => setState(_model.clear),
              icon: const Icon(AppIcons.trash),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _model,
                            builder: (BuildContext context, Widget? child) =>
                                CustomPaint(
                                  painter: SpectroPainter(model: _model),
                                ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 6,
                          child: Text(
                            context.l10n.text0Hz332,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 6,
                          child: Text(
                            context.l10n.text127Hz333,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 280, child: _SidePanel(model: _model)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.model});

  final SpectroModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          title: context.l10n.textMarkers334,
          headerIcon: AppIcons.flag,
          children: [
            if (model.markers.isEmpty)
              Text(
                context.l10n.markerInstructions,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final MapEntry<int, String> m in model.markers.entries)
                KeyValue(
                  keyLabel: m.value,
                  value: context.l10n.textSecArg0335(
                    (m.key / (model.maxColumns - 1) * 32).toStringAsFixed(1),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 8),
        InfoCard(
          title: context.l10n.textParameters336,
          headerIcon: AppIcons.sliders,
          children: [
            Text(
              context.l10n.textSensitivityArg0337(
                (model.gain.toStringAsFixed(1)).toString(),
              ),
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: model.gain,
              min: 0.5,
              max: 4,
              divisions: 14,
              onChanged: (double v) => model.gain = v,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InfoCard(
            title: context.l10n.textAboutVersions338,
            headerIcon: AppIcons.info,
            children: [
              Text(
                context.l10n.spectrogramVersionNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
