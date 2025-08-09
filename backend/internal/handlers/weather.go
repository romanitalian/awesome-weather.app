package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"awapp/backend/internal/metrics"
	"awapp/backend/internal/models"
)

type WeatherRQ struct {
	Lat   float64
	Lon   float64
	Units string
	Hours int
	Days  int
}

type WeatherRS struct {
	Source string                   `json:"source"`
	Issued time.Time                `json:"issued"`
	Data   models.WeatherNormalized `json:"data"`
}

type WeatherHandler struct {
	Logger *slog.Logger
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewWeatherHandler(logger *slog.Logger, cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *WeatherHandler {
	return &WeatherHandler{
		Logger: logger,
		Client: &http.Client{Timeout: 8 * time.Second},
		Cache:  cache,
	}
}

func (h *WeatherHandler) ParseRQ(r *http.Request) (WeatherRQ, error) {
	q := r.URL.Query()
	lat, err := parseFloat(q.Get("lat"))
	if err != nil {
		return WeatherRQ{}, errors.New("invalid lat")
	}
	lon, err := parseFloat(q.Get("lon"))
	if err != nil {
		return WeatherRQ{}, errors.New("invalid lon")
	}
	units := q.Get("units")
	if units == "" {
		units = "metric"
	}
	hours := parseIntDefault(q.Get("hours"), 48)
	days := parseIntDefault(q.Get("days"), 7)
	return WeatherRQ{Lat: lat, Lon: lon, Units: units, Hours: hours, Days: days}, nil
}

func parseFloat(s string) (float64, error) {
	return strconv.ParseFloat(s, 64)
}

func parseIntDefault(s string, d int) int {
	if s == "" {
		return d
	}
	v, err := strconv.Atoi(s)
	if err != nil {
		return d
	}
	return v
}

func parseLatLon(latS string, lonS string) (float64, float64, error) {
	lat, err := strconv.ParseFloat(latS, 64)
	if err != nil {
		return 0, 0, err
	}
	lon, err := strconv.ParseFloat(lonS, 64)
	if err != nil {
		return 0, 0, err
	}
	return lat, lon, nil
}

func (h *WeatherHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rq, err := h.ParseRQ(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Invalid request", map[string]string{"error": err.Error()})
		return
	}

	ctx := r.Context()
	rs, err := h.fetchOpenMeteo(ctx, rq)
	if err != nil {
		h.Logger.Error("Failed to fetch weather", "error", err, "lat", rq.Lat, "lon", rq.Lon)
		writeError(w, http.StatusInternalServerError, "fetch_error", "Failed to fetch weather data", map[string]string{"error": err.Error()})
		return
	}

	// Метрики для бизнес-логики
	cacheStatus := "miss"
	if rs.Source == "cache" {
		cacheStatus = "hit"
	}
	metrics.WeatherRequestsTotal.WithLabelValues(rq.Units, cacheStatus).Inc()

	data, _ := json.Marshal(rs)
	writeJSONBytes(w, http.StatusOK, data)
}

func (h *WeatherHandler) fetchOpenMeteo(ctx context.Context, rq WeatherRQ) (WeatherRS, error) {
	// Try cache first
	cacheKey := generateWeatherCacheKey(rq)
	if cached, found, err := h.Cache.GetBytes(ctx, cacheKey); err == nil && found {
		var rs WeatherRS
		if err := json.Unmarshal(cached, &rs); err == nil {
			rs.Source = "cache" // Помечаем что данные из кэша
			return rs, nil
		}
	}

	// Build URL
	baseURL := "https://api.open-meteo.com/v1/forecast"
	params := url.Values{}
	params.Set("latitude", fmt.Sprintf("%.4f", rq.Lat))
	params.Set("longitude", fmt.Sprintf("%.4f", rq.Lon))
	params.Set("hourly", "temperature_2m,wind_speed_10m,wind_gusts_10m,wind_direction_10m,precipitation,pressure_msl,cloud_cover")
	params.Set("daily", "temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,sunrise,sunset")
	params.Set("timezone", "UTC")
	params.Set("forecast_days", "7")

	url := baseURL + "?" + params.Encode()

	// Fetch with improved retry logic
	var resp *http.Response
	var err error
	var lastErr error

	for attempt := 1; attempt <= 3; attempt++ {
		start := time.Now()

		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			lastErr = fmt.Errorf("failed to create request: %w", err)
			continue
		}

		resp, err = h.Client.Do(req)
		duration := time.Since(start)

		// Метрики для внешнего API
		status := "error"
		if err == nil {
			status = fmt.Sprintf("%d", resp.StatusCode)
		}
		metrics.ExternalAPICallsTotal.WithLabelValues("open-meteo", "forecast", status).Inc()
		metrics.ExternalAPIDuration.WithLabelValues("open-meteo", "forecast").Observe(duration.Seconds())

		if err == nil && resp.StatusCode == 200 {
			break
		}

		if err != nil {
			lastErr = err
			metrics.ExternalAPIErrors.WithLabelValues("open-meteo", "forecast", "network_error").Inc()
		} else if resp.StatusCode >= 500 {
			lastErr = fmt.Errorf("server error %d", resp.StatusCode)
			metrics.ExternalAPIErrors.WithLabelValues("open-meteo", "forecast", "server_error").Inc()
		} else {
			lastErr = fmt.Errorf("unexpected status %d", resp.StatusCode)
			metrics.ExternalAPIErrors.WithLabelValues("open-meteo", "forecast", "client_error").Inc()
		}

		if resp != nil {
			resp.Body.Close()
		}

		if attempt < 3 {
			// Экспоненциальная задержка: 1s, 2s, 4s
			delay := time.Duration(1<<(attempt-1)) * time.Second
			h.Logger.Info("Retrying Open-Meteo API",
				"attempt", attempt,
				"delay", delay,
				"error", lastErr,
			)
			time.Sleep(delay)
		}
	}

	if err != nil {
		return WeatherRS{}, fmt.Errorf("failed to fetch after retries: %w", lastErr)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return WeatherRS{}, fmt.Errorf("API returned %d: %s", resp.StatusCode, string(body))
	}

	var src openMeteoRS
	if err := json.NewDecoder(resp.Body).Decode(&src); err != nil {
		return WeatherRS{}, fmt.Errorf("failed to decode response: %w", err)
	}

	// Normalize and validate
	normalized := normalizeOpenMeteo(src)
	if err := normalized.Validate(); err != nil {
		return WeatherRS{}, fmt.Errorf("validation failed: %w", err)
	}

	// Trim to requested size
	trimmed := trimNormalized(normalized, rq.Hours, rq.Days)

	rs := WeatherRS{
		Source: "open-meteo",
		Issued: time.Now().UTC(),
		Data:   trimmed,
	}

	// Cache for 30 minutes
	if data, err := json.Marshal(rs); err == nil {
		h.Cache.SetBytes(ctx, cacheKey, data, 30*time.Minute)
	}

	return rs, nil
}

type openMeteoRS struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	Hourly    struct {
		Time             []string  `json:"time"`
		Temperature2m    []float64 `json:"temperature_2m"`
		WindSpeed10m     []float64 `json:"wind_speed_10m"`
		WindGusts10m     []float64 `json:"wind_gusts_10m"`
		WindDirection10m []float64 `json:"wind_direction_10m"`
		Precipitation    []float64 `json:"precipitation"`
		PressureMsl      []float64 `json:"pressure_msl"`
		CloudCover       []float64 `json:"cloud_cover"`
	} `json:"hourly"`
	Daily struct {
		Time                     []string  `json:"time"`
		Temperature2mMax         []float64 `json:"temperature_2m_max"`
		Temperature2mMin         []float64 `json:"temperature_2m_min"`
		PrecipitationSum         []float64 `json:"precipitation_sum"`
		WindSpeed10mMax          []float64 `json:"wind_speed_10m_max"`
		WindGusts10mMax          []float64 `json:"wind_gusts_10m_max"`
		WindDirection10mDominant []float64 `json:"wind_direction_10m_dominant"`
		Sunrise                  []string  `json:"sunrise"`
		Sunset                   []string  `json:"sunset"`
	} `json:"daily"`
	HourlyUnits struct {
		Temperature2m    string `json:"temperature_2m"`
		WindSpeed10m     string `json:"wind_speed_10m"`
		WindGusts10m     string `json:"wind_gusts_10m"`
		WindDirection10m string `json:"wind_direction_10m"`
		Precipitation    string `json:"precipitation"`
		PressureMsl      string `json:"pressure_msl"`
		CloudCover       string `json:"cloud_cover"`
		Time             string `json:"time"`
	} `json:"hourly_units"`
}

