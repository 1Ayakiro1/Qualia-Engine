# Три уровня API Qualia Engine

Нормативное разделение API по **ответственности и границе взаимодействия**.
Это не три сетевых сервера, не уровни доступа и не замена security policy.
Транспорт (stdio/TCP/HTTP), язык модуля и расположение процесса сами по себе
не определяют уровень. Машиночитаемый контракт:
[`app/assets/module_sdk/api_layers.json`](../app/assets/module_sdk/api_layers.json).
Его копия включается в `qualia.lock.json` и доступна через внешний `api.describe`.

## Карта уровней

| Уровень / ID | Участники | Ответственность | Владелец границы |
|---|---|---|---|
| Внутренний / `internal` | экземпляр модуля ↔ экземпляр модуля | прикладные данные, адресные связи портов, схемы | host router |
| Средний / `middle` | модуль ↔ движок | handshake, параметры, события UI, состояние, supervision, перенос внутренних сообщений | module supervisor |
| Внешний / `external` | движок ↔ сторонние системы | AI/developer clients, auth/catalog/storage adapters, будущие service integrations | integration adapter |

```text
AI client / Supabase / third-party service
                 ↕ external (integration-specific binding)
Engine: adapters → application services → supervisor + router
                                          ↕ middle (process-v1)
                                       Module A     Module B
                                          └── internal ──┘
                                    A.output → host → B.input
```

Внутренний уровень семантически соединяет модули, но физически использует средний
канал и host router. Отдельное соединение A ↔ B для этого **не требуется**.
Движок не должен терять контроль адресации при смене транспорта.

## 1. Внутренний: прикладной контракт модулей

### Идентичность и адресация

- `module.id + version + releaseId/package hash` — идентичность **пакета**.
- `instanceId` — конкретный запущенный **экземпляр** (node ID в workspace).
- `portId` — стабильный ID входа/выхода, а не пользовательская подпись.
- Полный логический адрес: `(workspaceId, instanceId, portId)`.

Два узла одного пакета — разные адресаты, процессы и состояния. Активный workspace
задаёт область маршрутизации. Существующий `WorkspaceLink` хранит
`source/output/target/input` внутри этой области:

```json
{"source":"filter-1","output":"output","target":"classifier-2","input":"input"}
```

Модуль A отправляет **на собственный выход**, не назначает peer/PID/endpoint:

```json
{"type":"output","port":"output","value":{"score":0.8},"hops":31}
```

Host связывает отправителя с реальным экземпляром A, находит разрешённые links,
проверяет порты/схемы и доставляет B:

```json
{"type":"input","port":"input","value":{"score":0.8},"hops":30}
```

Это адресная связь с конкретным B. Один output может иметь несколько явных links
(fan-out); это **не** неограниченный broadcast/discovery. Содержимое `value`,
добавленные `target`, `source` или `workspaceId` в process frame не меняют маршрут.
Входы/выходы задаются manifest, а связи и разрешение запуска — host.

### Гарантии и ограничения v1

- `portSchemas` и host-owned аннотации проверяются без неявного преобразования типов.
- Бюджет hops уменьшается на ребре; есть bounded dispatch/fan-out и frame queues.
- Недостающие/disabled адресаты не получают данные; workspace switch останавливает
  старые экземпляры. Сообщения не являются persistent queue.
- Нет delivery acknowledgement, exactly-once, durable retry, транзакций между
  процессами или глобального порядка сообщений от разных отправителей.
- Самоссылки и processing-циклы запрещены при построении graph.
- Нет RPC «вызвать произвольный метод другого модуля», cross-workspace links,
  прямого доступа к памяти/состоянию peer или бинарного data-plane `.qmod`.

Для command/result можно **явно** описать прикладной envelope в schema порта
(например, `requestId`, `operation`, `payload`) и соединить нужные порты. Это
авторский payload, не встроенный host RPC; он не создаёт обратную связь и не
обходит запрет циклов. Для полноценного request/reply нужен отдельно реализованный
и версионированный контракт, а не новые самовольно придуманные process messages.

## 2. Средний: модуль ↔ host

Текущий binding: manifest schema **1**, `process-v1` / legacy
`native-process-v1`, IPC protocol **1**, UTF-8 NDJSON по stdio либо TCP.

| Направление | Сообщения | Назначение |
|---|---|---|
| module → host | `ready` | handshake, protocol, required capabilities |
| host → module | `init` | instance identity, capabilities, initial parameters |
| host → module | `parameters`, `event` | allowlisted параметры и события UI |
| module → host | `state` | только объявленные label/value/chart values |
| module → host / host → module | `output` / `input` | перенос внутреннего API |

Supervisor владеет запуском, проверкой installation integrity, завершением процесса,
таймаутом handshake и ограничениями кадров. Точный wire-контракт и лимиты:
[MODULE_AUTHORING_AI.md](MODULE_AUTHORING_AI.md),
[UNIVERSAL_MODULES.md](UNIVERSAL_MODULES.md).

