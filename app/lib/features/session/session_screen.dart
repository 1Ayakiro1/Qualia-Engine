import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';

import '../../state/engine_provider.dart';
import '../../core/runtime/runtime_events.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../../core/session/edf_codec.dart';
import '../../core/session/session_store.dart';
import '../../state/render_preferences.dart';
import '../../core/render/frame_gate.dart';
import '../../core/session/session_recorder.dart';
import '../../state/lsl_source.dart';
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
  SessionRecorder _recorder = SessionRecorder();
  List<Map<String, dynamic>> _savedSessions = [];
  SessionDocument? _selectedDocument;
  String? _storageError;
  String? _selectedSessionId;
  String _sourceId = 'simulator';
  double _sampleRate = 256;
  int _channels = 1;
  final SessionStore _sessionStore = SessionStore();

  StreamSubscription<RuntimeSignalBlock>? _signals;
  StreamSubscription<RuntimeFrame>? _frameSubscription;
  bool _running = false;
  DateTime? _startedAt;
  int _frames = 0;
  double _rms = 0;
  double _peakHz = 0;
  double _quality = 0;
  double _rmsSum = 0;
  int _metricSamples = 0;
  double _pendingRms = 0;
  double _pendingPeakHz = 0;
  double _pendingQuality = 0;
  FrameGate _frameGate = FrameGate();
  bool _saving = false;

  static const int _blockFrames = 64;
  static const int _popWindow = 256;
  Pointer<Float>? _inBuffer;
  Pointer<Float>? _outBuffer;

  bool get _coreOnline => ref.read(engineProvider).isOnline;
  late final EngineController _engineController;

  @override
  void initState() {
    super.initState();
    _engineController = ref.read(engineProvider.notifier);
    _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    try {
      final items = await _sessionStore.list();
      if (mounted) setState(() => _savedSessions = items.reversed.toList());
    } catch (error) {
      if (mounted) setState(() => _storageError = '$error');
    }
  }

  @override
  void dispose() {
    _stopStreams();
    if (_running) {
      final document = _recorder.finish(_startedAt ?? DateTime.now());
      if (document != null) unawaited(_saveDocument(document));
      if (_inBuffer != null) _engineController.stop();
    }
    _freeBuffers();
    super.dispose();
  }

  void _freeBuffers() {
    final EngineController controller = _engineController;
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
    if (_saving || _running) return;
    final source = ref.read(lslSourceProvider)?.active;
    final bool viaCore =
        _coreOnline &&
        (source == null || (source.channels == 1 && source.nominalRate == 256));
    if (viaCore) {
      final int? code = ref
          .read(engineProvider.notifier)
          .start(sampleRate: 256, channels: 1);
      if (code == null || code != 0) {
        AppLogger.instance.log(
          LogSource.session,
          'старт не удался (код ${code ?? 'null'})',
          level: LogLevel.error,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.textCouldNotStartTheCoreCodeArg0272(
                (code ?? 'null').toString(),
              ),
            ),
          ),
        );
        return;
      }
      final EngineController controller = ref.read(engineProvider.notifier);
      _inBuffer = controller.allocateSamples(_blockFrames);
      _outBuffer = controller.allocateSamples(_popWindow);
    } else {
      AppLogger.instance.log(
        LogSource.session,
        source == null
            ? 'сессия стартовала в Dart-симуляции'
            : 'сессия стартовала: raw LSL capture без legacy DSP',
      );
    }

    setState(() {
      _running = true;
      _startedAt = DateTime.now();
      _frames = 0;
      _rms = 0;
      _peakHz = 0;
      _quality = 0;
      _rmsSum = 0;
      _metricSamples = 0;
      _pendingRms = 0;
      _pendingPeakHz = 0;
      _pendingQuality = 0;
      _recorder = SessionRecorder();
      _frameGate = FrameGate();
      _storageError = null;
      final source = ref.read(lslSourceProvider)?.active;
      _sourceId = source?.sourceId ?? 'simulator';
      _sampleRate = source?.nominalRate ?? 256;
      _channels = source?.channels ?? 1;
    });

    _signals = RuntimeEventHub.instance.signals.listen(_processBlock);
    _frameSubscription = RuntimeEventHub.instance.frames.listen((frame) {
      if (mounted && _running) {
        final cap = ref.read(renderPreferencesProvider).frameRate;
        if (!_frameGate.accept(frame.timestamp, cap)) return;
        setState(() {
          _rms = _pendingRms;
          _peakHz = _pendingPeakHz;
          _quality = _pendingQuality;
        });
      }
    });
  }

  void _processBlock(RuntimeSignalBlock signal) {
    if (!_running) {
      return;
    }
    final List<double> block = signal.samples;
    _sourceId = signal.sourceId;
    _sampleRate = signal.sampleRate;
    _channels = signal.channels;
    try {
      _recorder.add(signal);
    } catch (error) {
      _storageError = '$error';
      unawaited(_stop());
      return;
    }

    // This legacy DSP preview is mono/256 Hz only. Preserve all raw channels
    // in the recorder; never flatten multichannel data into that pipeline.

    if (_coreOnline &&
        _inBuffer != null &&
        _outBuffer != null &&
        signal.channels == 1 &&
        signal.sampleRate == 256) {
      final EngineController controller = ref.read(engineProvider.notifier);
      for (var offset = 0; offset < block.length; offset += _blockFrames) {
        final frames = math.min(block.length - offset, _blockFrames);
        for (var i = 0; i < frames; i++) {
          _inBuffer![i] = block[offset + i];
        }
        controller.pushSamples(_inBuffer!, frames, 1);
      }
      final int? popped = controller.popSamplesInto(_outBuffer!, _popWindow, 1);
      final List<double>? metrics = controller.metrics();
      if (popped != null && popped > 0) _frames += popped;
      if (metrics != null) {
        _pendingRms = metrics[0];
        _pendingPeakHz = metrics[1];
        _pendingQuality = metrics[2];
        _rmsSum += metrics[0];
        _metricSamples++;
      }
    } else {
      double sum = 0;
      for (final double v in block) {
        sum += v * v;
      }
      _frames += signal.frames;
      _pendingRms = math.sqrt(sum / block.length);
      // No impedance/artifact estimator exists for arbitrary raw sources.
      _pendingQuality = 0;
      _rmsSum += _pendingRms;
      _metricSamples++;
    }
  }

  Future<void> _stop() async {
    if (!_running || _saving) return;
    setState(() {
      _running = false;
      _saving = true;
    });
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
    AppLogger.instance.log(
      LogSource.session,
      'сессия завершена: $_frames кадров за ${DateTime.now().difference(startedAt).inSeconds} с (RMS ${(_metricSamples > 0 ? _rmsSum / _metricSamples : 0).toStringAsFixed(3)})',
    );
    if (_inBuffer != null) {
      ref.read(engineProvider.notifier).stop();
    }
    _stopStreams();
    _freeBuffers();
    final document = _recorder.finish(startedAt);
    if (document != null) await _saveDocument(document);
    await _refreshSessions();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _saveDocument(SessionDocument document) async {
    try {
      final id = 'session_${document.startedAt!.microsecondsSinceEpoch}';
      await _sessionStore.save(id, document);
      _selectedDocument = document;
      _selectedSessionId = id;
      AppLogger.instance.log(LogSource.session, 'сессия сохранена: $id.edf');
    } catch (error) {
      if (mounted) setState(() => _storageError = '$error');
      AppLogger.instance.log(
        LogSource.session,
        'не удалось сохранить EDF: $error',
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _importEdf() async {
    if (_running || _saving) return;
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'EDF', extensions: ['edf']),
      ],
    );
    if (file == null || !mounted || _running || _saving) return;
    setState(() => _saving = true);
    try {
      if (await file.length() > EdfCodec.maxBytes) {
        throw const FormatException('EDF too large');
      }
      final document = await _sessionStore.importEdf(await file.readAsBytes());
      final id = 'import_${DateTime.now().microsecondsSinceEpoch}';
      await _sessionStore.save(id, document);
      _selectedDocument = document;
      _selectedSessionId = id;
      await _refreshSessions();
    } catch (error) {
      if (mounted) setState(() => _storageError = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportEdf() async {
    final document = _selectedDocument;
    if (document == null) return;
    final target = await getSaveLocation(suggestedName: 'session.edf');
    if (target == null) return;
    try {
      await File(target.path)
          .writeAsBytes(await _sessionStore.exportEdf(document), flush: true);
    } catch (error) {
      if (mounted) setState(() => _storageError = '$error');
    }
  }

  void _stopStreams() {
    _signals?.cancel();
    _signals = null;
    _frameSubscription?.cancel();
    _frameSubscription = null;
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
    final bool viaCore = _coreOnline && _channels == 1 && _sampleRate == 256;

    return ListView(
      children: [
        ScreenHeader(
          title: context.l10n.textSession40,
          subtitle: context.l10n.signalSourceDescription(
            _sourceId,
            _channels,
            _sampleRate.toStringAsFixed(1),
          ),
        ),
        InfoCard(
          title: _running
              ? context.l10n.textSessionRunning275
              : context.l10n.textTestSession276,
          headerIcon: AppIcons.heartbeat,
          trailing: StatusChip(
            label: viaCore
                ? context.l10n.textThroughCore277
                : context.l10n.textDartSimulation278,
            color: viaCore
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            icon: viaCore ? AppIcons.cpu : AppIcons.timer,
          ),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MetricTile(label: context.l10n.textTime279, value: _elapsed()),
                MetricTile(
                  label: context.l10n.textFrames280,
                  value: '$_frames',
                ),
                MetricTile(label: 'RMS', value: _rms.toStringAsFixed(4)),
                MetricTile(
                  label: context.l10n.textPeakHz281,
                  value: viaCore ? _peakHz.toStringAsFixed(1) : '—',
                ),
                MetricTile(
                  label: context.l10n.textQuality282,
                  value: viaCore ? _quality.toStringAsFixed(2) : '—',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!_running)
                  FilledButton.icon(
                    onPressed: _saving ? null : _start,
                    icon: const Icon(AppIcons.play),
                    label: Text(context.l10n.textStart283),
                  )
                else
                  FilledButton.icon(
                    onPressed: _stop,
                    icon: const Icon(AppIcons.stop),
                    label: Text(context.l10n.textStop284),
                  ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    context.l10n.signalSourceDescription(
                      _sourceId,
                      _channels,
                      _sampleRate.toStringAsFixed(1),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        InfoCard(
          title: context.l10n.savedSessions,
          headerIcon: AppIcons.history,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _running || _saving ? null : _importEdf,
                  child: Text(context.l10n.importEdf),
                ),
                OutlinedButton(
                  onPressed: _selectedDocument == null || _saving
                      ? null
                      : _exportEdf,
                  child: Text(context.l10n.exportEdf),
                ),
              ],
            ),
            if (_storageError != null) Text(_storageError!),
            for (final entry in _savedSessions)
              ListTile(
                title: Text(entry['id'] as String),
                subtitle: Text(
                  '${entry['channels']} ch · ${entry['sampleRate']} Hz · ${entry['frames']} frames',
                ),
                selected: _selectedSessionId == entry['id'],
                onTap: () async {
                  try {
                    final document = await _sessionStore.load(
                      entry['id'] as String,
                    );
                    if (mounted) {
                      setState(() {
                        _selectedDocument = document;
                        _selectedSessionId = entry['id'] as String;
                      });
                    }
                  } catch (error) {
                    if (mounted) setState(() => _storageError = '$error');
                  }
                },
              ),
            if (_history.isEmpty && _savedSessions.isEmpty)
              Text(
                context.l10n.textNoSessionsYetStartASession287,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final _SessionRecord r in _history)
                KeyValue(
                  keyLabel:
                      '${r.startedAt.day.toString().padLeft(2, '0')}.${r.startedAt.month.toString().padLeft(2, '0')} '
                      '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
                  value: context.l10n.sessionHistoryDetails(
                    r.viaCore ? context.hostLabel('ядро') : 'Dart',
                    r.duration.inSeconds,
                    r.frames,
                    r.avgRms.toStringAsFixed(3),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
