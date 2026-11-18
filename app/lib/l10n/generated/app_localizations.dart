import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @workspaceCanvasHints.
  ///
  /// In en, this message translates to:
  /// **'Canvas hints'**
  String get workspaceCanvasHints;

  /// No description provided for @sceneCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get sceneCreateGroup;

  /// No description provided for @sceneEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get sceneEditGroup;

  /// No description provided for @sceneGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get sceneGroupName;

  /// No description provided for @sceneMoveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get sceneMoveToGroup;

  /// No description provided for @sceneRemoveFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get sceneRemoveFromGroup;

  /// No description provided for @sceneDissolveGroup.
  ///
  /// In en, this message translates to:
  /// **'Dissolve group'**
  String get sceneDissolveGroup;

  /// No description provided for @workspaceObjectVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible on canvas'**
  String get workspaceObjectVisible;

  /// No description provided for @workspaceObjectGeometry.
  ///
  /// In en, this message translates to:
  /// **'Position and size'**
  String get workspaceObjectGeometry;

  /// No description provided for @canvasEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get canvasEraser;

  /// No description provided for @canvasBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get canvasBrush;

  /// No description provided for @canvasBrushColor.
  ///
  /// In en, this message translates to:
  /// **'Brush color'**
  String get canvasBrushColor;

  /// No description provided for @canvasColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get canvasColorWhite;

  /// No description provided for @canvasColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get canvasColorBlack;

  /// No description provided for @canvasDiameter.
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get canvasDiameter;

  /// No description provided for @workspaceSave.
  ///
  /// In en, this message translates to:
  /// **'Save workspace'**
  String get workspaceSave;

  /// No description provided for @workspaceSaved.
  ///
  /// In en, this message translates to:
  /// **'Workspace saved'**
  String get workspaceSaved;

  /// No description provided for @sceneSelection.
  ///
  /// In en, this message translates to:
  /// **'SCENE OBJECTS'**
  String get sceneSelection;

  /// No description provided for @sceneCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse scene selection'**
  String get sceneCollapse;

  /// No description provided for @sceneExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand scene selection'**
  String get sceneExpand;

  /// No description provided for @sceneNoObjects.
  ///
  /// In en, this message translates to:
  /// **'No objects found'**
  String get sceneNoObjects;

  /// No description provided for @sceneSelectObject.
  ///
  /// In en, this message translates to:
  /// **'Select an object'**
  String get sceneSelectObject;

  /// No description provided for @workspaceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the workspace. Your draft is still available.'**
  String get workspaceSaveFailed;

  /// No description provided for @canvasFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen canvas'**
  String get canvasFullscreen;

  /// No description provided for @canvasExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit canvas fullscreen'**
  String get canvasExitFullscreen;

  /// No description provided for @canvasScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Save canvas screenshot'**
  String get canvasScreenshot;

  /// No description provided for @canvasScreenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Canvas screenshot saved'**
  String get canvasScreenshotSaved;

  /// No description provided for @canvasScreenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the canvas screenshot.'**
  String get canvasScreenshotFailed;

  /// No description provided for @workspaceUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Save workspace changes?'**
  String get workspaceUnsavedTitle;

  /// No description provided for @workspaceUnsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your workspace has unsaved changes. Save them before closing, or discard changes since the last save.'**
  String get workspaceUnsavedMessage;

  /// No description provided for @workspaceDiscard.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get workspaceDiscard;

  /// No description provided for @workspaceUndoNotice.
  ///
  /// In en, this message translates to:
  /// **'Action undone'**
  String get workspaceUndoNotice;

  /// No description provided for @workspaceRedoNotice.
  ///
  /// In en, this message translates to:
  /// **'Action redone'**
  String get workspaceRedoNotice;

  /// No description provided for @railBottomZone.
  ///
  /// In en, this message translates to:
  /// **'Bottom of rail'**
  String get railBottomZone;

  /// No description provided for @railUnusedItems.
  ///
  /// In en, this message translates to:
  /// **'Unused items'**
  String get railUnusedItems;

  /// No description provided for @railUsedItems.
  ///
  /// In en, this message translates to:
  /// **'On the rail'**
  String get railUsedItems;

  /// No description provided for @railPinBottom.
  ///
  /// In en, this message translates to:
  /// **'Move to bottom'**
  String get railPinBottom;

  /// No description provided for @railPinTop.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get railPinTop;

  /// No description provided for @railDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag buttons into the rail to add or reorder them. Drag back here to remove. Click to toggle; Alt + ↑ / ↓ moves a focused button.'**
  String get railDragHint;

  /// No description provided for @logicBlocks.
  ///
  /// In en, this message translates to:
  /// **'Logic blocks'**
  String get logicBlocks;

  /// No description provided for @logicAdd.
  ///
  /// In en, this message translates to:
  /// **'Add logic block'**
  String get logicAdd;

  /// No description provided for @logicFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get logicFilter;

  /// No description provided for @logicSelectFields.
  ///
  /// In en, this message translates to:
  /// **'Select fields'**
  String get logicSelectFields;

  /// No description provided for @logicValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate input / output'**
  String get logicValidate;

  /// No description provided for @logicScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get logicScript;

  /// No description provided for @logicScriptHelp.
  ///
  /// In en, this message translates to:
  /// **'No files, network or loops. Use value.field, has(value, \"field\"), comparisons, and / or / not. Scripts support nested IF / ELSE and emit. select(value, \"field\") keeps only selected fields. Schema uses type, properties, required and additionalProperties.'**
  String get logicScriptHelp;

  /// No description provided for @logicTestInput.
  ///
  /// In en, this message translates to:
  /// **'Test input (JSON)'**
  String get logicTestInput;

  /// No description provided for @logicTest.
  ///
  /// In en, this message translates to:
  /// **'Test without sending to graph'**
  String get logicTest;

  /// No description provided for @logicShow.
  ///
  /// In en, this message translates to:
  /// **'Show logic blocks'**
  String get logicShow;

  /// No description provided for @logicHide.
  ///
  /// In en, this message translates to:
  /// **'Hide logic blocks'**
  String get logicHide;

  /// No description provided for @moduleBlocksShow.
  ///
  /// In en, this message translates to:
  /// **'Show module blocks'**
  String get moduleBlocksShow;

  /// No description provided for @moduleBlocksHide.
  ///
  /// In en, this message translates to:
  /// **'Hide module blocks'**
  String get moduleBlocksHide;

  /// No description provided for @moduleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete module'**
  String get moduleDelete;

  /// No description provided for @moduleActivate.
  ///
  /// In en, this message translates to:
  /// **'Make active'**
  String get moduleActivate;

  /// No description provided for @moduleDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Make inactive'**
  String get moduleDeactivate;

  /// No description provided for @moduleMoveToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Move to workspace'**
  String get moduleMoveToWorkspace;

  /// No description provided for @moduleMoveConnectionsWarning.
  ///
  /// In en, this message translates to:
  /// **'Connections to modules left in the source workspace will be removed. Parameters and connections within the moved group will be preserved. Continue?'**
  String get moduleMoveConnectionsWarning;

  /// No description provided for @moduleEditorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Module editing panel placeholder. Editing tools will be added later.'**
  String get moduleEditorPlaceholder;

  /// No description provided for @moduleCreateLocal.
  ///
  /// In en, this message translates to:
  /// **'Create locally'**
  String get moduleCreateLocal;

  /// No description provided for @moduleCreateOnline.
  ///
  /// In en, this message translates to:
  /// **'Create online'**
  String get moduleCreateOnline;

  /// No description provided for @moduleAddLocal.
  ///
  /// In en, this message translates to:
  /// **'Add locally (.qmod)'**
  String get moduleAddLocal;

  /// No description provided for @moduleAddOnline.
  ///
  /// In en, this message translates to:
  /// **'Add online'**
  String get moduleAddOnline;

  /// No description provided for @localModuleProject.
  ///
  /// In en, this message translates to:
  /// **'Local C++ module project'**
  String get localModuleProject;

  /// No description provided for @localModuleEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit the C++ source in your project directory, build a new .qmod version and add it locally. See docs/LOCAL_MODULES.md.'**
  String get localModuleEditHint;

  /// No description provided for @localModuleTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust this native module?'**
  String get localModuleTrustTitle;

  /// No description provided for @localModuleTrustWarning.
  ///
  /// In en, this message translates to:
  /// **'This package contains native C++ code. Each node runs in a separate process, but this is NOT a security sandbox: it has your user\'s access to files, network and devices. Install only code you trust. Adding a node starts its executable.'**
  String get localModuleTrustWarning;

  /// No description provided for @localModuleError.
  ///
  /// In en, this message translates to:
  /// **'Local module operation failed'**
  String get localModuleError;

  /// No description provided for @workspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspacesTitle;

  /// No description provided for @workspaceManager.
  ///
  /// In en, this message translates to:
  /// **'Workspace manager'**
  String get workspaceManager;

  /// No description provided for @workspaceCreate.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get workspaceCreate;

  /// No description provided for @workspaceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get workspaceEdit;

  /// No description provided for @workspaceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace'**
  String get workspaceDelete;

  /// No description provided for @workspaceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” and its graph? This does not remove modules from the library.'**
  String workspaceDeleteConfirm(String name);

  /// No description provided for @workspaceImport.
  ///
  /// In en, this message translates to:
  /// **'Import workspace'**
  String get workspaceImport;

  /// No description provided for @workspaceExport.
  ///
  /// In en, this message translates to:
  /// **'Export / share'**
  String get workspaceExport;

  /// No description provided for @workspaceSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit to Marketplace'**
  String get workspaceSubmit;

  /// No description provided for @workspaceSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Workspace submitted for review. It will appear in Marketplace after approval.'**
  String get workspaceSubmitted;

  /// No description provided for @workspaceReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub to submit. Publication requires review; submitting does not immediately publish the workspace.'**
  String get workspaceReviewNotice;

  /// No description provided for @workspaceShareWarning.
  ///
  /// In en, this message translates to:
  /// **'The graph includes module parameters and labels. Remove private values, tokens and local paths before sharing. Only share content you have permission to distribute.'**
  String get workspaceShareWarning;

  /// No description provided for @workspaceContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get workspaceContinue;

  /// No description provided for @workspaceProjectName.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get workspaceProjectName;

  /// No description provided for @workspaceProjectDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get workspaceProjectDescription;

  /// No description provided for @workspaceProjectActions.
  ///
  /// In en, this message translates to:
  /// **'Workspace actions'**
  String get workspaceProjectActions;

  /// No description provided for @workspaceGraphSummary.
  ///
  /// In en, this message translates to:
  /// **'{nodes} modules · {links} connections'**
  String workspaceGraphSummary(int nodes, int links);

  /// No description provided for @workspaceDependenciesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Required module versions are unavailable'**
  String get workspaceDependenciesUnavailable;

  /// No description provided for @workspaceOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Workspace operation failed'**
  String get workspaceOperationFailed;

  /// No description provided for @workspaceInstall.
  ///
  /// In en, this message translates to:
  /// **'Install workspace'**
  String get workspaceInstall;

  /// No description provided for @workspaceInstallNotice.
  ///
  /// In en, this message translates to:
  /// **'Creates a separate project and resolves available module versions automatically. External package execution requires a signed runtime; nothing is executed during import.'**
  String get workspaceInstallNotice;

  /// No description provided for @workspaceCatalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Workspace catalog is unavailable. Check your connection and try again. The backend also needs the workspace catalog migration.'**
  String get workspaceCatalogUnavailable;

  /// No description provided for @navigationMenuDown.
  ///
  /// In en, this message translates to:
  /// **'Next menu action'**
  String get navigationMenuDown;

  /// No description provided for @navigationMenuUp.
  ///
  /// In en, this message translates to:
  /// **'Previous menu action'**
  String get navigationMenuUp;

  /// No description provided for @navigationEditableHint.
  ///
  /// In en, this message translates to:
  /// **'Click a combination to change it, then Save or Ctrl+Enter to confirm. Changes are saved and apply to controls and menus. Esc cancels capture; Reset restores defaults.'**
  String get navigationEditableHint;

  /// No description provided for @navigationReset.
  ///
  /// In en, this message translates to:
  /// **'Reset shortcuts'**
  String get navigationReset;

  /// No description provided for @navigationConflict.
  ///
  /// In en, this message translates to:
  /// **'This combination is already used by another navigation action.'**
  String get navigationConflict;

  /// No description provided for @navigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigationTitle;

  /// No description provided for @navigationDescription.
  ///
  /// In en, this message translates to:
  /// **'Navigate without a mouse. Focus borders appear only during keyboard navigation and disappear when you use the mouse. Text fields keep their usual editing shortcuts.'**
  String get navigationDescription;

  /// No description provided for @navigationFixedBindings.
  ///
  /// In en, this message translates to:
  /// **'Navigation bindings are built into the controls and cannot be reassigned here. Fullscreen shortcuts apply inside an active module view.'**
  String get navigationFixedBindings;

  /// No description provided for @navigationMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get navigationMenus;

  /// No description provided for @navigationModules.
  ///
  /// In en, this message translates to:
  /// **'Modules and ports'**
  String get navigationModules;

  /// No description provided for @navigationKeyUpDown.
  ///
  /// In en, this message translates to:
  /// **'Up / Down'**
  String get navigationKeyUpDown;

  /// No description provided for @navigationKeyRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get navigationKeyRight;

  /// No description provided for @navigationKeyLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get navigationKeyLeft;

  /// No description provided for @navigationNext.
  ///
  /// In en, this message translates to:
  /// **'Focus the next control'**
  String get navigationNext;

  /// No description provided for @navigationPrevious.
  ///
  /// In en, this message translates to:
  /// **'Focus the previous control'**
  String get navigationPrevious;

  /// No description provided for @navigationActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate the focused control'**
  String get navigationActivate;

  /// No description provided for @navigationContext.
  ///
  /// In en, this message translates to:
  /// **'Open a node or port context menu'**
  String get navigationContext;

  /// No description provided for @navigationMenuMove.
  ///
  /// In en, this message translates to:
  /// **'Move between menu actions'**
  String get navigationMenuMove;

  /// No description provided for @navigationSubmenuOpen.
  ///
  /// In en, this message translates to:
  /// **'Open a submenu'**
  String get navigationSubmenuOpen;

  /// No description provided for @navigationSubmenuBack.
  ///
  /// In en, this message translates to:
  /// **'Return from a submenu'**
  String get navigationSubmenuBack;

  /// No description provided for @navigationDismiss.
  ///
  /// In en, this message translates to:
  /// **'Close a menu or dialog / return from fullscreen'**
  String get navigationDismiss;

  /// No description provided for @navigationConnect.
  ///
  /// In en, this message translates to:
  /// **'Focus and activate each port to connect them'**
  String get navigationConnect;

  /// No description provided for @navigationFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Toggle the active module fullscreen'**
  String get navigationFullscreen;

  /// No description provided for @navigationExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Return from module fullscreen'**
  String get navigationExitFullscreen;

  /// No description provided for @workspacePortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspacePortName;

  /// No description provided for @workspacePortRename.
  ///
  /// In en, this message translates to:
  /// **'Rename port'**
  String get workspacePortRename;

  /// No description provided for @workspacePortNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to restore the original name.'**
  String get workspacePortNameHint;

  /// No description provided for @workspacePortSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get workspacePortSave;

  /// No description provided for @workspacePortValue.
  ///
  /// In en, this message translates to:
  /// **'Value type'**
  String get workspacePortValue;

  /// No description provided for @workspacePortColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get workspacePortColor;

  /// No description provided for @workspacePortAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get workspacePortAny;

  /// No description provided for @workspacePortString.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get workspacePortString;

  /// No description provided for @workspacePortNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get workspacePortNumber;

  /// No description provided for @workspacePortBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get workspacePortBoolean;

  /// No description provided for @workspacePortList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get workspacePortList;

  /// No description provided for @workspacePortObject.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get workspacePortObject;

  /// No description provided for @moduleOpenWindow.
  ///
  /// In en, this message translates to:
  /// **'Open in separate window'**
  String get moduleOpenWindow;

  /// No description provided for @moduleFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen module'**
  String get moduleFullscreen;

  /// No description provided for @moduleExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get moduleExitFullscreen;

  /// No description provided for @moduleWindowFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the module window.'**
  String get moduleWindowFailed;

  /// No description provided for @workspaceAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get workspaceAppearance;

  /// No description provided for @workspaceInstance.
  ///
  /// In en, this message translates to:
  /// **'INSTANCE'**
  String get workspaceInstance;

  /// No description provided for @workspaceParameters.
  ///
  /// In en, this message translates to:
  /// **'PARAMETERS'**
  String get workspaceParameters;

  /// No description provided for @workspacePorts.
  ///
  /// In en, this message translates to:
  /// **'INPUTS / OUTPUTS'**
  String get workspacePorts;

  /// No description provided for @workspaceInputColor.
  ///
  /// In en, this message translates to:
  /// **'Input highlight'**
  String get workspaceInputColor;

  /// No description provided for @workspaceOutputColor.
  ///
  /// In en, this message translates to:
  /// **'Output highlight'**
  String get workspaceOutputColor;

  /// No description provided for @workspaceSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get workspaceSelect;

  /// No description provided for @workspaceSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get workspaceSelectAll;

  /// No description provided for @workspaceDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get workspaceDeselect;

  /// No description provided for @workspaceDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get workspaceDeleteSelected;

  /// No description provided for @workspaceZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get workspaceZoomIn;

  /// No description provided for @workspaceZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get workspaceZoomOut;

  /// No description provided for @workspaceActualSize.
  ///
  /// In en, this message translates to:
  /// **'Actual size (100%)'**
  String get workspaceActualSize;

  /// No description provided for @workspaceFrameSelection.
  ///
  /// In en, this message translates to:
  /// **'Frame selection'**
  String get workspaceFrameSelection;

  /// No description provided for @workspaceResizeNode.
  ///
  /// In en, this message translates to:
  /// **'Drag to resize module'**
  String get workspaceResizeNode;

  /// No description provided for @workspaceSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Shift / Alt + click — select multiple; Space + drag — pan canvas'**
  String get workspaceSelectHint;

  /// No description provided for @workspaceCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get workspaceCopy;

  /// No description provided for @workspaceCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get workspaceCut;

  /// No description provided for @workspacePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get workspacePaste;

  /// No description provided for @workspaceMoveJunction.
  ///
  /// In en, this message translates to:
  /// **'Move point'**
  String get workspaceMoveJunction;

  /// No description provided for @workspaceClipboardFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy or paste nodes. Check module availability and scene size.'**
  String get workspaceClipboardFailed;

  /// Host UI: Supabase Auth is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Supabase Auth is unavailable.'**
  String get textSupabaseAuthIsUnavailable0;

  /// Host UI: Sign in with GitHub before creating a module.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub before creating a module.'**
  String get textSignInWithGitHubBeforeCreatingA1;

  /// Host UI: Sign in with GitHub to manage your modules.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub to manage your modules.'**
  String get textSignInWithGitHubToManageYour2;

  /// Host UI: Only unpublished module drafts can be removed.
  ///
  /// In en, this message translates to:
  /// **'Only unpublished module drafts can be removed.'**
  String get textOnlyUnpublishedModuleDraftsCanBeRemoved3;

  /// Host UI: Отладка
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get textDebug4;

  /// Host UI: Инфо
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get textInfo5;

  /// Host UI: Предупреждения
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get textWarnings6;

  /// Host UI: Ошибки
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get textErrors7;

  /// Host UI: Поиск по источнику и тексту…
  ///
  /// In en, this message translates to:
  /// **'Search source and text…'**
  String get textSearchSourceAndText8;

  /// Host UI: LEVELS
  ///
  /// In en, this message translates to:
  /// **'LEVELS'**
  String get textLEVELS9;

  /// Host UI: Файл latest.log пока не создан.
  ///
  /// In en, this message translates to:
  /// **'The latest.log file has not been created yet.'**
  String get textTheLatestLogFileHasNotBeen10;

  /// Host UI: Запустите рабочую область приложения.
  ///
  /// In en, this message translates to:
  /// **'Open the application workspace.'**
  String get textOpenTheApplicationWorkspace11;

  /// Host UI: Повторить
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get textRetry12;

  /// Host UI: Debug terminal
  ///
  /// In en, this message translates to:
  /// **'Debug terminal'**
  String get textDebugTerminal13;

  /// Host UI: Продолжить
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get textResume14;

  /// Host UI: Пауза
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get textPause15;

  /// Host UI: Автопрокрутка
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get textAutoScroll16;

  /// Host UI: Сохранить видимое
  ///
  /// In en, this message translates to:
  /// **'Save visible entries'**
  String get textSaveVisibleEntries17;

  /// Host UI: Очистить вид
  ///
  /// In en, this message translates to:
  /// **'Clear view'**
  String get textClearView18;

  /// Host UI: Закрыть окно
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get textCloseWindow19;

  /// Host UI: Supabase Auth is not initialized.
  ///
  /// In en, this message translates to:
  /// **'Supabase Auth is not initialized.'**
  String get textSupabaseAuthIsNotInitialized20;

  /// Host UI: Could not open the GitHub sign-in page.
  ///
  /// In en, this message translates to:
  /// **'Could not open the GitHub sign-in page.'**
  String get textCouldNotOpenTheGitHubSignIn21;

  /// Host UI: Unsupported workspace preset format.
  ///
  /// In en, this message translates to:
  /// **'Unsupported workspace preset format.'**
  String get textUnsupportedWorkspacePresetFormat22;

  /// Host UI: A preset needs a name and a list of module IDs.
  ///
  /// In en, this message translates to:
  /// **'A preset needs a name and a list of module IDs.'**
  String get textAPresetNeedsANameAndA23;

  /// Host UI: A preset supports up to 500 modules.
  ///
  /// In en, this message translates to:
  /// **'A preset supports up to 500 modules.'**
  String get textAPresetSupportsUpTo500Modules24;

  /// Host UI: A module is missing.
  ///
  /// In en, this message translates to:
  /// **'A module is missing.'**
  String get textAModuleIsMissing25;

  /// Host UI: A module cannot connect to itself.
  ///
  /// In en, this message translates to:
  /// **'A module cannot connect to itself.'**
  String get textAModuleCannotConnectToItself26;

  /// Host UI: A port is missing.
  ///
  /// In en, this message translates to:
  /// **'A port is missing.'**
  String get textAPortIsMissing27;

  /// Host UI: This connection would create a processing cycle.
  ///
  /// In en, this message translates to:
  /// **'This connection would create a processing cycle.'**
  String get textThisConnectionWouldCreateAProcessingCycle28;

  /// Host UI: libbci_engine_core не найдена рядом с исполняемым файлом
  ///
  /// In en, this message translates to:
  /// **'libbci_engine_core was not found beside the executable'**
  String get textLibbciEngineCoreWasNotFoundBeside29;

  /// Host UI: Потребитель
  ///
  /// In en, this message translates to:
  /// **'Consumer'**
  String get textConsumer30;

  /// Host UI: Исследователь
  ///
  /// In en, this message translates to:
  /// **'Researcher'**
  String get textResearcher31;

  /// Host UI: Разработчик
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get textDeveloper32;

  /// Host UI: Личный и медицинский режим
  ///
  /// In en, this message translates to:
  /// **'Personal and medical mode'**
  String get textPersonalAndMedicalMode33;

  /// Host UI: Датасеты, спектрограммы, эксперименты
  ///
  /// In en, this message translates to:
  /// **'Datasets, spectrograms, experiments'**
  String get textDatasetsSpectrogramsExperiments34;

  /// Host UI: Модули, API, низкоуровневый доступ
  ///
  /// In en, this message translates to:
  /// **'Modules, API, low-level access'**
  String get textModulesAPILowLevelAccess35;

  /// Host UI: Обзор
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get textDashboard36;

  /// Host UI: Состояние системы
  ///
  /// In en, this message translates to:
  /// **'System status'**
  String get textSystemStatus37;

  /// Host UI: Устройства
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get textDevices38;

  /// Host UI: HAL, подключение плат
  ///
  /// In en, this message translates to:
  /// **'HAL, board connections'**
  String get textHALBoardConnections39;

  /// Host UI: Сессия
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get textSession40;

  /// Host UI: Запись и live-метрики
  ///
  /// In en, this message translates to:
  /// **'Recording and live metrics'**
  String get textRecordingAndLiveMetrics41;

  /// Host UI: Конвейер
  ///
  /// In en, this message translates to:
  /// **'Pipeline'**
  String get textPipeline42;

  /// Host UI: Цепочка модулей обработки
  ///
  /// In en, this message translates to:
  /// **'Signal-processing module chain'**
  String get textSignalProcessingModuleChain43;

  /// Host UI: Спектрограмма
  ///
  /// In en, this message translates to:
  /// **'Spectrogram'**
  String get textSpectrogram44;

  /// Host UI: Real-time визуализация
  ///
  /// In en, this message translates to:
  /// **'Real-time visualization'**
  String get textRealTimeVisualization45;

  /// Host UI: Канвас обработки модулей
  ///
  /// In en, this message translates to:
  /// **'Module processing canvas'**
  String get textModuleProcessingCanvas46;

  /// Host UI: Entity
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get textEntity47;

  /// Host UI: Neural network entities
  ///
  /// In en, this message translates to:
  /// **'Neural network entities'**
  String get textNeuralNetworkEntities48;

  /// Host UI: Датасеты
  ///
  /// In en, this message translates to:
  /// **'Datasets'**
  String get textDatasets49;

  /// Host UI: Загрузка и сравнение
  ///
  /// In en, this message translates to:
  /// **'Import and comparison'**
  String get textImportAndComparison50;

  /// Host UI: Модели
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get textModels51;

  /// Host UI: Обучение и реестр моделей
  ///
  /// In en, this message translates to:
  /// **'Training and model registry'**
  String get textTrainingAndModelRegistry52;

  /// Host UI: FFI-консоль ядра
  ///
  /// In en, this message translates to:
  /// **'Core FFI console'**
  String get textCoreFFIConsole53;

  /// Host UI: Marketplace
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get textMarketplace54;

  /// Host UI: Пользовательские расширения
  ///
  /// In en, this message translates to:
  /// **'Community extensions'**
  String get textCommunityExtensions55;

  /// Host UI: Bug report
  ///
  /// In en, this message translates to:
  /// **'Bug report'**
  String get textBugReport56;

  /// Host UI: Сообщить о проблеме
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get textReportAProblem57;

  /// Host UI: Настройки
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get textSettings58;

  /// Host UI: Режимы, сборка, лицензии
  ///
  /// In en, this message translates to:
  /// **'Modes, build, licenses'**
  String get textModesBuildLicenses59;

  /// Host UI: File
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get textFile60;

  /// Host UI: Edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get textEdit61;

  /// Host UI: View
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get textView62;

  /// Host UI: Help
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get textHelp63;

  /// Host UI: Ядро: активна сессия
  ///
  /// In en, this message translates to:
  /// **'Core: session active'**
  String get textCoreSessionActive64;

  /// Host UI: Ядро: онлайн
  ///
  /// In en, this message translates to:
  /// **'Core: online'**
  String get textCoreOnline65;

  /// Host UI: Ядро: офлайн
  ///
  /// In en, this message translates to:
  /// **'Core: offline'**
  String get textCoreOffline66;

  /// Host UI: Режим использования
  ///
  /// In en, this message translates to:
  /// **'Usage mode'**
  String get textUsageMode67;

  /// Host UI: General
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get textGeneral68;

  /// Host UI: Preset not imported
  ///
  /// In en, this message translates to:
  /// **'Preset not imported'**
  String get textPresetNotImported69;

  /// Host UI: Preset catalog unavailable
  ///
  /// In en, this message translates to:
  /// **'Preset catalog unavailable'**
  String get textPresetCatalogUnavailable70;

  /// Host UI: {arg0}. The preset remains loaded.
  ///
  /// In en, this message translates to:
  /// **'{arg0}. The preset remains loaded.'**
  String textArg0ThePresetRemainsLoaded71(String arg0);

  /// Host UI: Missing workspace modules
  ///
  /// In en, this message translates to:
  /// **'Missing workspace modules'**
  String get textMissingWorkspaceModules72;

  /// Host UI: {arg0}: {arg1}. The preset is saved; find the missing modules in Marketplace.
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1}. The preset is saved; find the missing modules in Marketplace.'**
  String textArg0Arg1ThePresetIsSavedFind73(String arg0, String arg1);

  /// Host UI: Missing modules: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Missing modules: {arg0}'**
  String textMissingModulesArg074(String arg0);

  /// Host UI: Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get textProfile75;

  /// Host UI: New tab
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get textNewTab76;

  /// Host UI: Preview module
  ///
  /// In en, this message translates to:
  /// **'Preview module'**
  String get textPreviewModule77;

  /// Host UI: Drag this placeholder to the canvas to change instance parameters. It is not a publishable draft.
  ///
  /// In en, this message translates to:
  /// **'Drag this placeholder to the canvas to change instance parameters. It is not a publishable draft.'**
  String get textDragThisPlaceholderToTheCanvasTo78;

  /// Host UI: Sign in required
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get textSignInRequired79;

  /// Host UI: Module not saved
  ///
  /// In en, this message translates to:
  /// **'Module not saved'**
  String get textModuleNotSaved80;

  /// Host UI: Module added
  ///
  /// In en, this message translates to:
  /// **'Module added'**
  String get textModuleAdded81;

  /// Host UI: Module updated
  ///
  /// In en, this message translates to:
  /// **'Module updated'**
  String get textModuleUpdated82;

  /// Host UI: {arg0} is now available in Workspace.
  ///
  /// In en, this message translates to:
  /// **'{arg0} is now available in Workspace.'**
  String textArg0IsNowAvailableInWorkspace83(String arg0);

  /// Host UI: Modules unavailable
  ///
  /// In en, this message translates to:
  /// **'Modules unavailable'**
  String get textModulesUnavailable84;

  /// Host UI: Could not load modules from your account.
  ///
  /// In en, this message translates to:
  /// **'Could not load modules from your account.'**
  String get textCouldNotLoadModulesFromYourAccount85;

  /// Host UI: Entity added
  ///
  /// In en, this message translates to:
  /// **'Entity added'**
  String get textEntityAdded86;

  /// Host UI: Entity updated
  ///
  /// In en, this message translates to:
  /// **'Entity updated'**
  String get textEntityUpdated87;

  /// Host UI: {arg0} is now available in Entity.
  ///
  /// In en, this message translates to:
  /// **'{arg0} is now available in Entity.'**
  String textArg0IsNowAvailableInEntity88(String arg0);

  /// Host UI: Entity removed
  ///
  /// In en, this message translates to:
  /// **'Entity removed'**
  String get textEntityRemoved89;

  /// Host UI: {arg0} was removed from Entity.
  ///
  /// In en, this message translates to:
  /// **'{arg0} was removed from Entity.'**
  String textArg0WasRemovedFromEntity90(String arg0);

  /// Host UI: Entity uninstalled
  ///
  /// In en, this message translates to:
  /// **'Entity uninstalled'**
  String get textEntityUninstalled91;

  /// Host UI: Entity installed
  ///
  /// In en, this message translates to:
  /// **'Entity installed'**
  String get textEntityInstalled92;

  /// Host UI: These placeholders belong to the local UI playground. Canvas instances can be deleted with right-click → Delete.
  ///
  /// In en, this message translates to:
  /// **'These placeholders belong to the local UI playground. Canvas instances can be deleted with right-click → Delete.'**
  String get textThesePlaceholdersBelongToTheLocalUI93;

  /// Host UI: Module not removed
  ///
  /// In en, this message translates to:
  /// **'Module not removed'**
  String get textModuleNotRemoved94;

  /// Host UI: Documentation
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get textDocumentation95;

  /// Host UI: Learn how to configure workspaces, devices, sessions and modules in Qualia Engine.
  ///
  /// In en, this message translates to:
  /// **'Learn how to configure workspaces, devices, sessions and modules in Qualia Engine.'**
  String get textLearnHowToConfigureWorkspacesDevicesSessions96;

  /// Host UI: About Us
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get textAboutUs97;

  /// Host UI: {arg0}
  /// Version {arg1}
  ///
  /// Built by {arg2} for focused brain-computer interface workflows.
  ///
  /// In en, this message translates to:
  /// **'{arg0}\nVersion {arg1}\n\nBuilt by {arg2} for focused brain-computer interface workflows.'**
  String textArg0VersionArg1BuiltByArg2For98(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Host UI: Welcome to Qualia Engine
  ///
  /// In en, this message translates to:
  /// **'Welcome to Qualia Engine'**
  String get textWelcomeToQualiaEngine99;

  /// Host UI: Qualia Engine is a desktop workspace for exploring BCI data, sessions and modular signal-processing pipelines.
  ///
  /// In en, this message translates to:
  /// **'Qualia Engine is a desktop workspace for exploring BCI data, sessions and modular signal-processing pipelines.'**
  String get textQualiaEngineIsADesktopWorkspaceFor100;

  /// Host UI: Tutorials
  ///
  /// In en, this message translates to:
  /// **'Tutorials'**
  String get textTutorials101;

  /// Host UI: Start with the Dashboard, connect a device, create a session and open Modules to build your processing workflow.
  ///
  /// In en, this message translates to:
  /// **'Start with the Dashboard, connect a device, create a session and open Modules to build your processing workflow.'**
  String get textStartWithTheDashboardConnectADevice102;

  /// Host UI: License
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get textLicense103;

  /// Host UI: Qualia Engine is distributed under the project license. See the repository license file for the complete terms.
  ///
  /// In en, this message translates to:
  /// **'Qualia Engine is distributed under the project license. See the repository license file for the complete terms.'**
  String get textQualiaEngineIsDistributedUnderTheProject104;

  /// Host UI: Check updates
  ///
  /// In en, this message translates to:
  /// **'Check updates'**
  String get textCheckUpdates105;

  /// Host UI: You are running Qualia Engine {arg0}. Update checking will be connected to the release channel in a future build.
  ///
  /// In en, this message translates to:
  /// **'You are running Qualia Engine {arg0}. Update checking will be connected to the release channel in a future build.'**
  String textYouAreRunningQualiaEngineArg0Update106(String arg0);

  /// Host UI: Our Youtube
  ///
  /// In en, this message translates to:
  /// **'Our Youtube'**
  String get textOurYoutube107;

  /// Host UI: Video tutorials and project updates will be available on the Qualia Engine YouTube channel.
  ///
  /// In en, this message translates to:
  /// **'Video tutorials and project updates will be available on the Qualia Engine YouTube channel.'**
  String get textVideoTutorialsAndProjectUpdatesWillBe108;

  /// Host UI: This help action is not available yet.
  ///
  /// In en, this message translates to:
  /// **'This help action is not available yet.'**
  String get textThisHelpActionIsNotAvailableYet109;

  /// Host UI: Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get textClose110;

  /// Host UI: Build
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get textBuild111;

  /// Host UI: Масштаб интерфейса (Ctrl + / Ctrl -)
  ///
  /// In en, this message translates to:
  /// **'Interface scale (Ctrl + / Ctrl -)'**
  String get textInterfaceScaleCtrlCtrl112;

  /// Host UI: Notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get textNotifications113;

  /// Host UI: Just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get textJustNow114;

  /// Host UI: {arg0} min ago
  ///
  /// In en, this message translates to:
  /// **'{arg0} min ago'**
  String textArg0MinAgo115(String arg0);

  /// Host UI: {arg0} h ago
  ///
  /// In en, this message translates to:
  /// **'{arg0} h ago'**
  String textArg0HAgo116(String arg0);

  /// Host UI: {arg0} d ago
  ///
  /// In en, this message translates to:
  /// **'{arg0} d ago'**
  String textArg0DAgo117(String arg0);

  /// Host UI: Mark all as read
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get textMarkAllAsRead118;

  /// Host UI: No notifications
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get textNoNotifications119;

  /// Host UI: Открыть терминал отладки
  ///
  /// In en, this message translates to:
  /// **'Open debug terminal'**
  String get textOpenDebugTerminal120;

  /// Host UI: Свернуть окно
  ///
  /// In en, this message translates to:
  /// **'Minimize window'**
  String get textMinimizeWindow121;

  /// Host UI: Восстановить окно
  ///
  /// In en, this message translates to:
  /// **'Restore window'**
  String get textRestoreWindow122;

  /// Host UI: Развернуть окно
  ///
  /// In en, this message translates to:
  /// **'Maximize window'**
  String get textMaximizeWindow123;

  /// Host UI: Add Workspace Preset
  ///
  /// In en, this message translates to:
  /// **'Add Workspace Preset'**
  String get textAddWorkspacePreset124;

  /// Host UI: New workspace
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get textNewWorkspace125;

  /// Host UI: Open project
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get textOpenProject126;

  /// Host UI: Import module (soon)
  ///
  /// In en, this message translates to:
  /// **'Import module (soon)'**
  String get textImportModuleSoon127;

  /// Host UI: Preferences
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get textPreferences128;

  /// Host UI: Rail settings
  ///
  /// In en, this message translates to:
  /// **'Rail settings'**
  String get textRailSettings129;

  /// Host UI: Undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get textUndo130;

  /// Host UI: Redo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get textRedo131;

  /// Host UI: Preferences (soon)
  ///
  /// In en, this message translates to:
  /// **'Preferences (soon)'**
  String get textPreferencesSoon132;

  /// Host UI: Explorer
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get textExplorer133;

  /// Host UI: Terminal
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get textTerminal134;

  /// Host UI: Customize layout (soon)
  ///
  /// In en, this message translates to:
  /// **'Customize layout (soon)'**
  String get textCustomizeLayoutSoon135;

  /// Host UI: Theme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get textTheme136;

  /// Host UI: System
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get textSystem137;

  /// Host UI: Dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get textDark138;

  /// Host UI: White
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get textWhite139;

  /// Host UI: Welcome
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get textWelcome140;

  /// Host UI: Report Issue
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get textReportIssue141;

  /// Host UI: Build project
  ///
  /// In en, this message translates to:
  /// **'Build project'**
  String get textBuildProject142;

  /// Host UI: Run session
  ///
  /// In en, this message translates to:
  /// **'Run session'**
  String get textRunSession143;

  /// Host UI: Build tasks (soon)
  ///
  /// In en, this message translates to:
  /// **'Build tasks (soon)'**
  String get textBuildTasksSoon144;

  /// Host UI: {arg0} menu
  ///
  /// In en, this message translates to:
  /// **'{arg0} menu'**
  String textArg0Menu145(String arg0);

  /// Host UI: QUICK ACTIONS
  ///
  /// In en, this message translates to:
  /// **'QUICK ACTIONS'**
  String get textQUICKACTIONS146;

  /// Host UI: Find module
  ///
  /// In en, this message translates to:
  /// **'Find module'**
  String get textFindModule147;

  /// Host UI: KEYBOARD SHORTCUTS
  ///
  /// In en, this message translates to:
  /// **'KEYBOARD SHORTCUTS'**
  String get textKEYBOARDSHORTCUTS148;

  /// Host UI: Increase interface scale
  ///
  /// In en, this message translates to:
  /// **'Increase interface scale'**
  String get textIncreaseInterfaceScale149;

  /// Host UI: Decrease interface scale
  ///
  /// In en, this message translates to:
  /// **'Decrease interface scale'**
  String get textDecreaseInterfaceScale150;

  /// Host UI: Shortcuts
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get textShortcuts151;

  /// Host UI: Search files, symbols...  (Ctrl+P)
  ///
  /// In en, this message translates to:
  /// **'Search files, symbols...  (Ctrl+P)'**
  String get textSearchFilesSymbolsCtrlP152;

  /// Host UI: User profile button
  ///
  /// In en, this message translates to:
  /// **'User profile button'**
  String get textUserProfileButton153;

  /// Host UI: bug report
  ///
  /// In en, this message translates to:
  /// **'bug report'**
  String get textBugReport154;

  /// Host UI: user&dev switcher
  ///
  /// In en, this message translates to:
  /// **'user&dev switcher'**
  String get textUserDevSwitcher155;

  /// Host UI: configs
  ///
  /// In en, this message translates to:
  /// **'configs'**
  String get textConfigs156;

  /// Host UI: EXPLORER
  ///
  /// In en, this message translates to:
  /// **'EXPLORER'**
  String get textEXPLORER157;

  /// Host UI: Add module
  ///
  /// In en, this message translates to:
  /// **'Add module'**
  String get textAddModule158;

  /// Host UI: Remove module
  ///
  /// In en, this message translates to:
  /// **'Remove module'**
  String get textRemoveModule159;

  /// Host UI: Edit module
  ///
  /// In en, this message translates to:
  /// **'Edit module'**
  String get textEditModule160;

  /// Host UI: Add entity
  ///
  /// In en, this message translates to:
  /// **'Add entity'**
  String get textAddEntity161;

  /// Host UI: Remove entity
  ///
  /// In en, this message translates to:
  /// **'Remove entity'**
  String get textRemoveEntity162;

  /// Host UI: Edit entity
  ///
  /// In en, this message translates to:
  /// **'Edit entity'**
  String get textEditEntity163;

  /// Host UI: WORKSPACE PRESETS
  ///
  /// In en, this message translates to:
  /// **'WORKSPACE PRESETS'**
  String get textWORKSPACEPRESETS164;

  /// Host UI: Import Workspace Preset
  ///
  /// In en, this message translates to:
  /// **'Import Workspace Preset'**
  String get textImportWorkspacePreset165;

  /// Host UI: Export {arg0}
  ///
  /// In en, this message translates to:
  /// **'Export {arg0}'**
  String textExportArg0166(String arg0);

  /// Host UI: Missing: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Missing: {arg0}'**
  String textMissingArg0167(String arg0);

  /// Host UI: ACTIVE MODULES
  ///
  /// In en, this message translates to:
  /// **'ACTIVE MODULES'**
  String get textACTIVEMODULES168;

  /// Host UI: Search active modules...
  ///
  /// In en, this message translates to:
  /// **'Search active modules...'**
  String get textSearchActiveModules169;

  /// Host UI: No active modules found
  ///
  /// In en, this message translates to:
  /// **'No active modules found'**
  String get textNoActiveModulesFound170;

  /// Host UI: MODULE CATALOG
  ///
  /// In en, this message translates to:
  /// **'MODULE CATALOG'**
  String get textMODULECATALOG171;

  /// Host UI: Search modules...
  ///
  /// In en, this message translates to:
  /// **'Search modules...'**
  String get textSearchModules172;

  /// Host UI: No modules found
  ///
  /// In en, this message translates to:
  /// **'No modules found'**
  String get textNoModulesFound173;

  /// Host UI: INSTALLED ENTITIES
  ///
  /// In en, this message translates to:
  /// **'INSTALLED ENTITIES'**
  String get textINSTALLEDENTITIES174;

  /// Host UI: ENTITY CATALOG
  ///
  /// In en, this message translates to:
  /// **'ENTITY CATALOG'**
  String get textENTITYCATALOG175;

  /// Host UI: Installed
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get textInstalled176;

  /// Host UI: Recommended
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get textRecommended177;

  /// Host UI: No active workspace items
  ///
  /// In en, this message translates to:
  /// **'No active workspace items'**
  String get textNoActiveWorkspaceItems178;

  /// Host UI: Clear module search
  ///
  /// In en, this message translates to:
  /// **'Clear module search'**
  String get textClearModuleSearch179;

  /// Host UI: Create new tab
  ///
  /// In en, this message translates to:
  /// **'Create new tab'**
  String get textCreateNewTab180;

  /// Host UI: Hide Explorer
  ///
  /// In en, this message translates to:
  /// **'Hide Explorer'**
  String get textHideExplorer181;

  /// Host UI: Show Explorer
  ///
  /// In en, this message translates to:
  /// **'Show Explorer'**
  String get textShowExplorer182;

  /// Host UI: Close tab
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get textCloseTab183;

  /// Host UI: No open tabs
  ///
  /// In en, this message translates to:
  /// **'No open tabs'**
  String get textNoOpenTabs184;

  /// Host UI: Create a new tab to continue
  ///
  /// In en, this message translates to:
  /// **'Create a new tab to continue'**
  String get textCreateANewTabToContinue185;

  /// Host UI: New module
  ///
  /// In en, this message translates to:
  /// **'New module'**
  String get textNewModule186;

  /// Host UI: Custom module description.
  ///
  /// In en, this message translates to:
  /// **'Custom module description.'**
  String get textCustomModuleDescription187;

  /// Host UI: ID
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get textID188;

  /// Host UI: Name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get textName189;

  /// Host UI: Category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get textCategory190;

  /// Host UI: Description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get textDescription191;

  /// Host UI: Marketplace cover
  ///
  /// In en, this message translates to:
  /// **'Marketplace cover'**
  String get textMarketplaceCover192;

  /// Host UI: Your image URL (HTTPS, optional)
  ///
  /// In en, this message translates to:
  /// **'Your image URL (HTTPS, optional)'**
  String get textYourImageURLHTTPSOptional193;

  /// Host UI: Background contour
  ///
  /// In en, this message translates to:
  /// **'Background contour'**
  String get textBackgroundContour194;

  /// Host UI: Center icon
  ///
  /// In en, this message translates to:
  /// **'Center icon'**
  String get textCenterIcon195;

  /// Host UI: Declarative manifest / UI schema (JSON)
  ///
  /// In en, this message translates to:
  /// **'Declarative manifest / UI schema (JSON)'**
  String get textDeclarativeManifestUISchemaJSON196;

  /// Host UI: Cover and UI metadata are saved locally for drafts. Published releases supply the manifest to Marketplace.
  ///
  /// In en, this message translates to:
  /// **'Cover and UI metadata are saved locally for drafts. Published releases supply the manifest to Marketplace.'**
  String get textCoverAndUIMetadataAreSavedLocally197;

  /// Host UI: Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get textCancel198;

  /// Host UI: {arg0} must be an array
  ///
  /// In en, this message translates to:
  /// **'{arg0} must be an array'**
  String textArg0MustBeAnArray199(String arg0);

  /// Host UI: Cover image must use HTTPS
  ///
  /// In en, this message translates to:
  /// **'Cover image must use HTTPS'**
  String get textCoverImageMustUseHTTPS200;

  /// Host UI: Invalid schema: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Invalid schema: {arg0}'**
  String textInvalidSchemaArg0201(String arg0);

  /// Host UI: Custom
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get textCustom202;

  /// Host UI: Save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get textSave203;

  /// Host UI: New neural entity
  ///
  /// In en, this message translates to:
  /// **'New neural entity'**
  String get textNewNeuralEntity204;

  /// Host UI: Neural network description.
  ///
  /// In en, this message translates to:
  /// **'Neural network description.'**
  String get textNeuralNetworkDescription205;

  /// Host UI: Framework
  ///
  /// In en, this message translates to:
  /// **'Framework'**
  String get textFramework206;

  /// Host UI: Version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get textVersion207;

  /// Host UI: Unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get textUnknown208;

  /// Host UI: Extension settings
  ///
  /// In en, this message translates to:
  /// **'Extension settings'**
  String get textExtensionSettings209;

  /// Host UI: Disable/enable
  ///
  /// In en, this message translates to:
  /// **'Disable/enable'**
  String get textDisableEnable210;

  /// Host UI: Autoupdate
  ///
  /// In en, this message translates to:
  /// **'Autoupdate'**
  String get textAutoupdate211;

  /// Host UI: Uninstall
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get textUninstall212;

  /// Host UI: Copy link
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get textCopyLink213;

  /// Host UI: Copy name
  ///
  /// In en, this message translates to:
  /// **'Copy name'**
  String get textCopyName214;

  /// Host UI: Keyboard
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get textKeyboard215;

  /// Host UI: Profiles operate
  ///
  /// In en, this message translates to:
  /// **'Profiles operate'**
  String get textProfilesOperate216;

  /// Host UI: Extension changed
  ///
  /// In en, this message translates to:
  /// **'Extension changed'**
  String get textExtensionChanged217;

  /// Host UI: {arg0}: {arg1} selected.
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1} selected.'**
  String textArg0Arg1Selected218(String arg0, String arg1);

  /// Host UI: TERMINAL
  ///
  /// In en, this message translates to:
  /// **'TERMINAL'**
  String get textTERMINAL219;

  /// Host UI: OUTPUT
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get textOUTPUT220;

  /// Host UI: Close rail settings
  ///
  /// In en, this message translates to:
  /// **'Close rail settings'**
  String get textCloseRailSettings221;

  /// Host UI: Visibility
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get textVisibility222;

  /// Host UI: Show rail
  ///
  /// In en, this message translates to:
  /// **'Show rail'**
  String get textShowRail223;

  /// Host UI: When hidden, content uses the full width.
  /// Restore it with Edit → Rail settings.
  ///
  /// In en, this message translates to:
  /// **'When hidden, content uses the full width.\nRestore it with Edit → Rail settings.'**
  String get textWhenHiddenContentUsesTheFullWidth224;

  /// Host UI: Sections
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get textSections225;

  /// Host UI: Extension sections
  ///
  /// In en, this message translates to:
  /// **'Extension sections'**
  String get textExtensionSections226;

  /// Host UI: Add an extension from the catalog to configure its rail entry here.
  ///
  /// In en, this message translates to:
  /// **'Add an extension from the catalog to configure its rail entry here.'**
  String get textAddAnExtensionFromTheCatalogTo227;

  /// Host UI: Changes are saved automatically
  ///
  /// In en, this message translates to:
  /// **'Changes are saved automatically'**
  String get textChangesAreSavedAutomatically228;

  /// Host UI: Done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get textDone229;

  /// Host UI: {arg0} {arg1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} {arg1}'**
  String textArg0Arg1230(String arg0, String arg1);

  /// Host UI: Hide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get textHide231;

  /// Host UI: Show
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get textShow232;

  /// Host UI: Back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get textBack233;

  /// Host UI: Extension context menu
  ///
  /// In en, this message translates to:
  /// **'Extension context menu'**
  String get textExtensionContextMenu234;

  /// Host UI: Состояние движка и быстрый старт
  ///
  /// In en, this message translates to:
  /// **'Engine status and quick start'**
  String get textEngineStatusAndQuickStart235;

  /// Host UI: Интерфейс обновлён · рабочая область готова
  ///
  /// In en, this message translates to:
  /// **'Interface updated · workspace ready'**
  String get textInterfaceUpdatedWorkspaceReady236;

  /// Host UI: Настроить
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get textConfigure237;

  /// Host UI: Ядро (C++ / FFI)
  ///
  /// In en, this message translates to:
  /// **'Core (C++ / FFI)'**
  String get textCoreCFFI238;

  /// Host UI: онлайн
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get textOnline239;

  /// Host UI: офлайн
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get textOffline240;

  /// Host UI: Версия ядра
  ///
  /// In en, this message translates to:
  /// **'Core version'**
  String get textCoreVersion241;

  /// Host UI: {arg0} (ожидается {arg1})
  ///
  /// In en, this message translates to:
  /// **'{arg0} (expected {arg1})'**
  String textArg0ExpectedArg1242(String arg0, String arg1);

  /// Host UI: Библиотека
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get textLibrary243;

  /// Host UI: не найдена
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get textNotFound244;

  /// Host UI: Модулей в конвейере
  ///
  /// In en, this message translates to:
  /// **'Modules in pipeline'**
  String get textModulesInPipeline245;

  /// Host UI: Ошибка
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get textError246;

  /// Host UI: Быстрый старт
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get textQuickStart247;

  /// Host UI: Запустить тестовую сессию
  ///
  /// In en, this message translates to:
  /// **'Start a test session'**
  String get textStartATestSession248;

  /// Host UI: Спектрограмма (demo)
  ///
  /// In en, this message translates to:
  /// **'Spectrogram (demo)'**
  String get textSpectrogramDemo249;

  /// Host UI: Реестр модулей
  ///
  /// In en, this message translates to:
  /// **'Module registry'**
  String get textModuleRegistry250;

  /// Host UI: 24.09 · тест
  ///
  /// In en, this message translates to:
  /// **'24.09 · test'**
  String get text2409Test251;

  /// Host UI: Симулятор · 00:32 · качество 0.86
  ///
  /// In en, this message translates to:
  /// **'Simulator · 00:32 · quality 0.86'**
  String get textSimulator0032Quality086252;

  /// Host UI: 23.09 · калибровка
  ///
  /// In en, this message translates to:
  /// **'23.09 · calibration'**
  String get text2309Calibration253;

  /// Host UI: Симулятор · 03:12 · готово
  ///
  /// In en, this message translates to:
  /// **'Simulator · 03:12 · complete'**
  String get textSimulator0312Complete254;

  /// Host UI: 22.09 · сон
  ///
  /// In en, this message translates to:
  /// **'22.09 · sleep'**
  String get text2209Sleep255;

  /// Host UI: Симулятор · 01:05 · качество 0.71
  ///
  /// In en, this message translates to:
  /// **'Simulator · 01:05 · quality 0.71'**
  String get textSimulator0105Quality071256;

  /// Host UI: Хранение сессий будет реализовано в Storage Service (v0.2).
  ///
  /// In en, this message translates to:
  /// **'Session storage will be implemented in Storage Service (v0.2).'**
  String get textSessionStorageWillBeImplementedInStorage257;

  /// Host UI: Симулятор ЭЭГ
  ///
  /// In en, this message translates to:
  /// **'EEG simulator'**
  String get textEEGSimulator258;

  /// Host UI: ADS1299-совместимая плата
  ///
  /// In en, this message translates to:
  /// **'ADS1299-compatible board'**
  String get textADS1299CompatibleBoard259;

  /// Host UI: LSL-источник
  ///
  /// In en, this message translates to:
  /// **'LSL source'**
  String get textLSLSource260;

  /// Host UI: Подключение к любому Lab Streaming Layer-потоку в сети.
  ///
  /// In en, this message translates to:
  /// **'Connect to any Lab Streaming Layer stream on the network.'**
  String get textConnectToAnyLabStreamingLayerStream261;

  /// Host UI: Hardware Abstraction Layer · v0.1 — виртуальные источники
  ///
  /// In en, this message translates to:
  /// **'Hardware Abstraction Layer · v0.1 — virtual sources'**
  String get textHardwareAbstractionLayerV01VirtualSources262;

  /// Host UI: Планы HAL (v0.2)
  ///
  /// In en, this message translates to:
  /// **'HAL roadmap (v0.2)'**
  String get textHALRoadmapV02263;

  /// Host UI: Нормализация
  ///
  /// In en, this message translates to:
  /// **'Normalization'**
  String get textNormalization264;

  /// Host UI: сырой сигнал → μV, масштаб платы
  ///
  /// In en, this message translates to:
  /// **'raw signal → μV, board scale'**
  String get textRawSignalVBoardScale265;

  /// Host UI: Импеданс
  ///
  /// In en, this message translates to:
  /// **'Impedance'**
  String get textImpedance266;

  /// Host UI: процедура калибровки контактов
  ///
  /// In en, this message translates to:
  /// **'contact calibration procedure'**
  String get textContactCalibrationProcedure267;

  /// Host UI: Hot-plug
  ///
  /// In en, this message translates to:
  /// **'Hot-plug'**
  String get textHotPlug268;

  /// Host UI: детекция подключения/отключения
  ///
  /// In en, this message translates to:
  /// **'connection/disconnection detection'**
  String get textConnectionDisconnectionDetection269;

  /// Host UI: Частота/каналы
  ///
  /// In en, this message translates to:
  /// **'Rate/channels'**
  String get textRateChannels270;

  /// Host UI: управление конфигурацией платы
  ///
  /// In en, this message translates to:
  /// **'board configuration management'**
  String get textBoardConfigurationManagement271;

  /// Host UI: Не удалось запустить ядро (код {arg0})
  ///
  /// In en, this message translates to:
  /// **'Could not start the core (code {arg0})'**
  String textCouldNotStartTheCoreCodeArg0272(String arg0);

  /// Host UI: Поток идёт через C++-ядро (push → pipeline → pop)
  ///
  /// In en, this message translates to:
  /// **'Streaming through the C++ core (push → pipeline → pop)'**
  String get textStreamingThroughTheCCorePushPipeline273;

  /// Host UI: Ядро офлайн — локальная симуляция в Dart
  ///
  /// In en, this message translates to:
  /// **'Core offline — local Dart simulation'**
  String get textCoreOfflineLocalDartSimulation274;

  /// Host UI: Сессия идёт
  ///
  /// In en, this message translates to:
  /// **'Session running'**
  String get textSessionRunning275;

  /// Host UI: Тестовая сессия
  ///
  /// In en, this message translates to:
  /// **'Test session'**
  String get textTestSession276;

  /// Host UI: через ядро
  ///
  /// In en, this message translates to:
  /// **'through core'**
  String get textThroughCore277;

  /// Host UI: Dart-симуляция
  ///
  /// In en, this message translates to:
  /// **'Dart simulation'**
  String get textDartSimulation278;

  /// Host UI: Время
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get textTime279;

  /// Host UI: Кадров
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get textFrames280;

  /// Host UI: Пик, Гц
  ///
  /// In en, this message translates to:
  /// **'Peak, Hz'**
  String get textPeakHz281;

  /// Host UI: Качество
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get textQuality282;

  /// Host UI: Старт
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get textStart283;

  /// Host UI: Стоп
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get textStop284;

  /// Host UI: Симулятор 256 Гц · 1 канал · блок {arg0} кадров
  ///
  /// In en, this message translates to:
  /// **'Simulator 256 Hz · 1 channel · block of {arg0} frames'**
  String textSimulator256Hz1ChannelBlockOf285(String arg0);

  /// Host UI: История сессий (в памяти, v0.1)
  ///
  /// In en, this message translates to:
  /// **'Session history (in memory, v0.1)'**
  String get textSessionHistoryInMemoryV01286;

  /// Host UI: Пока пусто — запустите сессию.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet — start a session.'**
  String get textNoSessionsYetStartASession287;

  /// Host UI: ядро
  ///
  /// In en, this message translates to:
  /// **'core'**
  String get textCore288;

  /// Host UI: Device → Raw Buffer → Preprocessing → Features → Output
  ///
  /// In en, this message translates to:
  /// **'Device → Raw Buffer → Preprocessing → Features → Output'**
  String get textDeviceRawBufferPreprocessingFeaturesOutput289;

  /// Host UI: Активная цепочка ядра
  ///
  /// In en, this message translates to:
  /// **'Active core pipeline'**
  String get textActiveCorePipeline290;

  /// Host UI: недоступно
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get textUnavailable291;

  /// Host UI: {arg0} модулей
  ///
  /// In en, this message translates to:
  /// **'{arg0} modules'**
  String textArg0Modules292(String arg0);

  /// Host UI: Модули получены из ядра через bci_engine_module_json():
  ///
  /// In en, this message translates to:
  /// **'Modules retrieved from the core via bci_engine_module_json():'**
  String get textModulesRetrievedFromTheCoreViaBci293;

  /// Host UI: Add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get textAdd294;

  /// Host UI: Replace module
  ///
  /// In en, this message translates to:
  /// **'Replace module'**
  String get textReplaceModule295;

  /// Host UI: Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get textDelete296;

  /// Host UI: Connect an output to an input.
  ///
  /// In en, this message translates to:
  /// **'Connect an output to an input.'**
  String get textConnectAnOutputToAnInput297;

  /// Host UI: {arg0} modules · {arg1} connections
  ///
  /// In en, this message translates to:
  /// **'{arg0} modules · {arg1} connections'**
  String textArg0ModulesArg1Connections298(String arg0, String arg1);

  /// No description provided for @workspaceHideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide right sidebar'**
  String get workspaceHideSidebar;

  /// No description provided for @workspaceShowSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show right sidebar'**
  String get workspaceShowSidebar;

  /// No description provided for @workspaceColorNone.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get workspaceColorNone;

  /// No description provided for @workspaceColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get workspaceColorRed;

  /// No description provided for @workspaceColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get workspaceColorOrange;

  /// No description provided for @workspaceColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get workspaceColorYellow;

  /// No description provided for @workspaceColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get workspaceColorGreen;

  /// No description provided for @workspaceColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get workspaceColorBlue;

  /// No description provided for @workspaceColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get workspaceColorPurple;

  /// No description provided for @workspaceHeaderColor.
  ///
  /// In en, this message translates to:
  /// **'Module color'**
  String get workspaceHeaderColor;

  /// No description provided for @workspaceSelectSameColor.
  ///
  /// In en, this message translates to:
  /// **'Select modules with this color'**
  String get workspaceSelectSameColor;

  /// No description provided for @workspaceSelectByColor.
  ///
  /// In en, this message translates to:
  /// **'Select by color'**
  String get workspaceSelectByColor;

  /// No description provided for @workspaceColorSelected.
  ///
  /// In en, this message translates to:
  /// **'Color selected'**
  String get workspaceColorSelected;

  /// No description provided for @workspaceFilterByColor.
  ///
  /// In en, this message translates to:
  /// **'Filter by color'**
  String get workspaceFilterByColor;

  /// No description provided for @workspaceAllColors.
  ///
  /// In en, this message translates to:
  /// **'All colors'**
  String get workspaceAllColors;

  /// No description provided for @workspaceNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching modules'**
  String get workspaceNoSearchResults;

  /// Host UI: Add module to canvas
  ///
  /// In en, this message translates to:
  /// **'Add module to canvas'**
  String get textAddModuleToCanvas299;

  /// Host UI: Frame all (F)
  ///
  /// In en, this message translates to:
  /// **'Frame all (F)'**
  String get textFrameAllF300;

  /// Host UI: Module settings
  ///
  /// In en, this message translates to:
  /// **'Module settings'**
  String get textModuleSettings301;

  /// Host UI: Build your workspace
  ///
  /// In en, this message translates to:
  /// **'Build your workspace'**
  String get textBuildYourWorkspace302;

  /// Host UI: Drag a module from Explorer or right-click → Add
  ///
  /// In en, this message translates to:
  /// **'Drag a module from Explorer or right-click → Add'**
  String get textDragAModuleFromExplorerOrRight303;

  /// Host UI: Return to modules
  ///
  /// In en, this message translates to:
  /// **'Return to start'**
  String get textReturnToModules304;

  /// Host UI: MMB / drag to pan · wheel to zoom · F to frame
  ///
  /// In en, this message translates to:
  /// **'MMB / drag to pan · wheel to zoom · F to frame'**
  String get textMMBDragToPanWheelToZoom305;

  /// Host UI: Select an opposite port · Esc to cancel
  ///
  /// In en, this message translates to:
  /// **'Select an opposite port · Esc to cancel'**
  String get textSelectAnOppositePortEscToCancel306;

  /// Host UI: + Input
  ///
  /// In en, this message translates to:
  /// **'+ Input'**
  String get textInput307;

  /// Host UI: + Output
  ///
  /// In en, this message translates to:
  /// **'+ Output'**
  String get textOutput308;

  /// Host UI: Open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get textOpen309;

  /// Host UI: MODULE SETTINGS
  ///
  /// In en, this message translates to:
  /// **'MODULE SETTINGS'**
  String get textMODULESETTINGS310;

  /// Host UI: Close module settings
  ///
  /// In en, this message translates to:
  /// **'Close module settings'**
  String get textCloseModuleSettings311;

  /// Host UI: Select a module on the canvas.
  ///
  /// In en, this message translates to:
  /// **'Select a module on the canvas.'**
  String get textSelectAModuleOnTheCanvas312;

  /// Host UI: No additional settings have been declared by the author.
  ///
  /// In en, this message translates to:
  /// **'No additional settings have been declared by the author.'**
  String get textNoAdditionalSettingsHaveBeenDeclaredBy313;

  /// Host UI: Connections
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get textConnections314;

  /// Host UI: Disconnect ports
  ///
  /// In en, this message translates to:
  /// **'Disconnect ports'**
  String get textDisconnectPorts315;

  /// Host UI: No connections
  ///
  /// In en, this message translates to:
  /// **'No connections'**
  String get textNoConnections316;

  /// Host UI: Search available modules...
  ///
  /// In en, this message translates to:
  /// **'Search available modules...'**
  String get textSearchAvailableModules317;

  /// Host UI: No available modules.
  /// Add a draft or find modules in Marketplace.
  ///
  /// In en, this message translates to:
  /// **'No available modules.\nAdd a draft or find modules in Marketplace.'**
  String get textNoAvailableModulesAddADraftOr318;

  /// Host UI: Module interface
  ///
  /// In en, this message translates to:
  /// **'Module interface'**
  String get textModuleInterface319;

  /// Host UI: This module has not declared an active-area UI schema yet. Its graph ports and host settings remain available in Workspace.
  ///
  /// In en, this message translates to:
  /// **'This module has not declared an active-area UI schema yet. Its graph ports and host settings remain available in Workspace.'**
  String get textThisModuleHasNotDeclaredAnActive320;

  /// Host UI: Module ID: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Module ID: {arg0}'**
  String textModuleIDArg0321(String arg0);

  /// Host UI: Graph editing is available. Executing external packages requires the signed sandbox runtime.
  ///
  /// In en, this message translates to:
  /// **'Graph editing is available. Executing external packages requires the signed sandbox runtime.'**
  String get textGraphEditingIsAvailableExecutingExternalPackages322;

  /// Host UI: Workspace preset
  ///
  /// In en, this message translates to:
  /// **'Workspace preset'**
  String get textWorkspacePreset323;

  /// Host UI: Preset file is too large.
  ///
  /// In en, this message translates to:
  /// **'Preset file is too large.'**
  String get textPresetFileIsTooLarge324;

  /// Host UI: Preset name
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get textPresetName325;

  /// Host UI: Additional Marketplace module IDs
  ///
  /// In en, this message translates to:
  /// **'Additional Marketplace module IDs'**
  String get textAdditionalMarketplaceModuleIDs326;

  /// Host UI: One ID per line or separated by commas
  ///
  /// In en, this message translates to:
  /// **'One ID per line or separated by commas'**
  String get textOneIDPerLineOrSeparatedBy327;

  /// Host UI: You can create an empty preset or list Marketplace module IDs above.
  ///
  /// In en, this message translates to:
  /// **'You can create an empty preset or list Marketplace module IDs above.'**
  String get textYouCanCreateAnEmptyPresetOr328;

  /// Host UI: STFT 256 / hop 32 · симулятор 256 Гц · маркеры событий
  ///
  /// In en, this message translates to:
  /// **'STFT 256 / hop 32 · simulator 256 Hz · event markers'**
  String get textSTFT256Hop32Simulator256Hz329;

  /// Host UI: Добавить маркер
  ///
  /// In en, this message translates to:
  /// **'Add marker'**
  String get textAddMarker330;

  /// Host UI: Очистить
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get textClear331;

  /// Host UI: 0 Гц
  ///
  /// In en, this message translates to:
  /// **'0 Hz'**
  String get text0Hz332;

  /// Host UI: ~127 Гц
  ///
  /// In en, this message translates to:
  /// **'~127 Hz'**
  String get text127Hz333;

  /// Host UI: Маркеры
  ///
  /// In en, this message translates to:
  /// **'Markers'**
  String get textMarkers334;

  /// Host UI: сек ≈ {arg0}
  ///
  /// In en, this message translates to:
  /// **'sec ≈ {arg0}'**
  String textSecArg0335(String arg0);

  /// Host UI: Параметры
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get textParameters336;

  /// Host UI: Чувствительность ×{arg0}
  ///
  /// In en, this message translates to:
  /// **'Sensitivity ×{arg0}'**
  String textSensitivityArg0337(String arg0);

  /// Host UI: О версиях
  ///
  /// In en, this message translates to:
  /// **'About versions'**
  String get textAboutVersions338;

  /// Host UI: ядро не загружено
  ///
  /// In en, this message translates to:
  /// **'core not loaded'**
  String get textCoreNotLoaded339;

  /// Host UI: engine создан
  ///
  /// In en, this message translates to:
  /// **'engine created'**
  String get textEngineCreated340;

  /// Host UI: create не удался
  ///
  /// In en, this message translates to:
  /// **'create failed'**
  String get textCreateFailed341;

  /// Host UI: engine стартовал (256 Гц × 1)
  ///
  /// In en, this message translates to:
  /// **'engine started (256 Hz × 1)'**
  String get textEngineStarted256Hz1342;

  /// Host UI: start → код {arg0}
  ///
  /// In en, this message translates to:
  /// **'start → code {arg0}'**
  String textStartCodeArg0343(String arg0);

  /// Host UI: ядра нет
  ///
  /// In en, this message translates to:
  /// **'no core'**
  String get textNoCore344;

  /// Host UI: stop → код {arg0}
  ///
  /// In en, this message translates to:
  /// **'stop → code {arg0}'**
  String textStopCodeArg0345(String arg0);

  /// Host UI: engine не создан
  ///
  /// In en, this message translates to:
  /// **'engine not created'**
  String get textEngineNotCreated346;

  /// Host UI: start → код {arg0}
  ///
  /// In en, this message translates to:
  /// **'start → code {arg0}'**
  String textStartCodeArg0347(String arg0);

  /// Host UI: модули недоступны (нужен запущенный engine)
  ///
  /// In en, this message translates to:
  /// **'modules unavailable (a running engine is required)'**
  String get textModulesUnavailableARunningEngineIsRequired348;

  /// Host UI: FFI-консоль ядра · bci_engine_* C API
  ///
  /// In en, this message translates to:
  /// **'Core FFI console · bci_engine_* C API'**
  String get textCoreFFIConsoleBciEngineCAPI349;

  /// Host UI: Создать engine
  ///
  /// In en, this message translates to:
  /// **'Create engine'**
  String get textCreateEngine350;

  /// Host UI: Echo-тест
  ///
  /// In en, this message translates to:
  /// **'Echo test'**
  String get textEchoTest351;

  /// Host UI: Модули (JSON)
  ///
  /// In en, this message translates to:
  /// **'Modules (JSON)'**
  String get textModulesJSON352;

  /// Host UI: Библиотека: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Library: {arg0}'**
  String textLibraryArg0353(String arg0);

  /// Host UI: Библиотека ядра не найдена — соберите ядро (scripts/build.sh).
  ///
  /// In en, this message translates to:
  /// **'Core library not found — build the core (scripts/build.sh).'**
  String get textCoreLibraryNotFoundBuildTheCore354;

  /// Host UI: Reset interface scale
  ///
  /// In en, this message translates to:
  /// **'Reset interface scale'**
  String get textResetInterfaceScale355;

  /// Host UI: WORKSPACE
  ///
  /// In en, this message translates to:
  /// **'WORKSPACE'**
  String get textWORKSPACE356;

  /// Host UI: INTERFACE
  ///
  /// In en, this message translates to:
  /// **'INTERFACE'**
  String get textINTERFACE357;

  /// Host UI: Keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get textKeyboardShortcuts358;

  /// Host UI: Edit shortcuts
  ///
  /// In en, this message translates to:
  /// **'Edit shortcuts'**
  String get textEditShortcuts359;

  /// Host UI: Press keys
  ///
  /// In en, this message translates to:
  /// **'Press keys'**
  String get textPressKeys360;

  /// Host UI: Import
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get textImport361;

  /// Host UI: Appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get textAppearance362;

  /// Host UI: Voice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get textVoice363;

  /// Host UI: Configuration
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get textConfiguration364;

  /// Host UI: Personalization
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get textPersonalization365;

  /// Host UI: Account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get textAccount366;

  /// Host UI: Search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get textSearch367;

  /// Host UI: Personal
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get textPersonal368;

  /// Host UI: Archived
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get textArchived369;

  /// Host UI: Back to app
  ///
  /// In en, this message translates to:
  /// **'Back to app'**
  String get textBackToApp370;

  /// Host UI: Permissions
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get textPermissions371;

  /// Host UI: Default permissions
  ///
  /// In en, this message translates to:
  /// **'Default permissions'**
  String get textDefaultPermissions372;

  /// Host UI: By default, Ayakiro can read and edit files in its workspace. It can ask for additional access when needed
  ///
  /// In en, this message translates to:
  /// **'By default, Ayakiro can read and edit files in its workspace. It can ask for additional access when needed'**
  String get textByDefaultAyakiroCanReadAndEdit373;

  /// Host UI: Full access
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get textFullAccess374;

  /// Host UI: When Ayakiro runs with full access, it can edit any file on your computer and run commands with network, without your approval. This significantly increases the risk of data loss, leaks, or unexpected behavior.
  ///
  /// In en, this message translates to:
  /// **'When Ayakiro runs with full access, it can edit any file on your computer and run commands with network, without your approval. This significantly increases the risk of data loss, leaks, or unexpected behavior.'**
  String get textWhenAyakiroRunsWithFullAccessIt375;

  /// Host UI: Learn more about elevated risks.
  ///
  /// In en, this message translates to:
  /// **'Learn more about elevated risks.'**
  String get textLearnMoreAboutElevatedRisks376;

  /// Host UI: Projectless task folder
  ///
  /// In en, this message translates to:
  /// **'Projectless task folder'**
  String get textProjectlessTaskFolder377;

  /// Host UI: The location where tasks started outside of projects store their data by default.
  ///
  /// In en, this message translates to:
  /// **'The location where tasks started outside of projects store their data by default.'**
  String get textTheLocationWhereTasksStartedOutsideOf378;

  /// Host UI: Change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get textChange379;

  /// Host UI: Default file open destination
  ///
  /// In en, this message translates to:
  /// **'Default file open destination'**
  String get textDefaultFileOpenDestination380;

  /// Host UI: Where files and folders open by default
  ///
  /// In en, this message translates to:
  /// **'Where files and folders open by default'**
  String get textWhereFilesAndFoldersOpenByDefault381;

  /// Host UI: Language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get textLanguage382;

  /// Host UI: Language for the app UI
  ///
  /// In en, this message translates to:
  /// **'Language for the app UI'**
  String get textLanguageForTheAppUI383;

  /// Host UI: Auto detect
  ///
  /// In en, this message translates to:
  /// **'Auto detect'**
  String get textAutoDetect384;

  /// Host UI: Bottom panel
  ///
  /// In en, this message translates to:
  /// **'Bottom panel'**
  String get textBottomPanel385;

  /// Host UI: Show the bottom panel control in the app header
  ///
  /// In en, this message translates to:
  /// **'Show the bottom panel control in the app header'**
  String get textShowTheBottomPanelControlInThe386;

  /// Host UI: Prevent sleep while running
  ///
  /// In en, this message translates to:
  /// **'Prevent sleep while running'**
  String get textPreventSleepWhileRunning387;

  /// Host UI: Keep your computer awake while Ayakiro is running a task
  ///
  /// In en, this message translates to:
  /// **'Keep your computer awake while Ayakiro is running a task'**
  String get textKeepYourComputerAwakeWhileAyakiroIs388;

  /// Host UI: Open source licenses
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get textOpenSourceLicenses389;

  /// Host UI: Third-party software used by Ayakiro BCI Engine
  ///
  /// In en, this message translates to:
  /// **'Third-party software used by Ayakiro BCI Engine'**
  String get textThirdPartySoftwareUsedByAyakiroBCI390;

  /// Host UI: Current application build
  ///
  /// In en, this message translates to:
  /// **'Current application build'**
  String get textCurrentApplicationBuild391;

  /// Host UI: {arg0} · local offline-first mode
  ///
  /// In en, this message translates to:
  /// **'{arg0} · local offline-first mode'**
  String textArg0LocalOfflineFirstMode392(String arg0);

  /// Host UI: Загрузка, формирование и сравнение записей
  ///
  /// In en, this message translates to:
  /// **'Import, creation and comparison of recordings'**
  String get textImportCreationAndComparisonOfRecordings393;

  /// Host UI: Здесь появятся ваши датасеты
  ///
  /// In en, this message translates to:
  /// **'Your datasets will appear here'**
  String get textYourDatasetsWillAppearHere394;

  /// Host UI: Обучение без кода и реестр моделей
  ///
  /// In en, this message translates to:
  /// **'No-code training and model registry'**
  String get textNoCodeTrainingAndModelRegistry395;

  /// Host UI: Реестр моделей пуст
  ///
  /// In en, this message translates to:
  /// **'The model registry is empty'**
  String get textTheModelRegistryIsEmpty396;

  /// Host UI: Sign in with GitHub
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get textSignInWithGitHub397;

  /// Host UI: GitHub вход не завершён. Вернитесь в приложение после авторизации.
  ///
  /// In en, this message translates to:
  /// **'GitHub sign-in is incomplete. Return to the app after authorization.'**
  String get textGitHubSignInIsIncompleteReturnTo398;

  /// Host UI: Не удалось выполнить действие. Проверьте подключение и настройки OAuth.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the action. Check your connection and OAuth settings.'**
  String get textCouldNotCompleteTheActionCheckYour399;

  /// Host UI: Log in with:
  ///
  /// In en, this message translates to:
  /// **'Log in with:'**
  String get textLogInWith400;

  /// Host UI: Connecting to GitHub…
  ///
  /// In en, this message translates to:
  /// **'Connecting to GitHub…'**
  String get textConnectingToGitHub401;

  /// Host UI: Signing out…
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get textSigningOut402;

  /// Host UI: Sign out
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get textSignOut403;

  /// Host UI: Filters and signal inspection helpers for live sessions.
  ///
  /// In en, this message translates to:
  /// **'Filters and signal inspection helpers for live sessions.'**
  String get textFiltersAndSignalInspectionHelpersForLive404;

  /// Host UI: Add structured notes and markers while recording a session.
  ///
  /// In en, this message translates to:
  /// **'Add structured notes and markers while recording a session.'**
  String get textAddStructuredNotesAndMarkersWhileRecording405;

  /// Host UI: A compact dashboard for custom BCI metrics and signals.
  ///
  /// In en, this message translates to:
  /// **'A compact dashboard for custom BCI metrics and signals.'**
  String get textACompactDashboardForCustomBCIMetrics406;

  /// Host UI: Export recordings and derived data to common formats.
  ///
  /// In en, this message translates to:
  /// **'Export recordings and derived data to common formats.'**
  String get textExportRecordingsAndDerivedDataToCommon407;

  /// Host UI: {arg0}: {arg1} selected.
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1} selected.'**
  String textArg0Arg1Selected408(String arg0, String arg1);

  /// Host UI: EXTENSION INSPECTOR
  ///
  /// In en, this message translates to:
  /// **'EXTENSION INSPECTOR'**
  String get textEXTENSIONINSPECTOR409;

  /// Host UI: Select an extension
  ///
  /// In en, this message translates to:
  /// **'Select an extension'**
  String get textSelectAnExtension410;

  /// Host UI: Category  {arg0}
  ///
  /// In en, this message translates to:
  /// **'Category  {arg0}'**
  String textCategoryArg0411(String arg0);

  /// Host UI: Disable
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get textDisable412;

  /// Host UI: Enable
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get textEnable413;

  /// Host UI: Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get textSettings414;

  /// Host UI: Extension details
  ///
  /// In en, this message translates to:
  /// **'Extension details'**
  String get textExtensionDetails415;

  /// Host UI: Category  {arg0}
  ///
  /// In en, this message translates to:
  /// **'Category  {arg0}'**
  String textCategoryArg0416(String arg0);

  /// Host UI: Choose an extension from the sidebar to open a tab.
  ///
  /// In en, this message translates to:
  /// **'Choose an extension from the sidebar to open a tab.'**
  String get textChooseAnExtensionFromTheSidebarTo417;

  /// Host UI: Classifies left- and right-hand motor imagery from EEG.
  ///
  /// In en, this message translates to:
  /// **'Classifies left- and right-hand motor imagery from EEG.'**
  String get textClassifiesLeftAndRightHandMotorImagery418;

  /// Host UI: Estimates attention and focus from live signal windows.
  ///
  /// In en, this message translates to:
  /// **'Estimates attention and focus from live signal windows.'**
  String get textEstimatesAttentionAndFocusFromLiveSignal419;

  /// Host UI: Detects common eye-blink and muscle artifacts in EEG.
  ///
  /// In en, this message translates to:
  /// **'Detects common eye-blink and muscle artifacts in EEG.'**
  String get textDetectsCommonEyeBlinkAndMuscleArtifacts420;

  /// Host UI: Select a neural entity
  ///
  /// In en, this message translates to:
  /// **'Select a neural entity'**
  String get textSelectANeuralEntity421;

  /// Host UI: Install
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get textInstall422;

  /// Host UI: ENTITY
  ///
  /// In en, this message translates to:
  /// **'ENTITY'**
  String get textENTITY423;

  /// Host UI: Catalog
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get textCatalog424;

  /// Host UI: No entities yet
  ///
  /// In en, this message translates to:
  /// **'No entities yet'**
  String get textNoEntitiesYet425;

  /// Host UI: Community
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get textCommunity426;

  /// Host UI: Extensions
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get textExtensions427;

  /// Host UI: Modules
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get textModules428;

  /// Host UI: Themes
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get textThemes429;

  /// Host UI: The engine’s neutral, dark-first appearance. A quiet workspace for focused research.
  ///
  /// In en, this message translates to:
  /// **'The engine’s neutral, dark-first appearance. A quiet workspace for focused research.'**
  String get textTheEngineSNeutralDarkFirstAppearance430;

  /// Host UI: Built-in
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get textBuiltIn431;

  /// Host UI: A clean white appearance with the same hierarchy and unified controls.
  ///
  /// In en, this message translates to:
  /// **'A clean white appearance with the same hierarchy and unified controls.'**
  String get textACleanWhiteAppearanceWithTheSame432;

  /// Host UI: Light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get textLight433;

  /// Host UI: All
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get textAll434;

  /// Host UI: All time
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get textAllTime435;

  /// Host UI: Relevance
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get textRelevance436;

  /// Host UI: Grid
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get textGrid437;

  /// Host UI: The catalog could not be loaded. Check your connection and try again.
  ///
  /// In en, this message translates to:
  /// **'The catalog could not be loaded. Check your connection and try again.'**
  String get textTheCatalogCouldNotBeLoadedCheck438;

  /// Host UI: This week
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get textThisWeek439;

  /// Host UI: This month
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get textThisMonth440;

  /// Host UI: Newest
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get textNewest441;

  /// Host UI: Recently updated
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get textRecentlyUpdated442;

  /// Host UI: Most downloaded
  ///
  /// In en, this message translates to:
  /// **'Most downloaded'**
  String get textMostDownloaded443;

  /// Host UI: Most liked
  ///
  /// In en, this message translates to:
  /// **'Most liked'**
  String get textMostLiked444;

  /// Host UI: by {arg0}
  ///
  /// In en, this message translates to:
  /// **'by {arg0}'**
  String textByArg0445(String arg0);

  /// Host UI: License: {arg0}
  ///
  /// In en, this message translates to:
  /// **'License: {arg0}'**
  String textLicenseArg0446(String arg0);

  /// Host UI: Local UI placeholder only. This entry is not published or executable. License labels are examples for filter testing.
  ///
  /// In en, this message translates to:
  /// **'Local UI placeholder only. This entry is not published or executable. License labels are examples for filter testing.'**
  String get textLocalUIPlaceholderOnlyThisEntryIs447;

  /// Host UI: Add this published manifest to the Workspace library. Package download and execution are not enabled until the signed sandbox runtime is available.
  ///
  /// In en, this message translates to:
  /// **'Add this published manifest to the Workspace library. Package download and execution are not enabled until the signed sandbox runtime is available.'**
  String get textAddThisPublishedManifestToTheWorkspace448;

  /// Host UI: Apply theme
  ///
  /// In en, this message translates to:
  /// **'Apply theme'**
  String get textApplyTheme449;

  /// Host UI: Add to Workspace
  ///
  /// In en, this message translates to:
  /// **'Add to Workspace'**
  String get textAddToWorkspace450;

  /// Host UI: Added to Workspace
  ///
  /// In en, this message translates to:
  /// **'Added to Workspace'**
  String get textAddedToWorkspace451;

  /// Host UI: {arg0} is available in Explorer. Package execution is not enabled.
  ///
  /// In en, this message translates to:
  /// **'{arg0} is available in Explorer. Package execution is not enabled.'**
  String textArg0IsAvailableInExplorerPackageExecution452(String arg0);

  /// Host UI: Filters
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get textFilters453;

  /// Host UI: Search {arg0}...
  ///
  /// In en, this message translates to:
  /// **'Search {arg0}...'**
  String textSearchArg0454(String arg0);

  /// Host UI: Clear search
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get textClearSearch455;

  /// Host UI: Sort by
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get textSortBy456;

  /// Host UI: List
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get textList457;

  /// Host UI: Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get textRetry458;

  /// Host UI: No published {arg0} yet
  ///
  /// In en, this message translates to:
  /// **'No published {arg0} yet'**
  String textNoPublishedArg0Yet459(String arg0);

  /// Host UI: No matching items
  ///
  /// In en, this message translates to:
  /// **'No matching items'**
  String get textNoMatchingItems460;

  /// Host UI: Published catalog entries will appear here automatically.
  ///
  /// In en, this message translates to:
  /// **'Published catalog entries will appear here automatically.'**
  String get textPublishedCatalogEntriesWillAppearHereAutomatically461;

  /// Host UI: {arg0}: {arg1}
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1}'**
  String textArg0Arg1462(String arg0, String arg1);

  /// Host UI: Reset filters
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get textResetFilters463;

  /// Host UI: Toggle filters
  ///
  /// In en, this message translates to:
  /// **'Toggle filters'**
  String get textToggleFilters464;

  /// Host UI: Published
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get textPublished465;

  /// Host UI: Availability
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get textAvailability466;

  /// Host UI: Built-in / connected
  ///
  /// In en, this message translates to:
  /// **'Built-in / connected'**
  String get textBuiltInConnected467;

  /// Host UI: In Workspace
  ///
  /// In en, this message translates to:
  /// **'In Workspace'**
  String get textInWorkspace468;

  /// Host UI: Preview entries are local UI placeholders, not published packages.
  ///
  /// In en, this message translates to:
  /// **'Preview entries are local UI placeholders, not published packages.'**
  String get textPreviewEntriesAreLocalUIPlaceholdersNot469;

  /// Host UI: Like {arg0}
  ///
  /// In en, this message translates to:
  /// **'Like {arg0}'**
  String textLikeArg0470(String arg0);

  /// Host UI: Created: {arg0}
  /// Updated: {arg1}
  ///
  /// In en, this message translates to:
  /// **'Created: {arg0}\nUpdated: {arg1}'**
  String textCreatedArg0UpdatedArg1471(String arg0, String arg1);

  /// Host UI: Enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get textEnabled472;

  /// Host UI: Instance label
  ///
  /// In en, this message translates to:
  /// **'Instance label'**
  String get textInstanceLabel473;

  /// Host UI: Proprietary
  ///
  /// In en, this message translates to:
  /// **'Proprietary'**
  String get textProprietary474;

  /// Host UI: Unspecified
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get textUnspecified475;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for the app interface. Changes apply immediately and are saved for the next launch.'**
  String get chooseLanguage;

  /// No description provided for @russianLanguage.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russianLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get recentSessions;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'No device is connected yet — the session will use the built-in signal simulator (256 Hz, 1 channel).'**
  String get simulatorNotice;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Built-in signal generator (256 Hz, 8 channels). Used for development without hardware.'**
  String get deviceSimulatorDescription;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'The first real HAL driver (USB/serial). Requires streaming firmware.'**
  String get deviceBoardDescription;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Core offline: the pipeline initializes when a session starts. Start a test session on the Session screen.'**
  String get pipelineOfflineNotice;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Add a marker with the flag in the toolbar — it will attach to the current signal time.'**
  String get markerInstructions;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'STFT is currently computed in Dart for demonstration. In v0.2 the spectrogram will use native core data (core.diagnostics) with the same UI.'**
  String get spectrogramVersionNotice;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'v0.2: import sessions and external files (EDF/CSV), group by experiments, tag and compare datasets and sessions — all without writing code.'**
  String get datasetsRoadmap;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'v0.2: train models on datasets (batches, spectrogram clusters), integrate trained models as Entities, export/import ONNX through Model Registry & Runtime.'**
  String get modelsRoadmap;

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String logSaved(String path);

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String logSaveFailed(String error);

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Paused — new entries are not loaded ({count})'**
  String logPausedCount(int count);

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'Entries: {visible} / {total} · file: latest.log (refresh 0.4 s)'**
  String logVisibleCount(int visible, int total);

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'{backend} · {seconds} s · {frames} frames · RMS {rms}'**
  String sessionHistoryDetails(
    String backend,
    int seconds,
    int frames,
    String rms,
  );

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'{modules, plural, =0{0 modules} one{1 module} other{{modules} modules}} · {connections, plural, =0{0 connections} one{1 connection} other{{connections} connections}}'**
  String workspaceCounts(int modules, int connections);

  /// Application-owned UI text
  ///
  /// In en, this message translates to:
  /// **'{app} {version} · core {core} (ABI {abi})'**
  String versionLabel(String app, String version, String core, int abi);

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Signal Source'**
  String get previewSignalSource;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Bandpass Filter'**
  String get previewBandpassFilter;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Notch Filter'**
  String get previewNotchFilter;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Channel Mixer'**
  String get previewChannelMixer;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'FFT Analyzer'**
  String get previewFftAnalyzer;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Feature Extractor'**
  String get previewFeatureExtractor;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Artifact Detector'**
  String get previewArtifactDetector;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Signal Viewer'**
  String get previewSignalViewer;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Signal Notes'**
  String get previewSignalNotes;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Session Browser'**
  String get previewSessionBrowser;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Dataset Tools'**
  String get previewDatasetTools;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Research Dashboard'**
  String get previewResearchDashboard;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Acquisition'**
  String get previewAcquisition;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'DSP'**
  String get previewDsp;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get previewRouting;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get previewAnalysis;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'ML'**
  String get previewMl;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Visualization'**
  String get previewVisualization;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get previewNotes;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get previewWorkflow;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get previewData;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewBadge;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Local placeholder for testing the canvas, ports and author UI. No signal processing or package execution.'**
  String get previewDescription;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Local extension placeholder for catalog and rail layout testing. No external code runs.'**
  String get previewExtensionDescription;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Preview {category} module for UI and Drag & Drop testing.'**
  String previewSummary(String category);

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Preview interface — controls store local values only. No executable module is installed.'**
  String get previewNotice;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Preview extension area for layout testing.'**
  String get previewExtensionNotice;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get previewGain;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get previewMode;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get previewStandard;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'Low latency'**
  String get previewLowLatency;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'High precision'**
  String get previewHighPrecision;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'waves'**
  String get shapeWaves;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'contours'**
  String get shapeContours;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'grid'**
  String get shapeGrid;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'module'**
  String get iconModule;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'signal'**
  String get iconSignal;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'brain'**
  String get iconBrain;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'chart'**
  String get iconChart;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'terrain'**
  String get iconTerrain;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'notes'**
  String get iconNotes;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'moon'**
  String get iconMoon;

  /// Local preview fixture or host authoring control
  ///
  /// In en, this message translates to:
  /// **'sun'**
  String get iconSun;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
