# Готовые модули Qualia Engine

Пакеты `.qmod` находятся в `modules/` в корне репозитория, отдельно от
сборок движка в `builds/`. Они не запускаются и не устанавливаются автоматически.

- `local-gain-0.1.0.qmod` — пример обработки и передачи числа между узлами.
- `test-module1-0.1.0.qmod` — калькулятор с двумя числами и кнопками `+`, `−`, `×`, `÷`.

Установка: Workspace → Explorer → **+** → **Добавить локально (.qmod)**.
После подтверждения доверия перетащите модуль на граф и выберите **Open**.

Исходники калькулятора на этом компьютере: `/home/ayakiro/Documents/test_module1`.
Сборка:

```bash
cd /home/ayakiro/Documents/test_module1
python3 qmod.py check .
python3 qmod.py build .
```

Результат: `dist/test-module1-0.1.0.qmod`. Технический ID использует дефис,
отображаемое имя и папка проекта — `test_module1`.

SDK остаётся в `app/assets/module_sdk/`: он включён в приложение для оффлайн
создания проектов. Установленные пакеты движок распаковывает в пользовательское
хранилище application support `qmod/<SHA-256>/`, а не рядом с AppImage.
На Linux обычно это `~/.local/share/com.ayakiro.bci_engine/qmod/`
(либо legacy-каталог `~/.local/share/bci_engine/qmod/`).

Отдельный процесс не является защитной песочницей; устанавливайте доверенный код.
Полный контракт SDK: [docs/LOCAL_MODULES.md](../docs/LOCAL_MODULES.md).
