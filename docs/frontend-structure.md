## Flutter frontend structure (proposal)

- `lib/`
  - `app/` — app root, routing (go_router)
  - `features/`
    - `weather/` — screens, widgets, state (Riverpod), repositories
    - `marine/`
  - `shared/` — theme, widgets, utils
  - `data/` — clients (Dio), local DB (Hive/Drift)
