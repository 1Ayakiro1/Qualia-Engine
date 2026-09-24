# Модульная система

## Контракт модуля (C++)

```cpp
class IModule {
 public:
  virtual ~IModule() = default;
  virtual const ModuleInfo& info() const = 0;   // id, имя, категория, версия
  virtual void init(EngineContext& ctx) {}      // один раз при старте движка
  virtual void process(SampleBlock& block) = 0; // блок сэмплов (интерлив)
};
```

`SampleBlock` — интерливнутый буфер `[frame * channels + channel]`,
плюс sample_rate и глобальный индекс первого сэмпла.

## Системные модули v0.1

| id | Этап | Что делает |
|---|---|---|
| `core.acquisition_passthrough` | Raw Buffer | пропуск сырых кадров HAL |
| `core.gain` | Preprocessing | масштабирование |
| `core.smoothing` | Preprocessing | EMA по каналам |
| `core.diagnostics` | Feature Extraction | RMS, FFT-пик (256, окно Ханна), качество |
| `core.event_markers` | Event Markers | каркас меток |
| `core.storage_recorder` | Storage | каркас записи сессий |

## Запланированные (исследовательские)

- `future.spectrogram_tools` — обрезка/заметки/маркировка/экспорт спектрограмм
- `future.ml_training` — обучение моделей без кода, ONNX
- `future.pattern_detection` — паттерны заболеваний + автопометка
- `future.topomap` — топокарты и 3D-визуализация

## Пользовательские модули (v0.2+)

План: модуль = манифест (id, права, категории) + нативная библиотека,
загружаемая из песочницы (Permission & Sandbox Manager), с ограниченным
доступом к `EngineContext`. Реестр модулей читается UI через
`bci_engine_module_json()`.
