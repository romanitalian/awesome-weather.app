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
	Issued string                   `json:"issued"`
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
		writeError(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	// cache key: weather:v1:lat:lon:units:days:hours (rounded coords to 2 decimals)
	key := h.cacheKey(rq)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		w.Header().Set("X-Cache", "HIT")
		writeJSONBytes(w, http.StatusOK, b)
		return
	}

	rs, err := h.fetchOpenMeteo(ctx, rq)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "weather upstream failed", map[string]string{"error": err.Error()})
		return
	}
	out, _ := json.Marshal(rs)
	_ = h.Cache.SetBytes(ctx, key, out, 10*time.Minute)
	w.Header().Set("X-Cache", "MISS")
	writeJSONBytes(w, http.StatusOK, out)
}

func (h *WeatherHandler) fetchOpenMeteo(ctx context.Context, rq WeatherRQ) (WeatherRS, error) {
	base := "https://api.open-meteo.com/v1/forecast"
	u, err := url.Parse(base)
	if err != nil {
		return WeatherRS{}, err
	}
	q := u.Query()
	q.Set("latitude", fmt.Sprintf("%f", rq.Lat))
	q.Set("longitude", fmt.Sprintf("%f", rq.Lon))
	q.Set("hourly", "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,pressure_msl,cloud_cover,wind_speed_10m,wind_gusts_10m,wind_direction_10m")
	q.Set("daily", "temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,sunrise,sunset")
	q.Set("timezone", "UTC")
	if rq.Units == "imperial" {
		q.Set("temperature_unit", "fahrenheit")
		q.Set("wind_speed_unit", "mph")
		q.Set("precipitation_unit", "inch")
	} else {
		q.Set("temperature_unit", "celsius")
		q.Set("wind_speed_unit", "ms")
		q.Set("precipitation_unit", "mm")
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return WeatherRS{}, err
	}
	resp, err := h.Client.Do(req)
	if err != nil {
		return WeatherRS{}, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return WeatherRS{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return WeatherRS{}, fmt.Errorf("upstream status %d", resp.StatusCode)
	}
	var payload openMeteoRS
	if err := json.Unmarshal(body, &payload); err != nil {
		return WeatherRS{}, err
	}
	normalized := normalizeOpenMeteo(payload)
	return WeatherRS{Source: "open-meteo", Issued: time.Now().UTC().Format(time.RFC3339), Data: normalized}, nil
}

// minimal Open-Meteo response subset
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
		h := models.Hour{
			Time:          safeString(src.Hourly.Time, i),
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
		d := models.Day{
			Date:                  safeString(src.Daily.Time, i),
			TempMax:               safeFloat(src.Daily.Temperature2mMax, i),
			TempMin:               safeFloat(src.Daily.Temperature2mMin, i),
			PrecipitationSum:      safeFloat(src.Daily.PrecipitationSum, i),
			WindSpeedMax:          safeFloat(src.Daily.WindSpeed10mMax, i),
			WindGustsMax:          safeFloat(src.Daily.WindGusts10mMax, i),
			WindDirectionDominant: safeFloat(src.Daily.WindDirection10mDominant, i),
			Sunrise:               safeString(src.Daily.Sunrise, i),
			Sunset:                safeString(src.Daily.Sunset, i),
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
