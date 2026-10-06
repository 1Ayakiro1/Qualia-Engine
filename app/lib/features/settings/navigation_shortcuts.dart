import '../../l10n/generated/app_localizations.dart';
import '../common/navigation_bindings.dart';

class NavigationShortcut {
  const NavigationShortcut(this.id, this.action, this.label);
  final String id;
  final NavigationAction action;
  final String Function(AppLocalizations) label;
  String keys(AppLocalizations l) => NavigationBindings.instance.label(action);
}

final navigationShortcutGroups = <String, List<NavigationShortcut>>{
  'workspace': [
    NavigationShortcut(
      'openWorkspace',
      NavigationAction.openWorkspace,
      (l) => l.textOpenProject126,
    ),
    NavigationShortcut(
      'findModule',
      NavigationAction.findModule,
      (l) => l.textFindModule147,
    ),
  ],
  'interface': [
    NavigationShortcut('next', NavigationAction.next, (l) => l.navigationNext),
    NavigationShortcut(
      'previous',
      NavigationAction.previous,
      (l) => l.navigationPrevious,
    ),
    NavigationShortcut(
      'activate',
      NavigationAction.activate,
      (l) => l.navigationActivate,
    ),
    NavigationShortcut(
      'context',
      NavigationAction.contextMenu,
      (l) => l.navigationContext,
    ),
    NavigationShortcut(
      'scaleUp',
      NavigationAction.scaleUp,
      (l) => l.textIncreaseInterfaceScale149,
    ),
    NavigationShortcut(
      'scaleDown',
      NavigationAction.scaleDown,
      (l) => l.textDecreaseInterfaceScale150,
    ),
    NavigationShortcut(
      'scaleReset',
      NavigationAction.scaleReset,
      (l) => l.textResetInterfaceScale355,
    ),
  ],
  'menus': [
    NavigationShortcut(
      'menuDown',
      NavigationAction.menuDown,
      (l) => l.navigationMenuDown,
    ),
    NavigationShortcut(
      'menuUp',
      NavigationAction.menuUp,
      (l) => l.navigationMenuUp,
    ),
    NavigationShortcut(
      'submenuOpen',
      NavigationAction.submenuOpen,
      (l) => l.navigationSubmenuOpen,
    ),
    NavigationShortcut(
      'submenuBack',
      NavigationAction.submenuBack,
      (l) => l.navigationSubmenuBack,
    ),
    NavigationShortcut(
      'dismiss',
      NavigationAction.dismiss,
      (l) => l.navigationDismiss,
    ),
  ],
  'modules': [
    NavigationShortcut(
      'fullscreen',
      NavigationAction.fullscreen,
      (l) => l.navigationFullscreen,
    ),
  ],
};
