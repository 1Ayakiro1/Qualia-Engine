# Готовые сборки

Папка для удобства пользователей: здесь лежат свежие собранное приложение,
которое можно запустить без сборочной цепочки. Содержимое перезаписывается
при каждом `./scripts/build_all.sh` и не попадает в git (кроме этого README).

| Файл | Что это |
|---|---|
| `Ayakiro_BCI_Engine-<версия>-x86_64.AppImage` | портативный запуск на Linux (один файл) |
| `Ayakiro_BCI_Engine-<версия>-linux-x64.tar.gz` | portable-архив того же бандла |
| `binary/` | **бинарник целиком**: `./bci_engine` + `lib/` + `data/` — запуск без распаковки |

```bash
# AppImage
chmod +x Ayakiro_BCI_Engine-*.AppImage && ./Ayakiro_BCI_Engine-*.AppImage

# бинарник
./binary/bci_engine
```

Windows (`*.zip`) и macOS складываются сюда же из CI-сборок.