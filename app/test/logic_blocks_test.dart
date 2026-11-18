import 'dart:convert';

import 'package:bci_engine/core/theme/app_icons.dart';

import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/logic/logic_script.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/modules/port_schema.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:bci_engine/core/workspace/workspace_repository.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceNode block(
  String id,
  LogicBlockType type, [
  Map<String, dynamic>? settings,
]) => WorkspaceNode(
  id: id,
  module: LogicBlocks.module(type),
  kind: WorkspaceNodeKind.logic,
  logicType: type,
  inputs: ['input'],
  outputs: LogicBlocks.outputs(type),
  settings: settings,
);

void main() {
  test('nested IF, short circuit, comparisons and select allowlist', () {
    final script = LogicScript('''
// Never forward secrets.
if has(value, "score") and value.score >= 0.7 {
  if not (value.channel == "C4") { emit true select(value, "score", "channel"); }
  else { emit false value.score; }
} else { drop; }
''');
    expect(script.run({}), isEmpty);
    final result = script.run({
      'score': 0.8,
      'channel': 'C3',
      'secret': 1,
    }).single;
    expect(result.port, 'true');
    expect(result.value, {'score': 0.8, 'channel': 'C3'});
    expect(script.run({'score': 0.8, 'channel': 'C4'}).single.port, 'false');
    expect(LogicScript.condition('true or value.missing > 1', {}), isTrue);
    expect(LogicScript.condition('value > -2 and value < 0', -1), isTrue);
  });

  test('drop terminates evaluation and discards prior emissions', () {
    expect(
      LogicScript('emit output value; drop; emit output value;').run(1),
      isEmpty,
    );
    expect(LogicScript('if true { drop; } emit output value;').run(1), isEmpty);
  });

  test(
    'unsafe syntax, non-booleans, injected statements and budgets fail closed',
    () {
      for (final source in [
        'while true {}',
        'emit output read("file");',
        'emit output value[0];',
        'emit output value + 1;',
        'emit output 1; }',
        'x' * 8193,
        'if ${'(' * 40}true${')' * 40} { drop; }',
      ]) {
        expect(
          () => LogicScript(source),
          throwsFormatException,
          reason: source,
        );
      }
      expect(() => LogicScript.condition('1', {}), throwsFormatException);
      expect(
        () => LogicScript.condition('true; emit output false', {}),
        throwsFormatException,
      );
      expect(
        () => LogicScript(List.filled(17, 'emit output value;').join()).run(1),
        throwsFormatException,
      );
      expect(
        () => LogicScript('if value > 1 { drop; }').run('2'),
        throwsFormatException,
      );
    },
  );

  test('all built-in block contracts', () {
    expect(
      LogicBlocks.run(LogicBlockType.condition, {
        'expression': 'value >= 2',
      }, 2).single.port,
      'true',
    );
    expect(
      LogicBlocks.run(LogicBlockType.filter, {'expression': 'value >= 2'}, 1),
      isEmpty,
    );
    expect(
      LogicBlocks.run(LogicBlockType.filter, {
        'expression': 'value >= 2',
      }, 2).single.port,
      'output',
    );
    expect(
      LogicBlocks.run(
        LogicBlockType.select,
        {'fields': 'score, channel'},
        {'score': 1, 'extra': 2},
      ).single.value,
      {'score': 1},
    );
    expect(
      LogicBlocks.run(LogicBlockType.validate, {}, {'score': 1}).single.port,
      'valid',
    );
    expect(
      LogicBlocks.run(LogicBlockType.validate, {}, {'score': '1'}).single.port,
      'invalid',
    );
    expect(
      LogicBlocks.run(LogicBlockType.validate, {}, {
        'score': 1,
        'extra': 2,
      }).single.port,
      'invalid',
    );
  });

  test('bounded schemas are strict and legacy ports remain compatible', () {
    final schema = {
      'type': 'object',
      'properties': {
        'scores': {
          'type': 'array',
          'items': {'type': 'number'},
        },
      },
      'required': ['scores'],
      'additionalProperties': false,
    };
    PortSchema.validate(schema);
    expect(
      PortSchema.accepts(schema, {
        'scores': [1, 2],
      }),
      isTrue,
    );
    for (final value in [
      {},
      {
        'scores': [1, '2'],
      },
      {
        'scores': [double.infinity],
      },
      {'scores': [], 'extra': 1},
    ]) {
      expect(PortSchema.accepts(schema, value), isFalse);
    }
    expect(PortSchema.accepts(null, 'legacy'), isTrue);
    expect(
      () => PortSchema.validate({
        'type': 'object',
        'required': ['missing'],
      }),
      throwsFormatException,
    );
    expect(
      () => PortSchema.validate({'type': 'number', 'minimum': 0}),
      throwsFormatException,
    );
  });

  test('logic-only workspaces have no executable dependencies and reconstruct host metadata', () async {
    final node = block('logic', LogicBlockType.script, {
      'script': 'emit output value;',
    });
    final document = WorkspaceProject(
      id: 'graph',
      name: 'Graph',
      nodes: [node],
    ).toPackage();
    expect(document['dependencies'], isEmpty);
    final restored = WorkspaceProject.fromPackage(
      jsonDecode(jsonEncode(document)),
    );
    expect(restored.nodes.single.isLogic, isTrue);
    expect(restored.nodes.single.settings['script'], 'emit output value;');
    expect(await resolveWorkspaceModules(restored, []), isEmpty);
    final serialized = node.toJson();
    serialized['module'] = {'entrypoint': '/unsafe'};
    expect(WorkspaceNode.fromJson(serialized).module.id, 'qualia.logic.script');
    serialized['logicType'] = 'unknown';
    expect(() => WorkspaceNode.fromJson(serialized), throwsFormatException);
  });

  test(
    'routing includes logic, skips disabled blocks and bounds cyclic fan-out',
    () {
      final results = <String, dynamic>{};
      final runtime = ModuleRuntime(
        onUpdate: (id, status, values) => results[id] = values['lastOutput'],
      );
      addTearDown(runtime.dispose);
      final nodes = [
        block('source', LogicBlockType.script),
        block('if', LogicBlockType.condition, {
          'expression': 'value.score > 0.7',
        }),
        block('select', LogicBlockType.select, {'fields': 'score'}),
        block('false', LogicBlockType.filter, {'expression': 'true'}),
      ];
      final links = [
        const WorkspaceLink(
          source: 'source',
          output: 'output',
          target: 'if',
          input: 'input',
        ),
        const WorkspaceLink(
          source: 'if',
          output: 'true',
          target: 'select',
          input: 'input',
        ),
        const WorkspaceLink(
          source: 'if',
          output: 'false',
          target: 'false',
          input: 'input',
        ),
      ];
      runtime.sync('graph', nodes, links, []);
      runtime.routeOutput('source', 'output', {'score': 0.8, 'secret': 1}, 32);
      expect(results['select'], {'score': 0.8});
      expect(results.containsKey('false'), isFalse);
      nodes[1].settings['enabled'] = false;
      results.clear();
      runtime.routeOutput('source', 'output', {'score': 0.8}, 32);
      expect(results, isEmpty);
      nodes[1].settings['enabled'] = true;
      runtime.sync('graph', nodes, [
        ...links,
        const WorkspaceLink(
          source: 'select',
          output: 'output',
          target: 'if',
          input: 'input',
        ),
      ], []);
      runtime.routeOutput('source', 'output', {'score': 0.8}, 32);
      expect(results['select'], {'score': 0.8});
    },
  );

  test(
    'independent filters persist without deleting nodes, settings or links',
    () async {
      SharedPreferences.setMockInitialValues({});
      var scope = ProviderContainer();
      scope.read(workspaceProvider);
      await Future<void>.delayed(Duration.zero);
      final controller = scope.read(workspaceProvider.notifier);
      final a = controller.addLogicBlock(
        LogicBlockType.condition,
        const Offset(4800, 4800),
      );
      final b = controller.addLogicBlock(
        LogicBlockType.select,
        const Offset(5200, 4800),
      );
      controller.connect(
        WorkspaceLink(
          source: a.id,
          output: 'true',
          target: b.id,
          input: 'input',
        ),
      );
      controller.setParameter(a.id, 'expression', 'value.score > 0.7');
      controller.setBlockVisibility(logic: false, modules: true);
      controller.addPort(a.id, true);
      expect(a.outputs, ['true', 'false']);
      expect(scope.read(workspaceProvider).links.length, 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      scope.dispose();
      scope = ProviderContainer();
      addTearDown(scope.dispose);
      scope.read(workspaceProvider);
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(workspaceProvider).showLogicBlocks, isFalse);
      expect(scope.read(workspaceProvider).showModuleBlocks, isTrue);
      expect(scope.read(workspaceProvider).nodes.length, 2);
      expect(
        scope.read(workspaceProvider).nodes.first.settings['expression'],
        'value.score > 0.7',
      );
      expect(scope.read(workspaceProvider).links.length, 1);
    },
  );

  testWidgets(
    'distinct logic icon, independent canvas filters and editable script',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const BciApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Workspace'));
      await tester.pumpAndSettle();
      final controller = scope.read(workspaceProvider.notifier);
      final node = controller.addLogicBlock(
        LogicBlockType.script,
        const Offset(4820, 4820),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.workflow), findsWidgets);
      expect(find.byKey(ValueKey('workspace node ${node.id}')), findsOneWidget);
      controller.setBlockVisibility(logic: false);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('workspace node ${node.id}')), findsNothing);
      expect(scope.read(workspaceProvider).nodes.single.id, node.id);
      controller.setBlockVisibility(logic: true, modules: false);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byKey(ValueKey('workspace node ${node.id}')),
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      // The scene pane also exposes these controls; edit the opened view here.
      final field = find.byKey(const ValueKey('logic editor script')).first;
      expect(field, findsOneWidget);
      await tester.enterText(field, 'emit output select(value, "score");');
      await tester.pumpAndSettle();
      expect(node.settings['script'], 'emit output select(value, "score");');
      final button = find.text('Test without sending to graph').first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('output: {"score":0.8}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
}
