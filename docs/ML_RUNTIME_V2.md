# ML runtime v2 — разработка 0.5.2, не опубликованный контракт

**Состояние: работа начата. Версия сборок `0.5.2-dev.1`, не релиз 0.5.2.**
Пользовательский критерий: все семь подсистем ниже, Linux/Windows/macOS,
независимый воспроизводимый ML-пример. Частичный транспорт не считается готовым
ML runtime. Внешний bci-express не предоставлен и не считается протестированным.

Публичный контракт пакетов пока остаётся schemaVersion 1 / protocol 1. Нельзя
просто разрешить manifest v2: host должен реализовать всё, что такой пакет требует,
либо отклонить его **до запуска**, а не откатить молча на JSON/неизолированный режим.

## Критерий релиза

| Подсистема | Обязательная реализация/проверка | Текущее состояние |
|---|---|---|
| 1. Data-plane | Раздельный control v2 и binary transport, SHM/TCP, credits и три политики, tensor schemas, чанки >1 MiB, v1 compatibility | Есть владение блоком/очереди C ABI и draft codec; нет маршрута host/module, SHM и protocol v2 |
| 2. HAL | Device Manager, LSL/serial/file replay, host scheduling, имена каналов, resampling/timestamps/loss/drift, реальный источник вместо UI SyntheticSignal | Не реализовано |
| 3. Runtime store | Install-time Python/lockfile, OS/ABI/CPU/CUDA варианты, общий CAS, atomic install, offline run, SBOM/licences, references + GC | Не реализовано |
| 4. Lifecycle | node/stateful/service/job, долгий startup, checkpoints, service health/restart, jobs/log/progress/cancel/artifacts, обязательные ресурсы/очередь GPU на трёх ОС | Не реализовано |
| 5. Storage | Persistent sessions/artifacts/refs, EDF/FIF import, dataset/window/filter/splits spec, signal contract + versioned Model Registry | Не реализовано |
| 6. UI | signal viewer/spectrogram/training curves/confusion matrix из данных runtime, reuse theme, ограниченная история без блокирования data-plane | Не реализовано |
| 7. Trust/distribution | Проверка подписи до execution/install hooks, dependency audit, capabilities с OS enforcement, remote install с signed URL и integrity | Не реализовано |

Проверки ОС в CI должны включать **поведение**, не только сборку: запрещённый net/fs,
разрешённый resource path, превышение RAM/CPU, отказ доступа к USB, process-tree
cleanup, job cancel, service restart. Manifest capabilities не являются sandbox.
Неподдерживаемая запрошенная capability/resource isolation — отказ запуска.

## Слои и границы ответственности

- **C++ core:** блоки/владение, byte-bounded очереди, HAL clock domains,
  DSP/windowing и native broker. Dart не переносит float tensors через JSON.
- **Data broker:** выдача edge/stream IDs и leases, negotiation и lifetime,
  credits только после освобождения блока конечным потребителем; ошибки соединения
  изолированы по экземпляру. Shared memory — OS mapping + process-safe protocol
  владения слотами, не просто файл с float32 и sleep/poll.
- **Execution supervisor:** отдельные области node/workspace, stateful/checkpoint,
  application-wide service и persisted finite job. Управление process groups,
  лимитами и capability policy принадлежит supervisor, а не ML-процессу.
- **Install/runtime service:** resolve/download/build только при явной установке,
  immutable hash-locked environment, verification и запрет недоверенных hooks.
  Ключ CAS учитывает ABI, Python, accelerator/runtime/driver compatibility и lock.
  Разделяемы immutable wheels/blobs; writable state и environments изолированы.
- **Storage/Registry:** blob digest + атомарные metadata/references; jobs публикуют
  веса и signal contract транзакционно, а не сохраняют в каталог установленного
  пакета. Удаление только unreferenced blobs с active lease protection.
- **UI:** наблюдатель downsampled signal/metrics и команд supervisor. Исчезновение
  виджета/смена workspace не прекращает application service или job.

## Реализованный фундамент C ABI v3

`core/include/bci_engine/c_api.h`:

1. `bci_block_create` создаёт нативную float32 allocation.
2. `bci_block_wrap` принимает **эксклюзивную mutable lease** внешней allocation с
   release callback. Это точка интеграции будущего SHM pool, не готовый SHM transport.
3. `bci_engine_push_block(engine, &handle)` передаёт владение только при `BCI_OK`,
   тогда `handle == NULL`. При overflow/invalid/not-started handle остаётся у caller.
4. Pipeline работает с тем же адресом. `bci_engine_pop_block` отдаёт тот же handle
   с тем же payload pointer; обработка in-place меняет значения, не layout/metadata.
5. `bci_block_release` освобождает lease ровно один раз. Callback может выполняться
   на worker thread; он не должен бросать исключения/блокироваться/reenter engine.

