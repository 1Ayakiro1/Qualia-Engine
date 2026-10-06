import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavigationAction {
  next,
  previous,
  activate,
  contextMenu,
  menuDown,
  menuUp,
  submenuOpen,
  submenuBack,
  dismiss,
  fullscreen,
  openWorkspace,
  findModule,
  scaleUp,
  scaleDown,
  scaleReset,
}

class NavigationChord {
  const NavigationChord(
    this.key, {
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });
  final LogicalKeyboardKey key;
  final bool control, shift, alt, meta;
  SingleActivator get activator => SingleActivator(
    key,
    control: control,
    shift: shift,
    alt: alt,
    meta: meta,
  );
  String get label => [
    if (control) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    if (meta) 'Meta',
    switch (key) {
      LogicalKeyboardKey.arrowUp => 'Up',
      LogicalKeyboardKey.arrowDown => 'Down',
      LogicalKeyboardKey.arrowLeft => 'Left',
      LogicalKeyboardKey.arrowRight => 'Right',
      LogicalKeyboardKey.escape => 'Esc',
      LogicalKeyboardKey.contextMenu => 'Menu',
      LogicalKeyboardKey.space => 'Space',
      _ => key.keyLabel,
    },
  ].join('+');
  Map<String, dynamic> toJson() => {
    'key': key.keyId,
    'control': control,
    'shift': shift,
    'alt': alt,
    'meta': meta,
  };
  static NavigationChord? fromEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _modifiers.contains(event.logicalKey)) {
      return null;
    }
    final keyboard = HardwareKeyboard.instance;
    return NavigationChord(
      event.logicalKey,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
  }

  static final _modifiers = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };
}

/// One persisted registry consumed by the actual controls, not just the editor.
/// Child windows may read it, but never write shared preferences.
class NavigationBindings extends ChangeNotifier {
  NavigationBindings._();
  static final instance = NavigationBindings._();
  static const storageKey = 'qualia.navigation.bindings.v1';
  static const defaults = <NavigationAction, List<NavigationChord>>{
    NavigationAction.next: [NavigationChord(LogicalKeyboardKey.tab)],
    NavigationAction.previous: [
      NavigationChord(LogicalKeyboardKey.tab, shift: true),
    ],
    NavigationAction.activate: [
      NavigationChord(LogicalKeyboardKey.enter),
      NavigationChord(LogicalKeyboardKey.numpadEnter),
      NavigationChord(LogicalKeyboardKey.space),
    ],
    NavigationAction.contextMenu: [
      NavigationChord(LogicalKeyboardKey.f10, shift: true),
      NavigationChord(LogicalKeyboardKey.contextMenu),
    ],
    NavigationAction.menuDown: [NavigationChord(LogicalKeyboardKey.arrowDown)],
    NavigationAction.menuUp: [NavigationChord(LogicalKeyboardKey.arrowUp)],
    NavigationAction.submenuOpen: [
      NavigationChord(LogicalKeyboardKey.arrowRight),
    ],
    NavigationAction.submenuBack: [
      NavigationChord(LogicalKeyboardKey.arrowLeft),
    ],
    NavigationAction.dismiss: [NavigationChord(LogicalKeyboardKey.escape)],
    NavigationAction.fullscreen: [NavigationChord(LogicalKeyboardKey.f11)],
    NavigationAction.openWorkspace: [
      NavigationChord(LogicalKeyboardKey.keyO, control: true),
    ],
    NavigationAction.findModule: [
      NavigationChord(LogicalKeyboardKey.keyM, control: true, shift: true),
    ],
    NavigationAction.scaleUp: [
      NavigationChord(LogicalKeyboardKey.equal, control: true),
      NavigationChord(LogicalKeyboardKey.equal, control: true, shift: true),
      NavigationChord(LogicalKeyboardKey.add, control: true),
    ],
    NavigationAction.scaleDown: [
      NavigationChord(LogicalKeyboardKey.minus, control: true),
    ],
    NavigationAction.scaleReset: [
      NavigationChord(LogicalKeyboardKey.digit0, control: true),
    ],
  };
  final Map<NavigationAction, List<NavigationChord>> _overrides = {};
  bool keyboardMode = false;
  bool _attached = false;
  int _revision = 0;
  List<NavigationChord> chords(NavigationAction action) =>
      _overrides[action] ?? defaults[action]!;
  String label(NavigationAction action) =>
      chords(action).map((key) => key.label).join(' / ');
  bool matches(NavigationAction action, KeyEvent event) => chords(action)
      .any((key) => key.activator.accepts(event, HardwareKeyboard.instance));
  bool isAssigned(NavigationChord chord) => NavigationAction.values.any(
    (action) => chords(action).any((key) => key.label == chord.label),
  );
  Map<ShortcutActivator, Intent> get activationShortcuts => {
    for (final chord in chords(NavigationAction.activate))
      chord.activator: const ActivateIntent(),
    for (final chord in defaults[NavigationAction.activate]!)
      if (!isAssigned(chord))
        chord.activator: const DoNothingAndStopPropagationIntent(),
  };
  void attach() {
    if (_attached) return;
    _attached = true;
    HardwareKeyboard.instance.addHandler(_keyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerEvent);
  }

