// Quick manual E2E check of the native core from Dart:
//   cd app && dart run tool/ffi_check.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

void main(List<String> args) {
  final String exeDir = File(Platform.resolvedExecutable).parent.path;
  final String libPath = args.isNotEmpty
      ? args[0]
      : '$exeDir/lib/libbci_engine_core.so';

  final DynamicLibrary lib = DynamicLibrary.open(libPath);
  final version = lib.lookupFunction<Pointer<Utf8> Function(),
      Pointer<Utf8> Function()>('bci_engine_core_version');
  stdout.writeln('core version: ${version().toDartString()}');

  final create = lib.lookupFunction<Pointer<Void> Function(),
      Pointer<Void> Function()>('bci_engine_create');
  final destroy = lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('bci_engine_destroy');
  final start = lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>('bci_engine_start');
  final stop = lib.lookupFunction<Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('bci_engine_stop');
  final push = lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32),
      int Function(Pointer<Void>, Pointer<Float>, int, int)>(
      'bci_engine_push_samples');
  final pop = lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32),
      int Function(Pointer<Void>, Pointer<Float>, int, int)>(
      'bci_engine_pop_samples');
  final getMetrics = lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Float>),
      int Function(Pointer<Void>, Pointer<Float>)>('bci_engine_get_metrics');
  final moduleCount = lib.lookupFunction<Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('bci_engine_module_count');

  final Pointer<Void> engine = create();
  stdout.writeln('engine created: ${engine != nullptr}');
  stdout.writeln('start: ${start(engine, 256, 1)}');
  stdout.writeln('modules: ${moduleCount(engine)}');

  final Pointer<Float> buf = malloc<Float>(64);
  for (int i = 0; i < 64; i++) {
    buf[i] = 0.4 * (i % 32 - 16) / 16.0;
  }
  for (int b = 0; b < 4; b++) {
    push(engine, buf, 64, 1);
  }
  sleep(const Duration(milliseconds: 50));

  final Pointer<Float> out = malloc<Float>(256);
  final int popped = pop(engine, out, 256, 1);
  double sum = 0;
  for (int i = 0; i < popped; i++) {
    sum += out[i] * out[i];
  }
  stdout.writeln(
      'popped: $popped frames, rms: ${sum > 0 ? math.sqrt(sum / popped) : 0}');

  final Pointer<Float> metrics = malloc<Float>(4);
  getMetrics(engine, metrics);
  stdout.writeln(
      'metrics: rms=${metrics[0]}, peak=${metrics[1]} Hz, quality=${metrics[2]}');

  malloc.free(buf);
  malloc.free(out);
  malloc.free(metrics);
  stdout.writeln('stop: ${stop(engine)}');
  destroy(engine);
  stdout.writeln('OK');
}
