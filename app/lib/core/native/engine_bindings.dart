import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'engine_loader.dart';

/// Raw bindings over the stable C ABI (core/include/bci_engine/c_api.h).
class CoreBindings {
  CoreBindings._(this._lib, this.path);

  final DynamicLibrary _lib;

  /// File the library was loaded from (for diagnostics in the UI).
  final String path;

  /// Raw handle (needed e.g. to install the core log callback).
  EngineLibrary get rawLibrary => EngineLibrary(_lib, path);

  static CoreBindings? tryLoad() {
    final EngineLibrary? loaded = loadEngineLibrary();
    if (loaded == null) {
      return null;
    }
    return CoreBindings._(loaded.library, loaded.path);
  }

  late final int Function() _abiVersion = _lib
      .lookupFunction<Int32 Function(), int Function()>(
        'bci_engine_abi_version',
      );

  late final Pointer<Utf8> Function() _coreVersion = _lib
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'bci_engine_core_version',
      );

  late final Pointer<Void> Function() _create = _lib
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'bci_engine_create',
      );

  late final void Function(Pointer<Void>) _destroy = _lib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('bci_engine_destroy');

  late final int Function(Pointer<Void>, int, int) _start = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Int32, Int32),
        int Function(Pointer<Void>, int, int)
      >('bci_engine_start');

  late final int Function(Pointer<Void>) _stop = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('bci_engine_stop');

  late final int Function(Pointer<Void>) _isRunning = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('bci_engine_is_running');

  late final int Function(Pointer<Void>, Pointer<Float>, int, int) _push = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32),
        int Function(Pointer<Void>, Pointer<Float>, int, int)
      >('bci_engine_push_samples');

  late final int Function(Pointer<Void>, Pointer<Float>, int, int) _pop = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32),
        int Function(Pointer<Void>, Pointer<Float>, int, int)
      >('bci_engine_pop_samples');

  late final int Function(Pointer<Void>, Pointer<Float>) _getMetrics = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Float>),
        int Function(Pointer<Void>, Pointer<Float>)
      >('bci_engine_get_metrics');

  late final int Function(Pointer<Void>) _moduleCount = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('bci_engine_module_count');

  late final Pointer<Utf8> Function(Pointer<Void>, int) _moduleJson = _lib
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>, Int32),
        Pointer<Utf8> Function(Pointer<Void>, int)
      >('bci_engine_module_json');

  late final Pointer<Utf8> Function(Pointer<Void>) _lastError = _lib
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)
      >('bci_engine_last_error');

  // ---- friendly wrappers -------------------------------------------------

  int get abiVersion => _abiVersion();

  String get coreVersion => _coreVersion().toDartString();

  Pointer<Void> create() => _create();

  void destroy(Pointer<Void> engine) => _destroy(engine);

  int start(Pointer<Void> engine, int sampleRate, int channels) =>
      _start(engine, sampleRate, channels);

  int stop(Pointer<Void> engine) => _stop(engine);

  bool isRunning(Pointer<Void> engine) => _isRunning(engine) == 1;

  int pushSamples(
    Pointer<Void> engine,
    Pointer<Float> samples,
    int frames,
    int channels,
  ) => _push(engine, samples, frames, channels);

  int popSamples(
    Pointer<Void> engine,
    Pointer<Float> out,
    int frames,
    int channels,
  ) => _pop(engine, out, frames, channels);

  /// Returns [rms, peakFreqHz, quality, reserved].
  List<double> metrics(Pointer<Void> engine) {
    final Pointer<Float> buf = malloc<Float>(4);
    try {
      final int code = _getMetrics(engine, buf);
      if (code != 0) {
        return const [0, 0, 0, 0];
      }
      return [buf[0], buf[1], buf[2], buf[3]];
    } finally {
      malloc.free(buf);
    }
  }

  int moduleCount(Pointer<Void> engine) => _moduleCount(engine);

  String moduleJson(Pointer<Void> engine, int index) =>
      _moduleJson(engine, index).toDartString();

  String lastError(Pointer<Void> engine) => _lastError(engine).toDartString();
}
