import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('module model maps an authored draft from the catalog', () {
    final module = SystemModule.fromJson({
      'id': 'f53d7135-5447-41e0-bfb4-6331c60bd884',
      'slug': 'user.abc12345.signal-cleaner',
      'author_id': 'abc12345-1234-1234-1234-123456789012',
      'name': 'Signal Cleaner',
      'summary': 'Removes a narrow-band component.',
      'description': 'A user-authored processing module.',
      'category': 'dsp',
      'review_state': 'draft',
    });

    expect(module.databaseId, 'f53d7135-5447-41e0-bfb4-6331c60bd884');
    expect(module.id, 'user.abc12345.signal-cleaner');
    expect(module.authorId, 'abc12345-1234-1234-1234-123456789012');
    expect(module.reviewState, 'draft');
    expect(module.active, isFalse);
    expect(module.name, 'Signal Cleaner');
  });
}
