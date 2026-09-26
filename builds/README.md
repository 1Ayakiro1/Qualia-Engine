# Готовые сборки

Папка для пользователей: здесь лежат свежие готовые сборки приложения,
которые можно запустить без сборочной цепочки. Содержимое обновляется при
каждом `./scripts/build_all.sh`; именно этот каталог используется для
публикации бинарников и релизных артефактов.

| Файл | Что это |
|---|---|
| `Ayakiro_BCI_Engine-<версия>-x86_64.AppImage` | портативный запуск на Linux (один файл) |
| `Ayakiro_BCI_Engine-<версия>-linux-x64.tar.gz` | portable-архив того же бандла |
| `binary/` | **бинарник целиком**: `./bci_engine` + `lib/` + `data/` — запуск без распаковки |

```bash
# AppImage
chmod +x Ayakiro_BCI_Engine-*.AppImage && ./Ayakiro_BCI_Engine-*.AppImage

# portable bundle (бинарник + lib/ + data/)
./binary/bci_engine
```

Windows (`*.zip`) и macOS складываются сюда же из CI-сборок.
Каталог `dist/` больше не используется: сборка и запуск выполняются через
`builds/`.