  bool _keyEvent(KeyEvent event) {
    final editing =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>() !=
        null;
    if (editing &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        (event.character != null ||
            const [
              LogicalKeyboardKey.arrowLeft,
              LogicalKeyboardKey.arrowRight,
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.numpadEnter,
              LogicalKeyboardKey.space,
              LogicalKeyboardKey.backspace,
              LogicalKeyboardKey.delete,
            ].contains(event.logicalKey))) {
      return false;
    }
    if (event is KeyDownEvent &&
        NavigationAction.values.any((a) => matches(a, event))) {
      setKeyboardMode(true);
    }
    return false;
  }

  void _pointerEvent(PointerEvent event) {
    if (event is PointerDownEvent ||
        event is PointerHoverEvent ||
        event is PointerMoveEvent ||
        event is PointerSignalEvent ||
        event is PointerPanZoomStartEvent ||
        event is PointerPanZoomUpdateEvent) {
      setKeyboardMode(false);
    }
  }

  void setKeyboardMode(bool value) {
    if (keyboardMode == value) return;
    keyboardMode = value;
    notifyListeners();
  }

  Future<void> load() async {
    attach();
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    try {
      final raw = prefs.getString(storageKey);
      _overrides.clear();
      if (raw != null) {
        final data = jsonDecode(raw) as Map;
        for (final action in NavigationAction.values) {
          final value = data[action.name];
          if (value is! Map || value['key'] is! int) continue;
          final key = LogicalKeyboardKey.findKeyByKeyId(value['key'] as int);
          if (key == null) continue;
          final chord = NavigationChord(
            key,
            control: value['control'] == true,
            shift: value['shift'] == true,
            alt: value['alt'] == true,
            meta: value['meta'] == true,
          );
          _overrides[action] = [chord];
        }
        for (final action in [..._overrides.keys]) {
          if (conflict(action, _overrides[action]!.single) != null) {
            _overrides.remove(action);
          }
        }
      }
      notifyListeners();
    } catch (_) {
      _overrides.clear();
      notifyListeners();
    }
  }

  NavigationAction? conflict(NavigationAction action, NavigationChord chord) {
    for (final other in NavigationAction.values) {
      if (other != action &&
          chords(other).any((key) => key.label == chord.label)) {
        return other;
      }
    }
    return null;
  }

  Future<bool> setBinding(
    NavigationAction action,
    NavigationChord chord,
  ) async {
    if (conflict(action, chord) != null) return false;
    _overrides[action] = [chord];
    _revision++;
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> reset() async {
    _overrides.clear();
    _revision++;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    // Encode after the await so concurrent edits cannot persist an older map.
    final data = jsonEncode({
      for (final entry in _overrides.entries)
        entry.key.name: entry.value.single.toJson(),
    });
    await prefs.setString(storageKey, data);
  }

  Map<ShortcutActivator, VoidCallback> callbacks(
    Map<NavigationAction, VoidCallback> actions,
  ) => {
    for (final entry in actions.entries)
      for (final chord in chords(entry.key)) chord.activator: entry.value,
    // Prevent old defaults falling through to Flutter/menu bindings after remap.
    for (final entry in actions.entries)
      if (_overrides.containsKey(entry.key))
        for (final chord in defaults[entry.key]!)
          if (!isAssigned(chord)) chord.activator: () {},
  };
}

class NavigationScope extends StatefulWidget {
  const NavigationScope({super.key, required this.child});
  final Widget child;
  @override
  State<NavigationScope> createState() => _NavigationScopeState();
}

class _NavigationScopeState extends State<NavigationScope> {
  @override
  void initState() {
    super.initState();
    NavigationBindings.instance.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NavigationBindings.instance,
    builder: (context, _) => CallbackShortcuts(
      bindings: NavigationBindings.instance.callbacks({
        NavigationAction.next: () =>
            FocusManager.instance.primaryFocus?.nextFocus(),
        NavigationAction.previous: () =>
            FocusManager.instance.primaryFocus?.previousFocus(),
      }),
      child: Shortcuts(
        shortcuts: NavigationBindings.instance.activationShortcuts,
        child: widget.child,
      ),
    ),
  );
}
