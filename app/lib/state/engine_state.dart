import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_info.dart';
import 'engine_provider.dart';

/// Availability of the native core from the Dart side.
enum EngineAvailability { unavailable, available }

/// High-level status shown in the shell.
enum EngineRunState { idle, running }

class EngineState {
  const EngineState({
    required this.availability,
    this.runState = EngineRunState.idle,
    this.coreVersion = '',
    this.abiVersion = 0,
    this.libraryPath = '',
    this.moduleCount = 0,
    this.lastError = '',
  });

  final EngineAvailability availability;
  final EngineRunState runState;
  final String coreVersion;
  final int abiVersion;
  final String libraryPath;
  final int moduleCount;
  final String lastError;

  bool get isOnline => availability == EngineAvailability.available;

  EngineState copyWith({
    EngineAvailability? availability,
    EngineRunState? runState,
    String? coreVersion,
    int? abiVersion,
    String? libraryPath,
    int? moduleCount,
    String? lastError,
  }) {
    return EngineState(
      availability: availability ?? this.availability,
      runState: runState ?? this.runState,
      coreVersion: coreVersion ?? this.coreVersion,
      abiVersion: abiVersion ?? this.abiVersion,
      libraryPath: libraryPath ?? this.libraryPath,
      moduleCount: moduleCount ?? this.moduleCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// UI-facing combined version label.
final Provider<String> versionLabelProvider = Provider<String>((Ref ref) {
  final EngineState engine = ref.watch(engineProvider);
  return '${AppInfo.appName} ${AppInfo.version} · '
      'ядро ${engine.coreVersion.isEmpty ? '—' : engine.coreVersion}'
      ' (ABI ${engine.abiVersion})';
});
