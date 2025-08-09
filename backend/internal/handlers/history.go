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

type HistoryRQ struct {
	Lat   float64
	Lon   float64
	Days  int
	Units string
}

type HistoryRS struct {
	Source string                   `json:"source"`
	Issued string                   `json:"issued"`
	Data   models.HistoryNormalized `json:"data"`
}

type HistoryHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewHistoryHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *HistoryHandler {
	return &HistoryHandler{Client: &http.Client{Timeout: 8 * time.Second}, Cache: cache}
}

func (h *HistoryHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, lon, err := parseLatLon(q.Get("lat"), q.Get("lon"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid lat/lon", nil)
		return
	}
	days := parseIntDefault(q.Get("days"), 7)
	if days < 1 {
		days = 1
	}
	if days > 30 {
		days = 30
	}
	units := q.Get("units")
	if units == "" {
		units = "metric"
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	key := fmt.Sprintf("history:v1:%.2f:%.2f:%d:%s", roundTo(lat, 2), roundTo(lon, 2), days, units)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}
	rs, err := h.fetchArchive(ctx, lat, lon, days, units)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "history upstream failed", map[string]string{"error": err.Error()})
		return
	}
	out, _ := json.Marshal(rs)
	_ = h.Cache.SetBytes(ctx, key, out, 6*time.Hour)
	writeJSONBytes(w, http.StatusOK, out)
}

// Open-Meteo archive API structures
type openMeteoArchiveRS struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	Daily     struct {
		Time             []string  `json:"time"`
		Temperature2mMax []float64 `json:"temperature_2m_max"`
		Temperature2mMin []float64 `json:"temperature_2m_min"`
		PrecipitationSum []float64 `json:"precipitation_sum"`
	} `json:"daily"`
	DailyUnits struct {
		Temperature2mMax string `json:"temperature_2m_max"`
		Temperature2mMin string `json:"temperature_2m_min"`
		PrecipitationSum string `json:"precipitation_sum"`
		Time             string `json:"time"`
	} `json:"daily_units"`
}

func (h *HistoryHandler) fetchArchive(ctx context.Context, lat, lon float64, days int, units string) (HistoryRS, error) {
	// Date range: last N days up to yesterday (archive not for future)
	end := time.Now().UTC().AddDate(0, 0, -1)
	start := end.AddDate(0, 0, -(days - 1))
	u, _ := url.Parse("https://archive-api.open-meteo.com/v1/archive")
	p := u.Query()
	p.Set("latitude", fmt.Sprintf("%f", lat))
	p.Set("longitude", fmt.Sprintf("%f", lon))
	p.Set("start_date", start.Format("2006-01-02"))
	p.Set("end_date", end.Format("2006-01-02"))
	p.Set("daily", "temperature_2m_max,temperature_2m_min,precipitation_sum")
	p.Set("timezone", "UTC")
	if units == "imperial" {
		p.Set("temperature_unit", "fahrenheit")
		p.Set("precipitation_unit", "inch")
	} else {
		p.Set("temperature_unit", "celsius")
		p.Set("precipitation_unit", "mm")
	}
	u.RawQuery = p.Encode()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	var resp *http.Response
	var err error
	for attempt := 0; attempt < 2; attempt++ {
		resp, err = h.Client.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			break
		}
		if resp != nil {
			resp.Body.Close()
		}
		select {
		case <-time.After(time.Duration(200*(attempt+1)) * time.Millisecond):
		case <-ctx.Done():
		}
	}
	if err != nil {
		return HistoryRS{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return HistoryRS{}, fmt.Errorf("status %d: %s", resp.StatusCode, string(b))
	}
	var payload openMeteoArchiveRS
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return HistoryRS{}, err
	}
	normalized := normalizeArchive(payload)
	return HistoryRS{Source: "open-meteo-archive", Issued: time.Now().UTC().Format(time.RFC3339), Data: normalized}, nil
}

func normalizeArchive(src openMeteoArchiveRS) models.HistoryNormalized {
	units := models.HistoryUnits{
		TempMax:       src.DailyUnits.Temperature2mMax,
		TempMin:       src.DailyUnits.Temperature2mMin,
		Precipitation: src.DailyUnits.PrecipitationSum,
	}
	days := make([]models.HistoryDay, 0, len(src.Daily.Time))
	for i := 0; i < len(src.Daily.Time); i++ {
		d := models.HistoryDay{
			Date:             safeString(src.Daily.Time, i),
			TempMax:          safeFloat(src.Daily.Temperature2mMax, i),
			TempMin:          safeFloat(src.Daily.Temperature2mMin, i),
			PrecipitationSum: safeFloat(src.Daily.PrecipitationSum, i),
		}
		days = append(days, d)
	}
	return models.HistoryNormalized{
		Latitude:  0, // optional
		Longitude: 0, // optional
		Timezone:  "UTC",
		Units:     units,
		Daily:     days,
	}
}




