# Сборка и упаковка

## Зависимости

- Flutter SDK (стабильный; используется 3.47.5): `~/development/flutter`
- Linux: `clang|gcc, cmake >= 3.21, ninja, pkg-config, gtk3-devel`
- Windows: Visual Studio Build Tools + Windows desktop toolchain
- macOS: Xcode (command line tools), CMake (`brew install cmake`)

Текущий рабочий код — `0.5.2-dev.2`, не готовый ML runtime/release 0.5.2.
Для dev-проверок без замены текущего набора:
`DIST_OUT=/tmp/opencode/qualia-check ./scripts/build_all.sh`.
Ограничения и критерий публикации: `docs/ML_RUNTIME_V2.md`.

## Команды

```bash
./scripts/check_version.sh   # VERSION == version.h == pubspec.yaml
./scripts/analyze.sh         # статический анализ (dart analyze, см. ниже)
./scripts/build_core.sh      # ядро + Catch2 тесты
./scripts/build_native_embedder.sh release # Flutter GTK с native vsync
./scripts/test_native_vsync.sh # native bridge и перевод времён кадра
./scripts/build_linux.sh     # анализ + release-бандл (включая libbci_engine_core.so)
./scripts/package_linux.sh   # portable tar.gz
./scripts/build_appimage.sh  # AppImage (appimagetool, скачивается в tools/)
./scripts/build_all.sh       # всё сразу
```

Проверки portable/TCP-модулей и больших пакетов (из `app/`):

```bash
flutter test test/module_transports_test.dart
# Отдельный тяжёлый тест: пакет почти 2 GiB, установка порциями и отказ >2 GiB.
QUALIA_LARGE_MODULE_TEST=full flutter test test/module_transports_test.dart \
  --plain-name 'large file-backed SDK package and oversized archive rejection'
```

Без этой переменной тяжёлый тест пропускается. Для варианта 257 MiB укажите
`QUALIA_LARGE_MODULE_TEST=1`. Нужны Python 3 и место под payload, архив и установку.

Новые native block/queue/QSB2 проверки запускаются через `./scripts/build_core.sh`.
Python wire conformance: `python3 -m unittest discover -s modules/tests -p 'test_signal_v2.py' -v`.
Native tests обязательны, а не молча пропускаются при сбое загрузки Catch2.
Для offline CMake tests передайте `-DBCI_FETCH_DEPS=OFF`
и `-DBCI_CATCH2_HEADER=/path/to/catch.hpp` (Catch2 2.13.10, pinned SHA256).
Это файл зависимости build toolchain, не часть runtime модулей.

> `flutter analyze` в этом репозитории запрещён: падает на путях с
> кириллицей/пробелами (баг LSP-фрейминга анализ-сервера). Используйте
> `./scripts/analyze.sh`.

Linux pipeline автоматически собирает pinned custom GTK embedder и включает
его в bundle/AppImage/tarball, не меняя Flutter SDK пользователя.
Первая сборка engine требует сети, нескольких десятков GB в
`~/.cache/qualia-native-vsync` и заметного времени; далее используется
инкрементальная сборка. `QUALIA_ENGINE_CACHE` меняет каталог,
`QUALIA_ENGINE_JOBS` — число compile jobs (по умолчанию 4).
Скрипт проверяет engine revision, чтобы исключить смешивание ABI/snapshot версий.
Native vsync и диагностика частоты описаны в `docs/PERFORMANCE.md`.

Артефакты складываются в **единственный** `builds/<VERSION>/`:

- `Qualia-Engine-<v>-x86_64.AppImage`
- `Qualia-Engine-<v>-linux-x64.tar.gz`
- бинарник: `builds/<v>/binary/bci_engine` (готовый бандл, запускается напрямую)
- `SHA256SUMS`: SHA-256 файлов пакетов и содержимого bundle

`build_all.sh` сначала создаёт полный набор во временном staging-каталоге.
Только после успеха всех шагов `publish_build.py` заменяет текущий набор,
удаляет старые version-папки/пакеты и `binary-previous-*` из `builds/`.
При ошибке сборки прежний набор остаётся; при ошибке замены выполняется rollback.
README и посторонние файлы в корне не удаляются. Не храните личные файлы внутри
каталогов версий: это управляемые, заменяемые результаты сборки.
Резервные копии не накапливаются. Старые source archives/verification не
переносятся в новый набор: одинаковый номер dev-версии не доказывает совпадение кода.

`DIST_OUT` задаёт **точный каталог** результата, без автоматического добавления
версии; его соседние каталоги не очищаются. Не задавайте `DIST_OUT=builds`:
используйте default либо отдельный путь вне `builds/`. Отдельные
`package_linux.sh`/`build_appimage.sh` — низкоуровневые шаги; для согласованного
набора с проверками и очисткой используйте `build_all.sh`.
Тесты публикации: `python3 -m unittest scripts.test_publish_build -v`.

## Windows / macOS

- Windows: `scripts/build_windows.ps1` → zip (ядро собирается вместе с приложением)
- macOS: `bash scripts/build_macos.sh` → zip с `.app`. Xcode Runner phase
  автоматически собирает C++-ядро для `ARCHS`, копирует dylib в
  `Contents/Frameworks` и подписывает её выбранной build identity (обычно ad-hoc).
  Это работает и с обычным `flutter build macos` / `flutter run -d macos`;
  ручная сборка/копирование ядра не нужны. Минимальная macOS — 12.0.
