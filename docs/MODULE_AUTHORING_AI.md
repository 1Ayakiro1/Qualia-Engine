# Инструкция для нейросети: создание модулей Qualia Engine

Используй этот документ как контракт реализованного локального runtime, а не
как описание будущих WASM, Marketplace или высокочастотных API.

## 1. Обязательные архитектурные правила

1. Модуль — доверенная самостоятельная программа для **Linux x86_64**.
   Движок не определяет язык и не загружает библиотеки модуля в свою память.
2. Один узел → один процесс. Вся изменяемая память экземпляра принадлежит ему.
   Окна/Inspector не запускают дополнительные вычислительные процессы.
3. Поставка — offline `.qmod`, без pip/npm/go get/скачивания при запуске.
   Для интерпретируемого языка положи runtime, стандартную библиотеку,
   зависимости и лицензии внутрь пакета. Системный Python/Node/Java не контракт.
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
- `launch.executable` — **реальный ELF x64**, путь внутри установленного пакета.
  Это программа, bundled интерпретатор или ELF launcher/loader, не shebang-скрипт
  и не `/usr/bin/env`. Движок не использует shell.
- `launch.arguments` — до 32 строк длиной до 4096 символов. Никакой shell
  интерполяции; пути в аргументах учитывают cwd = корень пакета. Формат допускает
  обычные флаги интерпретатора; автор обязан исключить ссылки на внешний runtime.
- Совместимость legacy C++: `runtime: native-process-v1`,
  `entrypoint: bin/module`; тот же протокол версии 1, без аргументов.
- Новая ОС/архитектура или версия протокола — отдельная совместимость, не язык.

Структура payload:

```text
manifest.json                # SDK берёт его из корня проекта, не из payload
payload/bin/module           # compiled программа (либо launch runtime/...)
payload/runtime/...          # интерпретатор + stdlib + third-party deps
payload/src/...              # исходный код интерпретируемого модуля
payload/lib/*.so[.N...]       # при необходимости: только shared libraries
payload/assets/...
payload/licenses/...
```

Пакет: ZIP STORE, ≤256 MiB **включая ZIP**, ≤4096 файлов; manifest ≤64 KiB.
Только обычные файлы, без symlinks, directory entries, traversal, шифрования,
дублирующихся путей, NUL и абсолютных путей. Дереференсируй runtime symlinks
при подготовке payload. Установщик сам выставляет разрешение запуска ELF.
SHA-256 проверяет пакет и установленные файлы перед запуском; это не подпись.

## 3. Протокол (одинаков для всех языков)

Строго UTF-8 NDJSON через stdin/stdout: один JSON object на строку, всегда flush.
stdout **только протокол**, логи — stderr. До 64 KiB на кадр,
1000 stdout кадров/сек, очередь host-write ≤128; ready за ≤5 секунд.

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

Собери relocatable runtime для выбранной платформы, включи библиотеки и лицензии.
Укажи bundled ELF в `launch.executable`, а код и флаги — в `arguments`.
Проверь поиск stdlib/native libs, отключи пользовательский site/environment
там, где это поддерживает runtime. Никаких pip/npm при запуске.

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
2. Запусти extracted payload с cwd в его корне, без сети и без системного
   интерпретатора/PATH/PYTHONHOME/PYTHONPATH. Проверь ready, init, input, events,
   flush, Unicode, null, неверные типы и schema rejection.
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
