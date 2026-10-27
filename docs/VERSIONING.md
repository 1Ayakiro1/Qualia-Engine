# Версионирование Qualia Engine

## Источники истины

| Объект | Формат | Источник |
|---|---|---|
| Engine release | SemVer (+ prerelease) | `VERSION` |
| Native core | та же версия + `BCI_CORE_ABI_VERSION` | `core/include/bci_engine/version.h` |
| Flutter application | `version: <engine>+build` | `app/pubspec.yaml` |
| Engine/API/contracts/dependencies | JSON lock | `qualia.lock.json` |
| Module release | `MAJOR.MINOR.PATCH[-prerelease]` | `manifest.json` + `module_releases` |
| Workspace graph | package format version 1 | `qualia-workspace` package |
| Workspace lineage | immutable revision block | `project.revision` / package `revision` |

Проверка:

```bash
./scripts/check_version.sh
python3 scripts/check_versions.py
```

После изменения `app/pubspec.lock`, Flutter plugin, native dependency или
toolchain запускайте:

```bash
python3 scripts/generate_version_lock.py
git diff -- qualia.lock.json
```

Lock фиксирует resolved версии, pub.dev SHA-256 где он присутствует, native
Catch2 digest, Flutter/Dart/CMake/Python/Go baseline, module/workspace/API
contract numbers и шесть поддерживаемых desktop targets. `qualia.lock.json`
коммитится вместе с исходниками; он не заменяет `pubspec.lock`, а делает
снимок понятным для AI/CI и включает native/plugin слой.

## Правила SemVer

- patch: исправление без изменения public module/API contract;
- minor: backward-compatible capability, новый module/plugin или dependency;
- major: несовместимый API, manifest/protocol/workspace format или core ABI.

Engine prerelease (`0.5.2-dev.1`) не является опубликованным `0.5.2`. Нельзя
называть dev artifact release и нельзя молча откатывать новый manifest/protocol
к старому. Host должен отклонять неизвестный contract до запуска.

`BCI_CORE_ABI_VERSION` увеличивается только при breaking C ABI. Additive C ABI
изменения документируются в `version.h` и сохраняют старые символы. Изменение
ABI требует проверки core tests, FFI smoke test и сборки поддерживаемых desktop
артефактов.

## Модули, библиотеки и плагины

`.qmod` — immutable artifact. Уникальность релиза — `(module_id, version)`;
published metadata/package digest/signature не редактируются. Исправление
опубликованного пакета получает новую module version и новый SHA-256.

В workspace сохраняются exact module `id + version + releaseId`, поэтому при
импорте host не подменяет установленную зависимость похожей версией. Для
portable package один digest относится ко всему универсальному archive, а не к
копии на каждую ОС. Для native `targets` каждый executable проверяется под свой
ABI.

### Fork

Fork — новый workspace/package и новый revision, а не update исходного объекта.
Он сохраняет `parentRevision` и `parentDigest`; parent остаётся неизменным.
Чтобы превратить fork в module release:

1. проверить `workspace.validate` и все module manifests;
2. получить `engine.plan_change` с `kind: module` или `plugin`;
3. выбрать новую SemVer (обычно patch для исправления, minor для capability);
4. собрать offline, записать package SHA-256 и lock snapshot;
5. проверить пакет SDK и host installer;
6. только затем отправить draft/release на review.

Никогда не переиспользуйте `releaseId`, не меняйте опубликованный manifest и не
публикуйте fork с тем же module `id+version`.

## Политика для AI

AI обязан сначала запросить `engine.context`, затем проверить входные manifest или
workspace и только после этого предложить `engine.plan_change`. Для core,
dependency и plugin изменений требуется human review. AI не должен:

- менять `qualia.lock.json` вручную без генератора;
- поднимать версию только чтобы скрыть несовместимость;
- включать новый protocol/schema в manifest, пока host его не реализует;
- добавлять dependency без lock entry, license и SHA-256/source;
- считать `manifest.languages` или capability строкой OS sandbox.
