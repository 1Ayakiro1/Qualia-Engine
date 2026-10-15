# Инструкция для нейросети: создание модулей Qualia Engine

Контракт **Alpha 0.5.1**, `schemaVersion: 1`, `process-v1`, IPC `protocol: 1`.
Если работаешь с более старым движком, не считай portable/TCP и новые лимиты
доступными: они добавлены в 0.5.1. Не меняй host ради нового языка модуля.

Используй этот документ как контракт реализованного локального runtime, а не
как описание будущих WASM, Marketplace или высокочастотных API.

## 0. Выбор режима до написания кода

| Задача | Поставка | Требования на машине пользователя |
|---|---|---|
| Общий Python/JS-скрипт, Java/.NET-байткод без native deps | `platform: portable`, `launch.launcher` | Явно установленный совместимый runtime и зависимости |
| C/C++/Rust/Go или самодостаточная среда | `platform` + `launch` либо `targets` | Совместимая ОС/ABI, loader/system baseline |
| Один релиз для нескольких desktop ABI | Один `.qmod`; общие ресурсы один раз, native варианты в `targets/` | Только реально включённые/проверенные ABI |
| Простая интеграция | Без `transport`: stdin/stdout NDJSON | Ничего сетевого |
| Программа с TCP listener | `transport.type: tcp`, тот же NDJSON | Доступный endpoint, права bind/firewall |

Шесть ABI — Linux/Windows/macOS × x64/ARM64, не Android/iOS. Переносимость Python
определяется интерпретатором и зависимостями, не наличием JIT; JVM/.NET/WASM runtime
тоже платформенные. Не обещай, что произвольный C++ executable работает на всех ОС.
Не включай копию Python/JVM в каждый portable-пакет: такой режим специально
предполагает внешнюю среду. Для автономной поставки используй native targets.

## 1. Обязательные архитектурные правила

1. Модуль — доверенная самостоятельная программа для Linux/Windows/macOS x64/arm64.
   Движок не определяет язык и не загружает библиотеки модуля в свою память.
2. Один узел → один процесс. Вся изменяемая память экземпляра принадлежит ему.
   Окна/Inspector не запускают дополнительные вычислительные процессы.
3. Поставка — `.qmod`, без автоматических pip/npm/go get/скачиваний при запуске.
   Для самодостаточного нативного пакета положи runtime, стандартную библиотеку,
   зависимости и лицензии внутрь пакета. Для одного общего скрипта/байткода есть
   явный `platform: "portable"` с внешним `launch.launcher`: нужный runtime
   устанавливает пользователь. Не выдавай такой пакет за полностью автономный.
4. Не используй абсолютные пути build-машины, пользовательский home,
   фиксированные имена временных файлов, глобальные порты для состояния узла.
5. Межъязыковые библиотеки связывай внутри процесса через FFI/линковку;
   разные модули связывай через порты общего протокола. Новое имя языка не
   требует регистрации в движке. `languages` — только информационное поле.
6. Модуль не является security sandbox. Не заявляй изоляцию файлов/сети,
   CPU/RAM, подписи или автоматическую проверку безопасности зависимостей.

## 2. Минимальный манифест для любого языка

```json
{
  "format": "qualia-module", "schemaVersion": 1,
  "id": "my-filter", "name": "My Filter", "version": "0.1.0",
  "runtime": "process-v1", "platform": "linux-x64",
  "languages": ["Any language"],
  "launch": {"executable": "bin/module", "arguments": []},
  "ports": {"inputs": ["input"], "outputs": ["output"]},
  "portSchemas": {
    "inputs": {"input": {"type": "number"}},
    "outputs": {"output": {"type": "number"}}
  },
  "ui": [
    {"id": "gain", "type": "number", "label": "Gain", "default": 1},
    {"id": "result", "type": "label", "label": "Result"}
  ]
}
```

- ID: `[a-z][a-z0-9-]{1,63}`; версия: три целых компонента; имя: 1–80 символов.
- IDs портов/полей: `[a-zA-Z][a-zA-Z0-9_]{0,63}`; никаких пробелов.
- В нативном режиме `launch.executable` — **реальный executable целевой ОС/ABI** (ELF, PE или Mach-O), путь внутри пакета.
  Это программа, bundled интерпретатор или launcher/loader, не shebang-скрипт
  и не `/usr/bin/env`. Движок не использует shell.
