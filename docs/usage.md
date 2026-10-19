# Usage Guide

Цей документ описує основні дії для роботи з проєктом: запуск AI-агента в VS Code Copilot Chat, локальну збірку та перевірку, запуск програми та запуск unit-тестів.

## 1. Запуск AI-агента у VS Code Copilot Chat

1. Відкрийте папку проєкту в VS Code.
2. Відкрийте панель Copilot Chat.
3. У полі вводу введіть:
   - `@build-engineer /init`
   - `@build-engineer /check`
4. Після цього агент виконає відповідні дії, пов'язані з ініціалізацією проєкту або перевіркою його стану.

### Команди агента

- `@build-engineer /init` — ініціалізує структуру проєкту та запуск базових етапів підготовки.
- `@build-engineer /check` — виконує перевірку поточного стану проєкту за критеріями без змін у коді або конфігурації.

## 2. Локальна збірка та перевірка

### Для Linux/macOS

У терміналі виконайте:

```bash
./ci.sh
```

Цей скрипт виконує наступні кроки:

```bash
npm install
node scripts/build.js
npm test -- --runInBand
```

### Для Windows

У PowerShell або командному рядку виконайте:

```powershell
.\ci.bat
```

Цей скрипт виконує аналогічну послідовність:

```bat
call npm install
call node scripts/build.js
call npm test -- --runInBand
```

## 3. Запуск головного файлу програми

Після успішної збірки можна запустити готовий бінарний/збірковий файл:

```bash
node dist/hello.js
```

Очікуваний результат:

```text
Hello, World!
```

## 4. Запуск unit-тестів

Для запуску тестів використовуйте:

```bash
npm test
```

Ця команда запускає Jest і перевіряє, що тест `BasicAddition` проходить успішно.

## 5. Коротка послідовність для нових користувачів

```bash
# Linux/macOS
./ci.sh
node dist/hello.js
npm test
```

```powershell
# Windows
.\ci.bat
node dist/hello.js
npm test
```

## 6. Підсумок

Основні команди проєкту:

- `@build-engineer /init`
- `@build-engineer /check`
- `./ci.sh` (Linux/macOS)
- `.\ci.bat` (Windows)
- `node dist/hello.js`
- `npm test`
