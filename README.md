# Qualia Engine

Кроссплатформенный модульный движок для нейроинтерфейсов (в первую очередь ЭЭГ).

**Статус: v0.4.1 — Qualia Engine UI polish.** Каркас-оболочка собран,
сборка и запуск проверяются на каждую версию (бинарник + AppImage + portable
tar.gz; Windows/macOS — в CI). Готовые сборки — в папке [`builds/`](builds/README.md).

## Режимы использования

| Режим | Экраны |
|---|---|
| Потребитель | Обзор, Устройства, Сессия, Настройки |
| Исследователь | + Конвейер, Спектрограмма, Модули, Датасеты, Модели |
| Разработчик | + FFI-консоль ядра |

## Что уже работает (v0.4.1)

- **Логгер сессии** (`AppLogger`): с момента запуска и до завершения пишет
  форматированные логи ядра и UI в `~/.local/share/bci_engine/logs/`
  (`latest.log` + `session-*.log`); мост логов C++ ядра → Dart (ABI 2)
- **Консоль логов в отдельном окне**: пауза/продолжить, фильтр уровня,
  поиск, автопрокрутка, сохранение видимого, очистка вида (минимализм в духе GNOME)
- **Flutter GUI** (Desktop-first): боковая навигация по режимам, тёмная тема, 10 экранов-каркасов
- **C++-ядро** (`core/`): движок с рабочим потоком, lock-free очереди
  (readerwriterqueue), конвейер из 6 системных модулей (passthrough, gain,
  EMA-сглаживание, диагностика RMS/FFT/качество, маркеры, рекордер)
- **FFI-мост** Dart ↔ C++ (стабильный C ABI, `bci_engine_*`)
- **E2E-сессия**: синтетический сигнал → ядро → live-метрики (RMS, доминирующая частота, качество)
- **Спектрограмма** в реальном времени (STFT-демо в Dart, маркеры событий)
- **Тесты**: Catch2 (ядро) + flutter_test (UI/реестр/FFI)
- **Сборка/упаковка**: `scripts/build_all.sh` → `builds/` (AppImage + tar.gz + бинарник); CI для Linux/Windows/macOS

## Быстрый старт

```bash
# полная локальная сборка (тесты ядра + приложение + артефакты)
./scripts/build_all.sh

# запуск приложения
./app/build/linux/x64/release/bundle/bci_engine

# или через AppImage
./builds/Ayakiro_BCI_Engine-0.4.1-x86_64.AppImage
```

### Отдельный debug terminal

Debug terminal работает как отдельный процесс и native window. Его можно открыть
из header или запустить вместе с приложением:

```bash
# Из release bundle
./scripts/run_with_debug_terminal.sh

# Напрямую через бинарник
./app/build/linux/x64/release/bundle/bci_engine --with-debug-terminal

# Только окно терминала, если основное приложение уже запущено
./app/build/linux/x64/release/bundle/bci_engine --debug-terminal
```

Одновременно открывается не более одного terminal window. Lock освобождается
при обычном закрытии, а после аварийного завершения автоматически отпускается
операционной системой.

Требования: Flutter SDK (Linux desktop toolchain), CMake ≥ 3.21, GCC/Clang, Ninja.

## Структура

```
core/        C++ ядро (CMake, Catch2, readerwriterqueue)
app/         Flutter-приложение (Riverpod)
builds/      Готовые сборки: AppImage, tar.gz, бинарник (для пользователей)
scripts/packaging/  Метаданные AppImage и AppRun
scripts/     Сборка/упаковка/проверки
docs/        Архитектура, модули, сборка, роадмап
```

Документация: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
[docs/MODULES.md](docs/MODULES.md) · [docs/BUILD.md](docs/BUILD.md) ·
[docs/ROADMAP.md](docs/ROADMAP.md)