- `launch.arguments` — до 32 строк длиной до 4096 символов. Никакой shell
  интерполяции; пути в аргументах учитывают cwd = корень пакета. Формат допускает
  обычные флаги интерпретатора. Самодостаточный нативный пакет не должен ссылаться
  на внешний runtime; portable-пакет, напротив, объявляет его явно.
- Совместимость legacy C++: `runtime: native-process-v1`,
  `entrypoint: bin/module`; тот же протокол версии 1, без аргументов.
- Новая ОС/архитектура или версия протокола — отдельная совместимость, не язык.

Для универсального архива заменяй одиночные `platform` и `launch` на `targets`:
ключи `linux-x64`, `linux-arm64`, `windows-x64`, `windows-arm64`, `macos-x64`,
`macos-arm64`; значения — `{ "executable": "targets/<target>/module", "arguments": [] }`.
Поставляй реально собранные runtime/библиотеки для каждого target. Не смешивай
`targets` с одиночными полями. Полный контракт: [UNIVERSAL_MODULES.md](UNIVERSAL_MODULES.md).

Для общего portable payload без копий по ABI используй вместо `targets`:

```json
"platform": "portable",
"launch": {"launcher": "python3", "executable": "main.py", "arguments": []}
```

`launcher` — команда внешнего runtime (либо карта команд по шести desktop ABI).
`executable` — скрипт/байткод внутри пакета. Путь вставляется первым аргументом;
для Java `arguments: ["-jar", "{entrypoint}"]` задаёт его позицию явно.
Нативные wheels/JNI/OS-specific API не становятся переносимыми от этого режима.

Для TCP добавь `"transport":{"type":"tcp","host":"127.0.0.1","port":0}`.
Модуль поднимает listener; host подключается и использует тот же NDJSON-контракт.
`0` выбирает независимый loopback-порт для экземпляра: читай
`QUALIA_MODULE_HOST`/`QUALIA_MODULE_PORT` либо используй целые аргументы
`{host}`/`{port}`. Фиксированные порты 1–65535 и сетевые IP/DNS тоже поддерживаются,
но учитывай конфликты, права ОС, firewall и отсутствие встроенных TLS/auth.

Структура payload:

```text
manifest.json                # SDK берёт его из корня проекта, не из payload
payload/bin/module           # compiled программа (либо launch runtime/...)
payload/runtime/...          # интерпретатор + stdlib + third-party deps
payload/src/...              # исходный код интерпретируемого модуля
payload/lib/*                # при необходимости: .so/.dll/.dylib
payload/assets/...
payload/licenses/...
```

Пакет: ZIP STORE, ≤2 GiB **включая ZIP**, ≤4096 файлов; manifest ≤1 MiB.
Только обычные файлы, без symlinks, directory entries, traversal, шифрования,
дублирующихся путей, NUL и абсолютных путей. Дереференсируй runtime symlinks
при подготовке payload. Установщик выставляет разрешение запуска ELF/Mach-O на Unix.
SHA-256 проверяет пакет и установленные файлы перед запуском; это не подпись.

## 3. Протокол (одинаков для всех языков)

Строго UTF-8 NDJSON через stdin/stdout либо TCP transport из manifest: один JSON
object на строку, всегда flush. stdout **только протокол**, логи — stderr.
До 1 MiB на кадр/manifest, 1000 кадров/сек, очередь host-write ≤128; ready за
≤5 секунд.

Предел кадра — **1 048 576 UTF-8 байт всего JSON**, без LF. Не считай только
`value` или символы строки: поля envelope и Unicode тоже занимают байты.
Предел архива — **2 147 483 648 байт**, включая ZIP overhead; сумма payload тоже
не должна его превышать. Это не лимиты RAM/CPU процесса. Превышение размера,
невалидный UTF-8/JSON, handshake или rate limit останавливает экземпляр.
Host не перезапускает аварийно завершившийся узел автоматически; выключи/включи
его для повторного запуска. Сохраняй ошибки в stderr и заверши процесс с кодом ≠0.

Первое сообщение модуля:

```json
{"type":"ready","protocol":1}
```

Необязательный `requires: ["port-schemas-v1"]` указывает обязательные возможности.
Host отклоняет неизвестные требования. `init` сообщает доступные возможности
(`port-schemas-v1`, `host-logic-v1`); это не разрешения OS/security capabilities.
Дополнительные необязательные поля нужно игнорировать для совместимости.

