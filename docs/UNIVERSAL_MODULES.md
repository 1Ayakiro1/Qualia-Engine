# Универсальные .qmod

`.qmod` — общий ZIP-контейнер, а не Linux-формат. В `process-v1` теперь можно
поставлять **один пакет с несколькими исполняемыми вариантами**. Движок выбирает
вариант по ABI своего процесса и запускает его без shell и без установки зависимостей.

## Manifest

```json
{
  "format": "qualia-module",
  "schemaVersion": 1,
  "runtime": "process-v1",
  "id": "portable-example",
  "name": "Portable example",
  "version": "0.1.0",
  "languages": ["Go"],
  "targets": {
    "linux-x64": {"executable": "targets/linux-x64/module", "arguments": []},
    "linux-arm64": {"executable": "targets/linux-arm64/module", "arguments": []},
    "windows-x64": {"executable": "targets/windows-x64/module.exe", "arguments": []},
    "windows-arm64": {"executable": "targets/windows-arm64/module.exe", "arguments": []},
    "macos-x64": {"executable": "targets/macos-x64/module", "arguments": []},
    "macos-arm64": {"executable": "targets/macos-arm64/module", "arguments": []}
  },
  "ports": {"inputs": ["input"], "outputs": ["output"]}
}
```

- Разрешено любое непустое подмножество шести target IDs. `targets` нельзя смешивать
  с одиночными `platform`/`launch` или legacy `entrypoint`.
- Старые `native-process-v1` Linux x64 пакеты совместимы без изменения. Одиночный
  `process-v1` с `platform`/`launch` также поддерживает все шесть target IDs.
- Схемы портов, параметры и UI общие для всех вариантов: перенос одного workspace
  не должен менять контракт модуля. Hash одного универсального архива одинаков на ОС.
- При отсутствии нужного варианта установка завершается понятной ошибкой со списком
  доступных платформ. Нет fallback на другой ABI, автоматического скачивания,
  Wine/Rosetta запуска, shell или системного интерпретатора.
- Проверяются **все** declared executables: Linux ELF64, Windows PE32+, macOS
  Mach-O64 или universal Mach-O с нужным slice. Неверные архитектуры отклоняются.
  Это проверка формата/архитектуры, не доказательство отсутствия вредоносного кода.
- Rosetta x64-приложение выбирает `macos-x64`; native arm64 — `macos-arm64`.
- cwd — корень пакета. Общие ресурсы можно хранить отдельно; зависимости разных
  платформ — в `targets/<target>/`. Windows DLL рядом с exe; macOS dylib связывать
  через `@loader_path`/`@rpath`; Linux `.so` — `$ORIGIN`. Host не подменяет loader paths.
- Bundled Python/Java/.NET/WASM runtime тоже возможен: launch указывает на его
  платформенный executable, arguments — на скрипт/assembly/wasm внутри пакета.
  Язык не ограничен списком `languages`, но runtime и зависимости нужны для каждой ОС.
- Пути case-insensitive unique, без Windows device names, двоеточий, trailing dot/
  space, traversal и symlinks. Лимиты пока общие: 256 MiB и 4096 файлов на весь архив.
  Большие runtimes можно поставлять отдельными одноцелевыми пакетами того же формата.

## Проверка

```bash
python3 modules/examples/universal/prepare.py /path/to/universal
cd app
QUALIA_UNIVERSAL_QMOD=/path/to/universal/dist/universal-go-0.1.0.qmod flutter test test/universal_modules_test.dart
```

Go example кросс-компилируется без CGO/сети на шесть платформ и использует JSON и
SHA-256. CI собирает архив один раз и передаёт одинаковые байты всем build hosts.
Дополнительно C++/C fixture компилируется на каждой ОС и загружает packaged
`.so`/`.dll`/`.dylib` из своего каталога. CI запускает установку, выбор ABI, независимые процессы, передачу
данных, контроль digest, завершение и integrity на каждой build OS. ARM payloads
можно собрать на x64, но это **не равно** подтверждению их запуска на ARM-устройстве;
фактическое покрытие определяется runners конкретного успешного Actions run.

## macOS и доверие

Qualia — обычное desktop-приложение, **не App Store sandbox**: App Sandbox выключен
для разрешённого пользователем запуска внешних модулей из Application Support.
Модули — доверенные пользовательские процессы, не изолированные security sandboxes.
Они обладают правами пользователя. Не устанавливайте непроверенные пакеты.

Developer ID/notarization приложения и сторонних модулей остаются отдельной задачей
распространения. Самодостаточность архива не отменяет Gatekeeper, разрешения на
исполнение, минимальную версию macOS/Windows, glibc baseline, драйверы и лицензионные
условия runtime. Нативные библиотеки необходимо собирать/проверять для каждого ABI.
Полностью один бинарник для всех ОС возможен только поверх portable VM, но сама VM
всё равно платформенная; встроенной VM или нового протокола для этого не требуется.
