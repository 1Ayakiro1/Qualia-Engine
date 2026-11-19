# Сигнальный путь — 0.5.2-dev.6

## Что можно проверить

1. Установить совместимую `liblsl` (`liblsl.so`, `.dylib`, `lsl.dll` в системном
   loader path). Библиотека не включается в дистрибутив и не скачивается движком.
2. «Устройства» → «Найти LSL»: поиск только по явному запросу пользователя.
   Поднять поток с непустым `source_id`, числом каналов 1–256 и положительной
   равномерной nominal rate; включить его существующим toggle в списке потоков.
3. «Сессия» → старт → стоп: необработанные float32 блоки сохраняются в EDF,
   метаданные — в JSON index в Application Support `sessions/`. Список доступен
   после перезапуска. Выбор записи активирует экспорт; поддержан импорт EDF.
4. «Спектрограмма» показывает первый канал текущего источника. В остальных
   каналах данные не перемешиваются; raw запись сохраняет все каналы.

## Ограничения, которые важно не скрывать

- Это host acquisition, не источник на графе `.qmod`. Внешний `apiLayers` binding
  описан в SDK descriptor. Process-v1 control/data остаётся NDJSON; native blocks
  и typed isolate transfers **не означают** бинарный module-to-module transport.
- Нет осциллографа/пробы конкретного провода графа, HAL-драйвера ADS1299,
  impedance/calibration, clock correction или EDF+ annotations.
- Запись буферизуется в памяти (не более 16 млн float values ≈64 MB payload),
  EDF кодируется на worker при остановке. Лимит/смена source или формата завершает
  запись с ошибкой и сохраняет предыдущие блоки. Нет crash-safe streaming writer;
  аварийное завершение процесса до сохранения может потерять текущую запись.
- EDF поддерживает plain EDF, несколько records, одинаковое samples-per-record
  у всех каналов, ASCII labels и физическую калибровку. EDF+/BDF, mixed-rate,
  unknown record count и annotations отвергаются. EDF quantization — int16,
  поэтому экспорт не является lossless float32 архивом.
- Единицы LSL не предполагаются автоматически: при записи неизвестные units
  остаются пустыми, а не объявляются μV. При EDF import/export units сохраняются.
- Demo-симулятор: 256 Hz, **1 канал**. Он отключается при активном LSL, acquisition
  не зависит от Flutter frame clock. Legacy native DSP preview пока mono/256 Hz;
  другие форматы получают raw capture и Dart RMS, не вымышленный native DSP.
- Проверка через ABI fixture не заменяет опыт с настоящим LSL outlet/оборудованием.

## Проверки

`scripts/build_core.sh`: тестовая liblsl C ABI проверяет discovery/open/pull,
JSON overflow, bounds, channels, timestamps, invalid arguments и cleanup.
Отдельная fixture лежит только в `core/build/test-lsl`, не в release bundle.

```bash
cd app
LD_LIBRARY_PATH="$PWD/../core/build:$PWD/../core/build/test-lsl" \
QUALIA_TEST_LSL=1 flutter test test/render_signal_test.dart test/session_store_test.dart
```
