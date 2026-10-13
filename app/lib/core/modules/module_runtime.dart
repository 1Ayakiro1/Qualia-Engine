import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../workspace/workspace_model.dart';
import 'local_module_store.dart';
import 'module_registry.dart';
import 'port_schema.dart';
import '../logic/logic_blocks.dart';

typedef RuntimeUpdate = void Function(
  String node,
  String status,
  Map<String, dynamic> values,
);

/// One supervised language-neutral process per module node, not a plugin in the
/// engine. Windows are views only; this host owns execution and port routing.
class ModuleRuntime {
  ModuleRuntime({
    required this.onUpdate,
    LocalModuleStore? store,
    Future<Process> Function(String, String)? launch,
    this.launchPackaged,
  }) : store = store ?? LocalModuleStore(),
       launch =
           launch ??
           ((executable, directory) =>
               Process.start(executable, [], workingDirectory: directory));
  final RuntimeUpdate onUpdate;
  final LocalModuleStore store;
  final Future<Process> Function(String, String) launch;
  final Future<Process> Function(ModuleLaunchCommand)? launchPackaged;
  final Map<String, _Instance> _instances = {};
  List<WorkspaceNode> _nodes = [];
  List<WorkspaceLink> _links = [];
  bool _disposed = false;
  String _project = '';

  void sync(
    String project,
    List<WorkspaceNode> nodes,
    List<WorkspaceLink> links,
    List<SystemModule> library,
  ) {
    if (_disposed) return;
    if (project != _project) {
      for (final instance in _instances.values) {
        instance.stop();
      }
      _instances.clear();
      _project = project;
    }
    _nodes = nodes;
    _links = links;
    final desired = <String, SystemModule>{};
    for (final node in nodes.where(
      (n) => !n.isLogic && n.module.isLocal && n.settings['enabled'] != false,
    )) {
      // Only host library installations authorize execution. An imported
      // workspace containing a package hash or entrypoint grants no trust.
      final installed = library
          .where(
            (m) =>
                m.id == node.module.id &&
                m.version == node.module.version &&
                m.localPackage == node.module.localPackage,
          )
          .firstOrNull;
      if (installed != null && installed.isLocal) desired[node.id] = installed;
    }
    for (final id in _instances.keys.toList()) {
      if (!desired.containsKey(id) ||
          _instances[id]!.module.localPackage != desired[id]!.localPackage) {
        _instances.remove(id)!.stop();
      }
    }
    for (final node in nodes) {
      final installed = desired[node.id];
      if (installed == null) continue;
      final instance = _instances.putIfAbsent(node.id, () {
        final instance = _Instance(installed);
        unawaited(_start(node.id, instance));
        return instance;
      });
      final parameters = {
        for (final f in _parameterFields(installed).whereType<Map>())
          if (f['type'] != 'button' &&
              f['type'] != 'label' &&
              f.containsKey('default'))
            f['id'] as String: f['default'],
        for (final f in _parameterFields(installed).whereType<Map>())
          if (f['type'] != 'button' &&
              f['type'] != 'label' &&
              node.settings.containsKey(f['id']))
            f['id'] as String: node.settings[f['id']],
      };
      final encoded = jsonEncode(parameters);
      if (instance.parameters != encoded) {
        instance.parameters = encoded;
        if (instance.ready) {
          instance.send({'type': 'parameters', 'values': parameters});
        }
      }
    }
  }

  bool _current(String id, _Instance instance) =>
      !_disposed && _instances[id] == instance;
  void _update(
    String id,
    _Instance instance,
    String status, [
    Map<String, dynamic> values = const {},
  ]) {
    scheduleMicrotask(() {
      if (_current(id, instance)) onUpdate(id, status, values);
    });
  }