Host не передаёт auth-токены через `init`, не предоставляет произвольное изменение
shell, файлов или сервисов. Окна — наблюдатели, не новые вычислительные экземпляры.
Process SDK понимает `stop`, но host v1 не гарантирует graceful-stop exchange:
автор не должен полагаться на его доставку. Долговременные services/jobs,
host-service RPC и enforced OS sandbox пока не реализованы.

`capabilities` v1 — **поддержанные функции протокола**, не OS permissions.
TCP listener модуля остаётся средним API даже с IP/DNS endpoint; это не внешний
service API. TLS/auth автоматически не появляются от использования TCP.

## 3. Внешний: движок ↔ сервисы/клиенты

Два направления одной границы:

- **Outbound:** движок вызывает сторонний сервис через adapter (сейчас
  `AuthService`, `ModuleRepository`, `WorkspaceRepository` для Supabase).
- **Inbound:** сторонний клиент обращается к опубликованному adapter движка
  (сейчас offline developer API `tools/qualia_ai_api.py`, JSON-RPC по stdio).

AI API — **development binding**, не мост к живому Flutter runtime: он описывает
контракты, проверяет документы, возвращает fork/план, но не запускает код, не
пишет репозиторий и не вызывает модули. Название `module.validate` не делает метод
внутренним или средним: участник здесь внешний developer client, а объект —
декларативный manifest.

Прямой HTTP-вызов из доверенного `.qmod` возможен на уровне ОС, поскольку sandbox
нет, но это **авторская сторонняя интеграция модуля**, а не внешний API движка.
Не передавайте так engine credentials и не объявляйте обход router поддержанным.

### Правила для новых adapters (требования, не готовая реализация)

1. Provider-specific DTO/auth/retry остаются в adapter; доменная логика движка
   не зависит от HTTP SDK конкретного поставщика.
2. Для будущего inbound control нужны аутентификация, workspace-scoped authorization,
   allowlisted commands, consent на запуск/установку, audit и rate/size limits.
   Loopback сам по себе не аутентификация. Публичного HTTP control-server сейчас нет.
3. Outbound: secrets хранятся вне manifest/workspace/логов; transport encryption,
   endpoint validation и доступ к данным определяются конкретным adapter.
   Биосигналы/модели не отправляются в сервис без явной политики пользователя.
4. Вызовы имеют deadlines, cancellation и ограниченные retries/backoff. Повтор
   неидемпотентной операции требует idempotency key либо явной защиты от дублей.
5. Если внешний клиент должен обратиться к модулю: adapter → authorization →
   application service → supervisor/router → declared instance/port. Никакого
   прямого проброса socket, чужого instance ID или секрета в module stream.
6. Пока такой binding не реализован и не протестирован, API сообщает unsupported,
   а не выдаёт план за успешное выполнение.

## Версии и совместимость

### LSL acquisition (external, dev.6)

`apiLayers: ["external"]`: пользователь явно запускает discovery и выбирает
LSL source ID. Адаптер движка владеет inlet на worker isolate; host/core C ABI
переносит interleaved float32, Dart mailbox ограничен одним блоком с ack.
Это не `middle` module service и не `internal` port transport: `.qmod` не получает
доступ к inlet/устройству через payload. Process-v1 остаётся JSON.
Частота и число каналов проверяются при открытии; remote LSL timestamp сохраняется
в live block без обещания clock synchronization. Требуются отдельно установленная
liblsl, непустой source ID, положительная равномерная частота и ≤256 каналов.
Нет board driver, cross-workspace routing, clock sync или binary module plane.
Native C ABI extension additive, ABI v3 сохранён; старое ядро без LSL symbols
показывается как LSL unavailable. `api.describe`/`engine.context` читают descriptor.

Уровни имеют отдельные contract versions; конкретный binding — свою версию.
Сейчас уровни `internal/middle/external` описаны как `1.0.0`, AI development
binding — **1.1.0** (additive `api.describe`, `apiLayers` в context/plan).
Это не изменение process protocol: старые `.qmod` продолжают использовать `1`.
Supabase versioning определяется migrations/provider API, не версией AI binding.

При изменении контракта: выбрать затронутые уровни → обновить descriptor и
реализацию → `generate_version_lock.py` → contract/regression tests → сборки.
Добавление необязательного metadata не разрешает новый protocol/capability.
Native C ABI и draft QSB2 — implementation contracts host/core, **не четвёртый
уровень** и не автоматическое разрешение модулю вызывать C++ напрямую.

## Чек-лист для разработчика и ИИ

1. Прочитать этот документ и `engine.context` / `api.describe`.
2. Назвать участников, адресата-экземпляр, владельца маршрута и затронутые уровни.
3. Не менять port ID при переименовании UI и не использовать package ID как instance ID.
4. Не смешивать routing payload, lifecycle control и сторонний auth.
5. Проверить negative tests: чужой адресат, unknown contract/capability, неверная
   схема, disabled node, смена workspace, disconnect и превышение лимитов.
6. Для изменения API добавить `apiLayers` в `engine.plan_change`, сохранить exact
   dependency versions/lineage; переход между границами требует review.
7. Явно отличать реализованное поведение от будущих RPC/gateway/sandbox возможностей.
