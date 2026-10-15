import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_platform.dart';
import 'package:bci_engine/core/modules/module_protocol.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temporary;
  late LocalModuleStore store;
  late Map<String, dynamic> manifest;
  late String script;
  late List<Process> processes;
  final python = Platform.isWindows ? 'python' : 'python3';

  setUp(() async {
    processes = [];
    temporary = await Directory.systemTemp.createTemp('qualia-transports-');
    store = LocalModuleStore(root: Directory('${temporary.path}/installed'));
    manifest = jsonDecode(
      await File('../modules/examples/portable/manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    script = await File('../modules/examples/portable/payload/main.py')
        .readAsString();
  });
  tearDown(() async {
    for (final process in processes) {
      process.kill(ProcessSignal.sigkill);
    }
    await Future.wait(processes.map((process) => process.exitCode))
        .timeout(const Duration(seconds: 5));
    await temporary.delete(recursive: true);
  });

  Future<Process> launchTracked(ModuleLaunchCommand command) async {
    final process = await Process.start(
      command.executable,
      command.arguments,
      workingDirectory: command.directory,
      environment: command.environment,
    );
    processes.add(process);
    return process;
  }

  List<int> package(
    Map<String, dynamic> m, {
    String? source,
    List<int>? asset,
  }) {
    final archive = Archive();
    for (final entry in {
      'manifest.json': utf8.encode(jsonEncode(m)),
      'main.py': utf8.encode(source ?? script),
      'assets/data.bin': ?asset,
    }.entries) {
      archive.addFile(
        ArchiveFile(entry.key, entry.value.length, entry.value)
          ..compress = false,
      );
    }
    return ZipEncoder().encode(
      archive,
      level: 0,
      // DOS time's low byte is 250. A search for a payload value must not
      // accidentally select this metadata byte (as the old CRC test did).
      modified: DateTime(2026, 10, 15, 12, 7, 52),
    )!;
  }

  Future<void> wait(bool Function() done, Map<String, String> statuses) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('Timeout: $statuses');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('portable payload selects identically on all six desktop ABIs', () {
    final m = LocalModuleStore.validateManifest(manifest);
    for (final platform in ModulePlatform.supported) {
      expect(
        ModulePlatform.select(m, target: platform)['executable'],
        'main.py',
      );
    }
    expect(
      () => ModulePlatform.select(m, target: 'android-arm64'),
      throwsFormatException,
    );
    expect(ModuleProtocol.maxFrameBytes, 1048576);
    expect(LocalModuleStore.maxBytes, 2147483648);
    for (final port in [0, 1, 65535]) {
      LocalModuleStore.validateManifest({
        ...m,
        'transport': {'type': 'tcp', 'host': '127.0.0.1', 'port': port},
      });
    }
    for (final port in [65536, -1, '80']) {
      expect(
        () => LocalModuleStore.validateManifest({
          ...m,
          'transport': {'type': 'tcp', 'host': 'localhost', 'port': port},
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'file-backed native ABI inspection agrees with in-memory inspection',
    () async {
      final file = File('${temporary.path}/binary');
      for (final target in ModulePlatform.supported) {
        final bytes = List<int>.filled(512, 0);
        final arm = target.endsWith('arm64');
        void put(int offset, int value, [int size = 4, bool big = false]) {
          for (var i = 0; i < size; i++) {
            bytes[offset + i] = (value >> ((big ? size - i - 1 : i) * 8)) & 255;
          }
        }

        if (target.startsWith('linux')) {
          bytes.setRange(0, 6, [127, 69, 76, 70, 2, 1]);
          put(16, 2, 2);
          put(18, arm ? 183 : 62, 2);
        } else if (target.startsWith('windows')) {
          bytes.setRange(0, 2, [77, 90]);
          put(60, 128);
          put(128, 0x4550);
          put(132, arm ? 0xaa64 : 0x8664, 2);
          put(152, 0x20b, 2);
        } else {
          put(0, 0xcafebabf, 4, true);
          put(4, 1, 4, true);
          put(8, arm ? 0x0100000c : 0x01000007, 4, true);
          put(20, 256, 4, true);
          put(28, 256, 4, true);
          put(256, 0xfeedfacf);
          put(260, arm ? 0x0100000c : 0x01000007);
          put(268, 2);
        }
        await file.writeAsBytes(bytes);
        for (final candidate in ModulePlatform.supported) {
          expect(ModulePlatform.matches(bytes, candidate), candidate == target);
          expect(
            await ModulePlatform.matchesFile(file, candidate),
            candidate == target,
          );
        }
      }
    },
  );

  test(
    'SDK packs a single portable payload and file install checks integrity',
    () async {
      final project = Directory('${temporary.path}/project');
      await Directory('${project.path}/payload').create(recursive: true);
      await File('${project.path}/manifest.json')
          .writeAsString(jsonEncode(manifest));
      await File('${project.path}/payload/main.py').writeAsString(script);
      final result = await Process.run(python, [
        'assets/module_sdk/qmod.py',
        'pack',
        project.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final file = File('${project.path}/dist/portable-echo-0.1.0.qmod');
      final installed = await store.installFile(file);
      expect(
        (await store.install(await file.readAsBytes())).localPackage,
        installed.localPackage,
      );
      final command = await store.command(installed);
      expect(command.executable, python);
      expect(command.arguments, [p.join(command.directory, 'main.py')]);
      expect(command.transport, isA<StdioModuleTransport>());
      await File('${command.directory}/main.py').writeAsString('tampered');
      await expectLater(
        store.command(installed),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'file-backed install preserves payload chunks and rejects corrupt CRC',
    () async {
      final asset = List.generate(160000, (i) => i % 251);
      final bytes = Uint8List.fromList(
        package(
          manifest,
          // Place the asset's local header after byte 1000 to exercise the
          // timestamp/payload ambiguity in the old indexOf(250, 1000) mutation.
          source: '${'# padding\n' * 150}$script',
          asset: asset,
        ),
      );
      final file = File('${temporary.path}/test.qmod');
      await file.writeAsBytes(bytes);
      final installed = await store.installFile(file);
      final command = await store.command(installed);
      expect(
        await File('${command.directory}/assets/data.bin').readAsBytes(),
        asset,
      );
      final directory = ZipDirectory.read(InputStream(bytes));
      final header = directory.fileHeaders.singleWhere(
        (entry) => entry.filename == 'assets/data.bin',
      );
      final local = header.localHeaderOffset!;
      final view = ByteData.sublistView(bytes);
      expect(view.getUint32(local, Endian.little), 0x04034b50);
      final dataStart =
          local +
          30 +
          view.getUint16(local + 26, Endian.little) +
          view.getUint16(local + 28, Endian.little);
      expect(header.compressionMethod, 0);
      expect(header.uncompressedSize, asset.length);
      expect(bytes.sublist(dataStart, dataStart + asset.length), asset);
      // The previous mutation could hit the timestamp, not the payload. Such a
      // change must be accepted: CRC covers entry content, not ZIP metadata.
      final oldIndex = bytes.indexOf(250, 1000);
      expect(oldIndex, inInclusiveRange(local, dataStart - 1));
      final metadataOnly = Uint8List.fromList(bytes)..[oldIndex] ^= 1;
      expect(
        ZipDecoder()
            .decodeBytes(metadataOnly)
            .findFile('assets/data.bin')!
            .content,
        asset,
      );
      await file.writeAsBytes(metadataOnly);
      await store.installFile(file);

      // Exercise both sides of the installer's 64 KiB read boundaries and the
      // tail. Corrupt a known payload offset, preserving both ZIP CRC fields.
      for (final offset in [0, 65535, 65536, asset.length - 1]) {
        final corrupt = Uint8List.fromList(bytes);
        corrupt[dataStart + offset] ^= 1;
        final corrupted = ZipDecoder()
            .decodeBytes(corrupt)
            .findFile('assets/data.bin')!;
        expect(corrupted.crc32, header.crc32);
        expect(getCrc32(corrupted.content as List<int>), isNot(header.crc32));
        expect(corrupt.sublist(0, dataStart), bytes.sublist(0, dataStart));
        expect(
          corrupt.sublist(dataStart + asset.length),
          bytes.sublist(dataStart + asset.length),
        );
        await file.writeAsBytes(corrupt);
        await expectLater(store.installFile(file), throwsFormatException);
      }
      expect(
        await (await store.directory)
            .list()
            .where((f) => f.path.contains('.install-'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'portable launcher supports Java-style flags before entrypoint',
    () async {
      final m = {
        ...manifest,
        'launch': {
          'launcher': 'java',
          'executable': 'main.py',
          'arguments': ['-jar', '{entrypoint}', 'arg'],
        },
      };
      final installed = await store.install(package(m));
      final command = await store.command(installed);
      expect(command.arguments, [
        '-jar',
        p.join(command.directory, 'main.py'),
        'arg',
      ]);
    },
  );

  test(
    'stdio -> TCP -> stdio routes JSON larger than 64 KiB and stops children',
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final tcpManifest = {
        ...manifest,
        'id': 'portable-tcp',
        'transport': {'type': 'tcp', 'host': '127.0.0.1', 'port': port},
        'launch': {
          ...manifest['launch'] as Map,
          'arguments': ['--tcp', '127.0.0.1', '$port'],
        },
      };
      final stdio = await store.install(package(manifest));
      final tcp = await store.install(package(tcpManifest));
      final statuses = <String, String>{};
      final values = <String, dynamic>{};
      final children = <Process>[];
      final runtime = ModuleRuntime(
        store: store,
        onUpdate: (id, status, state) {
          statuses[id] = status;
          if (state.containsKey('result')) values[id] = state['result'];
        },
        launchPackaged: (command) async {
          final child = await launchTracked(command);
          children.add(child);
          return child;
        },
      );
      addTearDown(runtime.dispose);
      runtime.sync(
        'network',
        [
          WorkspaceNode(
            id: 'source',
            module: LogicBlocks.module(LogicBlockType.select),
            kind: WorkspaceNodeKind.logic,
            logicType: LogicBlockType.select,
          ),
          WorkspaceNode(id: 'a', module: stdio),
          WorkspaceNode(id: 'b', module: tcp),
          WorkspaceNode(id: 'c', module: stdio),
        ],
        [
          const WorkspaceLink(
            source: 'source',
            output: 'output',
            target: 'a',
            input: 'input',
          ),
          const WorkspaceLink(
            source: 'a',
            output: 'output',
            target: 'b',
            input: 'input',
          ),
          const WorkspaceLink(
            source: 'b',
            output: 'output',
            target: 'c',
            input: 'input',
          ),
        ],
        [stdio, tcp],
      );
      await wait(
        () => ['a', 'b', 'c'].every((id) => statuses[id] == 'running'),
        statuses,
      );
      final payload = List.filled(50000, 'я').join();
      runtime.routeOutput('source', 'output', payload, 32);
      await wait(() => values['c'] == payload, statuses);
      expect(values['b'], payload);
      runtime.sync('other', [], [], [stdio, tcp]);
      await Future.wait(children.map((p) => p.exitCode))
          .timeout(const Duration(seconds: 3));
    },
  );

  test(
    'two TCP instances choose independent ports and isolate state',
    () async {
      final m = {
        ...manifest,
        'transport': {'type': 'tcp', 'host': '127.0.0.1', 'port': 0},
        'launch': {
          ...manifest['launch'] as Map,
          'arguments': ['--tcp', '{host}', '{port}'],
        },
      };
      final installed = await store.install(package(m));
      final statuses = <String, String>{};
      final ports = <int>[];
      final values = <String, dynamic>{};
      final children = <Process>[];
      final runtime = ModuleRuntime(
        store: store,
        onUpdate: (id, status, state) {
          statuses[id] = status;
          if (state.containsKey('result')) values[id] = state['result'];
        },
        launchPackaged: (command) async {
          ports.add((command.transport as TcpModuleTransport).port);
          expect(command.environment['QUALIA_MODULE_PORT'], '${ports.last}');
          final process = await launchTracked(command);
          children.add(process);
          return process;
        },
      );
      addTearDown(runtime.dispose);
      runtime.sync(
        'two',
        [
          WorkspaceNode(
            id: 'source',
            module: LogicBlocks.module(LogicBlockType.select),
            kind: WorkspaceNodeKind.logic,
            logicType: LogicBlockType.select,
          ),
          WorkspaceNode(id: 'a', module: installed),
          WorkspaceNode(id: 'b', module: installed),
        ],
        [
          const WorkspaceLink(
            source: 'source',
            output: 'output',
            target: 'a',
            input: 'input',
          ),
        ],
        [installed],
      );
      await wait(
        () => statuses['a'] == 'running' && statuses['b'] == 'running',
        statuses,
      );
      expect(ports.toSet(), hasLength(2));
      runtime.routeOutput('source', 'output', 42, 32);
      await wait(() => values['a'] == 42, statuses);
      expect(values['b'], isNull);
      runtime.dispose();
      await Future.wait(children.map((p) => p.exitCode))
          .timeout(const Duration(seconds: 3));
    },
  );

  test('TCP connection close fails only its instance', () async {
    final source = '''import socket, os
with socket.create_server((os.environ['QUALIA_MODULE_HOST'], int(os.environ['QUALIA_MODULE_PORT']))) as server:
    connection, _ = server.accept()
    with connection:
        connection.sendall(b'{"type":"ready","protocol":1}\\n')
        connection.recv(4096)
    import time
    time.sleep(10)
''';
    final installed = await store.install(
      package({
        ...manifest,
        'transport': {'type': 'tcp', 'host': '127.0.0.1', 'port': 0},
      }, source: source),
    );
    final sibling = await store.install(
      package({...manifest, 'id': 'sibling'}),
    );
    final statuses = <String, String>{};
    final runtime = ModuleRuntime(
      store: store,
      launchPackaged: launchTracked,
      onUpdate: (id, status, _) => statuses[id] = status,
    );
    addTearDown(runtime.dispose);
    runtime.sync(
      'closed',
      [
        WorkspaceNode(id: 'tcp', module: installed),
        WorkspaceNode(id: 'stdio', module: sibling),
      ],
      [],
      [installed, sibling],
    );
    await wait(
      () =>
          statuses['tcp'] == 'error: TCP connection closed' &&
          statuses['stdio'] == 'running',
      statuses,
    );
  });

  test(
    'large file-backed SDK package and oversized archive rejection',
    () async {
      final project = Directory('${temporary.path}/large');
      await Directory('${project.path}/payload/assets').create(recursive: true);
      await File('${project.path}/manifest.json')
          .writeAsString(jsonEncode(manifest));
      await File('${project.path}/payload/main.py').writeAsString(script);
      final size = Platform.environment['QUALIA_LARGE_MODULE_TEST'] == 'full'
          ? LocalModuleStore.maxBytes - 128 * 1024
          : 257 * 1024 * 1024;
      final asset = File('${project.path}/payload/assets/large.bin');
      final handle = await asset.open(mode: FileMode.write);
      await handle.truncate(size);
      await handle.close();
      final packed = await Process.run(python, [
        'assets/module_sdk/qmod.py',
        'pack',
        project.path,
      ]);
      expect(packed.exitCode, 0, reason: '${packed.stderr}');
      final file = File('${project.path}/dist/portable-echo-0.1.0.qmod');
      expect(await file.length(), greaterThan(256 * 1024 * 1024));
      expect(await file.length(), lessThanOrEqualTo(LocalModuleStore.maxBytes));
      final installed = await store.installFile(file);
      final command = await store.command(installed);
      expect(
        await File('${command.directory}/assets/large.bin').length(),
        size,
      );
      final oversized = await file.open(mode: FileMode.append);
      await oversized.truncate(LocalModuleStore.maxBytes + 1);
      await oversized.close();
      await expectLater(store.installFile(file), throwsFormatException);
    },
    skip: !Platform.environment.containsKey('QUALIA_LARGE_MODULE_TEST'),
    timeout: const Timeout(Duration(minutes: 5)),
  );

  for (final length in [
    ModuleProtocol.maxFrameBytes,
    ModuleProtocol.maxFrameBytes + 1,
  ]) {
    test('host outbound UTF-8 byte boundary: $length', () async {
      final installed = await store.install(
        package(
          manifest,
          source: '''import sys, json
print('{"type":"ready","protocol":1}', flush=True)
for line in sys.stdin.buffer:
    message = json.loads(line)
    if message['type'] == 'input':
        print(json.dumps({'type':'state', 'values':{'result': len(message['value'].encode('utf-8'))}}), flush=True)
''',
        ),
      );
      final statuses = <String, String>{};
      dynamic result;
      final runtime = ModuleRuntime(
        store: store,
        launchPackaged: launchTracked,
        onUpdate: (id, status, values) {
          statuses[id] = status;
          result = values['result'] ?? result;
        },
      );
      addTearDown(runtime.dispose);
      runtime.sync(
        'outbound',
        [
          WorkspaceNode(
            id: 'source',
            module: LogicBlocks.module(LogicBlockType.select),
            kind: WorkspaceNodeKind.logic,
            logicType: LogicBlockType.select,
          ),
          WorkspaceNode(id: 'test', module: installed),
        ],
        [
          const WorkspaceLink(
            source: 'source',
            output: 'output',
            target: 'test',
            input: 'input',
          ),
        ],
        [installed],
      );
      await wait(() => statuses['test'] == 'running', statuses);
      final overhead = utf8
          .encode(
            jsonEncode({
              'type': 'input',
              'port': 'input',
              'value': '',
              'hops': 31,
            }),
          )
          .length;
      final padding = length - overhead;
      final payload =
          '${List.filled(padding ~/ 2, 'я').join()}${padding.isOdd ? 'x' : ''}';
      runtime.routeOutput('source', 'output', payload, 32);
      if (length == ModuleProtocol.maxFrameBytes) {
        await wait(() => result != null, statuses);
        expect(result, padding);
      } else {
        await wait(
          () => statuses['test'] == 'error: outgoing frame too large',
          statuses,
        );
      }
    });

    test('host inbound limit is UTF-8 JSON bytes: $length', () async {
      const prefix = '{"type":"state","values":{"result":"';
      const suffix = '"}}';
      final padding = length - prefix.length - suffix.length;
      final source =
          '''import sys, json
print('{"type":"ready","protocol":1}', flush=True)
sys.stdin.buffer.readline()
sys.stdout.buffer.write(b'$prefix' + b'x' * $padding + b'$suffix\\n')
sys.stdout.buffer.flush()
sys.stdin.buffer.read()
''';
      final installed = await store.install(package(manifest, source: source));
      final statuses = <String, String>{};
      dynamic result;
      final runtime = ModuleRuntime(
        store: store,
        launchPackaged: launchTracked,
        onUpdate: (id, status, state) {
          statuses[id] = status;
          result = state['result'] ?? result;
        },
      );
      addTearDown(runtime.dispose);
      runtime.sync(
        'limit',
        [WorkspaceNode(id: 'test', module: installed)],
        [],
        [installed],
      );
      if (length == ModuleProtocol.maxFrameBytes) {
        await wait(() => result != null, statuses);
        expect((result as String).length, padding);
        expect(statuses['test'], 'running');
      } else {
        await wait(
          () => statuses['test']?.contains('frame too large') ?? false,
          statuses,
        );
      }
    });
  }
}
