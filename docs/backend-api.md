## Backend API (v1)

Base path: `/api/v1`

### Основные endpoints

- `GET /health` → `{ "status": "ok", "time": "<iso8601>" }`
- `GET /weather?lat&lon&units=metric|imperial&hours=48&days=7` — normalized forecast (server trims arrays to requested `hours`/`days`)
- `GET /marine?lat&lon` — surf/sailing metrics (Pro)
- `GET /tides?lat&lon` — tides (Pro; requires WORLDTIDES_API_KEY; returns 501 if missing key)
- `GET /alerts?lat&lon&units=metric|imperial&wind_speed_gte=10&precip_gte=1` — computed basic alerts for next 24h
- `GET /geocode?q` and `GET /geocode/reverse?lat&lon`
  - Reverse geocoding returns nearest place for coordinates. Cached 7 days.
- `GET /history?lat&lon&days=7&units=metric|imperial` — daily history from Open‑Meteo Archive, up to 30 days; cached 6h.

### Мониторинг и метрики

- `GET /metrics` — Prometheus metrics
  - **HTTP метрики:** `http_requests_total`, `http_request_duration_seconds`
  - **Внешние API:** `external_api_calls_total`, `external_api_duration_seconds`, `external_api_errors_total`
  - **Кэш:** `cache_hits_total`, `cache_misses_total`, `cache_errors_total`
  - **Rate limiting:** `rate_limit_hits_total`
  - **Бизнес метрики:** `weather_requests_total`, `geocode_requests_total`, `marine_requests_total`

### Rate Limiting

Rate limiting (optional): set `RATE_LIMIT_REQUESTS` and `RATE_LIMIT_WINDOW_SEC` envs to enable in-memory limiter per IP+path.

При превышении лимита возвращается:
```json
{
  "error": "rate_limit_exceeded",
  "message": "Too many requests",
  "retry_after": 60
}
```

### Примеры ответов

**Weather Response:**
```json
{
  "source": "open-meteo",
  "issued": "2025-08-07T19:09:49Z",
  "data": {
    "latitude": 59.93,
    "longitude": 30.31,
    "timezone": "UTC",
    "units": {
      "temperature": "°C",
      "wind_speed": "m/s",
      "wind_gust": "m/s",
      "wind_direction": "°",
      "precipitation": "mm",
      "pressure": "hPa",
      "cloud_cover": "%"
    },
    "current": { 
      "time": "2025-08-07T19:00:00Z", 
      "temperature": 17.2, 
      "wind_speed": 4.1, 
      "wind_direction": 220,
      "humidity": 65.0,
      "pressure": 1012.3,
      "cloud_cover": 50.0,
      "uv_index": 3.2
    },
    "hourly": [ 
      { 
        "time": "2025-08-07T19:00:00Z", 
        "temperature": 17.2, 
        "precipitation": 0, 
        "pressure": 1012.3, 
        "cloud_cover": 50, 
        "wind_speed": 4.1, 
        "wind_gust": 8.5, 
        "wind_direction": 220,
        "humidity": 65.0,
        "uv_index": 3.2
      } 
    ],
    "daily": [ 
      { 
        "date": "2025-08-07T00:00:00Z", 
        "temp_max": 20.3, 
        "temp_min": 15.1, 
        "precipitation_sum": 3.4, 
        "wind_speed_max": 6.6, 
        "wind_gusts_max": 13.3, 
        "wind_direction_dominant": 270, 
        "sunrise": "2025-08-07T05:30:00Z", 
        "sunset": "2025-08-07T21:45:00Z",
        "uv_index_max": 5.8
      } 
    ]
  }
}
```

**Marine Response:**
```json
{
  "source": "open-meteo-marine",
  "issued": "2025-08-07T19:57:39Z",
  "data": {
    "latitude": 59.93,
    "longitude": 30.31,
    "timezone": "UTC",
    "units": {
      "wave_height": "m", 
      "wave_period": "s", 
      "wave_direction": "°", 
      "swell_height": "m", 
      "swell_period": "s", 
      "swell_direction": "°"
    },
    "hourly": [
      {
        "time": "2025-08-07T19:00:00Z", 
        "wave_height": 0.6, 
        "wave_period": 6, 
        "wave_direction": 270, 
        "swell_height": 0.4, 
        "swell_period": 8, 
        "swell_direction": 300
      }
    ]
  }
}
```

### Errors format

```json
{ 
  "code": "string", 
  "message": "string", 
  "details": {}
}
```

### Кэширование

- **Weather:** 30 минут
- **Marine:** 30 минут  
- **Geocode:** 7 дней
- **Tides:** 1 час (если доступен API ключ)
- **Alerts:** 15 минут
- **History:** 6 часов

### Ретраи и отказоустойчивость

- **Внешние API:** до 3 попыток с экспоненциальной задержкой (1s, 2s, 4s)
- **Кэш fallback:** при недоступности Redis используется no-op кэш
- **Graceful degradation:** при недоступности внешних API возвращаются ошибки с деталями
