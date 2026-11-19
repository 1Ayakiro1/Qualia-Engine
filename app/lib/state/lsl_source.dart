import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/runtime/lsl_source.dart';
import 'engine_provider.dart';

final lslSourceProvider = Provider<LslRuntimeSource?>((ref) {
  final bindings = ref.watch(engineProvider.notifier).bindings;
  if (bindings == null) return null;
  final source = LslRuntimeSource(bindings.path);
  ref.onDispose(() => unawaited(source.stop()));
  return source;
});
