// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get workspaceSave => 'Save workspace';

  @override
  String get workspaceSaved => 'Workspace saved';

  @override
  String get workspaceSaveFailed =>
      'Could not save the workspace. Your draft is still available.';

  @override
  String get workspaceUnsavedTitle => 'Save workspace changes?';

  @override
  String get workspaceUnsavedMessage =>
      'Your workspace has unsaved changes. Save them before closing, or discard changes since the last save.';

  @override
  String get workspaceDiscard => 'Don\'t save';

  @override
  String get workspaceUndoNotice => 'Action undone';

  @override
  String get workspaceRedoNotice => 'Action redone';

  @override
  String get railBottomZone => 'Bottom of rail';

  @override
  String get railUnusedItems => 'Unused items';

  @override
  String get railUsedItems => 'On the rail';

  @override
  String get railPinBottom => 'Move to bottom';

  @override
  String get railPinTop => 'Move to top';

  @override
  String get railDragHint =>
      'Drag buttons into the rail to add or reorder them. Drag back here to remove. Click to toggle; Alt + ↑ / ↓ moves a focused button.';

  @override
  String get logicBlocks => 'Logic blocks';

  @override
  String get logicAdd => 'Add logic block';

  @override
  String get logicFilter => 'Filter';

  @override
  String get logicSelectFields => 'Select fields';

  @override
  String get logicValidate => 'Validate input / output';

  @override
  String get logicScript => 'Script';

  @override
  String get logicScriptHelp =>
      'No files, network or loops. Use value.field, has(value, \"field\"), comparisons, and / or / not. Scripts support nested IF / ELSE and emit. select(value, \"field\") keeps only selected fields. Schema uses type, properties, required and additionalProperties.';

  @override
  String get logicTestInput => 'Test input (JSON)';

  @override
  String get logicTest => 'Test without sending to graph';

  @override
  String get logicShow => 'Show logic blocks';

  @override
  String get logicHide => 'Hide logic blocks';

  @override
  String get moduleBlocksShow => 'Show module blocks';

  @override
  String get moduleBlocksHide => 'Hide module blocks';

  @override
  String get moduleDelete => 'Delete module';

  @override
  String get moduleActivate => 'Make active';

  @override
  String get moduleDeactivate => 'Make inactive';

  @override
  String get moduleMoveToWorkspace => 'Move to workspace';

  @override
  String get moduleMoveConnectionsWarning =>
      'Connections to modules left in the source workspace will be removed. Parameters and connections within the moved group will be preserved. Continue?';

  @override
  String get moduleEditorPlaceholder =>
      'Module editing panel placeholder. Editing tools will be added later.';

  @override
  String get moduleCreateLocal => 'Create locally';

  @override
  String get moduleCreateOnline => 'Create online';

  @override
  String get moduleAddLocal => 'Add locally (.qmod)';

  @override
  String get moduleAddOnline => 'Add online';

  @override
  String get localModuleProject => 'Local C++ module project';

  @override
  String get localModuleEditHint =>
      'Edit the C++ source in your project directory, build a new .qmod version and add it locally. See docs/LOCAL_MODULES.md.';

  @override
  String get localModuleTrustTitle => 'Trust this native module?';

  @override
  String get localModuleTrustWarning =>
      'This package contains native C++ code. Each node runs in a separate process, but this is NOT a security sandbox: it has your user\'s access to files, network and devices. Install only code you trust. Adding a node starts its executable.';

  @override
  String get localModuleError => 'Local module operation failed';

  @override
  String get workspacesTitle => 'Workspaces';

  @override
  String get workspaceManager => 'Workspace manager';

  @override
  String get workspaceCreate => 'New workspace';

  @override
  String get workspaceEdit => 'Edit workspace';

  @override
  String get workspaceDelete => 'Delete workspace';

  @override
  String workspaceDeleteConfirm(String name) {
    return 'Delete “$name” and its graph? This does not remove modules from the library.';
  }

  @override
  String get workspaceImport => 'Import workspace';

  @override
  String get workspaceExport => 'Export / share';

  @override
  String get workspaceSubmit => 'Submit to Marketplace';

  @override
  String get workspaceSubmitted =>
      'Workspace submitted for review. It will appear in Marketplace after approval.';

  @override
  String get workspaceReviewNotice =>
      'Sign in with GitHub to submit. Publication requires review; submitting does not immediately publish the workspace.';

  @override
  String get workspaceShareWarning =>
      'The graph includes module parameters and labels. Remove private values, tokens and local paths before sharing. Only share content you have permission to distribute.';

  @override
  String get workspaceContinue => 'Continue';

  @override
  String get workspaceProjectName => 'Workspace name';

  @override
  String get workspaceProjectDescription => 'Description';

  @override
  String get workspaceProjectActions => 'Workspace actions';

  @override
  String workspaceGraphSummary(int nodes, int links) {
    return '$nodes modules · $links connections';
  }

  @override
  String get workspaceDependenciesUnavailable =>
      'Required module versions are unavailable';

  @override
  String get workspaceOperationFailed => 'Workspace operation failed';

  @override
  String get workspaceInstall => 'Install workspace';

  @override
  String get workspaceInstallNotice =>
      'Creates a separate project and resolves available module versions automatically. External package execution requires a signed runtime; nothing is executed during import.';

  @override
  String get workspaceCatalogUnavailable =>
      'Workspace catalog is unavailable. Check your connection and try again. The backend also needs the workspace catalog migration.';

  @override
  String get navigationMenuDown => 'Next menu action';

  @override
  String get navigationMenuUp => 'Previous menu action';

  @override
  String get navigationEditableHint =>
      'Click a combination to change it, then Save or Ctrl+Enter to confirm. Changes are saved and apply to controls and menus. Esc cancels capture; Reset restores defaults.';

  @override
  String get navigationReset => 'Reset shortcuts';

  @override
  String get navigationConflict =>
      'This combination is already used by another navigation action.';

  @override
  String get navigationTitle => 'Navigation';

  @override
  String get navigationDescription =>
      'Navigate without a mouse. Focus borders appear only during keyboard navigation and disappear when you use the mouse. Text fields keep their usual editing shortcuts.';

  @override
  String get navigationFixedBindings =>
      'Navigation bindings are built into the controls and cannot be reassigned here. Fullscreen shortcuts apply inside an active module view.';

  @override
  String get navigationMenus => 'Menus';

  @override
  String get navigationModules => 'Modules and ports';

  @override
  String get navigationKeyUpDown => 'Up / Down';

  @override
  String get navigationKeyRight => 'Right';

  @override
  String get navigationKeyLeft => 'Left';

  @override
  String get navigationNext => 'Focus the next control';

  @override
  String get navigationPrevious => 'Focus the previous control';

  @override
  String get navigationActivate => 'Activate the focused control';

  @override
  String get navigationContext => 'Open a node or port context menu';

  @override
  String get navigationMenuMove => 'Move between menu actions';

  @override
  String get navigationSubmenuOpen => 'Open a submenu';

  @override
  String get navigationSubmenuBack => 'Return from a submenu';

  @override
  String get navigationDismiss =>
      'Close a menu or dialog / return from fullscreen';

  @override
  String get navigationConnect =>
      'Focus and activate each port to connect them';

  @override
  String get navigationFullscreen => 'Toggle the active module fullscreen';

  @override
  String get navigationExitFullscreen => 'Return from module fullscreen';

  @override
  String get workspacePortName => 'Name';

  @override
  String get workspacePortRename => 'Rename port';

  @override
  String get workspacePortNameHint =>
      'Leave empty to restore the original name.';

  @override
  String get workspacePortSave => 'Save';

  @override
  String get workspacePortValue => 'Value type';

  @override
  String get workspacePortColor => 'Color';

  @override
  String get workspacePortAny => 'Any';

  @override
  String get workspacePortString => 'String';

  @override
  String get workspacePortNumber => 'Number';

  @override
  String get workspacePortBoolean => 'Boolean';

  @override
  String get workspacePortList => 'List';

  @override
  String get workspacePortObject => 'Object';

  @override
  String get moduleOpenWindow => 'Open in separate window';

  @override
  String get moduleFullscreen => 'Fullscreen module';

  @override
  String get moduleExitFullscreen => 'Exit fullscreen';

  @override
  String get moduleWindowFailed => 'Could not open the module window.';

  @override
  String get workspaceAppearance => 'APPEARANCE';

  @override
  String get workspaceInstance => 'INSTANCE';

  @override
  String get workspaceParameters => 'PARAMETERS';

  @override
  String get workspacePorts => 'INPUTS / OUTPUTS';

  @override
  String get workspaceInputColor => 'Input highlight';

  @override
  String get workspaceOutputColor => 'Output highlight';

  @override
  String get workspaceSelect => 'Select';

  @override
  String get workspaceSelectAll => 'Select all';

  @override
  String get workspaceDeselect => 'Deselect all';

  @override
  String get workspaceDeleteSelected => 'Delete selected';

  @override
  String get workspaceZoomIn => 'Zoom in';

  @override
  String get workspaceZoomOut => 'Zoom out';

  @override
  String get workspaceActualSize => 'Actual size (100%)';

  @override
  String get workspaceFrameSelection => 'Frame selection';

  @override
  String get workspaceResizeNode => 'Drag to resize module';

  @override
  String get workspaceSelectHint => 'Shift + click to select multiple modules';

  @override
  String get textSupabaseAuthIsUnavailable0 => 'Supabase Auth is unavailable.';

  @override
  String get textSignInWithGitHubBeforeCreatingA1 =>
      'Sign in with GitHub before creating a module.';

  @override
  String get textSignInWithGitHubToManageYour2 =>
      'Sign in with GitHub to manage your modules.';

  @override
  String get textOnlyUnpublishedModuleDraftsCanBeRemoved3 =>
      'Only unpublished module drafts can be removed.';

  @override
  String get textDebug4 => 'Debug';

  @override
  String get textInfo5 => 'Info';

  @override
  String get textWarnings6 => 'Warnings';

  @override
  String get textErrors7 => 'Errors';

  @override
  String get textSearchSourceAndText8 => 'Search source and text…';

  @override
  String get textLEVELS9 => 'LEVELS';

  @override
  String get textTheLatestLogFileHasNotBeen10 =>
      'The latest.log file has not been created yet.';

  @override
  String get textOpenTheApplicationWorkspace11 =>
      'Open the application workspace.';

  @override
  String get textRetry12 => 'Retry';

  @override
  String get textDebugTerminal13 => 'Debug terminal';

  @override
  String get textResume14 => 'Resume';

  @override
  String get textPause15 => 'Pause';

  @override
  String get textAutoScroll16 => 'Auto-scroll';

  @override
  String get textSaveVisibleEntries17 => 'Save visible entries';

  @override
  String get textClearView18 => 'Clear view';

  @override
  String get textCloseWindow19 => 'Close window';

  @override
  String get textSupabaseAuthIsNotInitialized20 =>
      'Supabase Auth is not initialized.';

  @override
  String get textCouldNotOpenTheGitHubSignIn21 =>
      'Could not open the GitHub sign-in page.';

  @override
  String get textUnsupportedWorkspacePresetFormat22 =>
      'Unsupported workspace preset format.';

  @override
  String get textAPresetNeedsANameAndA23 =>
      'A preset needs a name and a list of module IDs.';

  @override
  String get textAPresetSupportsUpTo500Modules24 =>
      'A preset supports up to 500 modules.';

  @override
  String get textAModuleIsMissing25 => 'A module is missing.';

  @override
  String get textAModuleCannotConnectToItself26 =>
      'A module cannot connect to itself.';

  @override
  String get textAPortIsMissing27 => 'A port is missing.';

  @override
  String get textThisConnectionWouldCreateAProcessingCycle28 =>
      'This connection would create a processing cycle.';

  @override
  String get textLibbciEngineCoreWasNotFoundBeside29 =>
      'libbci_engine_core was not found beside the executable';

  @override
  String get textConsumer30 => 'Consumer';

  @override
  String get textResearcher31 => 'Researcher';

  @override
  String get textDeveloper32 => 'Developer';

  @override
  String get textPersonalAndMedicalMode33 => 'Personal and medical mode';

  @override
  String get textDatasetsSpectrogramsExperiments34 =>
      'Datasets, spectrograms, experiments';

  @override
  String get textModulesAPILowLevelAccess35 => 'Modules, API, low-level access';

  @override
  String get textDashboard36 => 'Dashboard';

  @override
  String get textSystemStatus37 => 'System status';

  @override
  String get textDevices38 => 'Devices';

  @override
  String get textHALBoardConnections39 => 'HAL, board connections';

  @override
  String get textSession40 => 'Session';

  @override
  String get textRecordingAndLiveMetrics41 => 'Recording and live metrics';

  @override
  String get textPipeline42 => 'Pipeline';

  @override
  String get textSignalProcessingModuleChain43 =>
      'Signal-processing module chain';

  @override
  String get textSpectrogram44 => 'Spectrogram';

  @override
  String get textRealTimeVisualization45 => 'Real-time visualization';

  @override
  String get textModuleProcessingCanvas46 => 'Module processing canvas';

  @override
  String get textEntity47 => 'Entity';

  @override
  String get textNeuralNetworkEntities48 => 'Neural network entities';

  @override
  String get textDatasets49 => 'Datasets';

  @override
  String get textImportAndComparison50 => 'Import and comparison';

  @override
  String get textModels51 => 'Models';

  @override
  String get textTrainingAndModelRegistry52 => 'Training and model registry';

  @override
  String get textCoreFFIConsole53 => 'Core FFI console';

  @override
  String get textMarketplace54 => 'Marketplace';

  @override
  String get textCommunityExtensions55 => 'Community extensions';

  @override
  String get textBugReport56 => 'Bug report';

  @override
  String get textReportAProblem57 => 'Report a problem';

  @override
  String get textSettings58 => 'Settings';

  @override
  String get textModesBuildLicenses59 => 'Modes, build, licenses';

  @override
  String get textFile60 => 'File';

  @override
  String get textEdit61 => 'Edit';

  @override
  String get textView62 => 'View';

  @override
  String get textHelp63 => 'Help';

  @override
  String get textCoreSessionActive64 => 'Core: session active';

  @override
  String get textCoreOnline65 => 'Core: online';

  @override
  String get textCoreOffline66 => 'Core: offline';

  @override
  String get textUsageMode67 => 'Usage mode';

  @override
  String get textGeneral68 => 'General';

  @override
  String get textPresetNotImported69 => 'Preset not imported';

  @override
  String get textPresetCatalogUnavailable70 => 'Preset catalog unavailable';

  @override
  String textArg0ThePresetRemainsLoaded71(String arg0) {
    return '$arg0. The preset remains loaded.';
  }

  @override
  String get textMissingWorkspaceModules72 => 'Missing workspace modules';

  @override
  String textArg0Arg1ThePresetIsSavedFind73(String arg0, String arg1) {
    return '$arg0: $arg1. The preset is saved; find the missing modules in Marketplace.';
  }

  @override
  String textMissingModulesArg074(String arg0) {
    return 'Missing modules: $arg0';
  }

  @override
  String get textProfile75 => 'Profile';

  @override
  String get textNewTab76 => 'New tab';

  @override
  String get textPreviewModule77 => 'Preview module';

  @override
  String get textDragThisPlaceholderToTheCanvasTo78 =>
      'Drag this placeholder to the canvas to change instance parameters. It is not a publishable draft.';

  @override
  String get textSignInRequired79 => 'Sign in required';

  @override
  String get textModuleNotSaved80 => 'Module not saved';

  @override
  String get textModuleAdded81 => 'Module added';

  @override
  String get textModuleUpdated82 => 'Module updated';

  @override
  String textArg0IsNowAvailableInWorkspace83(String arg0) {
    return '$arg0 is now available in Workspace.';
  }

  @override
  String get textModulesUnavailable84 => 'Modules unavailable';

  @override
  String get textCouldNotLoadModulesFromYourAccount85 =>
      'Could not load modules from your account.';

  @override
  String get textEntityAdded86 => 'Entity added';

  @override
  String get textEntityUpdated87 => 'Entity updated';

  @override
  String textArg0IsNowAvailableInEntity88(String arg0) {
    return '$arg0 is now available in Entity.';
  }

  @override
  String get textEntityRemoved89 => 'Entity removed';

  @override
  String textArg0WasRemovedFromEntity90(String arg0) {
    return '$arg0 was removed from Entity.';
  }

  @override
  String get textEntityUninstalled91 => 'Entity uninstalled';

  @override
  String get textEntityInstalled92 => 'Entity installed';

  @override
  String get textThesePlaceholdersBelongToTheLocalUI93 =>
      'These placeholders belong to the local UI playground. Canvas instances can be deleted with right-click → Delete.';

  @override
  String get textModuleNotRemoved94 => 'Module not removed';

  @override
  String get textDocumentation95 => 'Documentation';

  @override
  String get textLearnHowToConfigureWorkspacesDevicesSessions96 =>
      'Learn how to configure workspaces, devices, sessions and modules in Qualia Engine.';

  @override
  String get textAboutUs97 => 'About Us';

  @override
  String textArg0VersionArg1BuiltByArg2For98(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0\nVersion $arg1\n\nBuilt by $arg2 for focused brain-computer interface workflows.';
  }

  @override
  String get textWelcomeToQualiaEngine99 => 'Welcome to Qualia Engine';

  @override
  String get textQualiaEngineIsADesktopWorkspaceFor100 =>
      'Qualia Engine is a desktop workspace for exploring BCI data, sessions and modular signal-processing pipelines.';

  @override
  String get textTutorials101 => 'Tutorials';

  @override
  String get textStartWithTheDashboardConnectADevice102 =>
      'Start with the Dashboard, connect a device, create a session and open Modules to build your processing workflow.';

  @override
  String get textLicense103 => 'License';

  @override
  String get textQualiaEngineIsDistributedUnderTheProject104 =>
      'Qualia Engine is distributed under the project license. See the repository license file for the complete terms.';

  @override
  String get textCheckUpdates105 => 'Check updates';

  @override
  String textYouAreRunningQualiaEngineArg0Update106(String arg0) {
    return 'You are running Qualia Engine $arg0. Update checking will be connected to the release channel in a future build.';
  }

  @override
  String get textOurYoutube107 => 'Our Youtube';

  @override
  String get textVideoTutorialsAndProjectUpdatesWillBe108 =>
      'Video tutorials and project updates will be available on the Qualia Engine YouTube channel.';

  @override
  String get textThisHelpActionIsNotAvailableYet109 =>
      'This help action is not available yet.';

  @override
  String get textClose110 => 'Close';

  @override
  String get textBuild111 => 'Build';

  @override
  String get textInterfaceScaleCtrlCtrl112 =>
      'Interface scale (Ctrl + / Ctrl -)';

  @override
  String get textNotifications113 => 'Notifications';

  @override
  String get textJustNow114 => 'Just now';

  @override
  String textArg0MinAgo115(String arg0) {
    return '$arg0 min ago';
  }

  @override
  String textArg0HAgo116(String arg0) {
    return '$arg0 h ago';
  }

  @override
  String textArg0DAgo117(String arg0) {
    return '$arg0 d ago';
  }

  @override
  String get textMarkAllAsRead118 => 'Mark all as read';

  @override
  String get textNoNotifications119 => 'No notifications';

  @override
  String get textOpenDebugTerminal120 => 'Open debug terminal';

  @override
  String get textMinimizeWindow121 => 'Minimize window';

  @override
  String get textRestoreWindow122 => 'Restore window';

  @override
  String get textMaximizeWindow123 => 'Maximize window';

  @override
  String get textAddWorkspacePreset124 => 'Add Workspace Preset';

  @override
  String get textNewWorkspace125 => 'New workspace';

  @override
  String get textOpenProject126 => 'Open project';

  @override
  String get textImportModuleSoon127 => 'Import module (soon)';

  @override
  String get textPreferences128 => 'Preferences';

  @override
  String get textRailSettings129 => 'Rail settings';

  @override
  String get textUndo130 => 'Undo';

  @override
  String get textRedo131 => 'Redo';

  @override
  String get textPreferencesSoon132 => 'Preferences (soon)';

  @override
  String get textExplorer133 => 'Explorer';

  @override
  String get textTerminal134 => 'Terminal';

  @override
  String get textCustomizeLayoutSoon135 => 'Customize layout (soon)';

  @override
  String get textTheme136 => 'Theme';

  @override
  String get textSystem137 => 'System';

  @override
  String get textDark138 => 'Dark';

  @override
  String get textWhite139 => 'White';

  @override
  String get textWelcome140 => 'Welcome';

  @override
  String get textReportIssue141 => 'Report Issue';

  @override
  String get textBuildProject142 => 'Build project';

  @override
  String get textRunSession143 => 'Run session';

  @override
  String get textBuildTasksSoon144 => 'Build tasks (soon)';

  @override
  String textArg0Menu145(String arg0) {
    return '$arg0 menu';
  }

  @override
  String get textQUICKACTIONS146 => 'QUICK ACTIONS';

  @override
  String get textFindModule147 => 'Find module';

  @override
  String get textKEYBOARDSHORTCUTS148 => 'KEYBOARD SHORTCUTS';

  @override
  String get textIncreaseInterfaceScale149 => 'Increase interface scale';

  @override
  String get textDecreaseInterfaceScale150 => 'Decrease interface scale';

  @override
  String get textShortcuts151 => 'Shortcuts';

  @override
  String get textSearchFilesSymbolsCtrlP152 =>
      'Search files, symbols...  (Ctrl+P)';

  @override
  String get textUserProfileButton153 => 'User profile button';

  @override
  String get textBugReport154 => 'bug report';

  @override
  String get textUserDevSwitcher155 => 'user&dev switcher';

  @override
  String get textConfigs156 => 'configs';

  @override
  String get textEXPLORER157 => 'EXPLORER';

  @override
  String get textAddModule158 => 'Add module';

  @override
  String get textRemoveModule159 => 'Remove module';

  @override
  String get textEditModule160 => 'Edit module';

  @override
  String get textAddEntity161 => 'Add entity';

  @override
  String get textRemoveEntity162 => 'Remove entity';

  @override
  String get textEditEntity163 => 'Edit entity';

  @override
  String get textWORKSPACEPRESETS164 => 'WORKSPACE PRESETS';

  @override
  String get textImportWorkspacePreset165 => 'Import Workspace Preset';

  @override
  String textExportArg0166(String arg0) {
    return 'Export $arg0';
  }

  @override
  String textMissingArg0167(String arg0) {
    return 'Missing: $arg0';
  }

  @override
  String get textACTIVEMODULES168 => 'ACTIVE MODULES';

  @override
  String get textSearchActiveModules169 => 'Search active modules...';

  @override
  String get textNoActiveModulesFound170 => 'No active modules found';

  @override
  String get textMODULECATALOG171 => 'MODULE CATALOG';

  @override
  String get textSearchModules172 => 'Search modules...';

  @override
  String get textNoModulesFound173 => 'No modules found';

  @override
  String get textINSTALLEDENTITIES174 => 'INSTALLED ENTITIES';

  @override
  String get textENTITYCATALOG175 => 'ENTITY CATALOG';

  @override
  String get textInstalled176 => 'Installed';

  @override
  String get textRecommended177 => 'Recommended';

  @override
  String get textNoActiveWorkspaceItems178 => 'No active workspace items';

  @override
  String get textClearModuleSearch179 => 'Clear module search';

  @override
  String get textCreateNewTab180 => 'Create new tab';

  @override
  String get textHideExplorer181 => 'Hide Explorer';

  @override
  String get textShowExplorer182 => 'Show Explorer';

  @override
  String get textCloseTab183 => 'Close tab';

  @override
  String get textNoOpenTabs184 => 'No open tabs';

  @override
  String get textCreateANewTabToContinue185 => 'Create a new tab to continue';

  @override
  String get textNewModule186 => 'New module';

  @override
  String get textCustomModuleDescription187 => 'Custom module description.';

  @override
  String get textID188 => 'ID';

  @override
  String get textName189 => 'Name';

  @override
  String get textCategory190 => 'Category';

  @override
  String get textDescription191 => 'Description';

  @override
  String get textMarketplaceCover192 => 'Marketplace cover';

  @override
  String get textYourImageURLHTTPSOptional193 =>
      'Your image URL (HTTPS, optional)';

  @override
  String get textBackgroundContour194 => 'Background contour';

  @override
  String get textCenterIcon195 => 'Center icon';

  @override
  String get textDeclarativeManifestUISchemaJSON196 =>
      'Declarative manifest / UI schema (JSON)';

  @override
  String get textCoverAndUIMetadataAreSavedLocally197 =>
      'Cover and UI metadata are saved locally for drafts. Published releases supply the manifest to Marketplace.';

  @override
  String get textCancel198 => 'Cancel';

  @override
  String textArg0MustBeAnArray199(String arg0) {
    return '$arg0 must be an array';
  }

  @override
  String get textCoverImageMustUseHTTPS200 => 'Cover image must use HTTPS';

  @override
  String textInvalidSchemaArg0201(String arg0) {
    return 'Invalid schema: $arg0';
  }

  @override
  String get textCustom202 => 'Custom';

  @override
  String get textSave203 => 'Save';

  @override
  String get textNewNeuralEntity204 => 'New neural entity';

  @override
  String get textNeuralNetworkDescription205 => 'Neural network description.';

  @override
  String get textFramework206 => 'Framework';

  @override
  String get textVersion207 => 'Version';

  @override
  String get textUnknown208 => 'Unknown';

  @override
  String get textExtensionSettings209 => 'Extension settings';

  @override
  String get textDisableEnable210 => 'Disable/enable';

  @override
  String get textAutoupdate211 => 'Autoupdate';

  @override
  String get textUninstall212 => 'Uninstall';

  @override
  String get textCopyLink213 => 'Copy link';

  @override
  String get textCopyName214 => 'Copy name';

  @override
  String get textKeyboard215 => 'Keyboard';

  @override
  String get textProfilesOperate216 => 'Profiles operate';

  @override
  String get textExtensionChanged217 => 'Extension changed';

  @override
  String textArg0Arg1Selected218(String arg0, String arg1) {
    return '$arg0: $arg1 selected.';
  }

  @override
  String get textTERMINAL219 => 'TERMINAL';

  @override
  String get textOUTPUT220 => 'OUTPUT';

  @override
  String get textCloseRailSettings221 => 'Close rail settings';

  @override
  String get textVisibility222 => 'Visibility';

  @override
  String get textShowRail223 => 'Show rail';

  @override
  String get textWhenHiddenContentUsesTheFullWidth224 =>
      'When hidden, content uses the full width.\nRestore it with Edit → Rail settings.';

  @override
  String get textSections225 => 'Sections';

  @override
  String get textExtensionSections226 => 'Extension sections';

  @override
  String get textAddAnExtensionFromTheCatalogTo227 =>
      'Add an extension from the catalog to configure its rail entry here.';

  @override
  String get textChangesAreSavedAutomatically228 =>
      'Changes are saved automatically';

  @override
  String get textDone229 => 'Done';

  @override
  String textArg0Arg1230(String arg0, String arg1) {
    return '$arg0 $arg1';
  }

  @override
  String get textHide231 => 'Hide';

  @override
  String get textShow232 => 'Show';

  @override
  String get textBack233 => 'Back';

  @override
  String get textExtensionContextMenu234 => 'Extension context menu';

  @override
  String get textEngineStatusAndQuickStart235 =>
      'Engine status and quick start';

  @override
  String get textInterfaceUpdatedWorkspaceReady236 =>
      'Interface updated · workspace ready';

  @override
  String get textConfigure237 => 'Configure';

  @override
  String get textCoreCFFI238 => 'Core (C++ / FFI)';

  @override
  String get textOnline239 => 'online';

  @override
  String get textOffline240 => 'offline';

  @override
  String get textCoreVersion241 => 'Core version';

  @override
  String textArg0ExpectedArg1242(String arg0, String arg1) {
    return '$arg0 (expected $arg1)';
  }

  @override
  String get textLibrary243 => 'Library';

  @override
  String get textNotFound244 => 'not found';

  @override
  String get textModulesInPipeline245 => 'Modules in pipeline';

  @override
  String get textError246 => 'Error';

  @override
  String get textQuickStart247 => 'Quick start';

  @override
  String get textStartATestSession248 => 'Start a test session';

  @override
  String get textSpectrogramDemo249 => 'Spectrogram (demo)';

  @override
  String get textModuleRegistry250 => 'Module registry';

  @override
  String get text2409Test251 => '24.09 · test';

  @override
  String get textSimulator0032Quality086252 =>
      'Simulator · 00:32 · quality 0.86';

  @override
  String get text2309Calibration253 => '23.09 · calibration';

  @override
  String get textSimulator0312Complete254 => 'Simulator · 03:12 · complete';

  @override
  String get text2209Sleep255 => '22.09 · sleep';

  @override
  String get textSimulator0105Quality071256 =>
      'Simulator · 01:05 · quality 0.71';

  @override
  String get textSessionStorageWillBeImplementedInStorage257 =>
      'Session storage will be implemented in Storage Service (v0.2).';

  @override
  String get textEEGSimulator258 => 'EEG simulator';

  @override
  String get textADS1299CompatibleBoard259 => 'ADS1299-compatible board';

  @override
  String get textLSLSource260 => 'LSL source';

  @override
  String get textConnectToAnyLabStreamingLayerStream261 =>
      'Connect to any Lab Streaming Layer stream on the network.';

  @override
  String get textHardwareAbstractionLayerV01VirtualSources262 =>
      'Hardware Abstraction Layer · v0.1 — virtual sources';

  @override
  String get textHALRoadmapV02263 => 'HAL roadmap (v0.2)';

  @override
  String get textNormalization264 => 'Normalization';

  @override
  String get textRawSignalVBoardScale265 => 'raw signal → μV, board scale';

  @override
  String get textImpedance266 => 'Impedance';

  @override
  String get textContactCalibrationProcedure267 =>
      'contact calibration procedure';

  @override
  String get textHotPlug268 => 'Hot-plug';

  @override
  String get textConnectionDisconnectionDetection269 =>
      'connection/disconnection detection';

  @override
  String get textRateChannels270 => 'Rate/channels';

  @override
  String get textBoardConfigurationManagement271 =>
      'board configuration management';

  @override
  String textCouldNotStartTheCoreCodeArg0272(String arg0) {
    return 'Could not start the core (code $arg0)';
  }

  @override
  String get textStreamingThroughTheCCorePushPipeline273 =>
      'Streaming through the C++ core (push → pipeline → pop)';

  @override
  String get textCoreOfflineLocalDartSimulation274 =>
      'Core offline — local Dart simulation';

  @override
  String get textSessionRunning275 => 'Session running';

  @override
  String get textTestSession276 => 'Test session';

  @override
  String get textThroughCore277 => 'through core';

  @override
  String get textDartSimulation278 => 'Dart simulation';

  @override
  String get textTime279 => 'Time';

  @override
  String get textFrames280 => 'Frames';

  @override
  String get textPeakHz281 => 'Peak, Hz';

  @override
  String get textQuality282 => 'Quality';

  @override
  String get textStart283 => 'Start';

  @override
  String get textStop284 => 'Stop';

  @override
  String textSimulator256Hz1ChannelBlockOf285(String arg0) {
    return 'Simulator 256 Hz · 1 channel · block of $arg0 frames';
  }

  @override
  String get textSessionHistoryInMemoryV01286 =>
      'Session history (in memory, v0.1)';

  @override
  String get textNoSessionsYetStartASession287 =>
      'No sessions yet — start a session.';

  @override
  String get textCore288 => 'core';

  @override
  String get textDeviceRawBufferPreprocessingFeaturesOutput289 =>
      'Device → Raw Buffer → Preprocessing → Features → Output';

  @override
  String get textActiveCorePipeline290 => 'Active core pipeline';

  @override
  String get textUnavailable291 => 'unavailable';

  @override
  String textArg0Modules292(String arg0) {
    return '$arg0 modules';
  }

  @override
  String get textModulesRetrievedFromTheCoreViaBci293 =>
      'Modules retrieved from the core via bci_engine_module_json():';

  @override
  String get textAdd294 => 'Add';

  @override
  String get textReplaceModule295 => 'Replace module';

  @override
  String get textDelete296 => 'Delete';

  @override
  String get textConnectAnOutputToAnInput297 =>
      'Connect an output to an input.';

  @override
  String textArg0ModulesArg1Connections298(String arg0, String arg1) {
    return '$arg0 modules · $arg1 connections';
  }

  @override
  String get workspaceHideSidebar => 'Hide right sidebar';

  @override
  String get workspaceShowSidebar => 'Show right sidebar';

  @override
  String get workspaceColorNone => 'No color';

  @override
  String get workspaceColorRed => 'Red';

  @override
  String get workspaceColorOrange => 'Orange';

  @override
  String get workspaceColorYellow => 'Yellow';

  @override
  String get workspaceColorGreen => 'Green';

  @override
  String get workspaceColorBlue => 'Blue';

  @override
  String get workspaceColorPurple => 'Purple';

  @override
  String get workspaceHeaderColor => 'Module color';

  @override
  String get workspaceSelectSameColor => 'Select modules with this color';

  @override
  String get workspaceSelectByColor => 'Select by color';

  @override
  String get workspaceColorSelected => 'Color selected';

  @override
  String get workspaceFilterByColor => 'Filter by color';

  @override
  String get workspaceAllColors => 'All colors';

  @override
  String get workspaceNoSearchResults => 'No matching modules';

  @override
  String get textAddModuleToCanvas299 => 'Add module to canvas';

  @override
  String get textFrameAllF300 => 'Frame all (F)';

  @override
  String get textModuleSettings301 => 'Module settings';

  @override
  String get textBuildYourWorkspace302 => 'Build your workspace';

  @override
  String get textDragAModuleFromExplorerOrRight303 =>
      'Drag a module from Explorer or right-click → Add';

  @override
  String get textReturnToModules304 => 'Return to modules';

  @override
  String get textMMBDragToPanWheelToZoom305 =>
      'MMB / drag to pan · wheel to zoom · F to frame';

  @override
  String get textSelectAnOppositePortEscToCancel306 =>
      'Select an opposite port · Esc to cancel';

  @override
  String get textInput307 => '+ Input';

  @override
  String get textOutput308 => '+ Output';

  @override
  String get textOpen309 => 'Open';

  @override
  String get textMODULESETTINGS310 => 'MODULE SETTINGS';

  @override
  String get textCloseModuleSettings311 => 'Close module settings';

  @override
  String get textSelectAModuleOnTheCanvas312 =>
      'Select a module on the canvas.';

  @override
  String get textNoAdditionalSettingsHaveBeenDeclaredBy313 =>
      'No additional settings have been declared by the author.';

  @override
  String get textConnections314 => 'Connections';

  @override
  String get textDisconnectPorts315 => 'Disconnect ports';

  @override
  String get textNoConnections316 => 'No connections';

  @override
  String get textSearchAvailableModules317 => 'Search available modules...';

  @override
  String get textNoAvailableModulesAddADraftOr318 =>
      'No available modules.\nAdd a draft or find modules in Marketplace.';

  @override
  String get textModuleInterface319 => 'Module interface';

  @override
  String get textThisModuleHasNotDeclaredAnActive320 =>
      'This module has not declared an active-area UI schema yet. Its graph ports and host settings remain available in Workspace.';

  @override
  String textModuleIDArg0321(String arg0) {
    return 'Module ID: $arg0';
  }

  @override
  String get textGraphEditingIsAvailableExecutingExternalPackages322 =>
      'Graph editing is available. Executing external packages requires the signed sandbox runtime.';

  @override
  String get textWorkspacePreset323 => 'Workspace preset';

  @override
  String get textPresetFileIsTooLarge324 => 'Preset file is too large.';

  @override
  String get textPresetName325 => 'Preset name';

  @override
  String get textAdditionalMarketplaceModuleIDs326 =>
      'Additional Marketplace module IDs';

  @override
  String get textOneIDPerLineOrSeparatedBy327 =>
      'One ID per line or separated by commas';

  @override
  String get textYouCanCreateAnEmptyPresetOr328 =>
      'You can create an empty preset or list Marketplace module IDs above.';

  @override
  String get textSTFT256Hop32Simulator256Hz329 =>
      'STFT 256 / hop 32 · simulator 256 Hz · event markers';

  @override
  String get textAddMarker330 => 'Add marker';

  @override
  String get textClear331 => 'Clear';

  @override
  String get text0Hz332 => '0 Hz';

  @override
  String get text127Hz333 => '~127 Hz';

  @override
  String get textMarkers334 => 'Markers';

  @override
  String textSecArg0335(String arg0) {
    return 'sec ≈ $arg0';
  }

  @override
  String get textParameters336 => 'Parameters';

  @override
  String textSensitivityArg0337(String arg0) {
    return 'Sensitivity ×$arg0';
  }

  @override
  String get textAboutVersions338 => 'About versions';

  @override
  String get textCoreNotLoaded339 => 'core not loaded';

  @override
  String get textEngineCreated340 => 'engine created';

  @override
  String get textCreateFailed341 => 'create failed';

  @override
  String get textEngineStarted256Hz1342 => 'engine started (256 Hz × 1)';

  @override
  String textStartCodeArg0343(String arg0) {
    return 'start → code $arg0';
  }

  @override
  String get textNoCore344 => 'no core';

  @override
  String textStopCodeArg0345(String arg0) {
    return 'stop → code $arg0';
  }

  @override
  String get textEngineNotCreated346 => 'engine not created';

  @override
  String textStartCodeArg0347(String arg0) {
    return 'start → code $arg0';
  }

  @override
  String get textModulesUnavailableARunningEngineIsRequired348 =>
      'modules unavailable (a running engine is required)';

  @override
  String get textCoreFFIConsoleBciEngineCAPI349 =>
      'Core FFI console · bci_engine_* C API';

  @override
  String get textCreateEngine350 => 'Create engine';

  @override
  String get textEchoTest351 => 'Echo test';

  @override
  String get textModulesJSON352 => 'Modules (JSON)';

  @override
  String textLibraryArg0353(String arg0) {
    return 'Library: $arg0';
  }

  @override
  String get textCoreLibraryNotFoundBuildTheCore354 =>
      'Core library not found — build the core (scripts/build.sh).';

  @override
  String get textResetInterfaceScale355 => 'Reset interface scale';

  @override
  String get textWORKSPACE356 => 'WORKSPACE';

  @override
  String get textINTERFACE357 => 'INTERFACE';

  @override
  String get textKeyboardShortcuts358 => 'Keyboard shortcuts';

  @override
  String get textEditShortcuts359 => 'Edit shortcuts';

  @override
  String get textPressKeys360 => 'Press keys';

  @override
  String get textImport361 => 'Import';

  @override
  String get textAppearance362 => 'Appearance';

  @override
  String get textVoice363 => 'Voice';

  @override
  String get textConfiguration364 => 'Configuration';

  @override
  String get textPersonalization365 => 'Personalization';

  @override
  String get textAccount366 => 'Account';

  @override
  String get textSearch367 => 'Search';

  @override
  String get textPersonal368 => 'Personal';

  @override
  String get textArchived369 => 'Archived';

  @override
  String get textBackToApp370 => 'Back to app';

  @override
  String get textPermissions371 => 'Permissions';

  @override
  String get textDefaultPermissions372 => 'Default permissions';

  @override
  String get textByDefaultAyakiroCanReadAndEdit373 =>
      'By default, Ayakiro can read and edit files in its workspace. It can ask for additional access when needed';

  @override
  String get textFullAccess374 => 'Full access';

  @override
  String get textWhenAyakiroRunsWithFullAccessIt375 =>
      'When Ayakiro runs with full access, it can edit any file on your computer and run commands with network, without your approval. This significantly increases the risk of data loss, leaks, or unexpected behavior.';

  @override
  String get textLearnMoreAboutElevatedRisks376 =>
      'Learn more about elevated risks.';

  @override
  String get textProjectlessTaskFolder377 => 'Projectless task folder';

  @override
  String get textTheLocationWhereTasksStartedOutsideOf378 =>
      'The location where tasks started outside of projects store their data by default.';

  @override
  String get textChange379 => 'Change';

  @override
  String get textDefaultFileOpenDestination380 =>
      'Default file open destination';

  @override
  String get textWhereFilesAndFoldersOpenByDefault381 =>
      'Where files and folders open by default';

  @override
  String get textLanguage382 => 'Language';

  @override
  String get textLanguageForTheAppUI383 => 'Language for the app UI';

  @override
  String get textAutoDetect384 => 'Auto detect';

  @override
  String get textBottomPanel385 => 'Bottom panel';

  @override
  String get textShowTheBottomPanelControlInThe386 =>
      'Show the bottom panel control in the app header';

  @override
  String get textPreventSleepWhileRunning387 => 'Prevent sleep while running';

  @override
  String get textKeepYourComputerAwakeWhileAyakiroIs388 =>
      'Keep your computer awake while Ayakiro is running a task';

  @override
  String get textOpenSourceLicenses389 => 'Open source licenses';

  @override
  String get textThirdPartySoftwareUsedByAyakiroBCI390 =>
      'Third-party software used by Ayakiro BCI Engine';

  @override
  String get textCurrentApplicationBuild391 => 'Current application build';

  @override
  String textArg0LocalOfflineFirstMode392(String arg0) {
    return '$arg0 · local offline-first mode';
  }

  @override
  String get textImportCreationAndComparisonOfRecordings393 =>
      'Import, creation and comparison of recordings';

  @override
  String get textYourDatasetsWillAppearHere394 =>
      'Your datasets will appear here';

  @override
  String get textNoCodeTrainingAndModelRegistry395 =>
      'No-code training and model registry';

  @override
  String get textTheModelRegistryIsEmpty396 => 'The model registry is empty';

  @override
  String get textSignInWithGitHub397 => 'Sign in with GitHub';

  @override
  String get textGitHubSignInIsIncompleteReturnTo398 =>
      'GitHub sign-in is incomplete. Return to the app after authorization.';

  @override
  String get textCouldNotCompleteTheActionCheckYour399 =>
      'Could not complete the action. Check your connection and OAuth settings.';

  @override
  String get textLogInWith400 => 'Log in with:';

  @override
  String get textConnectingToGitHub401 => 'Connecting to GitHub…';

  @override
  String get textSigningOut402 => 'Signing out…';

  @override
  String get textSignOut403 => 'Sign out';

  @override
  String get textFiltersAndSignalInspectionHelpersForLive404 =>
      'Filters and signal inspection helpers for live sessions.';

  @override
  String get textAddStructuredNotesAndMarkersWhileRecording405 =>
      'Add structured notes and markers while recording a session.';

  @override
  String get textACompactDashboardForCustomBCIMetrics406 =>
      'A compact dashboard for custom BCI metrics and signals.';

  @override
  String get textExportRecordingsAndDerivedDataToCommon407 =>
      'Export recordings and derived data to common formats.';

  @override
  String textArg0Arg1Selected408(String arg0, String arg1) {
    return '$arg0: $arg1 selected.';
  }

  @override
  String get textEXTENSIONINSPECTOR409 => 'EXTENSION INSPECTOR';

  @override
  String get textSelectAnExtension410 => 'Select an extension';

  @override
  String textCategoryArg0411(String arg0) {
    return 'Category  $arg0';
  }

  @override
  String get textDisable412 => 'Disable';

  @override
  String get textEnable413 => 'Enable';

  @override
  String get textSettings414 => 'Settings';

  @override
  String get textExtensionDetails415 => 'Extension details';

  @override
  String textCategoryArg0416(String arg0) {
    return 'Category  $arg0';
  }

  @override
  String get textChooseAnExtensionFromTheSidebarTo417 =>
      'Choose an extension from the sidebar to open a tab.';

  @override
  String get textClassifiesLeftAndRightHandMotorImagery418 =>
      'Classifies left- and right-hand motor imagery from EEG.';

  @override
  String get textEstimatesAttentionAndFocusFromLiveSignal419 =>
      'Estimates attention and focus from live signal windows.';

  @override
  String get textDetectsCommonEyeBlinkAndMuscleArtifacts420 =>
      'Detects common eye-blink and muscle artifacts in EEG.';

  @override
  String get textSelectANeuralEntity421 => 'Select a neural entity';

  @override
  String get textInstall422 => 'Install';

  @override
  String get textENTITY423 => 'ENTITY';

  @override
  String get textCatalog424 => 'Catalog';

  @override
  String get textNoEntitiesYet425 => 'No entities yet';

  @override
  String get textCommunity426 => 'Community';

  @override
  String get textExtensions427 => 'Extensions';

  @override
  String get textModules428 => 'Modules';

  @override
  String get textThemes429 => 'Themes';

  @override
  String get textTheEngineSNeutralDarkFirstAppearance430 =>
      'The engine’s neutral, dark-first appearance. A quiet workspace for focused research.';

  @override
  String get textBuiltIn431 => 'Built-in';

  @override
  String get textACleanWhiteAppearanceWithTheSame432 =>
      'A clean white appearance with the same hierarchy and unified controls.';

  @override
  String get textLight433 => 'Light';

  @override
  String get textAll434 => 'All';

  @override
  String get textAllTime435 => 'All time';

  @override
  String get textRelevance436 => 'Relevance';

  @override
  String get textGrid437 => 'Grid';

  @override
  String get textTheCatalogCouldNotBeLoadedCheck438 =>
      'The catalog could not be loaded. Check your connection and try again.';

  @override
  String get textThisWeek439 => 'This week';

  @override
  String get textThisMonth440 => 'This month';

  @override
  String get textNewest441 => 'Newest';

  @override
  String get textRecentlyUpdated442 => 'Recently updated';

  @override
  String get textMostDownloaded443 => 'Most downloaded';

  @override
  String get textMostLiked444 => 'Most liked';

  @override
  String textByArg0445(String arg0) {
    return 'by $arg0';
  }

  @override
  String textLicenseArg0446(String arg0) {
    return 'License: $arg0';
  }

  @override
  String get textLocalUIPlaceholderOnlyThisEntryIs447 =>
      'Local UI placeholder only. This entry is not published or executable. License labels are examples for filter testing.';

  @override
  String get textAddThisPublishedManifestToTheWorkspace448 =>
      'Add this published manifest to the Workspace library. Package download and execution are not enabled until the signed sandbox runtime is available.';

  @override
  String get textApplyTheme449 => 'Apply theme';

  @override
  String get textAddToWorkspace450 => 'Add to Workspace';

  @override
  String get textAddedToWorkspace451 => 'Added to Workspace';

  @override
  String textArg0IsAvailableInExplorerPackageExecution452(String arg0) {
    return '$arg0 is available in Explorer. Package execution is not enabled.';
  }

  @override
  String get textFilters453 => 'Filters';

  @override
  String textSearchArg0454(String arg0) {
    return 'Search $arg0...';
  }

  @override
  String get textClearSearch455 => 'Clear search';

  @override
  String get textSortBy456 => 'Sort by';

  @override
  String get textList457 => 'List';

  @override
  String get textRetry458 => 'Retry';

  @override
  String textNoPublishedArg0Yet459(String arg0) {
    return 'No published $arg0 yet';
  }

  @override
  String get textNoMatchingItems460 => 'No matching items';

  @override
  String get textPublishedCatalogEntriesWillAppearHereAutomatically461 =>
      'Published catalog entries will appear here automatically.';

  @override
  String textArg0Arg1462(String arg0, String arg1) {
    return '$arg0: $arg1';
  }

  @override
  String get textResetFilters463 => 'Reset filters';

  @override
  String get textToggleFilters464 => 'Toggle filters';

  @override
  String get textPublished465 => 'Published';

  @override
  String get textAvailability466 => 'Availability';

  @override
  String get textBuiltInConnected467 => 'Built-in / connected';

  @override
  String get textInWorkspace468 => 'In Workspace';

  @override
  String get textPreviewEntriesAreLocalUIPlaceholdersNot469 =>
      'Preview entries are local UI placeholders, not published packages.';

  @override
  String textLikeArg0470(String arg0) {
    return 'Like $arg0';
  }

  @override
  String textCreatedArg0UpdatedArg1471(String arg0, String arg1) {
    return 'Created: $arg0\nUpdated: $arg1';
  }

  @override
  String get textEnabled472 => 'Enabled';

  @override
  String get textInstanceLabel473 => 'Instance label';

  @override
  String get textProprietary474 => 'Proprietary';

  @override
  String get textUnspecified475 => 'Unspecified';

  @override
  String get chooseLanguage =>
      'Choose the language for the app interface. Changes apply immediately and are saved for the next launch.';

  @override
  String get russianLanguage => 'Russian';

  @override
  String get englishLanguage => 'English';

  @override
  String get workspace => 'Workspace';

  @override
  String get recentSessions => 'Recent sessions';

  @override
  String get simulatorNotice =>
      'No device is connected yet — the session will use the built-in signal simulator (256 Hz, 1 channel).';

  @override
  String get deviceSimulatorDescription =>
      'Built-in signal generator (256 Hz, 8 channels). Used for development without hardware.';

  @override
  String get deviceBoardDescription =>
      'The first real HAL driver (USB/serial). Requires streaming firmware.';

  @override
  String get pipelineOfflineNotice =>
      'Core offline: the pipeline initializes when a session starts. Start a test session on the Session screen.';

  @override
  String get markerInstructions =>
      'Add a marker with the flag in the toolbar — it will attach to the current signal time.';

  @override
  String get spectrogramVersionNotice =>
      'STFT is currently computed in Dart for demonstration. In v0.2 the spectrogram will use native core data (core.diagnostics) with the same UI.';

  @override
  String get datasetsRoadmap =>
      'v0.2: import sessions and external files (EDF/CSV), group by experiments, tag and compare datasets and sessions — all without writing code.';

  @override
  String get modelsRoadmap =>
      'v0.2: train models on datasets (batches, spectrogram clusters), integrate trained models as Entities, export/import ONNX through Model Registry & Runtime.';

  @override
  String logSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String logSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String logPausedCount(int count) {
    return 'Paused — new entries are not loaded ($count)';
  }

  @override
  String logVisibleCount(int visible, int total) {
    return 'Entries: $visible / $total · file: latest.log (refresh 0.4 s)';
  }

  @override
  String sessionHistoryDetails(
    String backend,
    int seconds,
    int frames,
    String rms,
  ) {
    return '$backend · $seconds s · $frames frames · RMS $rms';
  }

  @override
  String workspaceCounts(int modules, int connections) {
    String _temp0 = intl.Intl.pluralLogic(
      modules,
      locale: localeName,
      other: '$modules modules',
      one: '1 module',
      zero: '0 modules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      connections,
      locale: localeName,
      other: '$connections connections',
      one: '1 connection',
      zero: '0 connections',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String versionLabel(String app, String version, String core, int abi) {
    return '$app $version · core $core (ABI $abi)';
  }

  @override
  String get previewSignalSource => 'Signal Source';

  @override
  String get previewBandpassFilter => 'Bandpass Filter';

  @override
  String get previewNotchFilter => 'Notch Filter';

  @override
  String get previewChannelMixer => 'Channel Mixer';

  @override
  String get previewFftAnalyzer => 'FFT Analyzer';

  @override
  String get previewFeatureExtractor => 'Feature Extractor';

  @override
  String get previewArtifactDetector => 'Artifact Detector';

  @override
  String get previewSignalViewer => 'Signal Viewer';

  @override
  String get previewSignalNotes => 'Signal Notes';

  @override
  String get previewSessionBrowser => 'Session Browser';

  @override
  String get previewDatasetTools => 'Dataset Tools';

  @override
  String get previewResearchDashboard => 'Research Dashboard';

  @override
  String get previewAcquisition => 'Acquisition';

  @override
  String get previewDsp => 'DSP';

  @override
  String get previewRouting => 'Routing';

  @override
  String get previewAnalysis => 'Analysis';

  @override
  String get previewMl => 'ML';

  @override
  String get previewVisualization => 'Visualization';

  @override
  String get previewNotes => 'Notes';

  @override
  String get previewWorkflow => 'Workflow';

  @override
  String get previewData => 'Data';

  @override
  String get previewBadge => 'Preview';

  @override
  String get previewDescription =>
      'Local placeholder for testing the canvas, ports and author UI. No signal processing or package execution.';

  @override
  String get previewExtensionDescription =>
      'Local extension placeholder for catalog and rail layout testing. No external code runs.';

  @override
  String previewSummary(String category) {
    return 'Preview $category module for UI and Drag & Drop testing.';
  }

  @override
  String get previewNotice =>
      'Preview interface — controls store local values only. No executable module is installed.';

  @override
  String get previewExtensionNotice =>
      'Preview extension area for layout testing.';

  @override
  String get previewGain => 'Gain';

  @override
  String get previewMode => 'Mode';

  @override
  String get previewStandard => 'Standard';

  @override
  String get previewLowLatency => 'Low latency';

  @override
  String get previewHighPrecision => 'High precision';

  @override
  String get shapeWaves => 'waves';

  @override
  String get shapeContours => 'contours';

  @override
  String get shapeGrid => 'grid';

  @override
  String get iconModule => 'module';

  @override
  String get iconSignal => 'signal';

  @override
  String get iconBrain => 'brain';

  @override
  String get iconChart => 'chart';

  @override
  String get iconTerrain => 'terrain';

  @override
  String get iconNotes => 'notes';

  @override
  String get iconMoon => 'moon';

  @override
  String get iconSun => 'sun';
}