| Направление | Сообщение |
|---|---|
| host → module | `{"type":"init","protocol":1,"instanceId":"...","parameters":{"gain":1},"capabilities":["..."]}` |
| host → module | `{"type":"parameters","values":{"gain":2}}` — полный набор |
| host → module | `{"type":"input","port":"input","value":3,"hops":31}` |
| host → module | `{"type":"event","id":"run","value":true}` |
| module → host | `{"type":"state","values":{"result":6}}` |
| module → host | `{"type":"output","port":"output","value":6,"hops":31}` |

`init.parameters` и `parameters.values` содержат **только объявленные параметры**
и defaults, не host label/enabled/скрытие/цвета и не button/label state.
Используется `parameters`, если это список, иначе legacy `ui`.
Для новых модулей объявляй контролы в `ui`: его проверяет SDK и renderer.
State разрешён только для `ui` label и `uiLayout` value/chart IDs.
State не сохраняется в workspace. Button — событие, не сохраняемый параметр.

Сохраняй полученный `hops` при обработке входа: host уменьшает его на каждом ребре,
включая встроенную логику. Самостоятельные события могут начинать с 32.
Не восстанавливай бюджет на ответах входного сообщения. Даже если значение
не меняется, используй стабильный port ID, не отображаемое название.

Схемы — ограниченный контракт, **не полный JSON Schema**; см.
[LOGIC_BLOCKS.md](LOGIC_BLOCKS.md). Описывай нужные поля, `required` и
`additionalProperties: false`, когда лишние поля недопустимы.

## 4. UI без дополнительных runtime-зависимостей

Контролы `slider`, `toggle`, `select`, `text`, `number`, `button`, `label` рисует
host. `uiLayout` размещается **только внутри активной области**; не меняй shell,
Explorer, окна или навигацию. Это не HTML/JS/WebView/Flutter-плагин.

Доступны `column`, `row`, `card`, `text`, `value`, `input`, `button`, `chart`,
`divider`, `spacer`; layout ≤512 элементов, глубина ≤12, children ≤64.
Interactive IDs должны быть объявлены в `ui`. Пример и полный порядок —
[LOCAL_MODULES.md](LOCAL_MODULES.md).

## 5. Сборка и упаковка

### C++ (готовый offline SDK)

```bash
python3 app/assets/module_sdk/qmod.py create /path/to/project
python3 /path/to/project/qmod.py check /path/to/project
python3 /path/to/project/qmod.py build /path/to/project
```

SDK включает JSON header. Свои `.so` положи в `lib/`; RPATH —
`$ORIGIN/../lib`. Не полагайся на LD_LIBRARY_PATH build-машины.

### Go

Пример: `modules/examples/go/`. Скопируй manifest в корень своего проекта,
скомпилируй в `payload/bin/module`:

```bash
mkdir -p /path/to/project/payload/bin
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o /path/to/project/payload/bin/module modules/examples/go/main.go
python3 app/assets/module_sdk/qmod.py pack /path/to/project
```

Это не требует системного Go на машине пользователя. Если включён CGO,
упакуй нативные зависимости и проверь libc baseline/RPATH отдельно.

### Python и другие интерпретируемые языки

**Portable-вариант:** используй `modules/examples/portable/`. Он содержит полный
рабочий Python runner (лимиты UTF-8, flush, handshake, state/output, stdio/TCP),
а не только псевдокод. Для stdio достаточно исходного manifest; упаковка:

```bash
python3 app/assets/module_sdk/qmod.py check modules/examples/portable
python3 app/assets/module_sdk/qmod.py pack modules/examples/portable
```

Для независимых TCP-экземпляров полный manifest выглядит так:

```json
{
  "format": "qualia-module", "schemaVersion": 1,
  "runtime": "process-v1", "platform": "portable",
  "id": "portable-echo", "name": "Portable Echo TCP", "version": "0.1.0",
  "languages": ["Python"],
  "launch": {
    "launcher": {
      "linux-x64": "python3", "linux-arm64": "python3",
      "windows-x64": "python", "windows-arm64": "python",
      "macos-x64": "python3", "macos-arm64": "python3"
    },
    "executable": "main.py",
    "arguments": ["--tcp", "{host}", "{port}"]
  },
  "transport": {"type": "tcp", "host": "127.0.0.1", "port": 0},
  "ports": {"inputs": ["input"], "outputs": ["output"]},
  "ui": [{"id": "result", "type": "label", "label": "Result", "default": ""}]
}
```

