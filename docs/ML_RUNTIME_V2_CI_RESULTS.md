# ML runtime v2 — результаты CI для 0.5.2-dev.1

Это отчёт о промежуточной разработке, **не релиз 0.5.2**. Полный критерий
готовности семи подсистем из [ML_RUNTIME_V2.md](ML_RUNTIME_V2.md) не выполнен.

## Проверенный исходный код

- Ветка: `feat/ml-runtime-v2`.
- Commit: `c1901b45dba0140aaf329f14a269e8759fb5f07b`.
- [GitHub Actions run 38759541709](https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38759541709).
- Итог всего запуска: **failure**, из-за ошибки macOS Flutter-теста.

| Job | Результат |
|---|---|
| Linux x64 | **success**: тесты, сборки, bundled-core smoke, запуск AppImage |
| Windows x64 | **success**: тесты, portable ZIP, bundled-core smoke |
| macOS | **failure**: Flutter-тест проверки CRC; дальнейшая сборка пропущена |
| AddressSanitizer | **success** |
| ThreadSanitizer | **success** |
| Universal module fixture | **success** |

## Linux: исправленный тест подтверждён

[Linux job и полный лог](https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38759541709/job/116507419470).

- `crashing instance does not kill its sibling or automatically respawn` прошёл.
  Тест больше не полагается на порядок параллельных запусков или фиксированные
  50 мс для получения уведомления о завершении процесса.
- Flutter: **149 passed, 1 skipped**, включая дополнительные CI fixtures.
  Native Dart FFI проверяется с `QUALIA_REQUIRE_NATIVE_TESTS=1`.
- Native CTest: 1/1 test executable прошёл; отсутствие тестов считается ошибкой.
- Python QSB2 codec: 6 тестов прошли.
- Проверка версий и Dart analyzer прошли.
- AppImage и tar.gz собраны, bundled-core ABI smoke прошёл.
- AppImage оставался запущенным до планового тайм-аута 15 секунд под Xvfb.
  Это проверка запуска, не полный интерактивный UI-тест.

Локально дополнительно: 19 native cases / 336 assertions, 145 Flutter tests
(3 opt-in skipped), 6 Python tests; crash-isolation тест — 10 повторений подряд.

## Сборки на GitHub

[Скачать Linux Actions artifact](https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38759541709/artifacts/11985671889)
(может требоваться вход в GitHub; срок хранения — 14 дней).

Имя: `Qualia-linux-x64-stock-c1901b45dba0140aaf329f14a269e8759fb5f07b`.
В CI использован **stock** Linux embedder; локальные native-vsync сборки —
другие файлы, их SHA256 не следует сравнивать с этими.

SHA256 скачанного Actions ZIP сверен с digest из GitHub API; CRC всех записей
ZIP проверен. Контрольные суммы файлов внутри:

```text
d0534f6e4cac06ce5dc5683b5d1c1e3b5ecedad18364220a5beda7a2915d48de  Qualia-Engine-0.5.2-dev.1-linux-x64.tar.gz
14e0574195bc1576445abe0622a0d9f6872d092b0224e11543d8e54f1460f337  Qualia-Engine-0.5.2-dev.1-x86_64.AppImage
```

SHA256 Actions ZIP:
`9051cac0dacca919b6e4632eef4c85299b8a91d65c306fbf60e5755221313401`.

[Windows portable ZIP](https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38759541709/artifacts/11984209842)
доступен в Artifacts этого же запуска (срок хранения — 14 дней).
Исходники находятся в ветке/commit выше; локальные source ZIP/tar.gz содержат
`SOURCE_COMMIT` и проверены побайтово относительно `c1901b4`.

## Открытая проблема macOS

[Неуспешный macOS job](https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38759541709/job/116507419601).

`app/test/module_transports_test.dart`, тест
`file-backed install preserves payload chunks and rejects corrupt CRC`:
ожидался `FormatException`, но `store.installFile(file)` вернул `SystemModule`.
Причина пока **не установлена**; нельзя считать это доказанной ошибкой только
теста или подтверждённым обходом проверки CRC. Требуется отдельная проверка
изменяемой записи ZIP и file-backed CRC-пути. Ошибка не скрыта повторным запуском
или отключением теста; macOS-сборка этого commit не подтверждена.

Предыдущий успешный macOS job не заменяет проверку текущего commit. Успех Linux,
Windows и sanitizer jobs также не подтверждает ещё не реализованные resource
limits/capabilities, SHM/TCP module routing и остальные подсистемы ML runtime.

## Публикация

Результаты публикуются как отчёт в ветке разработки и draft pull request.
Без merge в `main`, релизного тега или GitHub Release: версия 0.5.2 будет
публиковаться только после выполнения полного согласованного критерия готовности.
