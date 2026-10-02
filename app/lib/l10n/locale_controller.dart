import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A null preference follows the OS on first launch; explicit choices persist.
class LocaleController extends Notifier<Locale?> {
  bool _disposed = false;
  bool _changed = false;
  @override
  Locale? build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('qualia.language');
    if (!_disposed && !_changed && (code == 'ru' || code == 'en')) {
      state = Locale(code!);
    }
  }

  Future<void> select(String code) async {
    if (code != 'ru' && code != 'en') throw ArgumentError.value(code);
    _changed = true;
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qualia.language', code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