Положи runner из примера в `payload/main.py`. Меняй manifest в отдельной копии
проекта, не заменяй исходный пример. SDK берёт manifest из корня, а payload —
из `payload/`; `dist/` не включай в payload. Для Java команда будет
`launcher: "java", executable: "module.jar", arguments: ["-jar", "{entrypoint}"]`.
Для .NET — `launcher: "dotnet", executable: "Module.dll"`; assembly располагай
вне `lib/`, где разрешены только native shared libraries.

**Самодостаточный вариант:**
Собери relocatable runtime для выбранной платформы, включи библиотеки и лицензии.
Укажи bundled ELF в `launch.executable`, а код и флаги — в `arguments`.
Проверь поиск stdlib/native libs, отключи пользовательский site/environment
там, где это поддерживает runtime. Никаких pip/npm при запуске.

На Windows не используй locale-dependent `sys.stdin` для UTF-8 IPC. Читай
`sys.stdin.buffer`, передавай bytes в `json.loads`, пиши UTF-8 bytes через
`sys.stdout.buffer` с flush, как в portable runner. То же относится к socket
streams. Не рассчитывай на `PYTHONUTF8` или кодировку терминала пользователя.

JSON-only Python demo можно собрать офлайн из установленного на **build-машине**
CPython; helper копирует interpreter, loader, libc/libpython и Python stdlib:

```bash
python3 modules/examples/python/prepare_demo.py /path/to/python-demo
python3 app/assets/module_sdk/qmod.py pack /path/to/python-demo
```

Этот helper — демонстрация, **не универсальный сборщик Python-пакетов**:
не копирует native extensions/site-packages и не гарантирует переносимость
любого host CPython на другую систему. Для NumPy/SciPy/EEG SDK нужно отдельно
подготовить полную среду, совместимые `.so` и redistributable лицензии.
Не публикуй build-machine runtime без проверки лицензий и OS baseline.

### Готовый payload любого языка

```bash
python3 app/assets/module_sdk/qmod.py check /path/to/project
python3 app/assets/module_sdk/qmod.py pack /path/to/project --payload /path/to/payload
```

`pack` ничего не компилирует и не скачивает; результат — `project/dist/id-version.qmod`.
Для mixed-language модуля runtime/FFI запускает авторская программа внутри
одного вычислительного процесса; движку не нужен список языков для исполнения.

## 6. Проверка перед передачей пользователю

1. Проверь manifest SDK и установщиком движка; оба должны принять пакет.
2. Запусти extracted payload с cwd в его корне. Для самодостаточного варианта
   исключи системный интерпретатор/PATH/PYTHONHOME/PYTHONPATH; для portable
   установи только заявленную среду и проверь понятную ошибку при её отсутствии.
   Stdio проверяй без сети, TCP — с loopback listener. Проверь ready, init,
   input, events, flush, Unicode, null, неверные типы и schema rejection.
3. Установи через Explorer → **Добавить локально (.qmod)** с подтверждением доверия.
4. Создай два экземпляра: разные PID и независимое состояние. Соедини порты;
   добавь IF → выбор полей → проверку схемы и проверь обе ветки.
5. Проверь host UI, fullscreen, отдельное окно, выключение узла, смену workspace,
   аварийное завершение без гибели соседних модулей.
6. Перенеси пакет в другой каталог/другую поддерживаемую Linux-систему;
   проверь libc/loader baseline и все внешние зависимости. ELF header сам по себе
   не доказывает самодостаточность, ABI-совместимость или безопасность.
7. Обновление: увеличь version, собери новый immutable пакет. Не меняй файлы
   установки вручную. Workspace metadata не авторизует запуск executable.
8. Сдай исходники, manifest, инструкции сборки, `.qmod`, лицензии, результаты
   тестов и явно назови непроверенные платформы/языковые toolchains.

## 7. Чего нельзя обещать

- Не добавляй Docker/сетевые сервисы как обязательную зависимость движка.
- Не передавай высокочастотный EEG через JSON. SampleBlock/binary/shared-memory
  для внешних модулей ещё не реализован: это отдельный версионированный транспорт.
- Marketplace сейчас metadata-only, не установка удалённых исполняемых пакетов.
- Нет подписей пакетов, process-tree sandbox или автоматического dependency audit.
- Поддержка «любого языка» означает общий контракт и packaged runtime, а не
  автоматический запуск произвольных исходников без необходимой среды.