  Future<void> _start(String id, _Instance instance) async {
    _update(id, instance, 'starting');
    try {
      final command = await store.command(instance.module);
      if (!_current(id, instance)) return;
      final process = launchPackaged != null
          ? await launchPackaged!(command)
          : command.arguments.isEmpty
          ? await launch(command.executable, command.directory)
          : await Process.start(
              command.executable,
              command.arguments,
              workingDirectory: command.directory,
            );
      instance.process = process;
      if (!_current(id, instance) || instance.stopped) {
        process.kill(ProcessSignal.sigkill);
        return;
      }
      process.stdin.done.catchError((Object _) {});
      instance.timeout = Timer(
        const Duration(seconds: 5),
        () => _fail(id, instance, 'handshake timeout'),
      );
      var bytes = <int>[];
      var frames = 0;
      var window = DateTime.now();
      instance.stdout = process.stdout.listen((chunk) {
        for (final byte in chunk) {
          if (byte == 10) {
            if (DateTime.now().difference(window).inSeconds >= 1) {
              frames = 0;
              window = DateTime.now();
            }
            if (++frames > 1000) {
              _fail(id, instance, 'output rate exceeded');
              return;
            }
            try {
              _message(id, instance, jsonDecode(utf8.decode(bytes)));
            } catch (_) {
              _fail(id, instance, 'invalid protocol frame');
              return;
            }
            bytes = [];
          } else {
            bytes.add(byte);
            if (bytes.length > 65536) {
              _fail(id, instance, 'frame too large');
              return;
            }
          }
        }
      }, onError: (Object _) => _fail(id, instance, 'stdout error'));
      // Drain stderr without accumulating unbounded logs in the host.
      instance.stderr = process.stderr.listen((_) {});
      unawaited(
        process.exitCode.then((code) {
          if (!instance.stopped) {
            instance.stop();
            _update(id, instance, 'exited ($code)');
          }
        }),
      );
    } catch (e) {
      _fail(id, instance, '$e');
    }
  }

  void _fail(String id, _Instance instance, String reason) {
    instance.stop();
    _update(id, instance, 'error: $reason');
  }

  void _message(String id, _Instance instance, dynamic data) {
    if (!_current(id, instance) || instance.stopped || data is! Map) return;
    if (data['type'] == 'ready') {
      if (instance.ready || data['protocol'] != 1) {
        throw const FormatException('Invalid handshake');
      }
      final required = data['requires'] ?? const [];
      if (required is! List ||
          required.length > 32 ||
          required.any(
            (item) =>
                !const ['port-schemas-v1', 'host-logic-v1'].contains(item),
          )) {
        throw const FormatException('Unsupported required capability');
      }
      instance.timeout?.cancel();
      instance.ready = true;
      instance.send({
        'type': 'init',
        'protocol': 1,
        'capabilities': ['port-schemas-v1', 'host-logic-v1'],
        'instanceId': id,
        'parameters': jsonDecode(instance.parameters),
      });
      _update(id, instance, 'running');
    } else if (!instance.ready) {
      throw const FormatException('Handshake required');
    } else if (data['type'] == 'state' && data['values'] is Map) {
      final fields = <String>{
        ..._parameterFields(instance.module)
            .whereType<Map>()
            .where((f) => f['type'] == 'label')
            .map((f) => f['id']),
        ..._customValueFields(instance.module.manifest['uiLayout']),
      };
      _update(id, instance, 'running', {
        for (final entry in (data['values'] as Map).entries)
          if (fields.contains(entry.key)) entry.key as String: entry.value,
      });
    } else if (data['type'] == 'output') {
      final port = data['port'];
      final hops = data['hops'];
      if (hops is! int ||
          hops <= 0 ||
          hops > 32 ||
          !((instance.module.manifest['ports'] as Map)['outputs'] as List)
              .contains(port)) {
        return;
      }
      if (!PortSchema.accepts(
        PortSchema.forPort(instance.module.manifest, port as String, true),
        data['value'],
      )) {
        _update(id, instance, 'output rejected: schema');
        return;
      }
      routeOutput(id, port, data['value'], hops);
    }
  }

