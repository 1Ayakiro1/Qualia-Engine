# Актуальная сборка

Здесь хранится **только одна версия** — из корневого `VERSION`.
Все форматы этой сборки находятся вместе:

```text
builds/
├── README.md
└── <VERSION>/
    ├── Qualia-Engine-<VERSION>-x86_64.AppImage
    ├── Qualia-Engine-<VERSION>-linux-x64.tar.gz
    ├── binary/
    │   ├── bci_engine
    │   ├── lib/
    │   └── data/
    └── SHA256SUMS
```

Основной формат Linux — **AppImage**, один самодостаточный файл. Архив и
распакованный bundle — альтернативные формы **той же сборки**, не другие версии.
Windows/macOS создают ZIP на соответствующей ОС; они не компилируются на Linux.

Из корня репозитория:

```bash
# Полная сборка и замена актуального набора
./scripts/build_all.sh

# Запуск одного файла
./builds/$(cat VERSION)/Qualia-Engine-$(cat VERSION)-x86_64.AppImage

# Или распакованного bundle (lib/ и data/ должны оставаться рядом)
./builds/$(cat VERSION)/binary/bci_engine

# Проверка целостности
(cd "builds/$(cat VERSION)" && sha256sum -c SHA256SUMS)
```

Сначала собираются все форматы, затем заменяется каталог результата. При
ошибке сборки прежний набор остаётся. После успешной публикации прежние версии,
дубликаты и `binary-previous-*` удаляются; автоматического архива здесь нет.
Не храните личные файлы в каталогах версий. README в корне сохраняется.

Проверочная сборка отдельно: `DIST_OUT=/tmp/opencode/qualia-check ./scripts/build_all.sh`.
Детали, выбор stock/native GTK и ограничения платформ: [docs/BUILD.md](../docs/BUILD.md).
Номер `*-dev.*` означает development build, а не опубликованный стабильный релиз.
