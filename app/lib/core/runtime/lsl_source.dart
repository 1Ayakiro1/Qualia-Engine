import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'dart:ffi';

import '../native/engine_bindings.dart';
import 'runtime_events.dart';

/// One host-owned inlet, independent of device-page lifetime and display FPS.
/// Native handles stay on the acquisition isolate. One outstanding block is
/// allowed; the bounded liblsl buffer supplies backpressure, not an unbounded
/// Dart mailbox. Shutdown waits for native resource cleanup.
class LslRuntimeSource {
  LslRuntimeSource(this.path, {RuntimeEventHub? events})
    : events = events ?? RuntimeEventHub.instance;

  final String path;
  final RuntimeEventHub events;
  ReceivePort? _messages;
  SendPort? _commands;
  Completer<void>? _stopped;
  bool _starting = false;
  bool _stopRequested = false;
  LslStreamDescriptor? active;
  String? lastError;

  Future<bool> start(LslStreamDescriptor stream) async {
    if (_starting || _messages != null) return false;
    if (stream.sourceId.isEmpty ||
        stream.channels < 1 ||
        stream.channels > 256 ||
        !stream.nominalRate.isFinite ||
        stream.nominalRate <= 0) {
      return false;
    }
    _starting = true;
    _stopRequested = false;
    lastError = null;
    final ready = Completer<bool>();
    final stopped = _stopped = Completer<void>();
    final messages = _messages = ReceivePort();
    messages.listen((message) {
      if (message is SendPort) {
        _commands = message;
        if (_stopRequested) _commands?.send('stop');
      } else if (message == 'ready') {
        active = stream;
        events.useExternalSource(true);
        ready.complete(true);
        _commands?.send('next');
      } else if (message is List && message.first is TransferableTypedData) {
        final samples = (message[0] as TransferableTypedData)
            .materialize()
            .asFloat32List();
        try {
          if (!_stopRequested) {
            events.publishSignal(
              samples,
              sampleRate: stream.nominalRate,
              channels: stream.channels,
              timestampSeconds: message[1] as double,
              sourceId: stream.sourceId,
            );
          }
          if (!_stopRequested) _commands?.send('next');
        } catch (error) {
          lastError = '$error';
          _commands?.send('stop');
        }
      } else if (message is String && message.startsWith('error:')) {
        lastError = message.substring(6);
        if (!ready.isCompleted) ready.complete(false);
      } else if (message == 'done' || message == null) {
        if (!ready.isCompleted) ready.complete(false);
        if (active != null) events.useExternalSource(false);
        active = null;
        _messages = null;
        _commands = null;
        messages.close();
        if (!stopped.isCompleted) stopped.complete();
      }
    });
    try {
      await Isolate.spawn(_acquire, [
        path,
        stream.sourceId,
        messages.sendPort,
        stream.channels,
        stream.nominalRate,
      ], onExit: messages.sendPort);
      return await ready.future;
    } catch (error) {
      lastError = '$error';
      messages.close();
      _messages = null;
      if (!stopped.isCompleted) stopped.complete();
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    _commands?.send('stop');
    await _stopped?.future;
  }
}

void _acquire(List<Object> args) async {
  final host = args[2] as SendPort;
  final commands = ReceivePort();
  host.send(commands.sendPort);
  CoreBindings? bindings;
  Pointer<LslInletHandle>? inlet;
  final buffer = calloc<Float>(8192);
  final channels = calloc<Int32>();
  final timestamp = calloc<Double>();
  try {
    bindings = CoreBindings.open(args[0] as String);
    inlet = bindings.createLslInlet();
    if (inlet == nullptr ||
        bindings.openLslInlet(inlet, args[1] as String) != 0) {
      throw StateError('Cannot open LSL stream');
    }
    final info = bindings.lslInletInfo(inlet);
    if (info.channels != args[3] || info.nominalRate != args[4]) {
      throw StateError('LSL format changed since discovery; refresh streams');
    }
    host.send('ready');
    await for (final command in commands) {
      if (command == 'stop') break;
      if (command != 'next') continue;
      final frames = bindings.pullLsl(inlet, buffer, 8192, channels, timestamp);
      if (frames < 0) throw StateError('LSL pull failed ($frames)');
      if (frames > 0) {
        final count = frames * channels.value;
        if (channels.value < 1 || count > 8192) {
          throw StateError('Invalid LSL dimensions');
        }
        host.send([
          TransferableTypedData.fromList([
            Float32List.fromList(buffer.asTypedList(count)).buffer
                .asUint8List(),
          ]),
          timestamp.value,
        ]);
      } else {
        // No blocking native wait; shutdown remains responsive even on loss.
        await Future<void>.delayed(const Duration(milliseconds: 4));
        commands.sendPort.send('next');
      }
    }
  } catch (error) {
    host.send('error:$error');
  } finally {
    if (inlet != null && inlet != nullptr) bindings?.destroyLslInlet(inlet);
    calloc.free(buffer);
    calloc.free(channels);
    calloc.free(timestamp);
    commands.close();
    host.send('done');
  }
}
