import 'package:flutter/foundation.dart';

/// Small imperative adapter for pointer handlers. The source of truth is the
/// Riverpod selection provider; this adapter makes drag/marquee code testable
/// without knowing about widgets or the workspace document.
class CanvasSelectionController extends ChangeNotifier {
  final Set<String> _ids = {};
  String? primaryId;
  Set<String> get ids => Set.unmodifiable(_ids);

  void replace(Iterable<String> ids, {String? primary}) {
    _ids
      ..clear()
      ..addAll(ids);
    primaryId = primary;
    notifyListeners();
  }

  void add(String id) {
    if (_ids.add(id)) {
      primaryId = id;
      notifyListeners();
    }
  }

  void remove(String id) {
    if (_ids.remove(id)) {
      if (primaryId == id) primaryId = _ids.lastOrNull;
      notifyListeners();
    }
  }

  void clear() {
    if (_ids.isEmpty && primaryId == null) return;
    _ids.clear();
    primaryId = null;
    notifyListeners();
  }
}
