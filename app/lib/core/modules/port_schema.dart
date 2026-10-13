/// Small, bounded JSON contract. No coercion: an invalid payload is rejected.
class PortSchema {
  static const types = [
    'any',
    'null',
    'boolean',
    'number',
    'string',
    'array',
    'object',
  ];

  static void validate(dynamic schema, [int depth = 0]) {
    if (depth > 8 || schema is! Map || !types.contains(schema['type'])) {
      throw const FormatException('Invalid port schema type or depth.');
    }
    if (schema.keys.any(
      (key) => ![
        'type',
        'properties',
        'required',
        'additionalProperties',
        'items',
      ].contains(key),
    )) {
      throw const FormatException('Unknown port schema keyword.');
    }
    if (schema.containsKey('properties')) {
      final properties = schema['properties'];
      if (schema['type'] != 'object' ||
          properties is! Map ||
          properties.length > 64 ||
          properties.keys.any(
            (key) => key is! String || key.length > 64 || key.isEmpty,
          )) {
        throw const FormatException('Invalid schema properties.');
      }
      for (final child in properties.values) {
        validate(child, depth + 1);
      }
    }
    if (schema.containsKey('required')) {
      final required = schema['required'];
      if (schema['type'] != 'object' ||
          required is! List ||
          required.length > 64 ||
          required.any(
            (key) =>
                key is! String ||
                !(schema['properties'] as Map? ?? {}).containsKey(key),
          )) {
        throw const FormatException(
          'Required keys must have property schemas.',
        );
      }
    }
    if (schema.containsKey('additionalProperties') &&
        (schema['type'] != 'object' ||
            schema['additionalProperties'] is! bool)) {
      throw const FormatException('Invalid additionalProperties.');
    }
    if (schema.containsKey('items')) {
      if (schema['type'] != 'array') {
        throw const FormatException('items requires array.');
      }
      validate(schema['items'], depth + 1);
    }
  }

  static bool accepts(dynamic schema, dynamic value, [int depth = 0]) {
    if (depth > 16) return false;
    if (schema == null) return true; // Legacy ports remain compatible.
    if (schema is! Map) return false;
    switch (schema['type']) {
      case 'any':
        return true;
      case 'null':
        return value == null;
      case 'boolean':
        return value is bool;
      case 'number':
        return value is num && value.isFinite;
      case 'string':
        return value is String;
      case 'array':
        return value is List &&
            value.length <= 4096 &&
            value.every((v) => accepts(schema['items'], v, depth + 1));
      case 'object':
        if (value is! Map || value.length > 256) return false;
        final properties = schema['properties'] as Map? ?? {};
        final required = schema['required'] as List? ?? [];
        if (required.any((key) => !value.containsKey(key))) return false;
        return value.entries.every(
          (entry) =>
              entry.key is String &&
              (properties.containsKey(entry.key)
                  ? accepts(properties[entry.key], entry.value, depth + 1)
                  : schema['additionalProperties'] != false),
        );
      default:
        return false;
    }
  }

  static dynamic forPort(
    Map<String, dynamic> manifest,
    String port,
    bool output,
  ) {
    final schemas = manifest['portSchemas'];
    if (schemas is! Map) return null;
    final direction = schemas[output ? 'outputs' : 'inputs'];
    return direction is Map ? direction[port] : null;
  }

  static void validateManifest(Map<String, dynamic> manifest) {
    if (!manifest.containsKey('portSchemas')) return;
    final schemas = manifest['portSchemas'];
    if (schemas is! Map ||
        schemas.keys.any((k) => !['inputs', 'outputs'].contains(k))) {
      throw const FormatException('Invalid portSchemas.');
    }
    for (final direction in ['inputs', 'outputs']) {
      final entries = schemas[direction] ?? {};
      if (entries is! Map) {
        throw const FormatException('Invalid port schemas direction.');
      }
      for (final entry in entries.entries) {
        if (!((manifest['ports'] as Map)[direction] as List).contains(
          entry.key,
        )) {
          throw const FormatException('Schema refers to an undeclared port.');
        }
        validate(entry.value);
      }
    }
  }
}
