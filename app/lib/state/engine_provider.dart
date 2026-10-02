import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/log_entry.dart';
import '../core/native/core_log_bridge.dart';
import '../core/native/engine_bindings.dart';
import 'engine_state.dart';

/// Owns the native engine handle and exposes it to the UI.
class EngineController extends Notifier<EngineState> {
  Pointer<Void>? _engine;
  CoreBindings? _bindings;

  /// Raw bindings, null when the core library is not available.
  CoreBindings? get bindings => _bindings;

  @override
  EngineState build() {
    _bindings = CoreBindings.tryLoad();
    final CoreBindings? bindings = _bindings;
    if (bindings == null) {
      AppLogger.instance.log(
        LogSource.core,
        'libbci_engine_core не найдена — работа в офлайн-режиме (Dart-симуляция)',
        level: LogLevel.warning,
      );
      return const EngineState(
        availability: EngineAvailability.unavailable,
        lastError: 'libbci_engine_core не найдена рядом с исполняемым файлом',
      );
    }
    AppLogger.instance.log(
      LogSource.core,
      'ядро загружено: ${bindings.path} (v${bindings.coreVersion}, ABI ${bindings.abiVersion})',
    );
    return EngineState(
      availability: EngineAvailability.available,
      coreVersion: bindings.coreVersion,
      abiVersion: bindings.abiVersion,
      libraryPath: bindings.path,
    );
  }

  bool get hasEngineHandle => _engine != null;

  /// Creates the native engine instance. Returns null on failure.
  EngineState? createEngine() {
    final CoreBindings? bindings = _bindings;
    if (bindings == null || _engine != null) {
      return state;
    }
    final Pointer<Void> handle = bindings.create();
    if (handle == nullptr) {
      state = state.copyWith(lastError: 'bci_engine_create() вернул null');
      return null;
    }
    _engine = handle;
    return state;
  }

  void disposeEngine() {
    final CoreBindings? bindings = _bindings;
    if (bindings != null && _engine != null) {
      if (state.runState == EngineRunState.running) {
        bindings.stop(_engine!);
      }
      bindings.destroy(_engine!);
      _engine = null;
    }
    state = state.copyWith(runState: EngineRunState.idle);
  }

  /// Starts the engine session. Returns the status code or null when the
  /// core is unavailable.
  int? start({int sampleRate = 256, int channels = 1}) {
    final CoreBindings? bindings = _bindings;
    if (bindings == null) {
      return null;
    }
    createEngine();
    final Pointer<Void>? engine = _engine;
    if (engine == null) {
      return null;
    }
    final int code = bindings.start(engine, sampleRate, channels);
    _refreshModuleInfo();
    final bool ok = code == 0;
    AppLogger.instance.log(
      LogSource.session,
      ok
          ? 'сессия стартовала через ядро ($sampleRate Гц × $channels)'
          : 'start вернул код $code: ${bindings.lastError(engine)}',
      level: ok ? LogLevel.info : LogLevel.error,
    );
    state = state.copyWith(
      runState: code == 0 ? EngineRunState.running : state.runState,
      lastError: code == 0 ? '' : bindings.lastError(engine),
    );
    return code;
  }

  int? stop() {
    final CoreBindings? bindings = _bindings;
    final Pointer<Void>? engine = _engine;
    if (bindings == null || engine == null) {
      state = state.copyWith(runState: EngineRunState.idle);
      return null;
    }
    final int code = bindings.stop(engine);
    AppLogger.instance.log(
      LogSource.session,
      'сессия остановлена (код $code)',
      level: code == 0 ? LogLevel.info : LogLevel.warning,
    );
    state = state.copyWith(
      runState: EngineRunState.idle,
      lastError: code < 0 ? bindings.lastError(engine) : '',
    );
    return code;
  }

  /// Pushes an interleaved block. Returns the status code or null.
  int? pushSamples(Pointer<Float> samples, int frames, int channels) {
    final Pointer<Void>? engine = _engine;
    if (engine == null) {
      return null;
    }
    return bindings!.pushSamples(engine, samples, frames, channels);
  }

  /// Allocates an FFI float buffer of [length] elements.
  Pointer<Float> allocateSamples(int length) => malloc<Float>(length);

  void freeSamples(Pointer<Float> buffer) => malloc.free(buffer);

  /// Pops up to [frames] processed frames into [out].
  /// Returns the number of frames actually popped or null.
  int? popSamplesInto(Pointer<Float> out, int frames, int channels) {
    final Pointer<Void>? engine = _engine;
    if (engine == null) {
      return null;
    }
    return bindings!.popSamples(engine, out, frames, channels);
  }

  /// Returns [rms, peakFreqHz, quality, reserved] or null when offline.
  List<double>? metrics() {
    final Pointer<Void>? engine = _engine;
    if (engine == null) {
      return null;
    }
    return bindings!.metrics(engine);
  }

  /// JSON descriptors of the registered system modules.
  List<String> moduleJsons() {
    final CoreBindings? bindings = _bindings;
    final Pointer<Void>? engine = _engine;
    if (bindings == null || engine == null) {
      return const <String>[];
    }
    final int count = bindings.moduleCount(engine);
    return List<String>.generate(
      count,
      (int i) => bindings.moduleJson(engine, i),
    );
  }

  void _refreshModuleInfo() {
    final CoreBindings? bindings = _bindings;
    final Pointer<Void>? engine = _engine;
    if (bindings == null || engine == null) {
      return;
    }
    // Подключаем мост логов ядра один раз, когда есть живая библиотека.
    CoreLogBridge.install(bindings.rawLibrary, abiVersion: bindings.abiVersion);
    state = state.copyWith(
      moduleCount: bindings.moduleCount(engine),
      coreVersion: bindings.coreVersion,
      abiVersion: bindings.abiVersion,
      libraryPath: bindings.path,
    );
  }
}

final NotifierProvider<EngineController, EngineState> engineProvider =
    NotifierProvider<EngineController, EngineState>(EngineController.new);

/// Convenience: is the native core online (library + engine available)?
final Provider<bool> coreOnlineProvider = Provider<bool>((Ref ref) {
  return ref.watch(engineProvider).isOnline;
});