- Windows ZIP должен содержать executable, `bci_engine_core.dll`, Flutter DLL,
  plugin DLL и `data/`; один exe без соседних файлов не переносим.
- Эти команды запускаются **на соответствующей ОС**: Linux не компилирует
  Xcode/Visual Studio приложения. macOS архитектуры определяются Xcode/Flutter,
  проверяются `lipo -info` при необходимости; CI артефакт не обещает universal
  Intel/ARM без проверки содержимого bundle.
- Windows/macOS также публикуют один набор в `builds/<VERSION>/` с `SHA256SUMS`;
  нужен Python 3.12+. Публикация заменяет набор целиком, не смешивая старые
  platform artifacts с новой сборкой. Для объединения CI-пакетов разных ОС
  используйте отдельный каталог и проверяйте одинаковый исходный snapshot.
- macOS App Sandbox выключен для разрешённого пользователем запуска packaged
  модулей из Application Support. Это обычное desktop-приложение, не App Store
  sandbox; модули доверенные и работают с правами пользователя.
- ZIP macOS подписан локальной identity, но **не notarized**. Для публичного
  распространения нужны Developer ID, notarization и соответствующие secrets;
  Windows ZIP также не имеет Authenticode-подписи/инсталлятора.

### Реальный уровень адаптации

Flutter desktop shell и FFI loader имеют пути для Linux/Windows/macOS; Windows
CMake и macOS Xcode включают нативное ядро. Linux-only native vsync не переносится
на другие embedder-ы; они используют штатный Flutter. Пакеты `.qmod` используют
ELF/PE/Mach-O и могут иметь `targets` для всех ОС x64/arm64. Проверка executable
формата не заменяет OS baseline, signing и фактическое тестирование runtime.
Контракт: [UNIVERSAL_MODULES.md](UNIVERSAL_MODULES.md).
Мобильные Android/iOS, сенсорное управление и драйверы EEG не входят в эту
desktop-матрицу. Сборка не заменяет проверку на реальных устройствах.

## CI

`.github/workflows/ci.yml`: push в main, теги `v*`, PR и ручной запуск —
матрица ubuntu-24.04 / windows-2022 / macos-15. Flutter **3.47.5** зафиксирован,
а не плавающий stable (важно для ABI custom GTK). Каждая ОС выполняет version
check, `dart analyze`, C++ тесты с обязательным наличием тестов, Flutter tests,
сборку и ctypes smoke test **библиотеки из итогового bundle**. Linux также
проверяет запуск AppImage через Xvfb. Linux ELF integration tests выполняются
только на Linux; общие Dart/UI/window tests — на всех ОС. Go пример компилируется
в статический linux-x64 executable и упаковывается офлайн на всех build hosts.

По умолчанию CI Linux использует **stock GTK**: без тяжёлой пересборки всего
Flutter engine. Это явно отражено в имени artifact, не скрытая замена native
vsync релиза. Локальный `build_all.sh` по-прежнему использует **native**. Ручной
Actions запуск позволяет выбрать `linux_embedder: native`: нужны сеть, много
свободного диска и времени; стандартный GitHub runner может оказаться мал.
Для постоянной native сборки предпочтителен отдельный runner с engine cache.
Явно выбрать stock локально: `QUALIA_LINUX_EMBEDDER=stock bash scripts/build_all.sh`.

### Как пользоваться Actions

1. Закоммитьте и отправьте workflow в репозиторий (это отдельное действие).
2. GitHub → **Actions → Desktop builds → Run workflow**, выберите ветку и GTK режим.
3. Внизу завершённого запуска → **Artifacts**: ZIP Windows/macOS и архив с
   Linux AppImage/tarball; срок хранения 14 дней. Установка на GitHub Releases
   автоматически не выполняется; write permissions или secrets не нужны.
4. Если job красный, откройте первый упавший шаг; соседние ОС продолжают сборку.
   Первый настоящий запуск Windows/macOS необходим для подтверждения toolchains.

Проверка native библиотеки локально: `python3 scripts/smoke_native_core.py`.

## Про пути с кириллицей и пробелами (важно)

Проект может лежать в пути вида `.../Проекты/BCI/BCI Engine` — CMake, Flutter
build, тесты и `dart analyze` с этим справляются. Единственное исключение —
**`flutter analyze`**: его анализ-сервер общается по LSP, и фрейминг сообщений
ломается на не-ASCII/пробелах в пути (`analysis server exited with code 255`,
`FormatException: Unexpected end of input`). Это баг тулинга, а не проекта.

Правила, закреплённые в скриптах:

- Всегда запускайте анализ через `./scripts/analyze.sh` (внутри `dart analyze`).
- `scripts/build_linux.sh` перед сборкой сам гоняет анализ: на «плохом» пути —
  через симлинк `/tmp/bci-engine-build` (чистый ASCII), на обычном — напрямую.
- Никогда не используйте голый `flutter analyze` в этом репозитории.
