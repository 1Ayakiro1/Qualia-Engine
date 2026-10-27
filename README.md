# Qualia Engine

Кроссплатформенный модульный движок для нейроинтерфейсов (в первую очередь ЭЭГ).

**Опубликованная версия: Alpha 0.5.1. В разработке: 0.5.2-dev.1.**
Готовые release-пакеты и исходники — в [GitHub Releases](https://github.com/1Ayakiro1/Qualia-Engine/releases).
Linux AppImage/tarball и Windows/macOS ZIP собираются матрицей GitHub Actions.

Полный ML runtime ещё **не реализован**. [Состояние и критерий 0.5.2](docs/ML_RUNTIME_V2.md):
в текущей разработке есть native ownership/backpressure и draft binary codec,
но нет host protocol v2, HAL/Registry/job services и enforced sandbox на трёх ОС.

## Режимы использования

| Режим | Экраны |
|---|---|
| Потребитель | Обзор, Устройства, Сессия, Настройки |
| Исследователь | + Конвейер, Спектрограмма, Модули, Датасеты, Модели |
| Разработчик | + FFI-консоль ядра |

## Что уже работает

- **Универсальные `.qmod`**: один portable payload с внешним runtime либо архив
  с нативными вариантами Linux/Windows/macOS x64/arm64. NDJSON через stdio/TCP,
  кадр до 1 MiB, пакет до 2 GiB; установка больших пакетов с диска порциями.
  [Контракт и ограничения](docs/UNIVERSAL_MODULES.md).
- **Логические блоки**: IF, фильтр, выбор полей, проверка схемы и ограниченный
  script с редактором/dry-run, отдельным Explorer и фильтрами отображения.

- **Логгер сессии** (`AppLogger`): с момента запуска и до завершения пишет
  форматированные логи ядра и UI в `~/.local/share/bci_engine/logs/`
  (`latest.log` + `session-*.log`); мост логов C++ ядра → Dart (ABI 2)
- **Консоль логов в отдельном окне**: пауза/продолжить, фильтр уровня,
  поиск, автопрокрутка, сохранение видимого, очистка вида (минимализм в духе GNOME)
- **Flutter GUI** (Desktop-first): боковая навигация по режимам, тёмная тема, 10 экранов-каркасов
- **C++-ядро** (`core/`): рабочий поток, bounded ownership очереди с byte budget,
  конвейер из 4 системных модулей: passthrough, gain, EMA-сглаживание,
  диагностика RMS/FFT/качество. ABI 3 добавляет timestamped float32 blocks,
  channel-major layout и `every`/`drop-oldest`/`latest-only`; старый samples API сохранён.
  Это не hard-real-time гарантия и пока не data-plane внешних `.qmod`.
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
./builds/Qualia-Engine-$(cat VERSION)-x86_64.AppImage
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
core/        C++ ядро (CMake, Catch2, bounded block queues)
app/         Flutter-приложение (Riverpod)
builds/      Готовые сборки: AppImage, tar.gz, бинарник (для пользователей)
scripts/packaging/  Метаданные AppImage и AppRun
scripts/     Сборка/упаковка/проверки
docs/        Архитектура, модули, сборка, роадмап
```

Документация: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
[docs/MODULES.md](docs/MODULES.md) · [docs/BUILD.md](docs/BUILD.md) ·
[docs/ROADMAP.md](docs/ROADMAP.md)

Для нейросетей и авторов модулей: [MODULE_AUTHORING_AI.md](docs/MODULE_AUTHORING_AI.md).
API для ИИ-моделей: [AI_API.md](docs/AI_API.md). Политика версий и форков:
[VERSIONING.md](docs/VERSIONING.md). Машиночитаемый snapshot: [qualia.lock.json](qualia.lock.json).
Релиз: [Alpha 0.5.1](docs/releases/ALPHA_0.5.1.md). Полные исходники доступны в
теге `v0.5.1-alpha` и в отдельных source-архивах релиза.
