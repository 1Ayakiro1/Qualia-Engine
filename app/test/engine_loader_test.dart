import 'dart:ffi';
import 'dart:io';

import 'package:bci_engine/core/native/engine_bindings.dart';
import 'package:bci_engine/core/constants/app_info.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

CoreBindings? loadCore() {
  final bindings = CoreBindings.tryLoad();
  if (Platform.environment['QUALIA_REQUIRE_NATIVE_TESTS'] == '1') {
    expect(
      bindings,
      isNotNull,
      reason: 'CI must execute the native Dart FFI tests',
    );
  }
  return bindings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('engine library loads or degrades gracefully', () {
    final CoreBindings? bindings = loadCore();
    if (bindings == null) {
      // Native core not built in this environment (e.g. plain `flutter test`
      // on the host without the .so). The app must still work offline.
      return;
    }
    expect(
      bindings.coreVersion,
      matches(RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')),
    );
    expect(bindings.abiVersion, AppInfo.expectedCoreAbi);
  });

  test('engine start/stop round-trip when the core is available', () {
    final CoreBindings? bindings = loadCore();
    if (bindings == null) {
      return;
    }
    final engine = bindings.create();
    expect(engine, isNot(null));
    addTearDown(() => bindings.destroy(engine));

    expect(bindings.start(engine, 256, 1), 0);
    expect(bindings.isRunning(engine), isTrue);
    expect(bindings.stop(engine), 0);
    expect(bindings.isRunning(engine), isFalse);
  });

  test('native block FFI transfers ownership and preserves metadata', () async {
    final bindings = loadCore();
    if (bindings == null) return;
    expect(bindings.abiVersion, greaterThanOrEqualTo(3));
    expect(sizeOf<CoreBlockInfo>(), 48);
    final engine = bindings.create();
    expect(engine, isNot(nullptr));
    final info = calloc<CoreBlockInfo>();
    final input = calloc<Pointer<CoreBlock>>();
    final output = calloc<Pointer<CoreBlock>>();
    try {
      expect(
        bindings.configureQueues(
          engine,
          capacity: 2,
          maxBytes: 1024,
          input: CoreQueuePolicy.every,
          output: CoreQueuePolicy.every,
        ),
        0,
      );
      info.ref
        ..structSize = sizeOf<CoreBlockInfo>()
        ..layout = 1
        ..frames = 4
        ..channels = 2
        ..sampleRate = 250
        ..firstSample = 100
        ..timestampNs = -123456789
        ..clock = 1;
      input.value = bindings.createBlock(info);
      expect(input.value, isNot(nullptr));
      final original = input.value;
      final samples = bindings.blockData(original);
      samples.asTypedList(8).setAll(0, [1, 2, 3, 4, 10, 20, 30, 40]);
      expect(bindings.pushBlock(engine, input), -2);
      expect(input.value, original);
      expect(bindings.start(engine, 250, 2), 0);
      expect(bindings.pushBlock(engine, input), 0);
      expect(input.value, nullptr);
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        final code = bindings.popBlock(engine, output);
        if (code == 0) break;
        expect(code, -7);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(output.value, original);
      // The original payload is accessible only after pop returned ownership.
      expect(bindings.blockData(output.value), samples);
      expect(samples[1], closeTo(1.8, 1e-5));
      expect(samples[5], closeTo(18, 1e-5));
      expect(bindings.blockInfo(output.value, info), 0);
      expect(info.ref.timestampNs, -123456789);
      expect(info.ref.firstSample, 100);
      expect(info.ref.sampleRate, 250);
      expect(info.ref.layout, 1);
      expect(info.ref.clock, 1);
      expect(bindings.stop(engine), 0);
    } finally {
      bindings.destroy(engine);
      bindings.releaseBlock(input.value);
      bindings.releaseBlock(output.value);
      calloc.free(input);
      calloc.free(output);
      calloc.free(info);
    }
  });
}
