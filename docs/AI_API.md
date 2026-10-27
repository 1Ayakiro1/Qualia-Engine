# Qualia AI API

Контракт **Qualia AI API 1.0** предназначен для ИИ-моделей, которые создают
модули, анализируют workspace и предлагают изменения движка. Это локальный
JSON-RPC 2.0 сервис поверх `stdin/stdout`: один JSON-объект на строку, ответ
также одна строка JSON. Вызов не требует Flutter и работает на Python 3.

## Границы безопасности

API — это слой анализа и планирования, а не удалённая консоль администратора.
Он:

- не выполняет код модели и код `.qmod`;
- не запускает процессы и не устанавливает модули/dependencies;
- не пишет файлы репозитория и не делает сетевых запросов;
- не выдаёт секреты, токены Supabase или произвольный доступ к файловой системе;
- возвращает план, который должен применить человек или доверенный CI.

Запуск из корня checkout:

```bash
python3 tools/qualia_ai_api.py
```

Для интеграции модели используйте `--root /absolute/path/to/Qualia\ Engine`.
Модель должна считать `capabilities` и `safety` из `initialize` и не использовать
методы, которых там нет.

## JSON-RPC

Запрос:

```json
{"jsonrpc":"2.0","id":1,"method":"engine.context"}
```

Ошибки используют стандартные коды JSON-RPC: `-32600` invalid request,
`-32601` method not found, `-32602` invalid params, `-32603` internal error.
`-32001` означает отсутствие или несовместимость `qualia.lock.json`.

### `initialize` / `engine.context`

Возвращает API/engine version, contract versions, полный snapshot разрешённых
зависимостей, capabilities и явные safety guarantees. `initialize` — алиас для
клиентов, ожидающих привычное имя handshake.

### `module.validate`

Параметры: `{ "manifest": { ... } }`.

Manifest проверяется тем же offline SDK, что используется для `qmod.py check`:
`schemaVersion: 1`, `runtime`, target/launcher, ports, UI, schemas и лимиты.
Ответ содержит `ok`, `diagnostics`, а при успехе — `identity.id/version`.
API не принимает manifest как разрешение на запуск.

### `workspace.validate`

Параметры: `{ "package": { ... } }`.

Проверяются `qualia-workspace` version 1, лимиты 500 nodes/8000 links,
уникальность node IDs, существование node/port в links и SemVer module references.
Embedded manifest — только declarative metadata; доверие и установка остаются
за host.

### `workspace.fork`

Параметры:

```json
{
  "package": {"format":"qualia-workspace","version":1,"project":{...}},
  "forkId": "alpha-filter-fork",
  "name": "Alpha filter (fork)"
}
```

Метод сначала валидирует parent, затем меняет только id/name project и добавляет:

```json
"revision": {
  "revision": "fork-alpha-filter-fork-<12 hex chars>",
  "parentRevision": "...",
  "parentDigest": "sha256...",
  "kind": "fork"
}
```

Результат не изменяет parent. Повторный вызов с теми же входными данными даёт
тот же revision и package digest; публикация должна использовать новую версию
артефакта, а не перезаписывать parent release.

### `engine.plan_change`

Параметры: `kind` (`module`, `ui`, `core`, `dependency`, `plugin` или
`documentation`), обязательный `summary` и список исходных `files`. API отклоняет
absolute paths, traversal и build/secrets paths. В ответе есть рекомендуемый
`versionBump`, `requiresReview` и обязательные проверки. Для `core`, dependency
и plugin review обязателен.

### `version.compare`

Параметры `{ "left": "1.2.0", "right": "1.3.0" }`; `comparison` равен `-1`,
`0` или `1`. Сравнение следует SemVer precedence, включая prerelease.

## Минимальный клиент

```python
import json, subprocess

api = subprocess.Popen(
    ["python3", "tools/qualia_ai_api.py"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
)
api.stdin.write(json.dumps({
    "jsonrpc": "2.0", "id": 1, "method": "module.validate",
    "params": {"manifest": manifest},
}) + "\n")
api.stdin.flush()
response = json.loads(api.stdout.readline())
assert response["result"]["ok"]
```

Не отправляйте в API произвольные строки shell-команд как `files` и не считайте
`ok` заменой доверенной проверки пакета, подписи или security sandbox.
