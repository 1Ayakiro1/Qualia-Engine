# Changelog

## [0.5.2-dev.4] — 2026-10-29 (development snapshot, not a 0.5.2 release)

- Add protruding circular input/output ports while preserving stable graph
  coordinates and connection endpoints.
- Add a Workspace canvas tool rail for selection, freehand annotations,
  connection cutting and output branching.
- Persist canvas annotations in workspace projects and packages.
- Move module and Logic Block creation into the Workspace inspector while
  keeping the Explorer optional for the rest of the shell.
- Make Workspace canvas width and height configurable per project, with safe
  limits and legacy-project defaults; empty canvas area is not serialized.
- Improve connection curves with anti-aliased strokes and stable reverse-edge
  geometry, and keep Linux rendering on the monitor's native GTK refresh clock
  for high-refresh displays when using the native embedder build.

## [0.5.2-dev.3] — 2026-10-29 (development snapshot, not a 0.5.2 release)

- Add native-style hover switching for shared horizontal desktop menus, including
  Workspace toolbar menus.
- Add Workspace magnetic placement with optional grid and module-edge snapping,
  collision avoidance, rounded selection and Logic Blocks controls.
- Add canvas module hiding, Explorer selection synchronization, a compact active
  modules list above settings, and Workspace Explorer visibility control.
- Keep the canvas in a finite 10,000 × 10,000 scene with stable clamped movement
  instead of wrapping coordinates and breaking saved graph geometry.

## [0.5.2-dev.2] — 2026-10-29 (development snapshot, not a 0.5.2 release)

- Add explicit workspace checkpoints (Ctrl+S / File → Save), separate crash-recovery
  drafts, first-save naming and native close protection with save/discard/cancel.
- Show undo/redo feedback in a compact five-second bottom notification.
- Add persisted top/bottom rail zones, drag-to-pin and direct pin controls, plus
  animated icon return to the unused-items panel on removal.
- Match module picker density to top-bar menus; enable hover switching between
  open top-bar menus. Unify Marketplace outer/filter/catalog spacing to 20px.
- Lock hidden canvas instances against selection, drag, edit and keyboard focus;
  keep their graph and runtime active independently of visibility.
- Use shared monochrome pill toggles throughout the app; simplify module settings
  composition and remove module descriptions. Match Logic Blocks Explorer typography.
- Replace rail settings dialog with an in-shell customization mode: dimmed
  workspace, adjacent compact panel, hold-to-drag buttons, animated insertion,
  reorder/add/remove, persistent mixed section/extension ordering and keyboard controls.
- Keep canvas selection borders visible for mouse and keyboard independently of
  navigation focus, above opaque node headers; preserve port geometry.
- Remove the Marketplace filter/catalog divider while retaining its resize target;
  normalize filter rows and compact action hit targets.
- Open directly on the module workspace/canvas, including return from settings/profile.
- Unify Explorer section spacing, slightly recess search fields, and align workspace
  toolbar button heights. Show module dots only for packages placed on the active canvas;
  make the hidden-module eye an immediate reveal action.
- Replace module-add dialogs with compact, palette-matched context menus without titles
  or dimming. Complete a wire on empty canvas to choose and connect a new module.
- Add bounded session undo/redo (Ctrl+Z, Ctrl+Shift+Z / Ctrl+Y) for workspace edits,
  including Explorer removal across projects, library references, settings and links;
  group pointer drags and connected-node creation into single undo steps.
- Keep a single current artifact set in `builds/<VERSION>/`; stage complete builds
  before replacement, remove obsolete packages/backups, generate SHA256SUMS.
- Formalize internal (host-routed instance ports), middle (module/host process-v1)
  and external (engine/service adapters) API boundaries in SDK metadata and agent docs.
- External AI development API 1.1.0: additive `api.describe`, `apiLayers` context
  and layer-aware change plans; preserve module wire protocol 1 and existing routes.

## [0.5.2-dev.1] — Earlier development work (not a 0.5.2 release)

- Add local JSON-RPC 2.0 `qualia-ai` API for manifest/workspace validation,
  safe fork lineage, SemVer comparison and reviewed engine change plans.
- Add `qualia.lock.json` plus dependency/plugin/native/toolchain snapshot and
  version consistency checks for AI and CI consumers.
- Add immutable workspace `revision` metadata with parent digest/revision for
  reproducible forks; legacy workspace packages remain readable.
- Additive native C ABI 3: exclusive owned/wrapped timestamped float32 blocks,
  interleaved/channel-major layout, zero-copy ownership push/process/pop.
