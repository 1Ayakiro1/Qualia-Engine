import 'dart:convert';

import '../modules/module_registry.dart';
import '../modules/port_schema.dart';
import 'logic_script.dart';

enum LogicBlockType { condition, filter, select, validate, script, junction }

class LogicBlocks {
  static SystemModule module(LogicBlockType type) => SystemModule(
    id: 'qualia.logic.${type.name}',
    name: label(type),
    category: 'Logic',
    description: 'Host-owned bounded data routing. No external code execution.',
    active: true,
    manifest: {
      'ports': {
        'inputs': ['input'],
        'outputs': outputs(type),
      },
    },
  );
  static String label(LogicBlockType type) => switch (type) {
    LogicBlockType.condition => 'IF',
    LogicBlockType.filter => 'Filter',
    LogicBlockType.select => 'Select fields',
    LogicBlockType.validate => 'Validate',
    LogicBlockType.script => 'Script',
    LogicBlockType.junction => 'Junction',
  };
  static List<String> outputs(LogicBlockType type) => switch (type) {
    LogicBlockType.condition => ['true', 'false'],
    LogicBlockType.validate => ['valid', 'invalid'],
    LogicBlockType.script => ['output', 'true', 'false', 'valid', 'invalid'],
    LogicBlockType.junction => ['output'],
    _ => ['output'],
  };
  static Map<String, dynamic> defaults(LogicBlockType type) => switch (type) {
    LogicBlockType.condition ||
    LogicBlockType.filter => {'expression': 'value != null'},
    LogicBlockType.select => {'fields': 'score, channel'},
    LogicBlockType.validate => {
      'schema': '{"type":"object","properties":{"score":{"type":"number"}},"required":["score"],"additionalProperties":false}',
    },
    LogicBlockType.script => {
      'script': 'if has(value, "score") and value.score >= 0.7 {\n  emit true select(value, "score", "channel");\n} else {\n  emit false value;\n}',
    },
    LogicBlockType.junction => const {},
  };
  static List<LogicEmission> run(
    LogicBlockType type,
    Map<String, dynamic> settings,
    dynamic value,
  ) {
    final config = {...defaults(type), ...settings};
    switch (type) {
      case LogicBlockType.junction:
        return [LogicEmission('output', value)];
      case LogicBlockType.condition:
      case LogicBlockType.filter:
        final matches = LogicScript.condition(
          config['expression'] as String,
          value,
        );
        final emission = LogicEmission(matches ? 'true' : 'false', value);
        if (type == LogicBlockType.condition) return [emission];
        return emission.port == 'true' ? [LogicEmission('output', value)] : [];
      case LogicBlockType.select:
        if (value is! Map) {
          throw const FormatException('Select fields needs an object.');
        }
        final text = config['fields'];
        if (text is! String || text.length > 4096) {
          throw const FormatException('Invalid fields.');
        }
        final keys = text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (keys.isEmpty || keys.length > 64) {
          throw const FormatException('Choose 1–64 fields.');
        }
        return [
          LogicEmission('output', {
            for (final key in keys)
              if (value.containsKey(key)) key: value[key],
          }),
        ];
      case LogicBlockType.validate:
        final text = config['schema'];
        if (text is! String || text.length > 8192) {
          throw const FormatException('Invalid schema size.');
        }
        final schema = jsonDecode(text);
        PortSchema.validate(schema);
        return [
          LogicEmission(
            PortSchema.accepts(schema, value) ? 'valid' : 'invalid',
            value,
          ),
        ];
      case LogicBlockType.script:
        return LogicScript(config['script'] as String).run(value);
    }
  }
}