`bci_block_info`: frames, channels, sample_rate, first_sample, timestamp_ns,
layout (interleaved/channel-major), clock (unknown/monotonic/Unix). Время относится
к первому frame; spacing uniform. Между clock domains нужна явная трансформация,
а не арифметика wall-clock и LSL clock. Нет per-sample нерегулярных timestamps
в этом типе; HAL должен нормализовать поток или добавить отдельный тип.

Один блок ≤256 MiB, проверка dimensions/rate/index overflow до allocation.
Очередь ограничена **и числом блоков, и байтами**: capacity 1..4096, budget ≤2 GiB
на очередь. Есть ещё один in-flight worker block и один legacy partial-drain lease:
это не process-wide лимит RAM. Input/output отдельно настраиваются до start:

- `every`: input возвращает overflow без потери владения; output ждёт credits.
  Caller должен retry/приостановить upstream. stop закрывает очереди и будит worker.
- `drop-oldest`: атомарно вытесняет целые старые queued blocks.
- `latest-only`: оставляет только новейший queued block; уже исполняемый не отменяет.

Очередь использует короткий mutex: честный bounded/zero-copy API, **не** обещание
lock-free/hard-real-time. Вытеснение не вызывает release callback под mutex очереди.
Прежний producer-side dequeue из SPSC был гонкой с worker consumer; он устранён.

Legacy push/pop остаются доступны. Частичное чтение больше не пересобирает блок
и не ставит остаток в хвост за следующими блоками. Смешивание pop_block с частично
дренированным legacy block отклоняется, чтобы не нарушить порядок/metadata.

## Draft QSB2 wire codec

Код: `core/include/bci_engine/signal_v2.hpp`, `core/src/signal_v2.cpp`,
`app/assets/module_sdk/signal_v2.py`. Это **codec**, пока не транспорт движка.
Один согласованный stream соответствует одному ребру; произвольные port IDs и
auth tokens нельзя передавать из недоверенного data payload для смены маршрута.

Все числа little-endian; sample payload IEEE754 float32. Header 80 bytes:

| Offset | Тип | Значение |
|---|---|---|
| 0 | char[4] | `QSB2` |
| 4 / 6 | uint16 / uint16 | wire version 2 / header size 80 |
| 8 | uint32 | bit 0: channel-major; bits 8..9: clock; остальное 0 |
| 12 | uint32 | dtype 1 = float32 |
| 16 / 24 | uint64 / uint64 | sequence / first sample |
| 32 / 40 | int64 / float64 | timestamp ns / sample rate |
| 48 / 52 | uint32 / uint32 | channels / frames |
| 56 / 64 | uint64 / uint64 | payload byte offset / total block bytes |
| 72 / 76 | uint32 / uint32 | chunk payload bytes / IEEE CRC32 chunk |

Chunk ≤1 MiB, float-aligned; один блок ≤256 MiB независимо от лимита JSON.
Metadata повторяется и должна совпадать у всех chunks. Строго последовательные
offsets и возрастающие block sequence: gaps/duplicates/replay/corruption отклоняются.
Header проверяется до allocation, reassembly — в один итоговый bounded buffer,
без накопления списка chunks. Python encoder отдаёт memoryview без копирования.
TCP receive/reassembly копирует данные; это **не zero-copy между процессами**.
Нужны deadline и negotiated credits вокруг codec; CRC не заменяет auth/TLS/signature.

## Порядок дальнейшей реализации

1. Native broker + OS shared-memory leases и bounded TCP session/credits; подключить
   к ModuleRuntime и tensor schema negotiation. Только затем разрешить v2 manifest.
2. Device Manager / adapters + host-driven scheduling; публичная спецификация serial
   framing и реальный fixture до обещаний поддержки платы. Replay/LSL tests с
   injected clock, drift/gaps, resampling/channel-name numerical reference.
3. Registry/Storage и runtime CAS как независимые persistent services; lock and
   permission model до автоматического скачивания/установки чужих dependencies.
4. Supervisor и enforced OS isolation adapters + GPU queue. macOS capabilities
   требуют поддерживаемого OS механизма, не обещаний Python resource limits.
5. Сигнальный/обучающий UI поверх services, remote install/signatures/audit.
6. E2E независимый ML fixture: source → filter/window → inference → supervised sink;
   finite train → versioned model + contract → inference без пересборки `.qmod`.

Конечные E2E: 250 Hz многоканальный поток с оконным tensor >1 MiB, проверка
семплов/времени, slow consumer по всем policy, reconnect/crash, session persistence,
training cancel/resume/artifact integrity, model compatibility rejection, CAS
dedup/GC concurrent install/job, trusted/untrusted remote package, resource and
capability denial на **каждой из трёх ОС**. До этого релизный тег не создаётся.