- Bounded native queues with independent input/output backpressure policies and
  byte budgets. Remove unsafe producer dequeue from an SPSC queue. Preserve FIFO
  across partial legacy reads; stop wakes a blocked lossless output worker.
- Draft C++/Python QSB2 chunk codecs with shared conformance header, CRC and bounded
  assembly. Not yet host protocol-v2, TCP session negotiation or shared memory.
- Full ML/HAL/runtime/Storage/Registry/job/UI/trust release gates tracked in
  `docs/ML_RUNTIME_V2.md`; 0.5.2 is NOT published or complete.

## [0.5.1] — Alpha: portable modules and TCP

- UTF-8 NDJSON frames and manifests up to 1 MiB, with byte-accurate boundary checks.
- `.qmod` archives up to 2 GiB including ZIP headers; chunked file-backed installation,
  CRC/file-integrity checks and header-only native ABI inspection.
- Optional TCP module transport with fixed IP/DNS ports or per-instance loopback
  ports, preserving the existing ready/init/routing protocol and process supervision.
- Single-payload `platform: portable` packages with explicit external runtime launchers,
  per-ABI command names and `{entrypoint}` argument positioning. Native targets remain supported.
- Portable Python stdio/TCP example and regression tests for transport isolation,
  message boundaries, corrupt packages and installation near the 2 GiB limit.
- Expanded AI module-authoring guide, source archives and desktop release packages.
- Prepared private Supabase bucket limit migration; deployment/global Storage limits
  remain separate. Docker and cross-version artifact deduplication are not implemented.

## [0.5.0] — Alpha: logic and universal modules

- Host-owned IF/filter/select/validate/script nodes and schema-checked routing.
- Language-independent bundled runtimes and universal `.qmod` target selection
  for Linux/Windows/macOS x64/arm64, backward-compatible legacy Linux packages.
- Cross-language NumPy/OpenBLAS/C FFI/C++ shared library/Go integration tests.
- Automatic macOS native-core embedding, Windows DLL verification and desktop CI.
- Module management, custom active views and independent workspace transfers.
- AI authoring guide and release notes: `docs/releases/ALPHA_0.5.0.md`.

## [0.4.3] — Profile login and shortcuts polish

- Profile workspace заменён на экран `Log in with:` с провайдерами Github,
  Google и Gmail.
- Модальное окно Keyboard shortcuts расширено примерно на 20% по ширине.
- Из заголовка Keyboard shortcuts убраны иконка и дополнительный текст.
- Убрано лишнее пояснение про ввод новой комбинации клавиш.
- `Edit shortcuts` оформлена в едином стиле интерфейса с компактным hover и
  active-состояниями.

## [0.4.2] — Help menu and theme selection

- В header добавлено меню `Help` с разделами Documentation, About Us, Welcome,
  Tutorials, License, Check updates, Report Issue и Our Youtube.
- В меню `View` добавлен пункт `Theme` с вариантами `System`, `Dark` и `White`.
- Светлая тема применяется сразу и распространяется на shell, меню, диалоги и
  остальные Material overlays; `System` следует системной настройке.
- Добавлены UI-тесты для Help menu и переключения всех вариантов темы.

## [0.4.1] — Qualia Engine UI polish

- Репозиторий и локальная рабочая папка переименованы в Qualia Engine.
- Keyboard shortcuts расширены: action rows и key fields теперь без лишних
  borders, поле комбинации шире и центрировано для более чистого desktop-вида.
- Исправлен квадратный hover/focus state у кнопок действий в tab bar.
- После открытия/закрытия terminal panel shell возвращает keyboard focus;
  shortcuts масштаба продолжают работать без дополнительного клика.

## [0.4.0] — Extensions workspace and shortcut surfaces

- Extensions приведён к IDE-структуре Modules: отдельный Explorer, фильтры,
  единый tab-bar, активная рабочая область и опциональный Extension Inspector.
- Для Extensions добавлена отдельная иконка `auto_awesome_mosaic_outlined`,
  визуально отличающая её от Modules.
- Панель выбора пользовательского режима теперь доступна поверх Extensions,
  Profile и Bug report так же, как в основном workspace layout.
- Keyboard shortcuts переработан в единый переиспользуемый компонент для
  Preferences и contextual menu глобального поиска: группировка, читаемые
  key-fields, режим редактирования и единый нейтральный стиль.
- В debug console добавлен верхний отступ над заголовком и управляющими
  кнопками.

## [0.3.9] — Standalone debug terminal

