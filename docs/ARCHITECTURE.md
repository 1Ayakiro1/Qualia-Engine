# Архитектура Ayakiro BCI Engine

## Высокоуровневая структура

```
┌──────────────────────────────────────────────────────────┐
│                   Flutter UI (Riverpod)                  │
│  Shell → Обзор/Устройства/Сессия/Конвейер/Спектрограмма  │
│          Модули/Датасеты/Модели/Разработчик/Настройки    │
└───────────────────────┬──────────────────────────────────┘
                        │ dart:ffi (стабильный C ABI)
┌───────────────────────▼──────────────────────────────────┐
│                C++ Core (libbci_engine_core)             │
│  Engine (worker thread)                                  │
│   ├─ in queue  (lock-free SPSC)                          │
│   ├─ Pipeline: passthrough → gain → smoothing →          │
│   │             diagnostics → markers → recorder         │
│   ├─ out queue (lock-free SPSC)                          │
│   └─ EngineMetrics (RMS, peak Hz, quality)               │
└──────────────────────────────────────────────────────────┘
```

## Data Flow (соответствует ТЗ)

```
Device → Raw Buffer → Preprocessing → Feature Extraction → Inference → Output/Visualization
                                ↓
                          Event Markers
                                ↓
                       Storage / Session
```

В v0.1 источник данных — синтетический генератор (файл `signal_gen.dart`);
в v0.2 на его место встанет HAL (Device Manager + нормализация сырого сигнала).

## Core-сервисы (план реализации)

| Сервис | Статус v0.1 | Куда двигаться |
|---|---|---|
| Device Manager | заглушка (экран «Устройства») | HAL: ADS1299, LSL |
| Session Manager | in-memory история | локальное хранилище |
| Pipeline Engine | **работает** (C++) | параметры модулей, конфиги |
| Model Registry & Runtime | — | ONNX |
| Config & Profile Manager | — | JSON-конфиги |
| Event/Marker System | каркас модуля | шина событий |
| Storage Service | — | локальное + Postgres/Supabase |
| Permission & Sandbox | — | медицинский режим, песочница |
| Plugin/Module Loader | контракт IModule | загрузка пользовательских модулей |

## Поток данных через ядро

`push_samples()` (Dart) → SPSC-очередь → рабочий поток прогоняет блок через
цепочку модулей → SPSC-очередь → `pop_samples()` (Dart). При переполнении
очереди самые старые блоки отбрасываются (латентность ограничена), счётчики
в `EngineMetrics`.

## FFI ABI

`core/include/bci_engine/c_api.h` — единственный контракт между Dart и C++.
Любое изменение ABI увеличивает `BCI_CORE_ABI_VERSION`
(`app/lib/core/constants/app_info.dart` хранит ожидаемое значение).
