import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../logging/app_logger.dart';
import '../logging/log_entry.dart';
import 'engine_loader.dart';

typedef _NativeLogCallback = Void Function(Pointer<Utf8>);
typedef _SetLogCallbackNative = Void Function(Pointer<NativeFunction<_NativeLogCallback>>);
typedef _SetLogCallbackDart = void Function(Pointer<NativeFunction<_NativeLogCallback>>);

/// Forwards `core_log()` messages from libbci_engine_core into [AppLogger].
///
/// The C side may invoke the callback from its worker thread; using
/// [NativeCallable.listener] marshals the call onto the Dart isolate safely.
/// Requires core ABI >= 2 (`bci_engine_set_log_callback`).
class CoreLogBridge {
  CoreLogBridge._();

  static NativeCallable<_NativeLogCallback>? _listener;
  static bool _installed = false;

  static void _onCoreMessage(Pointer<Utf8> message) {
    String text;
    try {
      text = message.toDartString();
    } catch (_) {
      text = '<нечитаемое сообщение ядра>';
    }
    AppLogger.instance.log('core', text);
  }

  /// Installs the bridge once. No-op when the symbol is missing (old core).
  static void install(EngineLibrary loaded, {required int abiVersion}) {
    if (_installed || abiVersion < 2) {
      return;
    }
    try {
      final _SetLogCallbackDart setCallback = loaded.library.lookupFunction<
          _SetLogCallbackNative,
          _SetLogCallbackDart>('bci_engine_set_log_callback');
      _listener ??= NativeCallable<_NativeLogCallback>.listener(_onCoreMessage);
      setCallback(_listener!.nativeFunction);
      _installed = true;
      AppLogger.instance.log('core', 'мост логов ядра подключён (ABI $abiVersion)');
    } catch (e) {
      AppLogger.instance.log('core', 'мост логов недоступен: $e',
          level: LogLevel.warning);
    }
  }
}
