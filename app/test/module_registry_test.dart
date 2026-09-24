import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system module catalog has unique ids', () {
    final ids = kSystemModules.map((m) => m.id).toSet();
    expect(ids.length, kSystemModules.length);
  });

  test('every module has id, name, category and stage', () {
    for (final m in kSystemModules) {
      expect(m.id, isNotEmpty, reason: 'empty id in ${m.name}');
      expect(m.name, isNotEmpty);
      expect(m.category, isNotEmpty);
      expect(m.stage, isNotEmpty);
      expect(m.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    }
  });

  test('active modules follow the core.* id convention', () {
    for (final m in kSystemModules.where((m) => m.active)) {
      expect(m.id, startsWith('core.'));
    }
  });
}
