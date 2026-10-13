import 'dart:convert';

/// A bounded interpreter, not eval/JS/Python. No loops, assignment or OS access.
/// Grammar: if expression { statements } else { statements }; emit port expr;
/// or drop;. Expressions support value.field, JSON scalars, comparisons,
/// and/or/not, has(value,"field"), select(value,"field",...).
class LogicScript {
  LogicScript(String source) {
    if (source.length > 8192) {
      throw const FormatException('Script exceeds 8192 characters.');
    }
    final pattern = RegExp(
      r'\s+|//[^\n]*|"(?:\\.|[^"\\])*"|\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_]*|==|!=|>=|<=|[{}();,.<>!\-]',
    );
    var end = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start != end) {
        throw FormatException('Unexpected character at $end.');
      }
      end = match.end;
      final text = match.group(0)!;
      if (text.trim().isNotEmpty && !text.startsWith('//')) _tokens.add(text);
    }
    if (end != source.length || _tokens.length > 1024) {
      throw const FormatException('Invalid or oversized script.');
    }
    _program = _statements(false, 0);
    if (_index != _tokens.length) {
      throw const FormatException('Unexpected script suffix.');
    }
  }
  final List<String> _tokens = [];
  int _index = 0;
  late final List<_Statement> _program;

  /// Parse one expression only; block settings cannot inject emit statements.
  static bool condition(String source, dynamic value) {
    final script = LogicScript('emit output $source;');
    if (script._program.length != 1 ||
        script._program.single.port != 'output') {
      throw const FormatException('Expected one condition expression.');
    }
    final result = script.run(value).single.value;
    if (result is! bool) {
      throw const FormatException('Condition needs a boolean.');
    }
    return result;
  }

  String get _peek => _index < _tokens.length ? _tokens[_index] : '';
  bool _take(String token) {
    if (_peek != token) return false;
    _index++;
    return true;
  }

  String _next() {
    if (_peek.isEmpty) throw const FormatException('Unexpected end of script.');
    return _tokens[_index++];
  }

  void _expect(String token) {
    if (!_take(token)) {
      throw FormatException('Expected $token near token $_index.');
    }
  }

  List<_Statement> _statements(bool block, int depth) {
    if (depth > 16) throw const FormatException('Script nesting exceeds 16.');
    final result = <_Statement>[];
    while (_peek.isNotEmpty && _peek != '}') {
      if (_take('if')) {
        final test = _expression(0, depth + 1);
        _expect('{');
        final yes = _statements(true, depth + 1);
        final no = <_Statement>[];
        if (_take('else')) {
          _expect('{');
          no.addAll(_statements(true, depth + 1));
        }
        result.add(_Statement(test: test, yes: yes, no: no));
      } else if (_take('emit')) {
        final port = _next();
        if (!['output', 'true', 'false', 'valid', 'invalid'].contains(port)) {
          throw const FormatException('Unknown emit port.');
        }
        final value = _expression(0, depth + 1);
        _expect(';');
        result.add(_Statement(port: port, value: value));
      } else if (_take('drop')) {
        _expect(';');
        result.add(_Statement(drop: true));
      } else {
        throw FormatException('Expected if, emit or drop near token $_index.');
      }
    }
    if (block) _expect('}');
    return result;
  }

  static const _precedence = {
    'or': 1,
    'and': 2,
    '==': 3,
    '!=': 3,
    '>': 4,
    '>=': 4,
    '<': 4,
    '<=': 4,
  };
  _Expression _expression(int minimum, int depth) {
    if (depth > 32) {
      throw const FormatException('Expression nesting exceeds 32.');
    }
    _Expression left;
    if (_take('not') || _take('!')) {
      left = _Expression('not', children: [_expression(5, depth + 1)]);
    } else if (_take('(')) {
      left = _expression(0, depth + 1);
      _expect(')');
    } else if (_take('-')) {
      final number = num.tryParse(_next());
      if (number == null) {
        throw const FormatException('Expected number after minus.');
      }
      left = _Expression('literal', literal: -number);
    } else {
      final token = _next();
      if (token == 'value') {
        final path = <String>[];
        while (_take('.')) {
          final key = _next();
          if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
            throw const FormatException('Invalid field path.');
          }
          path.add(key);
        }
        left = _Expression('value', path: path);
      } else if (token == 'has' || token == 'select') {
        _expect('(');
        final args = <_Expression>[_expression(0, depth + 1)];
        while (_take(',')) {
          args.add(_expression(0, depth + 1));
        }
        _expect(')');
        if (args.length < 2 || (token == 'has' && args.length != 2)) {
          throw const FormatException('Invalid function arguments.');
        }
        left = _Expression(token, children: args);
      } else if (token.startsWith('"') ||
          ['true', 'false', 'null'].contains(token) ||
          num.tryParse(token) != null) {
        left = _Expression('literal', literal: jsonDecode(token));
      } else {
        throw FormatException('Unknown identifier: $token.');
      }
    }
    while ((_precedence[_peek] ?? -1) >= minimum) {
      final op = _next();
      left = _Expression(
        op,
        children: [left, _expression(_precedence[op]! + 1, depth + 1)],
      );
    }
    return left;
  }

  List<LogicEmission> run(dynamic value) {
    final result = <LogicEmission>[];
    var steps = 0;
    var dropped = false;
    void visit(List<_Statement> statements) {
      for (final statement in statements) {
        if (dropped) return;
        if (++steps > 256) {
          throw const FormatException('Script step budget exceeded.');
        }
        if (statement.drop) {
          dropped = true;
          result.clear();
          return;
        }
        if (statement.test != null) {
          final test = statement.test!.evaluate(value);
          if (test is! bool) throw const FormatException('IF needs a boolean.');
          visit(test ? statement.yes : statement.no);
        } else {
          if (result.length >= 16) {
            throw const FormatException('Too many emissions.');
          }
          result.add(
            LogicEmission(statement.port!, statement.value!.evaluate(value)),
          );
        }
      }
    }

    visit(_program);
    return result;
  }
}