- Debug terminal вынесен в отдельный процесс и native window с независимым
  Flutter engine; основное приложение больше не зависит от его event loop.
- Добавлен режим `--debug-terminal` с lock-файлом для защиты от дубликатов,
  безопасным tail-ингом `latest.log` и восстановлением после временной ошибки
  доступа к файлу.
- Кнопка debug terminal запускает это отдельное окно, а
  `--with-debug-terminal` запускает приложение сразу вместе с терминалом.
- Добавлен helper `scripts/run_with_debug_terminal.sh` для запуска release bundle.
- Раздел `Pets` удалён из Preferences.

## [0.3.8] — Extensions workspace and rail workspaces

- Профиль теперь открывается в рабочей области с сохранённой rail-панелью и без
  Explorer/sidebar; основной контент расширяется на освободившееся место.
- Добавлена пустая рабочая область `Bug report` без табов и sidebar.
- Rail-кнопка `projects` заменена на `extensions`.
- Добавлена рабочая область Extensions со списком пользовательских расширений,
  фильтрами `Downloaded`, `Active` и `All`, индикатором скачанных расширений и
  вкладками для открытых расширений.
- Global search остаётся видимым в восстановленном окне, когда ширина позволяет
  показать верхнее меню.

## [0.3.7] — In-app debug terminal

- Немного увеличены интервалы между пунктами и группами в Preferences.
- Debug terminal теперь существует только внутри основного окна приложения.
- Убран detached/native console path, включая кнопку открытия отдельного окна.
- Внутренняя панель отладки стала перемещаемой: её можно перетаскивать за
  заголовок, при этом панель остаётся в пределах рабочей области.

## [0.3.6] — Tabs and module workspace

- У кнопок смены режима убраны borders: hover и активный режим теперь
  отличаются только подсветкой background.
- В editor tabs добавлена кнопка `+`, создание и закрытие вкладок, а при
  отсутствии открытых вкладок показывается пустое состояние с предложением
  создать новую вкладку.
- Верхний ряд Explorer заменён на `+`, `−` и карандаш в окне Modules; действия
  поддерживают добавление, удаление и редактирование модулей с hover-состояниями.
- Для Modules добавлены левый Explorer с переключателем видимости и правый
  Module Inspector с информацией и действиями выбранного модуля.
- В остальных окнах убран активный module-sidebar из Explorer.
- Кнопки сворачивания, восстановления и закрытия окна получили общий стиль
  tooltip; глобальный поиск сохраняет overlay при переходе окна в restore mode.

## [0.3.5] — Profile route and terminal interaction polish

- Rail-кнопка профиля теперь открывает отдельную страницу `Profile`, а не
  Preferences; добавлен самостоятельный экран локального профиля.
- Hover в Preferences стал заметно темнее активного состояния, поэтому
  выбранный пункт и наведённый пункт больше не смешиваются.
- Панель `Keyboard shortcuts` увеличена по ширине и высоте; строки стали выше,
  внутренние keycap-поля получили прозрачное заполнение и убран бордер.
- `Edit shortcuts` переработана в кнопку с тем же hover-стилем, что и строки
  контекстных панелей.
- Debug terminal перенесён во внутреннюю немодальную панель shell: открытие и
  закрытие больше не блокируют клики и горячие клавиши основного интерфейса.
  Увеличены панель, поиск, кнопки управления и текст логов.

## [0.3.4] — Preferences navigation and debug console polish

- Preferences получил рабочую навигацию по разделам: активная страница меняется
  по клику и показывает временный контент вида `Import 1`, `Account 1` и т. п.;
  все пункты и `Back to app` подсвечиваются при наведении.
- Исправлено разделение действий rail: `User profile button` открывает `Account`,
  а `projects` продолжает открывать обзор проектов.
- `Change mode` стал компактной панелью из квадратных icon-only кнопок с
  tooltip и отдельными hover/active-состояниями.
- Keyboard shortcuts разделены на функциональные группы `WORKSPACE` и
  `INTERFACE`, а строки и keycap-поля оформлены в том же скруглённом стиле,
  что и контекстные меню.
- Debug terminal получил кастомную верхнюю панель без GNOME header bar,
  переключатели уровней `DEBUG/INFO/WARN/ERROR`, поиск, паузу, автопрокрутку,
  сохранение и очистку. Окно открывается отдельно, не остаётся always-on-top,
  предотвращает повторное открытие и возвращает фокус основному приложению.

## [0.3.3] — Adaptive shell layout and scrollbar polish

