## План работ и статус

### Сделано (MVP базовый функционал)
- Репозиторий: монорепо `app/` (Flutter) + `backend/` (Go), `docs/`.
- ТЗ: `tech-requirements.aw-app.md` (продукт/тех, функциональные/нефункц.).
- Backend (Go):
  - HTTP-сервер, `/health`.
  - Нормализованный `/api/v1/weather` (Open‑Meteo), кэш Redis, заголовок `X-Cache`.
  - `/api/v1/geocode` (Open‑Meteo geocoding), кэш 7 дней.
  - `/api/v1/marine` (Open‑Meteo Marine), кэш 30 минут.
  - CORS middleware.
  - Dockerfile (distroless), Makefile, конфиг по env.
- Frontend (Flutter):
  - Экран погоды: текущая/почасовая/дневная, переключение единиц (metric/imperial).
  - Геокодинг: поиск с дебаунсом, выбор локации, сохранение последней.
  - Избранное (SharedPreferences): добавление/удаление/быстрый переход.
  - Оффлайн‑фолбек: кеш последнего ответа погоды и marine.
  - Marine-блок: 12 часов (высота/период/направление волн).
  - Карта (OSM): выбор точки, маркеры избранного.
  - Параметр `API_BASE_URL` через `--dart-define`.
- Web/DevOps:
  - Docker Compose стек: `redis`, `backend:8080`, `web:8081` (Flutter Web в Nginx).
  - Nginx прокси `/api → backend` (единый origin, без CORS проблем).
  - Makefile цели: `dc-build`, `dc-up`, `dc-down`, `dc-logs`, `dc-up-open`, `open-web`, `backend-run`, `web-run`, `macos-*`.
  - Документация: `docs/backend-api.md`, `docs/architecture.md`, `docs/frontend-structure.md`, `docs/dev-setup.md`.

### Ближайшие задачи (Next)
- Backend:
  - Нормализовать финальную схему `WeatherRS` (единицы, обязательность, ошибки).
  - Предупреждения/алерты: базовые правила (ветер/осадки/давление), подготовка API.
  - Тиды (Pro): `/api/v1/tides` (WorldTides, ключ из env, кэш, нормализация).
  - Reverse геокодинг: `/api/v1/geocode/reverse` (Open‑Meteo), кэш 7 дней. [добавлено]
  - История (опция): интеграция Meteostat для трендов.
  - Rate limit, ретраи и метрики (Prometheus) для источников.
- Frontend:
  - Рефакторинг UI: карточки, базовые графики (температура/ветер/давление), отдельный блок Marine.
  - Экран списка избранного; улучшение UX поиска (подсветка страны/координат).
  - Хранение/выбор единиц и локаций в настройках, локализация RU/EN.
  - Виджет оффлайн‑статуса/ошибок.
- DevOps:
  - CI (GitHub Actions): линт/тесты/сборка backend, web‑артефакты.
  - Разделение окружений: `.env`, staging/prod compose, базовые алерты.
  - Кэш Docker сборок, уменьшение размера web-образа.

### Дальнейшие улучшения (Pro)
- Источники Pro: Stormglass (детальная морская), WorldTides (приливы/отливы).
- Продвинутые оповещения: пороговые правила, рассылка пушей (через backend).
- Карта‑радар осадков (RainViewer tiles), переключаемые слои.
- История и аналитика: тренды, сравнение локаций, экспорт.

### Команды запуска (Docker)
- Собрать и поднять весь стек: `make dc-build && make dc-up-open` (web на `http://localhost:8081`).
- Остановить: `make dc-down`.

### Примечания
- Кодовые стили (Go): без `panic`, без `%w`, без `reflect/generics`; ошибки из storage прокидываются выше; типы `*RQ/*RS`.
- Для локального Flutter (без Docker): `make backend-run` и `make web-run` (Chrome) либо `make macos-run` (требуется Xcode).


