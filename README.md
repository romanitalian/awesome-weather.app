Awesome Weather App
====================

Unified weather platform: beautiful Flutter client + fast Go backend. One API for forecast, marine and tides, with caching, metrics and clean architecture.

Features
--------
- Modern Flutter UI (web, macOS, Windows, Linux, iOS, Android)
- Normalized weather data from Open‑Meteo (current, hourly, daily)
- Marine and Tides modules (Pro-ready)
- Geocoding and Reverse geocoding
- Alerts (rule-based, next 24h)
- Redis caching, ISO‑8601 UTC timestamps, explicit units
- Prometheus metrics and structured logs
- Simple local dev and Docker stack

Architecture
------------
Client (Flutter) ↔ Backend (Go) ↔ Providers (Open‑Meteo, Marine, WorldTides)

- Backend: transport in `handlers/`, business rules + normalization, cache layer, metrics, CORS/rate‑limit middleware
- Frontend: feature-based modules (`features/<name>`), services, models, shared utilities
- See `.cursor/rules/*` for code generation conventions and project rules

API (v1)
--------
Base: `/api/v1`

- `GET /health` — service status
- `GET /weather?lat&lon&units=metric|imperial&hours=48&days=7`
- `GET /marine?lat&lon`
- `GET /tides?lat&lon` (requires `WORLDTIDES_API_KEY`)
- `GET /alerts?lat&lon&units=metric|imperial&wind_speed_gte=10&precip_gte=1`
- `GET /geocode?q`
- `GET /geocode/reverse?lat&lon`
- `GET /history?lat&lon&days=7&units=metric|imperial`

Responses are JSON; all times are ISO‑8601 UTC; error format: `{ code, message, details }`.

Quick Start
-----------
Prereqs: Docker (optional), Go 1.24+, Flutter 3.8+.

Option A — One command dev (Docker stack or local fallback):

```bash
make dev-open
```

Option B — Local backend + Flutter web:

```bash
make backend-run-local-bg
make web-run
```

Option C — Full Docker stack (Redis + Backend + Web):

```bash
make dc-up-open
```

Backend Local Run
-----------------

```bash
cd backend
make run HTTP_ADDR=127.0.0.1:8080 LOG_LEVEL=debug REDIS_ADDR=127.0.0.1:6379
```

Open `http://127.0.0.1:8080/health`

Frontend Local Run
------------------

```bash
cd app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Environment
-----------

Create `.env` in project root (not committed):

```dotenv
APP_ENV=dev
HTTP_ADDR=:8080
LOG_LEVEL=debug
REDIS_ADDR=127.0.0.1:6379
REDIS_DB=0
REDIS_PASSWORD=
RATE_LIMIT_REQUESTS=0
RATE_LIMIT_WINDOW_SEC=60
# WORLDTIDES_API_KEY=
```

Makefile Essentials
-------------------

Top-level:
- `make dev-open` — start stack (Docker if available) and open web
- `make backend-run-local-bg` — run backend locally in background
- `make web-run` — run Flutter app in Chrome
- `make dc-up` / `make dc-down` — Docker stack up/down

Backend `backend/Makefile`:
- `make run` — build and run server
- `make test` — run Go tests
- `make fmt` / `make vet` — format and vet

Project Structure
-----------------

```
awesome-weather.app/
├── app/ (Flutter)
│   └── lib/features/{weather,marine,tides,alerts,geocode,...}
├── backend/ (Go)
│   ├── cmd/server
│   └── internal/{handlers,models,cache,httpserver,metrics,config,telemetry}
└── docs/
```

Conventions & Rules
-------------------
- See `.cursor/rules` for style, architecture, endpoints, env, restricted patterns
- No `panic`, no `reflect`/`runtime`/generics/`any`, no `%w`
- Errors bubble up; no swallowing
- Use `strings.Builder` for non-trivial concatenation

Monitoring
----------
- Prometheus `/metrics`
- Counters for HTTP and external API calls; timers for durations; cache hit/miss

Roadmap (high-level)
--------------------
- UV index endpoint
- Offline cache for client
- Favorites sync
- Advanced alerting rules

