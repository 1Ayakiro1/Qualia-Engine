# Сборка и упаковка

## Зависимости

- Flutter SDK (стабильный; используется 3.47.5): `~/development/flutter`
- Linux: `clang|gcc, cmake >= 3.21, ninja, pkg-config, gtk3-devel`
- Windows: Visual Studio Build Tools + Windows desktop toolchain
- macOS: Xcode

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
- macOS: `scripts/build_macos.sh` → zip. TODO: интеграция ядра в Xcode-проект
  (сейчас на macOS приложение работает с ядром офлайн — FFI-лоадер корректно
  деградирует).

## CI

`.github/workflows/ci.yml`: на каждый push/PR —
проверка версий, тесты ядра, `dart analyze` (НЕ `flutter analyze`: тот падает
на путях с не-ASCII/пробелами из-за LSP-фрейминга анализ-сервера;
подробности ниже), flutter-тесты, сборка и
smoke-запуск AppImage, артефакты для трёх платформ.

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
