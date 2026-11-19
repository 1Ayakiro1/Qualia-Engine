# Плавность интерфейса и частота кадров

## Настройки dev.6

«Настройки → Производительность» сохраняет качество сетки и частоту обновления
live metrics/спектрограммы (Auto, 30/60/90/120/144/165/240). Это **не глобальный
FPS limiter** канваса/анимаций и не смена режима монитора. Frame gate использует
монотонное время и сохраняет фазу дробного отношения частот (144 Hz / 60 updates).
Симулятор и LSL acquisition работают независимо от display ticks.

Linux runner читает `~/.config/com.ayakiro.bci_engine/render-backend` (с учётом
XDG_CONFIG_HOME) до создания FlView: `auto`, `skia`, `impeller`. Выбор применяется
после перезапуска; это два GPU backend, не CPU/GPU selector. Impeller экспериментален
и зависит от драйвера. При сбое удалить этот файл для возврата к SDK default.
Environment Flutter switches имеют приоритет. Windows/macOS renderer selector
не показывается: их startup glue в этой версии не реализован.

Уменьшена геометрия header canvas, O(E×N) обход return-to-scene заменён индексом.
Это не доказательство «плавности как Blender»: hardware profile 144+ Hz, frame
timings, pan/drag на большом графе и GPU-driver matrix ещё требуют измерений.

## Native vsync в Linux-сборке

Приложение собирается на Flutter 3.47.5 (engine revision `af7e796e16`).
Стандартный Linux embedder `fl_engine.cc` не устанавливает `vsync_callback`.
`PlatformViewEmbedder::CreateVSyncWaiter` в этом случае выбирает fallback,
а `VsyncWaiterFallback` задаёт интервал `1 / 60` секунды. Частота монитора,
передаваемая через `FlDisplayMonitor`, сама по себе этот путь не меняет.

Поэтому переключатель «144 Гц» на уровне Dart не даст 144 FPS в стандартной сборке.
144 Гц — режим монитора; 144 FPS — частота новых кадров приложения. Настройка
монитора в системе необходима, но недостаточна для стандартного embedder.

Qualia теперь содержит небольшой native-vsync bridge в `native/linux_vsync/`.
Он подключает `FlutterProjectArgs.vsync_callback` к GTK frame clock окна.
Запросы engine с любого потока возвращаются на GTK platform thread; кадр
получает start/target timestamps через `FlutterEngineOnVsync`. Монотонные часы
GTK и Flutter переводятся через одновременно взятые отсчёты, без предположения
об одинаковой эпохе. Интервал берётся из `GdkFrameClock`, не из константы 144 Гц.
Окно использует frame clock своего текущего display; при перемещении между
мониторами bridge снова читает refresh info. Существующий Flutter GTK renderer,
input, accessibility и API плагинов сохранены.

Tick callback одноразовый: новый кадр запрашивается только при потребности
Flutter, постоянного рендеринга в простое нет. Для ещё не показанного окна,
unmap и shutdown незавершённые batons завершаются без ожидания отсутствующего
frame clock. Это защищает bootstrap и закрытие от зависаний, но не является
таймером постоянной отрисовки. Если GTK не имеет presentation history, его
refresh info временно использует 60 Гц — до появления настоящих timings.

Поддержка высокой частоты следует частоте, которую реально предоставляет GTK /
compositor. На Wayland это зависит от frame/presentation callbacks compositor;
на X11 — от поддержки presentation timings/window manager. Если GTK сообщает
60 Гц, bridge не выдумывает 144 Гц. Режимы 144/165/240 Гц и стабильный FPS
требуют проверки на соответствующем устройстве и достаточной производительности
GPU/CPU; добавление native-vsync само по себе не гарантирует отсутствие jank.

## Сборка и диагностика

`scripts/build_native_embedder.sh release` собирает из исходников pinned Flutter
GTK engine. SDK пользователя не изменяется: исходники, зависимости и результаты
хранятся в `~/.cache/qualia-native-vsync` (или `QUALIA_ENGINE_CACHE`). Первый запуск
требует сети, нескольких десятков GB свободного места и длительной C++-сборки.
Следующие сборки инкрементальные. `QUALIA_ENGINE_JOBS` задаёт число compile jobs
(по умолчанию 4), `QUALIA_SYNC_JOBS` — число download jobs (6).

`scripts/build_linux.sh` требует custom embedder и заменяет только библиотеку
`libflutter_linux_gtk.so` в release bundle перед созданием AppImage/tarball.
При несовпадении engine revision сборка завершается с ошибкой, а не незаметно
публикует стандартный fallback. Новую версию Flutter нужно адаптировать и
тестировать отдельно. Для `flutter run` из SDK custom библиотека не подключается
автоматически; опубликованные Linux-артефакты используют bridge.

При старте stderr содержит `Qualia native vsync: enabled`, а после native ticks
— `GTK frame clock ... Hz`. Это частота timings, не счётчик реально отображённых
кадров. Для сравнения со старым путём запустить:

```bash
QUALIA_NATIVE_VSYNC=0 ./builds/$(cat VERSION)/binary/bci_engine
```

Тесты `scripts/test_native_vsync.sh` проверяют перевод 60/144/165/240-Гц timings,
thread handoff, bootstrap, native tick, unmap и drainage при shutdown. Для GTK
bridge нужен display или `xvfb-run`. Они не подменяют hardware FPS-проверку.

Исходники установленной ревизии:

- [Linux engine](https://github.com/flutter/flutter/blob/af7e796e16/engine/src/flutter/shell/platform/linux/fl_engine.cc)
- [Embedder vsync selection](https://github.com/flutter/flutter/blob/af7e796e16/engine/src/flutter/shell/platform/embedder/platform_view_embedder.cc)
- [Fallback frame interval](https://github.com/flutter/flutter/blob/af7e796e16/engine/src/flutter/shell/common/vsync_waiter_fallback.cc)

## Реализованные изменения

- Каталог, фильтры Marketplace, Explorer и debug log используют общий
  `DesktopScrollController`. Крупные шаги scroll-событий (от 40 logical px)
  сглаживаются за 140 ms с накоплением цели; смена направления отменяет
  неотрисованный остаток. Мелкие дельты проходят напрямую. Linux не всегда
  отличает тачпад от мыши, поэтому это эвристика по величине дельты, не обещание
  определения физического устройства. Reduced-motion отключает сглаживание.
- Workspace сохраняет прямой pan/zoom без добавления задержки тачпаду.
- Фон канваса и узлы изолированы repaint-boundaries. Групповой drag публикует
  одно изменение состояния за pointer-событие, точки рисуются пакетно,
  lookup связей выполняется через индекс узлов вместо повторного обхода списка.
- Marketplace masonry использует ленивый sliver; обложки отделены
  repaint-boundaries от анимируемого hover-фона карточки.

Изменения уменьшают скачки прокрутки и лишнюю работу, но не являются замером
FPS на реальном 144-Гц дисплее. Для оценки производительности использовать
profile/release, не debug; сравнивать одинаковые сценарии pan, group drag,
scroll и resize окна. На 144 FPS бюджет кадра около 6.94 ms, на 60 FPS — 16.67 ms.
