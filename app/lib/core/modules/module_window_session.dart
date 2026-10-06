import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace/workspace_model.dart';
import '../../state/workspace_state.dart';

typedef ModuleProcessLauncher = Future<Process> Function(List<String> args);

final moduleWindowSessionsProvider = Provider<ModuleWindowSessions>((ref) {
  final sessions = ModuleWindowSessions(
    nodeById: (id) {
      final workspace = ref.read(workspaceProvider);
      return workspace.nodes
          .where(
            (node) =>
                node.id == id &&
                !workspace.hiddenModuleIds.contains(node.module.id),
          )
          .firstOrNull;
    },
    onParameter: (id, key, value) =>
        ref.read(workspaceProvider.notifier).setParameter(id, key, value),
  );
  ref.listen(workspaceProvider, (_, state) => sessions.update());
  ref.onDispose(sessions.dispose);
  return sessions;
});

/// Child windows never load/save shared preferences or run another workspace.
/// The main process owns settings; authenticated loopback WebSockets keep all
/// views of a node live, including updates from the Inspector.
class ModuleWindowSessions {
  ModuleWindowSessions({
    required this.nodeById,
    required this.onParameter,
    ModuleProcessLauncher? launch,
  }) : _launch = launch ?? _startProcess;
  final WorkspaceNode? Function(String id) nodeById;
  final void Function(String id, String key, dynamic value) onParameter;
  final ModuleProcessLauncher _launch;
  final Map<String, _ModuleWindowSession> _sessions = {};
  bool _disposed = false;

  static Future<Process> _startProcess(List<String> args) => Process.start(
    Platform.resolvedExecutable,
    args,
    workingDirectory: File(Platform.resolvedExecutable).parent.path,
  );

  Future<bool> open(
    WorkspaceNode node, {
    required String locale,
    required bool light,
  }) async {
    if (_disposed) return false;
    final existing = _sessions[node.id];
    if (existing != null) {
      existing.socket?.add(jsonEncode({'type': 'focus'}));
      return true;
    }
    final token = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_disposed) {
      await server.close(force: true);
      return false;
    }
    // A second activation may arrive while binding the first server.
    if (_sessions.containsKey(node.id)) {
      await server.close(force: true);
      _sessions[node.id]?.socket?.add(jsonEncode({'type': 'focus'}));
      return true;
    }
    final session = _ModuleWindowSession(server, token, locale, light);
    _sessions[node.id] = session;
    server.listen((request) async {
      if (request.uri.path != '/$token' ||
          session.socket != null ||
          !WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      if (_disposed || _sessions[node.id] != session) {
        await socket.close();
        return;
      }
      session.socket = socket;
      session.timeout?.cancel();
      _sendNode(node.id, session);
      socket.listen(
        (message) {
          if (message is! String || message.length > 65536) return;
          try {
            final data = jsonDecode(message);
            final current = nodeById(node.id);
            if (data is! Map ||
                data['type'] != 'parameter' ||
                data['key'] is! String ||
                current == null) {
              return;
            }
            final key = data['key'] as String;
            final fields = [
              if (current.module.manifest['parameters'] is List)
                ...current.module.manifest['parameters'] as List,
              if (current.module.manifest['ui'] is List)
                ...current.module.manifest['ui'] as List,
            ];
            final value = data['value'];
            final field = fields
                .whereType<Map>()
                .where((field) => field['id'] == key)
                .firstOrNull;
            final type = key == 'enabled'
                ? 'toggle'
                : key == 'label'
                ? 'text'
                : field?['type'];
            final valid = switch (type) {
              'toggle' || 'button' => value is bool,
              'text' => value is String && value.length <= 16384,
              'select' =>
                value is String &&
                    field?['options'] is List &&
                    (field!['options'] as List).contains(value),
              'slider' || 'number' => value is num && value.isFinite,
              _ => false,
            };
            if (valid) {
              onParameter(node.id, key, data['value']);
              _sendNode(node.id, session);
            }
          } catch (_) {}
        },
        onDone: () => _close(node.id, session),
        onError: (Object _) => _close(node.id, session),
      );
    });
    try {
      final process = await _launch([
        '--module-window',
        '${server.port}',
        token,
      ]);
      session.process = process;
      process.stdout.drain<void>();
      process.stderr.drain<void>();
      unawaited(process.exitCode.then((_) => _close(node.id, session)));
      if (session.socket == null) {
        session.timeout = Timer(
          const Duration(seconds: 20),
          () => _close(node.id, session),
        );
      }
      if (_disposed || _sessions[node.id] != session) {
        process.kill();
        _close(node.id, session);
      }
      return !_disposed;
    } catch (_) {
      _close(node.id, session);
      return false;
    }
  }

  void _sendNode(String id, _ModuleWindowSession session) {
    final node = nodeById(id);
    if (node == null) {
      _close(id, session);
      return;
    }
    session.socket?.add(
      jsonEncode({
        'type': 'node',
        'node': node.toJson(includeRuntime: true),
        'locale': session.locale,
        'light': session.light,
      }),
    );
  }

  void update() {
    for (final entry in _sessions.entries.toList()) {
      _sendNode(entry.key, entry.value);
    }
  }

  void _close(String id, _ModuleWindowSession session) {
    if (_sessions[id] != session) return;
    _sessions.remove(id);
    session.timeout?.cancel();
    unawaited(session.socket?.close() ?? Future<void>.value());
    unawaited(session.server.close(force: true));
    session.process?.kill();
  }

  void dispose() {
    _disposed = true;
    for (final entry in _sessions.entries.toList()) {
      _close(entry.key, entry.value);
    }
  }
}

class _ModuleWindowSession {
  _ModuleWindowSession(this.server, this.token, this.locale, this.light);
  final HttpServer server;
  final String token;
  final String locale;
  final bool light;
  WebSocket? socket;
  Process? process;
  Timer? timeout;
}
