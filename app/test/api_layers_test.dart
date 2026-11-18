import 'dart:convert';
import 'dart:io';

import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_protocol.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled API descriptor agrees with middle wire contract', () async {
    final description = jsonDecode(
      await rootBundle.loadString('assets/module_sdk/api_layers.json'),
    ) as Map<String, dynamic>;
    final layers = description['layers'] as Map<String, dynamic>;
    expect(layers.keys, unorderedEquals(['internal', 'middle', 'external']));
    expect(layers['middle']['protocol'], ModuleProtocol.version);
    expect(layers['middle']['capabilities'], ModuleProtocol.capabilities);
    expect(layers['internal']['address'], [
      'workspaceId',
      'instanceId',
      'portId',
    ]);
    expect(
      layers['external']['bindings']['aiDevelopment']['runtimeControl'],
      isFalse,
    );
  });

  test(
    'UI-created SDK project includes the canonical API descriptor',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qualia-api-sdk-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await LocalModuleStore().createProject(directory.path);
      expect(
        await File('${directory.path}/api_layers.json').readAsString(),
        await rootBundle.loadString('assets/module_sdk/api_layers.json'),
      );
    },
  );
}
