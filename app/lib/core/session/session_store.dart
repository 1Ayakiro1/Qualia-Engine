import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'edf_codec.dart';

/// File-backed session storage. JSON is metadata/index only; signal payloads
/// are EDF files and never travel through SharedPreferences or UI JSON frames.
class SessionStore {
  SessionStore({this.root});
  final Directory? root;

  static void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid session ID.');
    }
  }

  Future<Directory> _directory() async {
    final directory =
        root ??
        Directory(
          p.join((await getApplicationSupportDirectory()).path, 'sessions'),
        );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> save(String id, SessionDocument document) async {
    _validateId(id);
    final directory = await _directory();
    final staging = File(p.join(directory.path, '.$id.edf.tmp'));
    final target = File(p.join(directory.path, '$id.edf'));
    final bytes = await Isolate.run(() => EdfCodec.encode(document));
    await staging.writeAsBytes(bytes, flush: true);
    await staging.rename(target.path);
    final metadata = File(p.join(directory.path, '$id.json'));
    final metadataStaging = File('${metadata.path}.tmp');
    await metadataStaging.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'id': id,
        'sampleRate': document.sampleRate,
        'channels': document.channels,
        'frames': document.frames,
        'edf': target.uri.pathSegments.last,
        'startedAt': document.startedAt?.toIso8601String(),
      }),
      flush: true,
    );
    await metadataStaging.rename(metadata.path);
    return target;
  }

  Future<SessionDocument> load(String id) async {
    _validateId(id);
    final directory = await _directory();
    final file = File(p.join(directory.path, '$id.edf'));
    if (await file.length() > EdfCodec.maxBytes) {
      throw const FormatException('EDF too large');
    }
    return importEdf(await file.readAsBytes());
  }

  Future<List<Map<String, dynamic>>> list() async {
    final directory = await _directory();
    final result = <Map<String, dynamic>>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final value = jsonDecode(await entity.readAsString());
        if (value is Map<String, dynamic> &&
            value['schemaVersion'] == 1 &&
            value['id'] is String &&
            value['channels'] is num &&
            value['sampleRate'] is num &&
            value['frames'] is num) {
          _validateId(value['id'] as String);
          if (await File(p.join(directory.path, '${value['id']}.edf'))
              .exists()) {
            result.add(value);
          }
        }
      } catch (_) {
        // A damaged index entry cannot make the session directory unreadable.
      }
    }
    result.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return result;
  }

  Future<Uint8List> exportEdf(SessionDocument document) =>
      Isolate.run(() => EdfCodec.encode(document));

  Future<SessionDocument> importEdf(Uint8List bytes) =>
      Isolate.run(() => EdfCodec.decode(bytes));
}