  /// A bounded, iterative graph dispatcher shared by processes and logic nodes.
  /// Hops are decremented at every edge; fan-out also has an event budget.
  void routeOutput(String id, String port, dynamic value, int hops) {
    if (_disposed || hops <= 0 || hops > 32) return;
    final queue = <(String, String, dynamic, int)>[(id, port, value, hops)];
    var cursor = 0;
    var deliveries = 0;
    while (cursor < queue.length && cursor < 512) {
      final (source, output, payload, remaining) = queue[cursor++];
      if (remaining <= 0) continue;
      final sourceNode = _nodes.where((node) => node.id == source).firstOrNull;
      if (sourceNode == null ||
          !sourceNode.outputs.contains(output) ||
          !_acceptsType(sourceNode.portType(output, true), payload)) {
        continue;
      }
      for (final link in _links.where(
        (l) => l.source == source && l.output == output,
      )) {
        if (++deliveries > 512) return;
        final node = _nodes.where((n) => n.id == link.target).firstOrNull;
        if (node == null ||
            node.settings['enabled'] == false ||
            !node.inputs.contains(link.input)) {
          continue;
        }
        final validType = _acceptsType(
          node.portType(link.input, false),
          payload,
        );
        if (!validType ||
            !PortSchema.accepts(
              PortSchema.forPort(
                _instances[node.id]?.module.manifest ?? node.module.manifest,
                link.input,
                false,
              ),
              payload,
            )) {
          onUpdate(node.id, 'input rejected: schema/type', {});
          continue;
        }
        if (node.isLogic) {
          try {
            final emitted = LogicBlocks.run(
              node.logicType,
              node.settings,
              payload,
            );
            onUpdate(node.id, 'running', {
              'lastInput': payload,
              'lastOutput': emitted.isEmpty ? null : emitted.last.value,
            });
            for (final emission in emitted) {
              if (node.outputs.contains(emission.port) && queue.length < 512) {
                queue.add((
                  node.id,
                  emission.port,
                  emission.value,
                  remaining - 1,
                ));
              }
            }
          } catch (error) {
            onUpdate(node.id, 'logic error: $error', {});
          }
        } else {
          final target = _instances[node.id];
          if (target == null ||
              !target.ready ||
              target.stopped ||
              !((target.module.manifest['ports'] as Map)['inputs'] as List)
                  .contains(link.input)) {
            continue;
          }
          target.send({
            'type': 'input',
            'port': link.input,
            'value': payload,
            'hops': remaining - 1,
          });
        }
      }
    }
  }

  static bool _acceptsType(WorkspacePortType type, dynamic value) =>
      switch (type) {
        WorkspacePortType.any => true,
        WorkspacePortType.number => value is num && value.isFinite,
        WorkspacePortType.string => value is String,
        WorkspacePortType.boolean => value is bool,
        WorkspacePortType.list => value is List,
        WorkspacePortType.object => value is Map,
      };

  static List<dynamic> _parameterFields(SystemModule module) =>
      module.manifest['parameters'] is List
      ? module.manifest['parameters'] as List
      : module.manifest['ui'] is List
      ? module.manifest['ui'] as List
      : const [];

  static Set<String> _customValueFields(dynamic value) {
    final result = <String>{};
    void visit(dynamic node) {
      if (node is! Map) return;
      if (node['type'] == 'value' || node['type'] == 'chart') {
        if (node['id'] is String) result.add(node['id'] as String);
      }
      if (node['children'] is List) {
        for (final child in node['children'] as List) {
          visit(child);
        }
      }
    }

    visit(value);
    return result;
  }

  void event(String id, String field, dynamic value) {
    final instance = _instances[id];
    if (instance == null || !instance.ready || instance.stopped) return;
    instance.send({'type': 'event', 'id': field, 'value': value});
  }

  void dispose() {
    _disposed = true;
    for (final instance in _instances.values) {
      instance.stop();
    }
    _instances.clear();
  }
}

class _Instance {
  _Instance(this.module);
  final SystemModule module;
  Process? process;
  Timer? timeout;
  StreamSubscription<List<int>>? stdout, stderr;
  String parameters = '{}';
  bool ready = false, stopped = false;
  int pending = 0;
  Future<void> writes = Future<void>.value();
  void send(Map<String, dynamic> message) {
    if (stopped || process == null) return;
    final frame = '${jsonEncode(message)}\n';
    if (utf8.encode(frame).length > 65537 || ++pending > 128) {
      stop();
      return;
    }
    writes = writes.then((_) async {
      try {
        if (!stopped) {
          process!.stdin.write(frame);
          await process!.stdin.flush();
        }
      } catch (_) {
        stop();
      } finally {
        pending--;
      }
    });
  }

  void stop() {
    if (stopped) return;
    stopped = true;
    timeout?.cancel();
    unawaited(stdout?.cancel() ?? Future<void>.value());
    unawaited(stderr?.cancel() ?? Future<void>.value());
    process?.kill(ProcessSignal.sigkill);
  }
}
