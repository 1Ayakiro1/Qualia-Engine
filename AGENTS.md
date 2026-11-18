# Инструкции для агентов

- Сохраняй консистентность интерфейса: переиспользуй существующие блоки, цвета, скругления и другие элементы. Создавай новые элементы интерфейса только по прямой просьбе пользователя.
- После каждого изменения функциональности или визуальной части движка собирай AppImage и другие поддерживаемые форматы запуска программы, чтобы пользователь мог проверить и протестировать изменения.
- В `builds/` держи только один актуальный набор `builds/<VERSION>/`: все форматы одной сборки и `SHA256SUMS`, без старых версий и `binary-previous-*`. Публикуй Linux через `scripts/build_all.sh` (staging → полная сборка → замена); проверочные сборки направляй через `DIST_OUT` за пределы `builds/`. Не смешивай старые source/OS artifacts с новым snapshot под тем же dev-номером.
- Придерживайся корректной, читаемой и масштабируемой архитектуры, удобной для дальнейшей адаптации и сопровождения проекта.
- Перед изменениями API прочитай `docs/API_LAYERS.md` и `app/assets/module_sdk/api_layers.json`: `internal` — модуль ↔ модуль через host-owned links, `middle` — модуль ↔ движок (`process-v1`), `external` — движок ↔ сторонние клиенты/сервисы. Это границы ответственности, не уровни привилегий и не типы транспорта.
- Адресуй конкретный экземпляр через `(workspaceId, instanceId, portId)`, не package ID/PID/подпись UI. Модуль отправляет на свой output; получателей определяет host. Payload не разрешает обращаться к чужому модулю, workspace, engine service или секретам.
- Не объявляй direct module RPC, live external gateway, protocol v2 или OS sandbox реализованными без кода и тестов. C ABI — implementation boundary host/core, не разрешённый API внешнего `.qmod`.
- Согласовывай API descriptor, `api.describe`/`engine.context`, SDK, документацию и тесты. После изменения descriptor генерируй `qualia.lock.json` через `scripts/generate_version_lock.py` и запускай `scripts/check_version.sh`. Для планов API-изменений указывай `apiLayers` (`internal`, `middle`, `external`).