func normalizeOpenMeteo(src openMeteoRS) models.WeatherNormalized {
	units := models.WeatherUnits{
		Temperature:   src.HourlyUnits.Temperature2m,
		WindSpeed:     src.HourlyUnits.WindSpeed10m,
		WindGust:      src.HourlyUnits.WindGusts10m,
		WindDirection: src.HourlyUnits.WindDirection10m,
		Precipitation: src.HourlyUnits.Precipitation,
		Pressure:      src.HourlyUnits.PressureMsl,
		CloudCover:    src.HourlyUnits.CloudCover,
	}

	hours := make([]models.Hour, 0, len(src.Hourly.Time))
	for i := 0; i < len(src.Hourly.Time); i++ {
		timeStr := safeString(src.Hourly.Time, i)
		parsedTime, _ := time.Parse("2006-01-02T15:04", timeStr)

		h := models.Hour{
			Time:          parsedTime,
			Temperature:   safeFloat(src.Hourly.Temperature2m, i),
			WindSpeed:     safeFloat(src.Hourly.WindSpeed10m, i),
			WindGust:      safeFloat(src.Hourly.WindGusts10m, i),
			WindDirection: safeFloat(src.Hourly.WindDirection10m, i),
			Precipitation: safeFloat(src.Hourly.Precipitation, i),
			Pressure:      safeFloat(src.Hourly.PressureMsl, i),
			CloudCover:    safeFloat(src.Hourly.CloudCover, i),
		}
		hours = append(hours, h)
	}

	days := make([]models.Day, 0, len(src.Daily.Time))
	for i := 0; i < len(src.Daily.Time); i++ {
		dateStr := safeString(src.Daily.Time, i)
		sunriseStr := safeString(src.Daily.Sunrise, i)
		sunsetStr := safeString(src.Daily.Sunset, i)

		parsedDate, _ := time.Parse("2006-01-02", dateStr)
		parsedSunrise, _ := time.Parse("2006-01-02T15:04", sunriseStr)
		parsedSunset, _ := time.Parse("2006-01-02T15:04", sunsetStr)

		d := models.Day{
			Date:                  parsedDate,
			TempMax:               safeFloat(src.Daily.Temperature2mMax, i),
			TempMin:               safeFloat(src.Daily.Temperature2mMin, i),
			PrecipitationSum:      safeFloat(src.Daily.PrecipitationSum, i),
			WindSpeedMax:          safeFloat(src.Daily.WindSpeed10mMax, i),
			WindGustsMax:          safeFloat(src.Daily.WindGusts10mMax, i),
			WindDirectionDominant: safeFloat(src.Daily.WindDirection10mDominant, i),
			Sunrise:               parsedSunrise,
			Sunset:                parsedSunset,
		}
		days = append(days, d)
	}

	current := models.Current{}
	if len(hours) > 0 {
		current = models.Current{
			Time:          hours[0].Time,
			Temperature:   hours[0].Temperature,
			WindSpeed:     hours[0].WindSpeed,
			WindDirection: hours[0].WindDirection,
			Pressure:      hours[0].Pressure,
			CloudCover:    hours[0].CloudCover,
		}
	}

	return models.WeatherNormalized{
		Latitude:  src.Latitude,
		Longitude: src.Longitude,
		Timezone:  src.Timezone,
		Units:     units,
		Current:   current,
		Hourly:    hours,
		Daily:     days,
	}
}