class LogicEmission {
  const LogicEmission(this.port, this.value);
  final String port;
  final dynamic value;
}

class _Statement {
  _Statement({
    this.test,
    this.yes = const [],
    this.no = const [],
    this.port,
    this.value,
    this.drop = false,
  });
  final _Expression? test, value;
  final List<_Statement> yes, no;
  final String? port;
  final bool drop;
}

class _Expression {
  _Expression(
    this.op, {
    this.literal,
    this.path = const [],
    this.children = const [],
  });
  final String op;
  final dynamic literal;
  final List<String> path;
  final List<_Expression> children;
  dynamic evaluate(dynamic input, [int depth = 0]) {
    if (depth > 64) throw const FormatException('Expression budget exceeded.');
    if (op == 'literal') return literal;
    if (op == 'value') {
      dynamic value = input;
      for (final key in path) {
        value = value is Map ? value[key] : null;
      }
      return value;
    }
    final a = children.first.evaluate(input, depth + 1);
    if (op == 'not') {
      if (a is! bool) throw const FormatException('not needs a boolean.');
      return !a;
    }
    if (op == 'and' || op == 'or') {
      if (a is! bool) throw const FormatException('and/or need booleans.');
      if (op == 'and' && !a || op == 'or' && a) return a;
      final b = children[1].evaluate(input, depth + 1);
      if (b is! bool) throw const FormatException('and/or need booleans.');
      return b;
    }
    final b = children[1].evaluate(input, depth + 1);
    if (op == 'has') return a is Map && b is String && a.containsKey(b);
    if (op == 'select') {
      if (a is! Map) throw const FormatException('select needs an object.');
      final result = <String, dynamic>{};
      for (final child in children.skip(1)) {
        final key = child.evaluate(input, depth + 1);
        if (key is! String) {
          throw const FormatException('select keys must be strings.');
        }
        if (a.containsKey(key)) result[key] = a[key];
      }
      return result;
    }
    if (op == '==') return a == b;
    if (op == '!=') return a != b;
    if (a is! num || b is! num || !a.isFinite || !b.isFinite) {
      throw const FormatException('Ordering comparisons need finite numbers.');
    }
    return switch (op) {
      '>' => a > b,
      '>=' => a >= b,
      '<' => a < b,
      '<=' => a <= b,
      _ => false,
    };
  }
}
