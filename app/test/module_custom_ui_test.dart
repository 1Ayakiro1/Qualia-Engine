import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/modules/module_custom_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'custom layout validation accepts host elements and rejects unsafe shapes',
    () {
      expect(
        LocalModuleStore.validateManifest({
          'format': 'qualia-module',
          'schemaVersion': 1,
          'runtime': 'native-process-v1',
          'platform': 'linux-x64',
          'entrypoint': 'bin/module',
          'id': 'custom-ui',
          'name': 'Custom UI',
          'version': '1.0.0',
          'ports': {'inputs': [], 'outputs': []},
          'ui': [
            {'id': 'run', 'type': 'button', 'label': 'Run'},
            {'id': 'result', 'type': 'label', 'label': 'Result'},
          ],
          'uiLayout': {
            'type': 'column',
            'children': [
              {
                'type': 'card',
                'children': [
                  {'type': 'button', 'id': 'run', 'label': 'Run'},
                  {'type': 'chart', 'id': 'result', 'title': 'Result'},
                ],
              },
            ],
          },
        })['uiLayout'],
        isA<Map>(),
      );
      expect(
        () => LocalModuleStore.validateManifest({
          'format': 'qualia-module',
          'schemaVersion': 1,
          'runtime': 'native-process-v1',
          'platform': 'linux-x64',
          'entrypoint': 'bin/module',
          'id': 'unsafe-ui',
          'name': 'Unsafe UI',
          'version': '1.0.0',
          'ports': {'inputs': [], 'outputs': []},
          'ui': [
            {'id': 'run', 'type': 'button', 'label': 'Run'},
          ],
          'uiLayout': {'type': 'webview', 'url': 'https://example.com'},
        }),
        throwsFormatException,
      );
      expect(
        () => LocalModuleStore.validateManifest({
          'format': 'qualia-module',
          'schemaVersion': 1,
          'runtime': 'native-process-v1',
          'platform': 'linux-x64',
          'entrypoint': 'bin/module',
          'id': 'invalid-ui',
          'name': 'Invalid UI',
          'version': '1.0.0',
          'ports': {'inputs': [], 'outputs': []},
          'ui': 'not-a-list',
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'custom UI stays inside the module surface and sends host events',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: AppThemeScope(
            palette: AppPalette.dark,
            child: Scaffold(
              body: ModuleCustomUi(
                schema: const {
                  'type': 'column',
                  'children': [
                    {'type': 'text', 'text': 'Module surface'},
                    {
                      'type': 'card',
                      'children': [
                        {'type': 'button', 'id': 'run', 'label': 'Run'},
                        {'type': 'value', 'id': 'result', 'label': 'Result'},
                        {'type': 'chart', 'id': 'result', 'title': 'History'},
                      ],
                    },
                  ],
                },
                values: const {'result': 42},
                history: const {
                  'result': [1, 4, 9, 16],
                },
                onChanged: (id, _) => events.add(id),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Module surface'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      await tester.tap(find.text('Run'));
      expect(events, ['run']);
    },
  );
}