- Scrollbar Explorer стал тоньше (`3px`), менее контрастным и с коротким thumb;
  трек прозрачен, а scrollbar скрывается, когда содержимое не требует прокрутки.
- Верхнее меню `File`, `Edit`, `View`, `Build` больше не исчезает при масштабе
  `150%`; поиск автоматически уступает место меню на узкой логической ширине.
- Исправлено масштабирование `80%`: shell теперь выравнивается от верхнего
  левого края и заполняет рабочее окно без пустых полей по краям.
- Добавлен перетаскиваемый resize handle для ширины Explorer/sidebar с
  адаптивными минимальными и максимальными границами.
- Центральная рабочая область корректно пересчитывает доступное место при
  изменении ширины sidebar и масштаба интерфейса.

## [0.3.2] — Shortcut and shell menu visual refresh

- Панель `Keyboard shortcuts` увеличена, получила более читаемую типографику,
  крупные строки действий, прокрутку и более выразительные keycap-поля.
- Из Preferences удалены разделы `Integrations` и `Coding`.
- Debug terminal перемещён в верхнюю часть интерфейса рядом с global search.
- Кнопка `Run` удалена из header; действие запуска осталось доступно в меню Build.
- Контекстные меню `File`, `Edit`, `View` и `Build` получили отдельные
  скруглённые строки с отступами и shortcut-плашками в стиле референса.

## [0.3.1] — Search and tooltip interaction polish

- Tooltip получили единый размер текста `14px` и задержку появления `1 секунда`.
- Global search перемещён в центр header и превращён в полноценное поле ввода.
- Активное поле поиска получает отдельную подсветку и принимает ввод текста.
- Контекстное меню поиска работает как toggle: повторный клик по полю закрывает
  меню, клик по любой области вне search-контекста также закрывает его.
- Добавлены регрессионные тесты фокуса, ввода, toggle и закрытия поиска.

## [0.3.0] — Preferences panel visual polish

- Панель смены режима переработана в полноценный popover: увеличена ширина,
  добавлен заголовок, подписи режимов, аккуратные состояния active/hover и
  информативные tooltip.
- Панель `Keyboard shortcuts` оформлена как центральная карточка с заголовком,
  описанием, секцией доступных комбинаций, keycap-полями и аккуратным footer.
- В режиме редактирования shortcut-поля получили отдельное визуальное состояние
  и понятную подсказку по назначению новой комбинации.
- Убраны переполнения layout на компактных размерах окна.

## [0.2.9] — Shell controls and shortcuts

- Исправлено выравнивание правого блока header: поиск, масштаб, `Run` и
  оконные кнопки прижаты к правому краю без смещения к центру.
- Убран статус `Engine online` из header.
- Исключены конфликтующие активные состояния rail-кнопок: одновременно
  подсвечивается только одна кнопка.
- Между `ACTIVE MODULES` и `MODULE CATALOG` добавлен визуальный divider.
- Поиск в header получил рабочую кнопку `Shortcuts` с hover-состоянием и
  центральной панелью горячих клавиш.
- Добавлен режим редактирования shortcut-комбинаций с захватом нажатых клавиш.
- Scrollbar Explorer уменьшен до 4 пикселей и оформлен в нейтральном стиле.

## [0.2.8] — Rail and mode switcher polish

- Поменяны местами пункты `projects` и `configs` в нижней и верхней части
  activity rail.
- Задержка tooltip activity rail сокращена до 1,33 секунды.
- Панель смены режима уменьшена до компактного блока с тремя плитками 64×64 и
  отступами 5 пикселей между плитками.
- Hover-подсветка rail-кнопок и пунктов контекстного меню переведена на явное
  состояние наведения мыши.

## [0.2.7] — Shell interaction polish

- Preferences теперь заменяют rail и Explorer на всём рабочем окне; выход
  выполняется стрелкой `Back to app`.
- Исправлено вертикальное выравнивание текста активного editor tab.
- Добавлены hover-состояния для пунктов контекстных меню и стилизованные
  tooltip activity rail с задержкой появления две секунды.
- В Explorer добавлен отдельный поиск активных модулей и скруглены оба поиска.
- Строки модулей стали выше, получили плавную подсветку при наведении, а
  отображение версий удалено для более чистого интерфейса.

## [0.2.6] — Preferences workspace and 120% density

- Базовая визуальная плотность shell увеличена до 120%, при этом пользовательский
  индикатор масштаба и значение по умолчанию остаются `100%`.
- В `File` добавлен рабочий пункт `Preferences` с возвратом в приложение.
- Экран настроек перестроен в двухколоночный preferences workspace с поиском,
  группами разделов и карточками параметров по макету.
