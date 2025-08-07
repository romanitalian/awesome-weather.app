## Backend API (v1)

Base path: `/api/v1`

- `GET /health` → `{ "status": "ok", "time": "<iso8601>" }`
- `GET /weather?lat&lon&units=metric|imperial&hours=48&days=7` — normalized forecast
- `GET /marine?lat&lon` — surf/sailing metrics (Pro)
  - Response:
  ```json
  {
    "source": "open-meteo-marine",
    "issued": "2025-08-07T19:57:39Z",
    "data": {
      "latitude": 59.93,
      "longitude": 30.31,
      "timezone": "GMT",
      "units": {"wave_height": "m", "wave_period": "s", "wave_direction": "°", "swell_height": "m", "swell_period": "s", "swell_direction": "°"},
      "hourly": [
        {"time": "...", "wave_height": 0.6, "wave_period": 6, "wave_direction": 270, "swell_height": 0.4, "swell_period": 8, "swell_direction": 300}
      ]
    }
  }
  ```
- `GET /tides?lat&lon` — tides (Pro)
- `GET /geocode?q` and `GET /geocode/reverse?lat&lon`
  - Reverse geocoding returns nearest place for coordinates.

Response:
```json
{
  "source": "open-meteo",
  "issued": "2025-08-07T19:09:49Z",
  "data": {
    "latitude": 59.93,
    "longitude": 30.31,
    "timezone": "GMT",
    "units": {
      "temperature": "°C",
      "wind_speed": "m/s",
      "wind_gust": "m/s",
      "wind_direction": "°",
      "precipitation": "mm",
      "pressure": "hPa",
      "cloud_cover": "%"
    },
    "current": { "time": "...", "temperature": 17.2, "wind_speed": 4.1, "wind_direction": 220 },
    "hourly": [ { "time": "...", "temperature": 17.2, "precipitation": 0, "pressure": 1012.3, "cloud_cover": 50, "wind_speed": 4.1, "wind_gust": 8.5, "wind_direction": 220 } ],
    "daily": [ { "date": "2025-08-07", "temp_max": 20.3, "temp_min": 15.1, "precipitation_sum": 3.4, "wind_speed_max": 6.6, "wind_gusts_max": 13.3, "wind_direction_dominant": 270, "sunrise": "...", "sunset": "..." } ]
  }
}
```

Errors format:
```json
{ "code": "string", "message": "string", "details": {}}
```
