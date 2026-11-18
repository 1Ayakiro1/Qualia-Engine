// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get workspaceCanvasHints => 'Подсказки на канвасе';

  @override
  String get sceneCreateGroup => 'Создать группу';

  @override
  String get sceneEditGroup => 'Изменить группу';

  @override
  String get sceneGroupName => 'Название группы';

  @override
  String get sceneMoveToGroup => 'Переместить в группу';

  @override
  String get sceneRemoveFromGroup => 'Убрать из группы';

  @override
  String get sceneDissolveGroup => 'Расформировать группу';

  @override
  String get workspaceObjectVisible => 'Видимость на канвасе';

  @override
  String get workspaceObjectGeometry => 'Положение и размер';

  @override
  String get canvasEraser => 'Ластик';

  @override
  String get canvasBrush => 'Кисть';

  @override
  String get canvasBrushColor => 'Цвет кисти';

  @override
  String get canvasColorWhite => 'Белый';

  @override
  String get canvasColorBlack => 'Чёрный';

  @override
  String get canvasDiameter => 'Диаметр';

  @override
  String get workspaceSave => 'Сохранить воркспейс';

  @override
  String get workspaceSaved => 'Воркспейс сохранён';

  @override
  String get sceneSelection => 'ОБЪЕКТЫ СЦЕНЫ';

  @override
  String get sceneCollapse => 'Свернуть выбор сцены';

  @override
  String get sceneExpand => 'Развернуть выбор сцены';

  @override
  String get sceneNoObjects => 'Объекты не найдены';

  @override
  String get sceneSelectObject => 'Выберите объект';

  @override
  String get workspaceSaveFailed =>
      'Не удалось сохранить воркспейс. Черновик по-прежнему доступен.';

  @override
  String get canvasFullscreen => 'Полноэкранный канвас';

  @override
  String get canvasExitFullscreen => 'Выйти из полноэкранного канваса';

  @override
  String get canvasScreenshot => 'Сохранить снимок канваса';

  @override
  String get canvasScreenshotSaved => 'Снимок канваса сохранён';

  @override
  String get canvasScreenshotFailed => 'Не удалось сохранить снимок канваса.';

  @override
  String get workspaceUnsavedTitle => 'Сохранить изменения воркспейса?';

  @override
  String get workspaceUnsavedMessage =>
      'В воркспейсе есть несохранённые изменения. Сохраните их перед закрытием или отмените изменения после последнего сохранения.';

  @override
  String get workspaceDiscard => 'Не сохранять';

  @override
  String get workspaceUndoNotice => 'Действие отменено';

  @override
  String get workspaceRedoNotice => 'Действие возвращено';

  @override
  String get privacyDataTitle => 'Приватность данных';

  @override
  String get privacyDataDescription =>
      'Локальная обработка включена по умолчанию. Необязательная диагностика выключена, пока вы явно её не разрешите.';

  @override
  String get privacyCrashReports => 'Краш-репорты';

  @override
  String get privacyCrashReportsDescription =>
      'Разрешить подготовку обезличенной диагностики сбоев для внешнего сервиса. Эта сборка ничего не отправляет.';

  @override
  String get privacyMetrics => 'Метрики использования';

  @override
  String get privacyMetricsDescription =>
      'Согласие на необязательные метрики использования. В этой сборке нет сервиса отправки метрик; метрики не передаются.';

  @override
  String get privacyExternalData => 'Разрешить передачу данных наружу';

  @override
  String get privacyExternalDataDescription =>
      'Включить вход через Supabase, каталог, обложки и явную публикацию. Выключение блокирует новые HTTP-запросы приложения, но не изолирует установленные модули и не отменяет уже отправленные запросы.';

  @override
  String get privacyOutboundLog =>
      'Аудит передачи: logs/outbound.jsonl в локальном каталоге данных приложения. Содержит назначение, имена полей, размер и ответ/ошибку, без значений и токенов. Вход в браузере записывается как передача управления, а не завершённая отправка. Подробнее: docs/DATA_PRIVACY.md.';

  @override
  String get workspaceHideFully => 'Скрыть полностью';

  @override
  String get workspaceShowFully => 'Показать полностью';

  @override
  String get railBottomZone => 'Нижняя часть рейла';

  @override
  String get railUnusedItems => 'Неиспользуемые элементы';

  @override
  String get railUsedItems => 'На рейле';

  @override
  String get railPinBottom => 'Переместить вниз';

  @override
  String get railPinTop => 'Переместить наверх';

  @override
  String get railDragHint =>
      'Перетаскивайте кнопки в рейл, чтобы добавить их или изменить порядок. Верните сюда, чтобы убрать. Нажатие переключает видимость; Alt + ↑ / ↓ перемещает кнопку в фокусе.';

  @override
  String get logicBlocks => 'Логические блоки';

  @override
  String get logicAdd => 'Добавить логический блок';

  @override
  String get logicFilter => 'Фильтр';

  @override
  String get logicSelectFields => 'Выбор полей';

  @override
  String get logicValidate => 'Проверка входа / выхода';

  @override
  String get logicScript => 'Скрипт';

  @override
  String get logicScriptHelp =>
      'Без файлов, сети и циклов. Доступны value.field, has(value, \"field\"), сравнения, and / or / not. Скрипты поддерживают вложенные IF / ELSE и emit. select(value, \"field\") оставляет только выбранные поля. Схема: type, properties, required, additionalProperties.';

  @override
  String get logicTestInput => 'Тестовый вход (JSON)';

  @override
  String get logicTest => 'Проверить без отправки в граф';

  @override
  String get logicShow => 'Показать логические блоки';

  @override
  String get logicHide => 'Скрыть логические блоки';

  @override
  String get moduleBlocksShow => 'Показать блоки модулей';

  @override
  String get moduleBlocksHide => 'Скрыть блоки модулей';

  @override
  String get moduleDelete => 'Удалить модуль';

  @override
  String get moduleActivate => 'Сделать активным';

  @override
  String get moduleDeactivate => 'Сделать неактивным';

  @override
  String get moduleMoveToWorkspace => 'Переместить в воркспейс';

  @override
  String get moduleMoveConnectionsWarning =>
      'Связи с модулями, оставшимися в исходном воркспейсе, будут удалены. Параметры и связи внутри переносимой группы сохранятся. Продолжить?';

  @override
  String get moduleEditorPlaceholder =>
      'Заглушка панели редактирования модуля. Инструменты редактирования будут добавлены позже.';

  @override
  String get moduleCreateLocal => 'Создать локально';

  @override
  String get moduleCreateOnline => 'Создать онлайн';

  @override
  String get moduleAddLocal => 'Добавить локально (.qmod)';

  @override
  String get moduleAddOnline => 'Добавить онлайн';

  @override
  String get localModuleProject => 'Локальный проект C++-модуля';

  @override
  String get localModuleEditHint =>
      'Редактируйте C++-исходники в папке проекта, соберите новую версию .qmod и добавьте её локально. Инструкция: docs/LOCAL_MODULES.md.';

  @override
  String get localModuleTrustTitle => 'Доверять нативному модулю?';

  @override
  String get localModuleTrustWarning =>
      'Пакет содержит нативный C++-код. Каждый узел работает отдельным процессом, но это НЕ защитная песочница: код имеет доступ к файлам, сети и устройствам от имени вашего пользователя. Устанавливайте только доверенный код. Добавление узла запускает его исполняемый файл.';

  @override
  String get localModuleError => 'Ошибка локального модуля';

  @override
  String get workspacesTitle => 'Воркспейсы';

  @override
  String get workspaceManager => 'Менеджер рабочих зон';

  @override
  String get workspaceCreate => 'Новый воркспейс';

  @override
  String get workspaceEdit => 'Редактировать воркспейс';

  @override
  String get workspaceDelete => 'Удалить воркспейс';

  @override
  String workspaceDeleteConfirm(String name) {
    return 'Удалить «$name» и его граф? Модули останутся в библиотеке.';
  }

  @override
  String get workspaceImport => 'Импорт воркспейса';

  @override
  String get workspaceExport => 'Экспорт / поделиться';

  @override
  String get workspaceSubmit => 'Отправить в Marketplace';

  @override
  String get workspaceSubmitted =>
      'Воркспейс отправлен на проверку. После одобрения он появится в Marketplace.';

  @override
  String get workspaceReviewNotice =>
      'Для отправки войдите через GitHub. Публикация требует проверки: отправка не размещает воркспейс в каталоге мгновенно.';

  @override
  String get workspaceShareWarning =>
      'Граф содержит параметры модулей и подписи. Перед отправкой удалите приватные значения, токены и локальные пути. Делитесь только тем, что имеете право распространять.';

  @override
  String get workspaceContinue => 'Продолжить';

  @override
  String get workspaceProjectName => 'Название воркспейса';

  @override
  String get workspaceProjectDescription => 'Описание';

  @override
  String get workspaceProjectActions => 'Действия с воркспейсом';

  @override
  String workspaceGraphSummary(int nodes, int links) {
    return 'Модулей: $nodes · Связей: $links';
  }

  @override
  String get workspaceDependenciesUnavailable =>
      'Нужные версии модулей недоступны';

  @override
  String get workspaceOperationFailed => 'Не удалось выполнить действие';

  @override
  String get workspaceInstall => 'Установить воркспейс';

  @override
  String get workspaceInstallNotice =>
      'Создаёт отдельный проект и автоматически подгружает доступные версии модулей. Для запуска внешних пакетов нужен подписанный runtime; импорт ничего не исполняет.';

  @override
  String get workspaceCatalogUnavailable =>
      'Каталог воркспейсов недоступен. Проверьте подключение и повторите попытку. На сервере также нужна миграция каталога рабочих зон.';

  @override
  String get navigationMenuDown => 'Следующий пункт меню';

  @override
  String get navigationMenuUp => 'Предыдущий пункт меню';

  @override
  String get navigationEditableHint =>
      'Нажмите на сочетание для изменения, затем «Сохранить» или Ctrl+Enter. Изменения сохраняются и действуют в интерфейсе и меню. Esc отменяет ввод; сброс возвращает исходные сочетания.';

  @override
  String get navigationReset => 'Сбросить сочетания';

  @override
  String get navigationConflict =>
      'Это сочетание уже используется другим навигационным действием.';

  @override
  String get navigationTitle => 'Навигация';

  @override
  String get navigationDescription =>
      'Управляйте без мыши. Рамка фокуса появляется только при навигации клавишами и скрывается при использовании мыши. В текстовых полях сохраняются обычные команды редактирования.';

  @override
  String get navigationFixedBindings =>
      'Навигационные сочетания встроены в элементы интерфейса и здесь не переназначаются. Полноэкранные команды работают в активной области модуля.';

  @override
  String get navigationMenus => 'Меню';

  @override
  String get navigationModules => 'Модули и порты';

  @override
  String get navigationKeyUpDown => 'Вверх / Вниз';

  @override
  String get navigationKeyRight => 'Вправо';

  @override
  String get navigationKeyLeft => 'Влево';

  @override
  String get navigationNext => 'Перейти к следующему элементу';

  @override
  String get navigationPrevious => 'Перейти к предыдущему элементу';

  @override
  String get navigationActivate => 'Активировать выбранный элемент';

  @override
  String get navigationContext => 'Открыть контекстное меню узла или порта';

  @override
  String get navigationMenuMove => 'Перейти между пунктами меню';

  @override
  String get navigationSubmenuOpen => 'Открыть подменю';

  @override
  String get navigationSubmenuBack => 'Вернуться из подменю';

  @override
  String get navigationDismiss =>
      'Закрыть меню или диалог / выйти из полноэкранного режима';

  @override
  String get navigationConnect =>
      'Выбрать и активировать каждый порт для соединения';

  @override
  String get navigationFullscreen => 'Переключить полноэкранный режим модуля';

  @override
  String get navigationExitFullscreen =>
      'Вернуться из полноэкранного режима модуля';

  @override
  String get workspacePortName => 'Название';

  @override
  String get workspacePortRename => 'Переименовать порт';

  @override
  String get workspacePortNameHint => 'Пустое поле вернёт исходное название.';

  @override
  String get workspacePortSave => 'Сохранить';

  @override
  String get workspacePortValue => 'Значение';

  @override
  String get workspacePortColor => 'Цвет';

  @override
  String get workspacePortAny => 'Любое';

  @override
  String get workspacePortString => 'Строка';

  @override
  String get workspacePortNumber => 'Число';

  @override
  String get workspacePortBoolean => 'Логическое';

  @override
  String get workspacePortList => 'Список';

  @override
  String get workspacePortObject => 'Объект';

  @override
  String get moduleOpenWindow => 'Открыть в отдельном окне';

  @override
  String get moduleFullscreen => 'Модуль на весь экран';

  @override
  String get moduleExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get moduleWindowFailed => 'Не удалось открыть окно модуля.';

  @override
  String get workspaceAppearance => 'ОФОРМЛЕНИЕ';

  @override
  String get workspaceInstance => 'ЭКЗЕМПЛЯР';

  @override
  String get workspaceParameters => 'ПАРАМЕТРЫ';

  @override
  String get workspacePorts => 'ВХОДЫ / ВЫХОДЫ';

  @override
  String get workspaceInputColor => 'Подсветка входа';

  @override
  String get workspaceOutputColor => 'Подсветка выхода';

  @override
  String get workspaceSelect => 'Выделение';

  @override
  String get workspaceSelectAll => 'Выделить всё';

  @override
  String get workspaceDeselect => 'Снять выделение';

  @override
  String get workspaceDeleteSelected => 'Удалить выделенное';

  @override
  String get workspaceZoomIn => 'Приблизить';

  @override
  String get workspaceZoomOut => 'Отдалить';

  @override
  String get workspaceActualSize => 'Исходный масштаб (100%)';

  @override
  String get workspaceFrameSelection => 'Показать выделенное';

  @override
  String get workspaceResizeNode => 'Потяните, чтобы изменить размер модуля';

  @override
  String get workspaceSelectHint =>
      'Shift / Alt + клик — выделить несколько; Space + перетаскивание — переместить канвас';

  @override
  String get workspaceCopy => 'Копировать';

  @override
  String get workspaceCut => 'Вырезать';

  @override
  String get workspacePaste => 'Вставить';

  @override
  String get workspaceMoveJunction => 'Переместить точку';

  @override
  String get workspaceClipboardFailed =>
      'Не удалось скопировать или вставить ноды. Проверьте доступность модулей и размер сцены.';

  @override
  String get textSupabaseAuthIsUnavailable0 => 'Supabase Auth недоступен.';

  @override
  String get textSignInWithGitHubBeforeCreatingA1 =>
      'Войдите через GitHub перед созданием модуля.';

  @override
  String get textSignInWithGitHubToManageYour2 =>
      'Войдите через GitHub для управления своими модулями.';

  @override
  String get textOnlyUnpublishedModuleDraftsCanBeRemoved3 =>
      'Можно удалять только неопубликованные черновики модулей.';

  @override
  String get textDebug4 => 'Отладка';

  @override
  String get textInfo5 => 'Инфо';

  @override
  String get textWarnings6 => 'Предупреждения';

  @override
  String get textErrors7 => 'Ошибки';

  @override
  String get textSearchSourceAndText8 => 'Поиск по источнику и тексту…';

  @override
  String get textLEVELS9 => 'УРОВНИ';

  @override
  String get textTheLatestLogFileHasNotBeen10 =>
      'Файл latest.log пока не создан.';

  @override
  String get textOpenTheApplicationWorkspace11 =>
      'Запустите рабочую область приложения.';

  @override
  String get textRetry12 => 'Повторить';

  @override
  String get textDebugTerminal13 => 'Терминал отладки';

  @override
  String get textResume14 => 'Продолжить';

  @override
  String get textPause15 => 'Пауза';

  @override
  String get textAutoScroll16 => 'Автопрокрутка';

  @override
  String get textSaveVisibleEntries17 => 'Сохранить видимое';

  @override
  String get textClearView18 => 'Очистить вид';

  @override
  String get textCloseWindow19 => 'Закрыть окно';

  @override
  String get textSupabaseAuthIsNotInitialized20 =>
      'Supabase Auth не инициализирован.';

  @override
  String get textCouldNotOpenTheGitHubSignIn21 =>
      'Не удалось открыть страницу входа через GitHub.';

  @override
  String get textUnsupportedWorkspacePresetFormat22 =>
      'Неподдерживаемый формат пресета рабочего пространства.';

  @override
  String get textAPresetNeedsANameAndA23 =>
      'Пресету нужны название и список ID модулей.';

  @override
  String get textAPresetSupportsUpTo500Modules24 =>
      'Пресет поддерживает до 500 модулей.';

  @override
  String get textAModuleIsMissing25 => 'Модуль отсутствует.';

  @override
  String get textAModuleCannotConnectToItself26 =>
      'Модуль нельзя соединить с самим собой.';

  @override
  String get textAPortIsMissing27 => 'Порт отсутствует.';

  @override
  String get textThisConnectionWouldCreateAProcessingCycle28 =>
      'Это соединение создаст цикл обработки.';

  @override
  String get textLibbciEngineCoreWasNotFoundBeside29 =>
      'libbci_engine_core не найдена рядом с исполняемым файлом';

  @override
  String get textConsumer30 => 'Потребитель';

  @override
  String get textResearcher31 => 'Исследователь';

  @override
  String get textDeveloper32 => 'Разработчик';

  @override
  String get textPersonalAndMedicalMode33 => 'Личный и медицинский режим';

  @override
  String get textDatasetsSpectrogramsExperiments34 =>
      'Датасеты, спектрограммы, эксперименты';

  @override
  String get textModulesAPILowLevelAccess35 =>
      'Модули, API, низкоуровневый доступ';

  @override
  String get textDashboard36 => 'Обзор';

  @override
  String get textSystemStatus37 => 'Состояние системы';

  @override
  String get textDevices38 => 'Устройства';

  @override
  String get textHALBoardConnections39 => 'HAL, подключение плат';

  @override
  String get textSession40 => 'Сессия';

  @override
  String get textRecordingAndLiveMetrics41 => 'Запись и live-метрики';

  @override
  String get textPipeline42 => 'Конвейер';

  @override
  String get textSignalProcessingModuleChain43 => 'Цепочка модулей обработки';

  @override
  String get textSpectrogram44 => 'Спектрограмма';

  @override
  String get textRealTimeVisualization45 => 'Real-time визуализация';

  @override
  String get textModuleProcessingCanvas46 => 'Канвас обработки модулей';

  @override
  String get textEntity47 => 'Нейросети';

  @override
  String get textNeuralNetworkEntities48 => 'Нейросетевые сущности';

  @override
  String get textDatasets49 => 'Датасеты';

  @override
  String get textImportAndComparison50 => 'Загрузка и сравнение';

  @override
  String get textModels51 => 'Модели';

  @override
  String get textTrainingAndModelRegistry52 => 'Обучение и реестр моделей';

  @override
  String get textCoreFFIConsole53 => 'FFI-консоль ядра';

  @override
  String get textMarketplace54 => 'Маркетплейс';

  @override
  String get textCommunityExtensions55 => 'Пользовательские расширения';

  @override
  String get textBugReport56 => 'Сообщить об ошибке';

  @override
  String get textReportAProblem57 => 'Сообщить о проблеме';

  @override
  String get textSettings58 => 'Настройки';

  @override
  String get textModesBuildLicenses59 => 'Режимы, сборка, лицензии';

  @override
  String get textFile60 => 'Файл';

  @override
  String get textEdit61 => 'Правка';

  @override
  String get textView62 => 'Вид';

  @override
  String get textHelp63 => 'Справка';

  @override
  String get textCoreSessionActive64 => 'Ядро: активна сессия';

  @override
  String get textCoreOnline65 => 'Ядро: онлайн';

  @override
  String get textCoreOffline66 => 'Ядро: офлайн';

  @override
  String get textUsageMode67 => 'Режим использования';

  @override
  String get textGeneral68 => 'Общие';

  @override
  String get textPresetNotImported69 => 'Пресет не импортирован';

  @override
  String get textPresetCatalogUnavailable70 => 'Каталог пресета недоступен';

  @override
  String textArg0ThePresetRemainsLoaded71(String arg0) {
    return '$arg0. Пресет остаётся загруженным.';
  }

  @override
  String get textMissingWorkspaceModules72 =>
      'Отсутствуют модули рабочего пространства';

  @override
  String textArg0Arg1ThePresetIsSavedFind73(String arg0, String arg1) {
    return '$arg0: $arg1. Пресет сохранён; найдите отсутствующие модули в маркетплейсе.';
  }

  @override
  String textMissingModulesArg074(String arg0) {
    return 'Отсутствуют модули: $arg0';
  }

  @override
  String get textProfile75 => 'Профиль';

  @override
  String get textNewTab76 => 'Новая вкладка';

  @override
  String get textPreviewModule77 => 'Демонстрационный модуль';

  @override
  String get textDragThisPlaceholderToTheCanvasTo78 =>
      'Перетащите эту заглушку на канвас, чтобы изменить параметры экземпляра. Это не черновик для публикации.';

  @override
  String get textSignInRequired79 => 'Требуется вход';

  @override
  String get textModuleNotSaved80 => 'Модуль не сохранён';

  @override
  String get textModuleAdded81 => 'Модуль добавлен';

  @override
  String get textModuleUpdated82 => 'Модуль обновлён';

  @override
  String textArg0IsNowAvailableInWorkspace83(String arg0) {
    return '$arg0 теперь доступен в рабочем пространстве.';
  }

  @override
  String get textModulesUnavailable84 => 'Модули недоступны';

  @override
  String get textCouldNotLoadModulesFromYourAccount85 =>
      'Не удалось загрузить модули вашей учётной записи.';

  @override
  String get textEntityAdded86 => 'Нейросеть добавлена';

  @override
  String get textEntityUpdated87 => 'Нейросеть обновлена';

  @override
  String textArg0IsNowAvailableInEntity88(String arg0) {
    return '$arg0 теперь доступна в разделе нейросетей.';
  }

  @override
  String get textEntityRemoved89 => 'Нейросеть удалена';

  @override
  String textArg0WasRemovedFromEntity90(String arg0) {
    return '$arg0 удалена из раздела нейросетей.';
  }

  @override
  String get textEntityUninstalled91 => 'Нейросеть деинсталлирована';

  @override
  String get textEntityInstalled92 => 'Нейросеть установлена';

  @override
  String get textThesePlaceholdersBelongToTheLocalUI93 =>
      'Эти заглушки предназначены для локального тестирования интерфейса. Экземпляры на канвасе можно удалить через ПКМ → Удалить.';

  @override
  String get textModuleNotRemoved94 => 'Модуль не удалён';

  @override
  String get textDocumentation95 => 'Документация';

  @override
  String get textLearnHowToConfigureWorkspacesDevicesSessions96 =>
      'Узнайте, как настроить рабочие пространства, устройства, сессии и модули Qualia Engine.';

  @override
  String get textAboutUs97 => 'О нас';

  @override
  String textArg0VersionArg1BuiltByArg2For98(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0\nВерсия $arg1\n\nРазработано $arg2 для работы с нейрокомпьютерными интерфейсами.';
  }

  @override
  String get textWelcomeToQualiaEngine99 => 'Добро пожаловать в Qualia Engine';

  @override
  String get textQualiaEngineIsADesktopWorkspaceFor100 =>
      'Qualia Engine — рабочее пространство для исследования данных BCI, сессий и модульных конвейеров обработки сигнала.';

  @override
  String get textTutorials101 => 'Обучающие материалы';

  @override
  String get textStartWithTheDashboardConnectADevice102 =>
      'Начните с обзора, подключите устройство, создайте сессию и откройте модули для настройки обработки сигнала.';

  @override
  String get textLicense103 => 'Лицензия';

  @override
  String get textQualiaEngineIsDistributedUnderTheProject104 =>
      'Qualia Engine распространяется по лицензии проекта. Полные условия приведены в файле лицензии репозитория.';

  @override
  String get textCheckUpdates105 => 'Проверить обновления';

  @override
  String textYouAreRunningQualiaEngineArg0Update106(String arg0) {
    return 'Вы используете Qualia Engine $arg0. Проверка обновлений будет подключена к каналу релизов в следующей версии.';
  }

  @override
  String get textOurYoutube107 => 'Наш YouTube';

  @override
  String get textVideoTutorialsAndProjectUpdatesWillBe108 =>
      'Видеоуроки и новости проекта будут доступны на YouTube-канале Qualia Engine.';

  @override
  String get textThisHelpActionIsNotAvailableYet109 =>
      'Этот раздел справки пока недоступен.';

  @override
  String get textClose110 => 'Закрыть';

  @override
  String get textBuild111 => 'Сборка';

  @override
  String get textInterfaceScaleCtrlCtrl112 =>
      'Масштаб интерфейса (Ctrl + / Ctrl -)';

  @override
  String get textNotifications113 => 'Уведомления';

  @override
  String get textJustNow114 => 'Только что';

  @override
  String textArg0MinAgo115(String arg0) {
    return '$arg0 мин. назад';
  }

  @override
  String textArg0HAgo116(String arg0) {
    return '$arg0 ч. назад';
  }

  @override
  String textArg0DAgo117(String arg0) {
    return '$arg0 дн. назад';
  }

  @override
  String get textMarkAllAsRead118 => 'Отметить всё прочитанным';

  @override
  String get textNoNotifications119 => 'Нет уведомлений';

  @override
  String get textOpenDebugTerminal120 => 'Открыть терминал отладки';

  @override
  String get textMinimizeWindow121 => 'Свернуть окно';

  @override
  String get textRestoreWindow122 => 'Восстановить окно';

  @override
  String get textMaximizeWindow123 => 'Развернуть окно';

  @override
  String get textAddWorkspacePreset124 =>
      'Добавить пресет рабочего пространства';

  @override
  String get textNewWorkspace125 => 'Новое рабочее пространство';

  @override
  String get textOpenProject126 => 'Открыть проект';

  @override
  String get textImportModuleSoon127 => 'Импортировать модуль (скоро)';

  @override
  String get textPreferences128 => 'Настройки';

  @override
  String get textRailSettings129 => 'Настройки рейла';

  @override
  String get textUndo130 => 'Отменить';

  @override
  String get textRedo131 => 'Повторить';

  @override
  String get textPreferencesSoon132 => 'Настройки (скоро)';

  @override
  String get textExplorer133 => 'Проводник';

  @override
  String get textTerminal134 => 'Терминал';

  @override
  String get textCustomizeLayoutSoon135 => 'Настроить расположение (скоро)';

  @override
  String get textTheme136 => 'Тема';

  @override
  String get textSystem137 => 'Системная';

  @override
  String get textDark138 => 'Тёмная';

  @override
  String get textWhite139 => 'Светлая';

  @override
  String get textWelcome140 => 'Добро пожаловать';

  @override
  String get textReportIssue141 => 'Сообщить о проблеме';

  @override
  String get textBuildProject142 => 'Собрать проект';

  @override
  String get textRunSession143 => 'Запустить сессию';

  @override
  String get textBuildTasksSoon144 => 'Задачи сборки (скоро)';

  @override
  String textArg0Menu145(String arg0) {
    return 'Меню «$arg0»';
  }

  @override
  String get textQUICKACTIONS146 => 'БЫСТРЫЕ ДЕЙСТВИЯ';

  @override
  String get textFindModule147 => 'Найти модуль';

  @override
  String get textKEYBOARDSHORTCUTS148 => 'ГОРЯЧИЕ КЛАВИШИ';

  @override
  String get textIncreaseInterfaceScale149 => 'Увеличить масштаб интерфейса';

  @override
  String get textDecreaseInterfaceScale150 => 'Уменьшить масштаб интерфейса';

  @override
  String get textShortcuts151 => 'Горячие клавиши';

  @override
  String get textSearchFilesSymbolsCtrlP152 =>
      'Поиск файлов, символов...  (Ctrl+P)';

  @override
  String get textUserProfileButton153 => 'Профиль пользователя';

  @override
  String get textBugReport154 => 'сообщить об ошибке';

  @override
  String get textUserDevSwitcher155 => 'переключить режим';

  @override
  String get textConfigs156 => 'настройки';

  @override
  String get textEXPLORER157 => 'ПРОВОДНИК';

  @override
  String get textAddModule158 => 'Добавить модуль';

  @override
  String get textRemoveModule159 => 'Удалить модуль';

  @override
  String get textEditModule160 => 'Редактировать модуль';

  @override
  String get textAddEntity161 => 'Добавить нейросеть';

  @override
  String get textRemoveEntity162 => 'Удалить нейросеть';

  @override
  String get textEditEntity163 => 'Редактировать нейросеть';

  @override
  String get textWORKSPACEPRESETS164 => 'ПРЕСЕТЫ РАБОЧЕГО ПРОСТРАНСТВА';

  @override
  String get textImportWorkspacePreset165 =>
      'Импортировать пресет рабочего пространства';

  @override
  String textExportArg0166(String arg0) {
    return 'Экспортировать $arg0';
  }

  @override
  String textMissingArg0167(String arg0) {
    return 'Отсутствует: $arg0';
  }

  @override
  String get textACTIVEMODULES168 => 'АКТИВНЫЕ МОДУЛИ';

  @override
  String get textSearchActiveModules169 => 'Поиск активных модулей...';

  @override
  String get textNoActiveModulesFound170 => 'Активные модули не найдены';

  @override
  String get textMODULECATALOG171 => 'КАТАЛОГ МОДУЛЕЙ';

  @override
  String get textSearchModules172 => 'Поиск модулей...';

  @override
  String get textNoModulesFound173 => 'Модули не найдены';

  @override
  String get textINSTALLEDENTITIES174 => 'УСТАНОВЛЕННЫЕ НЕЙРОСЕТИ';

  @override
  String get textENTITYCATALOG175 => 'КАТАЛОГ НЕЙРОСЕТЕЙ';

  @override
  String get textInstalled176 => 'Установлено';

  @override
  String get textRecommended177 => 'Рекомендуемое';

  @override
  String get textNoActiveWorkspaceItems178 =>
      'Нет активных элементов рабочего пространства';

  @override
  String get textClearModuleSearch179 => 'Очистить поиск модулей';

  @override
  String get textCreateNewTab180 => 'Создать новую вкладку';

  @override
  String get textHideExplorer181 => 'Скрыть проводник';

  @override
  String get textShowExplorer182 => 'Показать проводник';

  @override
  String get textCloseTab183 => 'Закрыть вкладку';

  @override
  String get textNoOpenTabs184 => 'Нет открытых вкладок';

  @override
  String get textCreateANewTabToContinue185 =>
      'Создайте новую вкладку, чтобы продолжить';

  @override
  String get textNewModule186 => 'Новый модуль';

  @override
  String get textCustomModuleDescription187 =>
      'Описание пользовательского модуля.';

  @override
  String get textID188 => 'ID';

  @override
  String get textName189 => 'Название';

  @override
  String get textCategory190 => 'Категория';

  @override
  String get textDescription191 => 'Описание';

  @override
  String get textMarketplaceCover192 => 'Обложка в маркетплейсе';

  @override
  String get textYourImageURLHTTPSOptional193 =>
      'URL изображения (HTTPS, необязательно)';

  @override
  String get textBackgroundContour194 => 'Фоновый контур';

  @override
  String get textCenterIcon195 => 'Центральная иконка';

  @override
  String get textDeclarativeManifestUISchemaJSON196 =>
      'Декларативный manifest / схема UI (JSON)';

  @override
  String get textCoverAndUIMetadataAreSavedLocally197 =>
      'Обложка и метаданные интерфейса черновиков сохраняются локально. Опубликованные релизы передают manifest в маркетплейс.';

  @override
  String get textCancel198 => 'Отмена';

  @override
  String textArg0MustBeAnArray199(String arg0) {
    return '$arg0 должен быть массивом';
  }

  @override
  String get textCoverImageMustUseHTTPS200 =>
      'Изображение обложки должно использовать HTTPS';

  @override
  String textInvalidSchemaArg0201(String arg0) {
    return 'Недопустимая схема: $arg0';
  }

  @override
  String get textCustom202 => 'Пользовательское';

  @override
  String get textSave203 => 'Сохранить';

  @override
  String get textNewNeuralEntity204 => 'Новая нейросеть';

  @override
  String get textNeuralNetworkDescription205 => 'Описание нейросети.';

  @override
  String get textFramework206 => 'Фреймворк';

  @override
  String get textVersion207 => 'Версия';

  @override
  String get textUnknown208 => 'Неизвестно';

  @override
  String get textExtensionSettings209 => 'Настройки расширения';

  @override
  String get textDisableEnable210 => 'Включить/выключить';

  @override
  String get textAutoupdate211 => 'Автообновление';

  @override
  String get textUninstall212 => 'Удалить';

  @override
  String get textCopyLink213 => 'Копировать ссылку';

  @override
  String get textCopyName214 => 'Копировать название';

  @override
  String get textKeyboard215 => 'Клавиатура';

  @override
  String get textProfilesOperate216 => 'Управление профилями';

  @override
  String get textExtensionChanged217 => 'Расширение изменено';

  @override
  String textArg0Arg1Selected218(String arg0, String arg1) {
    return '$arg0: выбрано действие «$arg1».';
  }

  @override
  String get textTERMINAL219 => 'ТЕРМИНАЛ';

  @override
  String get textOUTPUT220 => 'ВЫВОД';

  @override
  String get textCloseRailSettings221 => 'Закрыть настройки рейла';

  @override
  String get textVisibility222 => 'Видимость';

  @override
  String get textShowRail223 => 'Показать рейл';

  @override
  String get textWhenHiddenContentUsesTheFullWidth224 =>
      'Если рейл скрыт, содержимое занимает всю ширину.\nВосстановить его можно через Правка → Настройки рейла.';

  @override
  String get textSections225 => 'Разделы';

  @override
  String get textExtensionSections226 => 'Разделы расширений';

  @override
  String get textAddAnExtensionFromTheCatalogTo227 =>
      'Добавьте расширение из каталога, чтобы настроить его раздел в рейле.';

  @override
  String get textChangesAreSavedAutomatically228 =>
      'Изменения сохраняются автоматически';

  @override
  String get textDone229 => 'Готово';

  @override
  String textArg0Arg1230(String arg0, String arg1) {
    return '$arg0 $arg1';
  }

  @override
  String get textHide231 => 'Скрыть';

  @override
  String get textShow232 => 'Показать';

  @override
  String get textBack233 => 'Назад';

  @override
  String get textExtensionContextMenu234 => 'Контекстное меню расширения';

  @override
  String get textEngineStatusAndQuickStart235 =>
      'Состояние движка и быстрый старт';

  @override
  String get textInterfaceUpdatedWorkspaceReady236 =>
      'Интерфейс обновлён · рабочая область готова';

  @override
  String get textConfigure237 => 'Настроить';

  @override
  String get textCoreCFFI238 => 'Ядро (C++ / FFI)';

  @override
  String get textOnline239 => 'онлайн';

  @override
  String get textOffline240 => 'офлайн';

  @override
  String get textCoreVersion241 => 'Версия ядра';

  @override
  String textArg0ExpectedArg1242(String arg0, String arg1) {
    return '$arg0 (ожидается $arg1)';
  }

  @override
  String get textLibrary243 => 'Библиотека';

  @override
  String get textNotFound244 => 'не найдена';

  @override
  String get textModulesInPipeline245 => 'Модулей в конвейере';

  @override
  String get textError246 => 'Ошибка';

  @override
  String get textQuickStart247 => 'Быстрый старт';

  @override
  String get textStartATestSession248 => 'Запустить тестовую сессию';

  @override
  String get textSpectrogramDemo249 => 'Спектрограмма (demo)';

  @override
  String get textModuleRegistry250 => 'Реестр модулей';

  @override
  String get text2409Test251 => '24.09 · тест';

  @override
  String get textSimulator0032Quality086252 =>
      'Симулятор · 00:32 · качество 0.86';

  @override
  String get text2309Calibration253 => '23.09 · калибровка';

  @override
  String get textSimulator0312Complete254 => 'Симулятор · 03:12 · готово';

  @override
  String get text2209Sleep255 => '22.09 · сон';

  @override
  String get textSimulator0105Quality071256 =>
      'Симулятор · 01:05 · качество 0.71';

  @override
  String get textSessionStorageWillBeImplementedInStorage257 =>
      'Хранение сессий будет реализовано в Storage Service (v0.2).';

  @override
  String get textEEGSimulator258 => 'Симулятор ЭЭГ';

  @override
  String get textADS1299CompatibleBoard259 => 'ADS1299-совместимая плата';

  @override
  String get textLSLSource260 => 'LSL-источник';

  @override
  String get textConnectToAnyLabStreamingLayerStream261 =>
      'Подключение к любому Lab Streaming Layer-потоку в сети.';

  @override
  String get textHardwareAbstractionLayerV01VirtualSources262 =>
      'Hardware Abstraction Layer · v0.1 — виртуальные источники';

  @override
  String get textHALRoadmapV02263 => 'Планы HAL (v0.2)';

  @override
  String get textNormalization264 => 'Нормализация';

  @override
  String get textRawSignalVBoardScale265 => 'сырой сигнал → μV, масштаб платы';

  @override
  String get textImpedance266 => 'Импеданс';

  @override
  String get textContactCalibrationProcedure267 =>
      'процедура калибровки контактов';

  @override
  String get textHotPlug268 => 'Горячее подключение';

  @override
  String get textConnectionDisconnectionDetection269 =>
      'детекция подключения/отключения';

  @override
  String get textRateChannels270 => 'Частота/каналы';

  @override
  String get textBoardConfigurationManagement271 =>
      'управление конфигурацией платы';

  @override
  String textCouldNotStartTheCoreCodeArg0272(String arg0) {
    return 'Не удалось запустить ядро (код $arg0)';
  }

  @override
  String get textStreamingThroughTheCCorePushPipeline273 =>
      'Поток идёт через C++-ядро (push → pipeline → pop)';

  @override
  String get textCoreOfflineLocalDartSimulation274 =>
      'Ядро офлайн — локальная симуляция в Dart';

  @override
  String get textSessionRunning275 => 'Сессия идёт';

  @override
  String get textTestSession276 => 'Тестовая сессия';

  @override
  String get textThroughCore277 => 'через ядро';

  @override
  String get textDartSimulation278 => 'Dart-симуляция';

  @override
  String get textTime279 => 'Время';

  @override
  String get textFrames280 => 'Кадров';

  @override
  String get textPeakHz281 => 'Пик, Гц';

  @override
  String get textQuality282 => 'Качество';

  @override
  String get textStart283 => 'Старт';

  @override
  String get textStop284 => 'Стоп';

  @override
  String textSimulator256Hz1ChannelBlockOf285(String arg0) {
    return 'Симулятор 256 Гц · 1 канал · блок $arg0 кадров';
  }

  @override
  String get textSessionHistoryInMemoryV01286 =>
      'История сессий (в памяти, v0.1)';

  @override
  String get textNoSessionsYetStartASession287 =>
      'Пока пусто — запустите сессию.';

  @override
  String get textCore288 => 'ядро';

  @override
  String get textDeviceRawBufferPreprocessingFeaturesOutput289 =>
      'Устройство → Буфер → Предобработка → Признаки → Вывод';

  @override
  String get textActiveCorePipeline290 => 'Активная цепочка ядра';

  @override
  String get textUnavailable291 => 'недоступно';

  @override
  String textArg0Modules292(String arg0) {
    return '$arg0 модулей';
  }

  @override
  String get textModulesRetrievedFromTheCoreViaBci293 =>
      'Модули получены из ядра через bci_engine_module_json():';

  @override
  String get textAdd294 => 'Добавить';

  @override
  String get textReplaceModule295 => 'Заменить модуль';

  @override
  String get textDelete296 => 'Удалить';

  @override
  String get textConnectAnOutputToAnInput297 => 'Соедините выход со входом.';

  @override
  String textArg0ModulesArg1Connections298(String arg0, String arg1) {
    return 'Модулей: $arg0 · Соединений: $arg1';
  }

  @override
  String get workspaceHideSidebar => 'Скрыть правую панель';

  @override
  String get workspaceShowSidebar => 'Показать правую панель';

  @override
  String get workspaceColorNone => 'Без цвета';

  @override
  String get workspaceColorRed => 'Красный';

  @override
  String get workspaceColorOrange => 'Оранжевый';

  @override
  String get workspaceColorYellow => 'Жёлтый';

  @override
  String get workspaceColorGreen => 'Зелёный';

  @override
  String get workspaceColorBlue => 'Синий';

  @override
  String get workspaceColorPurple => 'Фиолетовый';

  @override
  String get workspaceHeaderColor => 'Цвет модуля';

  @override
  String get workspaceSelectSameColor => 'Выбрать модули этого цвета';

  @override
  String get workspaceSelectByColor => 'Выбрать по цвету';

  @override
  String get workspaceColorSelected => 'Цвет выделенных';

  @override
  String get workspaceFilterByColor => 'Фильтр по цвету';

  @override
  String get workspaceAllColors => 'Все цвета';

  @override
  String get workspaceNoSearchResults => 'Модули не найдены';

  @override
  String get textAddModuleToCanvas299 => 'Добавить модуль на канвас';

  @override
  String get textFrameAllF300 => 'Показать всё (F)';

  @override
  String get textModuleSettings301 => 'Настройки модуля';

  @override
  String get textBuildYourWorkspace302 => 'Создайте рабочее пространство';

  @override
  String get textDragAModuleFromExplorerOrRight303 =>
      'Перетащите модуль из проводника или нажмите ПКМ → Добавить';

  @override
  String get textReturnToModules304 => 'Вернуться к началу';

  @override
  String get textMMBDragToPanWheelToZoom305 =>
      'СКМ / перетаскивание — панорама · колесо — масштаб · F — показать всё';

  @override
  String get textSelectAnOppositePortEscToCancel306 =>
      'Выберите противоположный порт · Esc — отмена';

  @override
  String get textInput307 => '+ Вход';

  @override
  String get textOutput308 => '+ Выход';

  @override
  String get textOpen309 => 'Открыть';

  @override
  String get textMODULESETTINGS310 => 'НАСТРОЙКИ МОДУЛЯ';

  @override
  String get textCloseModuleSettings311 => 'Закрыть настройки модуля';

  @override
  String get textSelectAModuleOnTheCanvas312 => 'Выберите модуль на канвасе.';

  @override
  String get textNoAdditionalSettingsHaveBeenDeclaredBy313 =>
      'Автор не указал дополнительных настроек.';

  @override
  String get textConnections314 => 'Соединения';

  @override
  String get textDisconnectPorts315 => 'Отключить порты';

  @override
  String get textNoConnections316 => 'Нет соединений';

  @override
  String get textSearchAvailableModules317 => 'Поиск доступных модулей...';

  @override
  String get textNoAvailableModulesAddADraftOr318 =>
      'Нет доступных модулей.\nДобавьте черновик или найдите модули в маркетплейсе.';

  @override
  String get textModuleInterface319 => 'Интерфейс модуля';

  @override
  String get textThisModuleHasNotDeclaredAnActive320 =>
      'Этот модуль ещё не указал схему интерфейса активной области. Его порты и настройки движка доступны в рабочем пространстве.';

  @override
  String textModuleIDArg0321(String arg0) {
    return 'ID модуля: $arg0';
  }

  @override
  String get textGraphEditingIsAvailableExecutingExternalPackages322 =>
      'Редактирование графа доступно. Выполнение внешних пакетов требует подписанной изолированной среды выполнения.';

  @override
  String get textWorkspacePreset323 => 'Пресет рабочего пространства';

  @override
  String get textPresetFileIsTooLarge324 => 'Файл пресета слишком большой.';

  @override
  String get textPresetName325 => 'Название пресета';

  @override
  String get textAdditionalMarketplaceModuleIDs326 =>
      'Дополнительные ID модулей маркетплейса';

  @override
  String get textOneIDPerLineOrSeparatedBy327 =>
      'Один ID на строку или через запятую';

  @override
  String get textYouCanCreateAnEmptyPresetOr328 =>
      'Можно создать пустой пресет или перечислить выше ID модулей маркетплейса.';

  @override
  String get textSTFT256Hop32Simulator256Hz329 =>
      'STFT 256 / hop 32 · симулятор 256 Гц · маркеры событий';

  @override
  String get textAddMarker330 => 'Добавить маркер';

  @override
  String get textClear331 => 'Очистить';

  @override
  String get text0Hz332 => '0 Гц';

  @override
  String get text127Hz333 => '~127 Гц';

  @override
  String get textMarkers334 => 'Маркеры';

  @override
  String textSecArg0335(String arg0) {
    return 'сек ≈ $arg0';
  }

  @override
  String get textParameters336 => 'Параметры';

  @override
  String textSensitivityArg0337(String arg0) {
    return 'Чувствительность ×$arg0';
  }

  @override
  String get textAboutVersions338 => 'О версиях';

  @override
  String get textCoreNotLoaded339 => 'ядро не загружено';

  @override
  String get textEngineCreated340 => 'engine создан';

  @override
  String get textCreateFailed341 => 'create не удался';

  @override
  String get textEngineStarted256Hz1342 => 'engine стартовал (256 Гц × 1)';

  @override
  String textStartCodeArg0343(String arg0) {
    return 'start → код $arg0';
  }

  @override
  String get textNoCore344 => 'ядра нет';

  @override
  String textStopCodeArg0345(String arg0) {
    return 'stop → код $arg0';
  }

  @override
  String get textEngineNotCreated346 => 'engine не создан';

  @override
  String textStartCodeArg0347(String arg0) {
    return 'start → код $arg0';
  }

  @override
  String get textModulesUnavailableARunningEngineIsRequired348 =>
      'модули недоступны (нужен запущенный engine)';

  @override
  String get textCoreFFIConsoleBciEngineCAPI349 =>
      'FFI-консоль ядра · bci_engine_* C API';

  @override
  String get textCreateEngine350 => 'Создать engine';

  @override
  String get textEchoTest351 => 'Echo-тест';

  @override
  String get textModulesJSON352 => 'Модули (JSON)';

  @override
  String textLibraryArg0353(String arg0) {
    return 'Библиотека: $arg0';
  }

  @override
  String get textCoreLibraryNotFoundBuildTheCore354 =>
      'Библиотека ядра не найдена — соберите ядро (scripts/build.sh).';

  @override
  String get textResetInterfaceScale355 => 'Сбросить масштаб интерфейса';

  @override
  String get textWORKSPACE356 => 'РАБОЧЕЕ ПРОСТРАНСТВО';

  @override
  String get textINTERFACE357 => 'ИНТЕРФЕЙС';

  @override
  String get textKeyboardShortcuts358 => 'Горячие клавиши';

  @override
  String get textEditShortcuts359 => 'Редактировать горячие клавиши';

  @override
  String get textPressKeys360 => 'Нажмите клавиши';

  @override
  String get textImport361 => 'Импорт';

  @override
  String get textAppearance362 => 'Оформление';

  @override
  String get textVoice363 => 'Голос';

  @override
  String get textConfiguration364 => 'Конфигурация';

  @override
  String get textPersonalization365 => 'Персонализация';

  @override
  String get textAccount366 => 'Учётная запись';

  @override
  String get textSearch367 => 'Поиск';

  @override
  String get textPersonal368 => 'Личные';

  @override
  String get textArchived369 => 'Архив';

  @override
  String get textBackToApp370 => 'Назад в приложение';

  @override
  String get textPermissions371 => 'Разрешения';

  @override
  String get textDefaultPermissions372 => 'Разрешения по умолчанию';

  @override
  String get textByDefaultAyakiroCanReadAndEdit373 =>
      'По умолчанию Ayakiro может читать и редактировать файлы в своём рабочем пространстве. При необходимости приложение может запросить дополнительный доступ.';

  @override
  String get textFullAccess374 => 'Полный доступ';

  @override
  String get textWhenAyakiroRunsWithFullAccessIt375 =>
      'При полном доступе Ayakiro может изменять любые файлы на компьютере и выполнять команды с доступом к сети без вашего подтверждения. Это значительно увеличивает риск потери данных, утечек и неожиданного поведения.';

  @override
  String get textLearnMoreAboutElevatedRisks376 =>
      'Подробнее о повышенных рисках.';

  @override
  String get textProjectlessTaskFolder377 => 'Папка задач вне проектов';

  @override
  String get textTheLocationWhereTasksStartedOutsideOf378 =>
      'Здесь по умолчанию сохраняются данные задач, запущенных вне проектов.';

  @override
  String get textChange379 => 'Изменить';

  @override
  String get textDefaultFileOpenDestination380 =>
      'Открывать файлы по умолчанию в';

  @override
  String get textWhereFilesAndFoldersOpenByDefault381 =>
      'Где по умолчанию открываются файлы и папки';

  @override
  String get textLanguage382 => 'Язык';

  @override
  String get textLanguageForTheAppUI383 => 'Язык интерфейса приложения';

  @override
  String get textAutoDetect384 => 'Определять автоматически';

  @override
  String get textBottomPanel385 => 'Нижняя панель';

  @override
  String get textShowTheBottomPanelControlInThe386 =>
      'Показывать кнопку нижней панели в заголовке приложения';

  @override
  String get textPreventSleepWhileRunning387 => 'Не переходить в спящий режим';

  @override
  String get textKeepYourComputerAwakeWhileAyakiroIs388 =>
      'Не выключать компьютер во время выполнения задач Ayakiro';

  @override
  String get textOpenSourceLicenses389 => 'Лицензии открытого ПО';

  @override
  String get textThirdPartySoftwareUsedByAyakiroBCI390 =>
      'Стороннее ПО, используемое Ayakiro BCI Engine';

  @override
  String get textCurrentApplicationBuild391 => 'Текущая сборка приложения';

  @override
  String textArg0LocalOfflineFirstMode392(String arg0) {
    return '$arg0 · локальный режим с приоритетом офлайн';
  }

  @override
  String get textImportCreationAndComparisonOfRecordings393 =>
      'Загрузка, формирование и сравнение записей';

  @override
  String get textYourDatasetsWillAppearHere394 =>
      'Здесь появятся ваши датасеты';

  @override
  String get textNoCodeTrainingAndModelRegistry395 =>
      'Обучение без кода и реестр моделей';

  @override
  String get textTheModelRegistryIsEmpty396 => 'Реестр моделей пуст';

  @override
  String get textSignInWithGitHub397 => 'Войти через GitHub';

  @override
  String get textGitHubSignInIsIncompleteReturnTo398 =>
      'GitHub вход не завершён. Вернитесь в приложение после авторизации.';

  @override
  String get textCouldNotCompleteTheActionCheckYour399 =>
      'Не удалось выполнить действие. Проверьте подключение и настройки OAuth.';

  @override
  String get textLogInWith400 => 'Войти через:';

  @override
  String get textConnectingToGitHub401 => 'Подключение к GitHub…';

  @override
  String get textSigningOut402 => 'Выход…';

  @override
  String get textSignOut403 => 'Выйти';

  @override
  String get textFiltersAndSignalInspectionHelpersForLive404 =>
      'Фильтры и инструменты анализа сигнала для сессий в реальном времени.';

  @override
  String get textAddStructuredNotesAndMarkersWhileRecording405 =>
      'Добавляйте структурированные заметки и маркеры во время записи сессии.';

  @override
  String get textACompactDashboardForCustomBCIMetrics406 =>
      'Компактная панель пользовательских метрик и сигналов BCI.';

  @override
  String get textExportRecordingsAndDerivedDataToCommon407 =>
      'Экспорт записей и обработанных данных в распространённые форматы.';

  @override
  String textArg0Arg1Selected408(String arg0, String arg1) {
    return '$arg0: выбрано действие «$arg1».';
  }

  @override
  String get textEXTENSIONINSPECTOR409 => 'ИНСПЕКТОР РАСШИРЕНИЙ';

  @override
  String get textSelectAnExtension410 => 'Выберите расширение';

  @override
  String textCategoryArg0411(String arg0) {
    return 'Категория  $arg0';
  }

  @override
  String get textDisable412 => 'Выключить';

  @override
  String get textEnable413 => 'Включить';

  @override
  String get textSettings414 => 'Настройки';

  @override
  String get textExtensionDetails415 => 'Сведения о расширении';

  @override
  String textCategoryArg0416(String arg0) {
    return 'Категория  $arg0';
  }

  @override
  String get textChooseAnExtensionFromTheSidebarTo417 =>
      'Выберите расширение на боковой панели, чтобы открыть вкладку.';

  @override
  String get textClassifiesLeftAndRightHandMotorImagery418 =>
      'Классификация воображаемых движений левой и правой руки по ЭЭГ.';

  @override
  String get textEstimatesAttentionAndFocusFromLiveSignal419 =>
      'Оценка внимания и концентрации по окнам сигнала в реальном времени.';

  @override
  String get textDetectsCommonEyeBlinkAndMuscleArtifacts420 =>
      'Обнаружение артефактов моргания и мышечной активности в ЭЭГ.';

  @override
  String get textSelectANeuralEntity421 => 'Выберите нейросеть';

  @override
  String get textInstall422 => 'Установить';

  @override
  String get textENTITY423 => 'НЕЙРОСЕТЬ';

  @override
  String get textCatalog424 => 'Каталог';

  @override
  String get textNoEntitiesYet425 => 'Пока нет нейросетей';

  @override
  String get textCommunity426 => 'Сообщество';

  @override
  String get textExtensions427 => 'Расширения';

  @override
  String get textModules428 => 'Модули';

  @override
  String get textThemes429 => 'Темы';

  @override
  String get textTheEngineSNeutralDarkFirstAppearance430 =>
      'Нейтральное тёмное оформление движка. Спокойное рабочее пространство для сосредоточенного исследования.';

  @override
  String get textBuiltIn431 => 'Встроенная';

  @override
  String get textACleanWhiteAppearanceWithTheSame432 =>
      'Светлое оформление с той же иерархией и единым стилем элементов управления.';

  @override
  String get textLight433 => 'Светлая';

  @override
  String get textAll434 => 'Все';

  @override
  String get textAllTime435 => 'За всё время';

  @override
  String get textRelevance436 => 'Релевантность';

  @override
  String get textGrid437 => 'Сетка';

  @override
  String get textTheCatalogCouldNotBeLoadedCheck438 =>
      'Не удалось загрузить каталог. Проверьте подключение и повторите попытку.';

  @override
  String get textThisWeek439 => 'На этой неделе';

  @override
  String get textThisMonth440 => 'В этом месяце';

  @override
  String get textNewest441 => 'Сначала новые';

  @override
  String get textRecentlyUpdated442 => 'Недавно обновлённые';

  @override
  String get textMostDownloaded443 => 'Больше загрузок';

  @override
  String get textMostLiked444 => 'Больше лайков';

  @override
  String textByArg0445(String arg0) {
    return 'автор: $arg0';
  }

  @override
  String textLicenseArg0446(String arg0) {
    return 'Лицензия: $arg0';
  }

  @override
  String get textLocalUIPlaceholderOnlyThisEntryIs447 =>
      'Локальная заглушка интерфейса. Эта запись не опубликована и не исполняется. Лицензии приведены как примеры для проверки фильтров.';

  @override
  String get textAddThisPublishedManifestToTheWorkspace448 =>
      'Добавить опубликованный manifest в библиотеку рабочего пространства. Загрузка и выполнение пакетов недоступны до появления подписанной изолированной среды выполнения.';

  @override
  String get textApplyTheme449 => 'Применить тему';

  @override
  String get textAddToWorkspace450 => 'Добавить в рабочее пространство';

  @override
  String get textAddedToWorkspace451 => 'Добавлено в рабочее пространство';

  @override
  String textArg0IsAvailableInExplorerPackageExecution452(String arg0) {
    return '$arg0 доступен в проводнике. Выполнение пакетов отключено.';
  }

  @override
  String get textFilters453 => 'Фильтры';

  @override
  String textSearchArg0454(String arg0) {
    return 'Поиск: $arg0...';
  }

  @override
  String get textClearSearch455 => 'Очистить поиск';

  @override
  String get textSortBy456 => 'Сортировка';

  @override
  String get textList457 => 'Список';

  @override
  String get textRetry458 => 'Повторить';

  @override
  String textNoPublishedArg0Yet459(String arg0) {
    return 'Опубликованных записей раздела «$arg0» пока нет';
  }

  @override
  String get textNoMatchingItems460 => 'Совпадений нет';

  @override
  String get textPublishedCatalogEntriesWillAppearHereAutomatically461 =>
      'Опубликованные записи каталога появятся здесь автоматически.';

  @override
  String textArg0Arg1462(String arg0, String arg1) {
    return '$arg0: $arg1';
  }

  @override
  String get textResetFilters463 => 'Сбросить фильтры';

  @override
  String get textToggleFilters464 => 'Переключить фильтры';

  @override
  String get textPublished465 => 'Опубликовано';

  @override
  String get textAvailability466 => 'Доступность';

  @override
  String get textBuiltInConnected467 => 'Встроенные / добавленные';

  @override
  String get textInWorkspace468 => 'В рабочем пространстве';

  @override
  String get textPreviewEntriesAreLocalUIPlaceholdersNot469 =>
      'Preview-записи — локальные заглушки интерфейса, а не опубликованные пакеты.';

  @override
  String textLikeArg0470(String arg0) {
    return 'Нравится: $arg0';
  }

  @override
  String textCreatedArg0UpdatedArg1471(String arg0, String arg1) {
    return 'Создано: $arg0\nОбновлено: $arg1';
  }

  @override
  String get textEnabled472 => 'Включён';

  @override
  String get textInstanceLabel473 => 'Название экземпляра';

  @override
  String get textProprietary474 => 'Проприетарная';

  @override
  String get textUnspecified475 => 'Не указана';

  @override
  String get chooseLanguage =>
      'Выберите язык интерфейса. Изменения применяются сразу и сохраняются для следующего запуска.';

  @override
  String get russianLanguage => 'Русский';

  @override
  String get englishLanguage => 'Английский';

  @override
  String get workspace => 'Рабочее пространство';

  @override
  String get recentSessions => 'Последние сессии';

  @override
  String get simulatorNotice =>
      'Устройство ещё не подключено — сессия запустится на встроенном симуляторе сигнала (256 Гц, 1 канал).';

  @override
  String get deviceSimulatorDescription =>
      'Встроенный генератор сигнала (256 Гц, 8 каналов). Используется для разработки без железа.';

  @override
  String get deviceBoardDescription =>
      'Первый реальный HAL-драйвер (USB/serial). Требуется прошивка с потоковой передачей.';

  @override
  String get pipelineOfflineNotice =>
      'Ядро офлайн: цепочка инициализируется при старте сессии. Запустите тестовую сессию на экране «Сессия».';

  @override
  String get markerInstructions =>
      'Добавьте маркер флагом на панели — он привяжется к текущему времени сигнала.';

  @override
  String get spectrogramVersionNotice =>
      'Сейчас STFT считается в Dart для наглядности. В v0.2 спектрограмма перейдёт на данные нативного ядра (core.diagnostics) с тем же UI.';

  @override
  String get datasetsRoadmap =>
      'v0.2: импорт сессий и внешних файлов (EDF/CSV), группировка по экспериментам, теги, сравнение датасетов и сессий — всё без написания кода.';

  @override
  String get modelsRoadmap =>
      'v0.2: обучение моделей на датасетах (батчи, кластеры спектрограмм), интеграция обученных моделей как Entities, экспорт/загрузка в ONNX через Model Registry & Runtime.';

  @override
  String logSaved(String path) {
    return 'Сохранено: $path';
  }

  @override
  String logSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String logPausedCount(int count) {
    return 'Пауза — новые строки не подгружаются ($count)';
  }

  @override
  String logVisibleCount(int visible, int total) {
    return 'Строк: $visible / $total · файл: latest.log (обновление 0,4 с)';
  }

  @override
  String sessionHistoryDetails(
    String backend,
    int seconds,
    int frames,
    String rms,
  ) {
    return '$backend · $seconds с · $frames кадров · RMS $rms';
  }

  @override
  String workspaceCounts(int modules, int connections) {
    String _temp0 = intl.Intl.pluralLogic(
      modules,
      locale: localeName,
      other: '$modules модуля',
      many: '$modules модулей',
      few: '$modules модуля',
      one: '$modules модуль',
      zero: '0 модулей',
    );
    String _temp1 = intl.Intl.pluralLogic(
      connections,
      locale: localeName,
      other: '$connections соединения',
      many: '$connections соединений',
      few: '$connections соединения',
      one: '$connections соединение',
      zero: '0 соединений',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String versionLabel(String app, String version, String core, int abi) {
    return '$app $version · ядро $core (ABI $abi)';
  }

  @override
  String get previewSignalSource => 'Источник сигнала';

  @override
  String get previewBandpassFilter => 'Полосовой фильтр';

  @override
  String get previewNotchFilter => 'Режекторный фильтр';

  @override
  String get previewChannelMixer => 'Микшер каналов';

  @override
  String get previewFftAnalyzer => 'Анализатор FFT';

  @override
  String get previewFeatureExtractor => 'Извлечение признаков';

  @override
  String get previewArtifactDetector => 'Детектор артефактов';

  @override
  String get previewSignalViewer => 'Просмотр сигнала';

  @override
  String get previewSignalNotes => 'Заметки о сигнале';

  @override
  String get previewSessionBrowser => 'Обзор сессий';

  @override
  String get previewDatasetTools => 'Инструменты датасетов';

  @override
  String get previewResearchDashboard => 'Панель исследования';

  @override
  String get previewAcquisition => 'Получение сигнала';

  @override
  String get previewDsp => 'ЦОС';

  @override
  String get previewRouting => 'Маршрутизация';

  @override
  String get previewAnalysis => 'Анализ';

  @override
  String get previewMl => 'Машинное обучение';

  @override
  String get previewVisualization => 'Визуализация';

  @override
  String get previewNotes => 'Заметки';

  @override
  String get previewWorkflow => 'Рабочий процесс';

  @override
  String get previewData => 'Данные';

  @override
  String get previewBadge => 'Демо';

  @override
  String get previewDescription =>
      'Локальная заглушка для проверки канваса, портов и авторского интерфейса. Обработка сигнала и выполнение пакетов отключены.';

  @override
  String get previewExtensionDescription =>
      'Локальная заглушка расширения для проверки каталога и рейла. Внешний код не исполняется.';

  @override
  String previewSummary(String category) {
    return 'Демонстрационный модуль категории «$category» для проверки интерфейса и перетаскивания.';
  }

  @override
  String get previewNotice =>
      'Демонстрационный интерфейс — элементы управления сохраняют значения только локально. Исполняемый модуль не установлен.';

  @override
  String get previewExtensionNotice =>
      'Демонстрационная область расширения для проверки расположения.';

  @override
  String get previewGain => 'Усиление';

  @override
  String get previewMode => 'Режим';

  @override
  String get previewStandard => 'Стандартный';

  @override
  String get previewLowLatency => 'Низкая задержка';

  @override
  String get previewHighPrecision => 'Высокая точность';

  @override
  String get shapeWaves => 'волны';

  @override
  String get shapeContours => 'контуры';

  @override
  String get shapeGrid => 'сетка';

  @override
  String get iconModule => 'модуль';

  @override
  String get iconSignal => 'сигнал';

  @override
  String get iconBrain => 'мозг';

  @override
  String get iconChart => 'график';

  @override
  String get iconTerrain => 'рельеф';

  @override
  String get iconNotes => 'заметки';

  @override
  String get iconMoon => 'луна';

  @override
  String get iconSun => 'солнце';
}
