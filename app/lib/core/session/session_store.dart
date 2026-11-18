import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'edf_codec.dart';

/// File-backed session storage. JSON is metadata/index only; signal payloads
/// are EDF files and never travel through SharedPreferences or UI JSON frames.
class SessionStore {
  SessionStore({this.root});
  final Directory? root;

  Future<Directory> _directory() async {
    final directory = root ??
        Directory(p.join((await getApplicationSupportDirectory()).path, 'sessions'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> save(String id, SessionDocument document) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid session ID.');
    }
    final directory = await _directory();
    final staging = File(p.join(directory.path, '.$id.edf.tmp'));
    final target = File(p.join(directory.path, '$id.edf'));
    await staging.writeAsBytes(EdfCodec.encode(document), flush: true);
    await staging.rename(target.path);
    final metadata = File(p.join(directory.path, '$id.json'));
    await metadata.writeAsString(jsonEncode({
      'schemaVersion': 1,
      'id': id,
      'sampleRate': document.sampleRate,
      'channels': document.channels,
      'frames': document.frames,
      'edf': target.uri.pathSegments.last,
    }), flush: true);
    return target;
  }

  Future<SessionDocument> load(String id) async {
    final directory = await _directory();
    return EdfCodec.decode(await File(p.join(directory.path, '$id.edf')).readAsBytes());
  }

  Future<List<Map<String, dynamic>>> list() async {
    final directory = await _directory();
    final result = <Map<String, dynamic>>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final value = jsonDecode(await entity.readAsString());
        if (value is Map<String, dynamic>) result.add(value);
      } catch (_) {
        // A damaged index entry cannot make the session directory unreadable.
      }
    }
    return result;
  }

  Future<Uint8List> exportEdf(SessionDocument document) async =>
      EdfCodec.encode(document);
}
