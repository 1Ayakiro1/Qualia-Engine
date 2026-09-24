/// System module catalog.
///
/// Mirrors the C++ core modules (see core/src/modules.cpp) and lists planned
/// ones that will be implemented per feature. The Pipeline and Modules
/// screens read from here; when the native core is online the active chain
/// is cross-checked against bci_engine_module_json().
class SystemModule {
  const SystemModule({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.version = '0.1.0',
    this.active = true,
    this.stage = '',
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String version;

  /// true — реализован в ядре v0.1; false — запланирован.
  final bool active;

  /// Этап конвейера (Data Flow из ТЗ).
  final String stage;
}

const List<SystemModule> kSystemModules = <SystemModule>[
  SystemModule(
    id: 'core.acquisition_passthrough',
    name: 'Прохождение сырого сигнала',
    category: 'acquisition',
    stage: 'Raw Buffer',
    description:
        'Точка входа сырых кадров HAL в конвейер. В v0.1 просто пропускает '
        'данные, в v0.2 здесь появится нормализация каналов от HAL.',
  ),
  SystemModule(
    id: 'core.gain',
    name: 'Усиление',
    category: 'dsp',
    stage: 'Preprocessing',
    description:
        'Масштабирование сигнала на коэффициент усиления (Preprocessing).',
  ),
  SystemModule(
    id: 'core.smoothing',
    name: 'Сглаживание (EMA)',
    category: 'dsp',
    stage: 'Preprocessing',
    description:
        'Экспоненциальное сглаживание по каналам; снижает высокочастотный '
        'шум. Полноценная очистка (фильтр 50/60 Гц, ICA) — следующий шаг.',
  ),
  SystemModule(
    id: 'core.diagnostics',
    name: 'Диагностика сигнала',
    category: 'feature',
    stage: 'Feature Extraction',
    description:
        'RMS, доминирующая частота спектра (FFT 256 c окном Ханна) и '
        'эвристическое качество сигнала.',
  ),
  SystemModule(
    id: 'core.event_markers',
    name: 'Маркеры событий',
    category: 'utility',
    stage: 'Event Markers',
    description:
        'Заготовка системы меток, привязанных к событиям парадигмы '
        '(ERP-разметка).',
  ),
  SystemModule(
    id: 'core.storage_recorder',
    name: 'Рекордер сессий',
    category: 'output',
    stage: 'Storage',
    description:
        'Заготовка записи потока в локальное хранилище сессий.',
  ),
  // --- planned (TODO per roadmap) ---
  SystemModule(
    id: 'future.spectrogram_tools',
    name: 'Инструменты спектрограммы',
    category: 'feature',
    stage: 'Visualization',
    description:
        'Обрезка, заметки, маркировка, экспорт спектрограмм. Реализуется '
        'на экране «Спектрограмма».',
    active: false,
  ),
  SystemModule(
    id: 'future.ml_training',
    name: 'Обучение моделей',
    category: 'inference',
    stage: 'Inference',
    description:
        'Обучение нейросетевых моделей без кода: батчи, кластеры '
        'спектрограмм, экспорт в ONNX.',
    active: false,
  ),
  SystemModule(
    id: 'future.pattern_detection',
    name: 'Обнаружение паттернов',
    category: 'inference',
    stage: 'Post-processing',
    description:
        'Обнаружение паттернов заболеваний и автопометка (медицинский '
        'режим, под контролем прав).',
    active: false,
  ),
  SystemModule(
    id: 'future.topomap',
    name: 'Топографические карты',
    category: 'feature',
    stage: 'Visualization',
    description: 'Топокарты и 3D-визуализация активации ЭЭГ.',
    active: false,
  ),
];
