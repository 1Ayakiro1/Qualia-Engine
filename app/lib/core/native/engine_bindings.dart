import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'engine_loader.dart';

/// ABI v3 metadata. Float32 signal payload stays in native-owned memory.
final class CoreBlockInfo extends Struct {
  @Uint32()
  external int structSize;
  @Uint32()
  external int layout;
  @Int32()
  external int frames;
  @Int32()
  external int channels;
  @Double()
  external double sampleRate;
  @Uint64()
  external int firstSample;
  @Int64()
  external int timestampNs;
  @Uint32()
  external int clock;
  @Uint32()
  external int reserved;
}

final class CoreBlock extends Opaque {}

enum CoreQueuePolicy { every, dropOldest, latestOnly }

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

  late final Pointer<CoreBlock> Function(Pointer<CoreBlockInfo>) _createBlock =
      _lib.lookupFunction<
        Pointer<CoreBlock> Function(Pointer<CoreBlockInfo>),
        Pointer<CoreBlock> Function(Pointer<CoreBlockInfo>)
      >('bci_block_create');

  late final void Function(Pointer<CoreBlock>) _releaseBlock = _lib
      .lookupFunction<
        Void Function(Pointer<CoreBlock>),
        void Function(Pointer<CoreBlock>)
      >('bci_block_release');

  late final Pointer<Float> Function(Pointer<CoreBlock>) _blockData = _lib
      .lookupFunction<
        Pointer<Float> Function(Pointer<CoreBlock>),
        Pointer<Float> Function(Pointer<CoreBlock>)
      >('bci_block_data');

  late final int Function(Pointer<CoreBlock>, Pointer<CoreBlockInfo>)
  _blockInfo = _lib
      .lookupFunction<
        Int32 Function(Pointer<CoreBlock>, Pointer<CoreBlockInfo>),
        int Function(Pointer<CoreBlock>, Pointer<CoreBlockInfo>)
      >('bci_block_get_info');

  late final int Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>)
  _pushBlock = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>),
        int Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>)
      >('bci_engine_push_block');

  late final int Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>)
  _popBlock = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>),
        int Function(Pointer<Void>, Pointer<Pointer<CoreBlock>>)
      >('bci_engine_pop_block');

  late final int Function(Pointer<Void>, int, int, int, int) _configureQueues =
      _lib.lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Uint64, Uint32, Uint32),
        int Function(Pointer<Void>, int, int, int, int)
      >('bci_engine_configure_queues');

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

  late final int Function(
    Pointer<Float>,
    int,
    Pointer<NativeStftConfig>,
    Pointer<Float>,
    int,
    int,
  ) _stft = _lib.lookupFunction<
    Int32 Function(
      Pointer<Float>,
      Uint32,
      Pointer<NativeStftConfig>,
      Pointer<Float>,
      Uint32,
      Uint32,
    ),
    int Function(
      Pointer<Float>,
      int,
      Pointer<NativeStftConfig>,
      Pointer<Float>,
      int,
      int,
    )
  >('bci_stft_compute');

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

  // ABI v3. Legacy ABI v2 users can still use the existing samples API. These
  // symbols are resolved lazily; callers must check abiVersion >= 3 first.
  Pointer<CoreBlock> createBlock(Pointer<CoreBlockInfo> info) =>
      _createBlock(info);
  void releaseBlock(Pointer<CoreBlock> block) => _releaseBlock(block);
  Pointer<Float> blockData(Pointer<CoreBlock> block) => _blockData(block);
  int blockInfo(Pointer<CoreBlock> block, Pointer<CoreBlockInfo> info) =>
      _blockInfo(block, info);

  /// On success [block].value becomes nullptr; on refusal it is unchanged.
  /// Do not access native payload after ownership has moved to the engine.
  int pushBlock(Pointer<Void> engine, Pointer<Pointer<CoreBlock>> block) =>
      _pushBlock(engine, block);
  int popBlock(Pointer<Void> engine, Pointer<Pointer<CoreBlock>> block) =>
      _popBlock(engine, block);

  int configureQueues(
    Pointer<Void> engine, {
    required int capacity,
    required int maxBytes,
    required CoreQueuePolicy input,
    required CoreQueuePolicy output,
  }) => _configureQueues(engine, capacity, maxBytes, input.index, output.index);

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

  /// Computes native Hann/STFT rows for a mono buffer. Returns empty when the
  /// optional additive symbol is unavailable in an older core.
  List<List<double>> stft(
    Pointer<Float> samples,
    int sampleCount, {
    int windowSize = 256,
    int hopSize = 32,
    double sampleRate = 256,
    int maxRows = 64,
  }) {
    final config = calloc<NativeStftConfig>();
    final bins = windowSize ~/ 2 + 1;
    final output = calloc<Float>(maxRows * bins);
    try {
      config.ref
        ..windowSize = windowSize
        ..hopSize = hopSize
        ..sampleRate = sampleRate;
      final int rows;
      try {
        rows = _stft(
          samples,
          sampleCount,
          config,
          output,
          maxRows,
          maxRows * bins,
        );
      } on ArgumentError {
        return const <List<double>>[];
      }
      if (rows <= 0) return const <List<double>>[];
      return <List<double>>[
        for (var row = 0; row < rows; row++)
          <double>[
            for (var bin = 0; bin < bins; bin++) output[row * bins + bin],
          ],
      ];
    } finally {
      calloc.free(config);
      calloc.free(output);
    }
  }
}

final class NativeStftConfig extends Struct {
  @Uint32()
  external int windowSize;
  @Uint32()
  external int hopSize;
  @Double()
  external double sampleRate;
}
