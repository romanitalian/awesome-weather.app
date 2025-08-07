package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"awapp/backend/internal/models"
)

type MarineRQ struct {
	Lat float64
	Lon float64
}

type MarineRS struct {
	Source string                  `json:"source"`
	Issued string                  `json:"issued"`
	Data   models.MarineNormalized `json:"data"`
}

type MarineHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewMarineHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *MarineHandler {
	return &MarineHandler{Client: &http.Client{Timeout: 8 * time.Second}, Cache: cache}
}

func (h *MarineHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, lon, err := parseLatLon(q.Get("lat"), q.Get("lon"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid lat/lon", nil)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	key := fmt.Sprintf("marine:v1:%.2f:%.2f", lat, lon)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}
	rs, err := h.fetchOpenMeteoMarine(ctx, lat, lon)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "marine upstream failed", map[string]string{"error": err.Error()})
		return
	}
	out, _ := json.Marshal(rs)
	_ = h.Cache.SetBytes(ctx, key, out, 30*time.Minute)
	writeJSONBytes(w, http.StatusOK, out)
}

func (h *MarineHandler) fetchOpenMeteoMarine(ctx context.Context, lat, lon float64) (MarineRS, error) {
	u, _ := url.Parse("https://marine-api.open-meteo.com/v1/marine")
	p := u.Query()
	p.Set("latitude", fmt.Sprintf("%f", lat))
	p.Set("longitude", fmt.Sprintf("%f", lon))
	p.Set("hourly", "wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,swell_wave_period")
	p.Set("timezone", "UTC")
	u.RawQuery = p.Encode()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	resp, err := h.Client.Do(req)
	if err != nil {
		return MarineRS{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return MarineRS{}, fmt.Errorf("status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return MarineRS{}, err
	}
	var om openMeteoMarineRS
	if err := json.Unmarshal(body, &om); err != nil {
		return MarineRS{}, err
	}
	normalized := normalizeMarine(om)
	return MarineRS{Source: "open-meteo-marine", Issued: time.Now().UTC().Format(time.RFC3339), Data: normalized}, nil
}

type openMeteoMarineRS struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	Hourly    struct {
		Time               []string  `json:"time"`
		WaveHeight         []float64 `json:"wave_height"`
		WaveDirection      []float64 `json:"wave_direction"`
		WavePeriod         []float64 `json:"wave_period"`
		SwellWaveHeight    []float64 `json:"swell_wave_height"`
		SwellWaveDirection []float64 `json:"swell_wave_direction"`
		SwellWavePeriod    []float64 `json:"swell_wave_period"`
	} `json:"hourly"`
	HourlyUnits struct {
		WaveHeight         string `json:"wave_height"`
		WaveDirection      string `json:"wave_direction"`
		WavePeriod         string `json:"wave_period"`
		SwellWaveHeight    string `json:"swell_wave_height"`
		SwellWaveDirection string `json:"swell_wave_direction"`
		SwellWavePeriod    string `json:"swell_wave_period"`
	} `json:"hourly_units"`
}

func normalizeMarine(src openMeteoMarineRS) models.MarineNormalized {
	units := models.MarineUnits{
		WaveHeight:     src.HourlyUnits.WaveHeight,
		WavePeriod:     src.HourlyUnits.WavePeriod,
		WaveDirection:  src.HourlyUnits.WaveDirection,
		SwellHeight:    src.HourlyUnits.SwellWaveHeight,
		SwellPeriod:    src.HourlyUnits.SwellWavePeriod,
		SwellDirection: src.HourlyUnits.SwellWaveDirection,
	}
	hours := make([]models.MarineHour, 0, len(src.Hourly.Time))
	for i := 0; i < len(src.Hourly.Time); i++ {
		h := models.MarineHour{
			Time:           src.Hourly.Time[i],
			WaveHeight:     safeFloat(src.Hourly.WaveHeight, i),
			WavePeriod:     safeFloat(src.Hourly.WavePeriod, i),
			WaveDirection:  safeFloat(src.Hourly.WaveDirection, i),
			SwellHeight:    safeFloat(src.Hourly.SwellWaveHeight, i),
			SwellPeriod:    safeFloat(src.Hourly.SwellWavePeriod, i),
			SwellDirection: safeFloat(src.Hourly.SwellWaveDirection, i),
		}
		hours = append(hours, h)
	}
	return models.MarineNormalized{
		Latitude:  src.Latitude,
		Longitude: src.Longitude,
		Timezone:  src.Timezone,
		Units:     units,
		Hourly:    hours,
	}
}
