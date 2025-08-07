## Architecture

Client (Flutter) ←→ Backend (Go) ←→ External weather providers (Open‑Meteo, Marine; optional Stormglass, WorldTides)

- All provider keys live on backend only.
- Two‑level cache: Redis (server), local DB (client).
- REST/JSON, `/api/v1`, ISO‑8601 UTC times, explicit units.
