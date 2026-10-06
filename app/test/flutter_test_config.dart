import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Optional readable review captures. Normal regressions retain the test fonts;
/// no font assets or platform-specific paths are added to the released app.
Future<void> testExecutable(Future<void> Function() testMain) async {
  final fontDirectory = Platform.environment['QUALIA_TEST_FONT_DIR'];
  if (Platform.environment['QUALIA_TEST_CAPTURE_DIR'] != null &&
      fontDirectory != null) {
    TestWidgetsFlutterBinding.ensureInitialized();
    Future<ByteData> font(String file) async =>
        ByteData.sublistView(await File('$fontDirectory/$file').readAsBytes());
    for (final family in [
      'FlutterTest',
      'Ahem',
      'Roboto',
      'Ubuntu',
      'monospace',
    ]) {
      await (FontLoader(family)..addFont(font('Roboto-Regular.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(font('MaterialIcons-Regular.otf'))).load();
  }
  await testMain();
}