func trimNormalized(in models.WeatherNormalized, hours int, days int) models.WeatherNormalized {
	out := in
	if hours > 0 && len(out.Hourly) > hours {
		out.Hourly = out.Hourly[:hours]
		// refresh current from first hour after trim
		if len(out.Hourly) > 0 {
			out.Current = models.Current{
				Time:          out.Hourly[0].Time,
				Temperature:   out.Hourly[0].Temperature,
				WindSpeed:     out.Hourly[0].WindSpeed,
				WindDirection: out.Hourly[0].WindDirection,
				Pressure:      out.Hourly[0].Pressure,
				CloudCover:    out.Hourly[0].CloudCover,
			}
		}
	}
	if days > 0 && len(out.Daily) > days {
		out.Daily = out.Daily[:days]
	}
	return out
}

func safeString(arr []string, i int) string {
	if i >= 0 && i < len(arr) {
		return arr[i]
	}
	return ""
}

func safeFloat(arr []float64, i int) float64 {
	if i >= 0 && i < len(arr) {
		return arr[i]
	}
	return 0
}

// generateWeatherCacheKey creates a cache key for weather data
func generateWeatherCacheKey(rq WeatherRQ) string {
	lat := roundTo(rq.Lat, 2)
	lon := roundTo(rq.Lon, 2)
	b := make([]byte, 0, 64)
	b = append(b, "weather:v1:"...)
	b = append(b, strconv.FormatFloat(lat, 'f', 2, 64)...)
	b = append(b, ':')
	b = append(b, strconv.FormatFloat(lon, 'f', 2, 64)...)
	b = append(b, ':')
	b = append(b, rq.Units...)
	b = append(b, ':')
	b = append(b, strconv.Itoa(rq.Days)...)
	b = append(b, ':')
	b = append(b, strconv.Itoa(rq.Hours)...)
	return string(b)
}
