import 'dart:ffi';
import 'dart:io';

/// Loaded handle of libbci_engine_core.
class EngineLibrary {
  const EngineLibrary(this.library, this.path);

  final DynamicLibrary library;
  final String path;
}

/// Locates and opens the native core next to the running executable.
///
/// Linux bundle:   `<exe>/lib/libbci_engine_core.so`
/// Windows bundle: `<exe>/bci_engine_core.dll`
/// macOS bundle:   `<exe>/../Frameworks/libbci_engine_core.dylib`
EngineLibrary? loadEngineLibrary() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final String sep = Platform.pathSeparator;

  final List<String> candidates;
  if (Platform.isWindows) {
    candidates = [
      '$exeDir${sep}bci_engine_core.dll',
      'bci_engine_core.dll',
    ];
  } else if (Platform.isMacOS) {
    candidates = [
      '$exeDir/../Frameworks/libbci_engine_core.dylib',
      '$exeDir/libbci_engine_core.dylib',
      'libbci_engine_core.dylib',
    ];
  } else {
    candidates = [
      '$exeDir/lib/libbci_engine_core.so',
      '$exeDir/libbci_engine_core.so',
      'libbci_engine_core.so',
    ];
  }

  for (final path in candidates) {
    try {
      return EngineLibrary(DynamicLibrary.open(path), path);
    } on ArgumentError {
      // Try the next candidate location.
    }
  }
  return null;
}
