# Сборка и упаковка

## Зависимости

- Flutter SDK (стабильный; используется 3.47.5): `~/development/flutter`
- Linux: `clang|gcc, cmake >= 3.21, ninja, pkg-config, gtk3-devel`
- Windows: Visual Studio Build Tools + Windows desktop toolchain
- macOS: Xcode (command line tools), CMake (`brew install cmake`)

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

Артефакты складываются в `builds/` (папка в корне репозитория):

- `Ayakiro_BCI_Engine-<v>-x86_64.AppImage`
- `Ayakiro_BCI_Engine-<v>-linux-x64.tar.gz`
- бинарник: `builds/binary/bci_engine` (готовый бандл, запускается напрямую)

Старые версии артефактов сохраняются. Предыдущий raw bundle при упаковке
перемещается в `binary-previous-<timestamp>/`. Для проверочной сборки без замены
пользовательских файлов задайте `DIST_OUT=/tmp/opencode/<каталог>`; после проверки
обновите актуальные AppImage/tarball/bundle в `builds/`, сохранив прежние файлы.

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