## 8. TCP: последовательность и диагностика

1. Host проверяет установленный пакет и запускает **один процесс на узел**.
2. При loopback port 0 host выбирает порт и передаёт его через environment и/или
   целые аргументы `{host}`/`{port}`. Подстановка внутри `--port={port}` не работает.
   Port 0 разрешён только для `127.0.0.1` или `::1`, не `localhost`/внешнего адреса.
3. Модуль делает bind/listen, host подключается. Это **не** схема, где модуль
   подключается к listener движка. При фиксированном endpoint автор отвечает за
   уникальность портов/привязку соединения к экземпляру. Между выбором свободного
   порта и bind остаётся окно гонки: не скрывай bind errors.
4. По TCP модуль отправляет `ready`, затем читает `init`; дальше контракт тот же.
   TCP — поток, границы `recv()` не совпадают с кадрами. Буферизуй до LF,
   принимай фрагменты и несколько кадров за один recv, ограничивай буфер **до** parse.
5. В TCP-режиме stdout/stderr не являются IPC; host дренирует их без накопления.
   В stdio-режиме stdout — только NDJSON. Не пиши приветствия/логи в протокол.
6. Закрытие TCP-соединения считается ошибкой экземпляра. Host убивает процесс
   при отключении узла, смене workspace и завершении; не рассчитывай на обязательный
   `stop`/graceful shutdown. Собственные дочерние процессы убирай самостоятельно.

| Симптом | Что проверить |
|---|---|
| Runtime/executable not found | Установлен ли внешний launcher, видит ли GUI его PATH, верное ли имя для текущей ОС |
| Handshake timeout | Listener стартует до 5 секунд, host/port совпадают, ready отправлен и flush выполнен |
| Второй экземпляр падает | Используй port 0 + environment/аргументы, не один глобальный порт |
| Invalid protocol frame | Только UTF-8 JSON object + LF, без логов, NaN, BOM или произвольных бинарных данных |
| Frame too large | Размер сериализованного envelope, Unicode и escaping; деление данных на сообщения по контракту автора |
| Installed package is damaged | Не редактируй установленный каталог; собери и установи новую immutable версию |
| Unsupported platform/ABI | Нужный target отсутствует/неверно собран; portable не исправляет native deps |

Собственные HTTP/UDP/TCP соединения процесса разрешены правами ОС и не требуют
нового host API. Связи workspace всё равно маршрутизирует host; прямое обнаружение
и сетевой протокол module-to-module авторы реализуют сами. Здесь нет remote-only
runtime, Docker, TLS/auth или открытия firewall от имени движка.

## 9. Версии и экономия хранилища

- Один модуль + одна версия → одна release-запись и один `.qmod`/`package_path`,
  а не шесть одинаковых публикаций. В portable храни общие исходники/байткод один раз.
- В `targets` общие скрипты/ресурсы тоже лежат один раз, а бинарники различаются по ABI.
  Один ZIP не убирает вес разных native runtimes. Не выдавай упаковку за дедупликацию.
- Смена содержимого требует увеличения `version`; workspace требует точную
  установленную версию/hash. Нет semver range resolver или автоматического обновления.
- Дедупликация между разными версиями, общий runtime manager, cleanup старых релизов,
  автоматическое перенесение существующих объектов Supabase ещё не реализованы.
- Для больших файлов Storage bucket limit 2 GiB недостаточен без глобального
  лимита и подходящего тарифа. Миграция включена в исходники, не применяется
  программой автоматически. Не используй service-role key в desktop-клиенте.

## 10. Формат результата работы нейросети

Перед кодом назови: целевые ОС/ABI, runtime и его версию, stdio/TCP, portable либо
самодостаточную поставку, native зависимости и ограничения переносимости.
Если требований не хватает — уточни их, не придумывай возможность host.

Сдай:

1. Полный проект с исходниками и manifest, без build-machine абсолютных путей.
2. Команды check/build/pack, версии toolchains, список/лицензии зависимостей.
3. `.qmod`, его SHA-256 и краткую инструкцию установки/соединения портов.
4. Проверки двух независимых экземпляров, Unicode и граничных размеров,
   штатного отключения/аварии и TCP closure для сетевого модуля.
5. Таблицу «проверено запуском / только собрано / не проверено» по платформам.

Не называй результат готовым, если приведён только пример JSON или header
прошёл проверку: нужны работающий payload и реальный запуск через движок.