- Убрана верхняя линия активной вкладки editor; кнопки activity rail получили
  более заметное скругление.

## [0.2.5] — Neutral shell palette

- Основные поверхности shell переведены на `#141414` и `#181818`.
- Бордеры унифицированы до `#272727`, основной текст — до `#bdbdbd`.
- Убраны голубые выделения активного tab и activity rail; активность теперь
  обозначается только разницей оттенков поверхностей.
- Снижено количество цветных акцентных деталей в верхней панели, меню и
  Explorer.

## [0.2.4] — Layout foundation and active modules

- Исправлен пересчёт логических размеров и `MediaQuery` при масштабировании
  интерфейса.
- Все модули каталога переведены в активное рабочее пространство.
- Добавлены контекстные меню `File`, `Edit`, `View`, `Build` и глобального
  поиска с горячими клавишами и временными заглушками.
- Добавлена основа динамического layout: независимые скруглённые поверхности,
  модель геометрии shell и изменяемые разделители rail/explorer.

## [0.2.3] — Масштабирование и обновлённый rail

- Добавлены соответствующие названиям Figma иконки activity rail.
- Добавлено масштабирование интерфейса: `Ctrl +`, `Ctrl -`, `Ctrl + 0`.
- Масштаб интерфейса по умолчанию увеличен до 110%; доступен выбор масштаба
  через индикатор процента в верхней панели.
- Удалён устаревший `dist/`; исходники упаковки перенесены в
  `scripts/packaging/`, а пользовательские артефакты собираются в `builds/`.
- Верхняя панель очищена от ENGINE и переключателя режима; добавлены
  собственные кнопки свернуть, развернуть/восстановить и закрыть окно.

## [0.2.2] — Релизная сборка

- Полная пересборка всех артефактов (бинарник, tar.gz, AppImage) из свежих
  исходников: фикс регистрации плагинов во втором окне (окно консоли логов),
  защитный `check_version.sh` по макросам версии, устойчивый `main()`.

## [0.2.1] — Папка builds/ и фикс окна консоли

## [0.2.1] — Папка `builds/` для пользователей

- Все готовые артефакты теперь в `builds/` в корне репозитория
  (вместо `dist-out/`): AppImage, tar.gz и готовый к запуску бинарник
  `builds/binary/`; `README.md` внутри папки объясняет, что с чем запускать.
- Скрипты, CI, `.gitignore` и документация переведены на новый путь;
  бинарники в git не попадают.

## [0.2.0] — Логгер + консоль в отдельном окне

- C++ ядро: `bci_engine_set_log_callback` (ABI 2), `core_log()` форвардит
  сообщения движка в Dart через потокобезопасный колбэк; тест Catch2 на колбэк.
- Dart: `AppLogger` (кольцевой буфер 5000 + `latest.log` + `session-*.log`),
  формат `[ISO-время] [LEVEL] [источник ] сообщение`.
- Отдельное окно «Консоль логов» (desktop_multi_window, тёмная GNOME-стилистика):
  фильтр уровня, поиск, пауза, автопрокрутка, сохранение видимого, очистка вида.
- Кнопка консоли в топ-баре + на дашборде; логируются запуск/загрузка ядра/сессии.
- `scripts/analyze.sh` (`dart analyze`) и авто-анализ в `build_linux.sh` через
  ASCII-симлинк — фикс падения `flutter analyze` на путях с кириллицей/пробелами.

## [0.1.0] — Скелет-каркас

## 0.1.0 — skeleton
- Flutter GUI: shell с навигацией по режимам (Потребитель/Исследователь/Разработчик),
  экраны: Обзор, Устройства, Сессия, Конвейер, Спектрограмма, Модули,
  Датасеты, Модели, Разработчик, Настройки.
- C++-ядро libbci_engine_core: движок с рабочим потоком, lock-free очереди
  (readerwriterqueue, с внутренним фолбэком), конвейер системных модулей
  (passthrough, gain, EMA-сглаживание, диагностика RMS/FFT, маркеры, рекордер).
- Стабильный C ABI + Dart FFI-биндинги, лоадер с деградацией офлайн.
- E2E-сессия: синтетический сигнал → ядро → live-метрики.
- Спектрограмма real-time (STFT-демо в Dart, маркеры событий).
- Тесты: Catch2 (ядро), flutter_test (UI/реестр/FFI).
- Сборка: AppImage + tar.gz + бинарник (Linux), zip (Windows/macOS), CI.
