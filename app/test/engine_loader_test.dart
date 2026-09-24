import 'package:bci_engine/core/native/engine_bindings.dart';
import 'package:bci_engine/core/constants/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('engine library loads or degrades gracefully', () {
    final CoreBindings? bindings = CoreBindings.tryLoad();
    if (bindings == null) {
      // Native core not built in this environment (e.g. plain `flutter test`
      // on the host without the .so). The app must still work offline.
      return;
    }
    expect(bindings.coreVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(bindings.abiVersion, AppInfo.expectedCoreAbi);
  });

  test('engine start/stop round-trip when the core is available', () {
    final CoreBindings? bindings = CoreBindings.tryLoad();
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
}
