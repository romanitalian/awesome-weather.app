package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

type Alert struct {
	Type    string  `json:"type"`
	Time    string  `json:"time"`
	Value   float64 `json:"value"`
	Unit    string  `json:"unit"`
	Message string  `json:"message"`
}

type AlertsRS struct {
	Source string  `json:"source"`
	Issued string  `json:"issued"`
	Alerts []Alert `json:"alerts"`
}

type AlertsHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewAlertsHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *AlertsHandler {
	return &AlertsHandler{Client: &http.Client{Timeout: 8 * time.Second}, Cache: cache}
}

func (h *AlertsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, lon, err := parseLatLon(q.Get("lat"), q.Get("lon"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid lat/lon", nil)
		return
	}
	units := q.Get("units")
	if units == "" {
		units = "metric"
	}
	windThresh := parseFloatDefault(q.Get("wind_speed_gte"), 10.0)
	precipThresh := parseFloatDefault(q.Get("precip_gte"), 1.0)

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	key := fmt.Sprintf("alerts:v1:%.2f:%.2f:%s:%.1f:%.1f", roundTo(lat, 2), roundTo(lon, 2), units, windThresh, precipThresh)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}

	// Fetch minimal weather hourly data for 24h window
	rs, err := h.fetchHourly(ctx, lat, lon, units, 24)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "weather upstream failed", map[string]string{"error": err.Error()})
		return
	}
	alerts := make([]Alert, 0)
	for i := 0; i < len(rs.Hourly.Time) && i < 24; i++ {
		// wind
		if i < len(rs.Hourly.WindSpeed10m) && rs.Hourly.WindSpeed10m[i] >= windThresh {
			alerts = append(alerts, Alert{
				Type:    "wind",
				Time:    rs.Hourly.Time[i],
				Value:   rs.Hourly.WindSpeed10m[i],
				Unit:    rs.HourlyUnits.WindSpeed10m,
				Message: fmt.Sprintf("Wind >= %.1f %s", windThresh, rs.HourlyUnits.WindSpeed10m),
			})
		}
		// precipitation
		if i < len(rs.Hourly.Precipitation) && rs.Hourly.Precipitation[i] >= precipThresh {
			alerts = append(alerts, Alert{
				Type:    "precipitation",
				Time:    rs.Hourly.Time[i],
				Value:   rs.Hourly.Precipitation[i],
				Unit:    rs.HourlyUnits.Precipitation,
				Message: fmt.Sprintf("Precip >= %.1f %s", precipThresh, rs.HourlyUnits.Precipitation),
			})
		}
	}
	out := AlertsRS{Source: "computed/open-meteo", Issued: time.Now().UTC().Format(time.RFC3339), Alerts: alerts}
	b, _ := json.Marshal(out)
	_ = h.Cache.SetBytes(ctx, key, b, 5*time.Minute)
	writeJSONBytes(w, http.StatusOK, b)
}

func (h *AlertsHandler) fetchHourly(ctx context.Context, lat, lon float64, units string, hours int) (openMeteoRS, error) {
	base := "https://api.open-meteo.com/v1/forecast"
	u, _ := url.Parse(base)
	p := u.Query()
	p.Set("latitude", fmt.Sprintf("%f", lat))
	p.Set("longitude", fmt.Sprintf("%f", lon))
    p.Set("hourly", "precipitation,wind_speed_10m")
	p.Set("timezone", "UTC")
	if units == "imperial" {
		p.Set("wind_speed_unit", "mph")
		p.Set("precipitation_unit", "inch")
	} else {
		p.Set("wind_speed_unit", "ms")
		p.Set("precipitation_unit", "mm")
	}
	u.RawQuery = p.Encode()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	resp, err := h.Client.Do(req)
	if err != nil {
		return openMeteoRS{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return openMeteoRS{}, fmt.Errorf("status %d: %s", resp.StatusCode, string(b))
	}
	var payload openMeteoRS
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return openMeteoRS{}, err
	}
	// Trim hours
	if hours > 0 && len(payload.Hourly.Time) > hours {
		payload.Hourly.Time = payload.Hourly.Time[:hours]
		if len(payload.Hourly.WindSpeed10m) > hours {
			payload.Hourly.WindSpeed10m = payload.Hourly.WindSpeed10m[:hours]
		}
		if len(payload.Hourly.Precipitation) > hours {
			payload.Hourly.Precipitation = payload.Hourly.Precipitation[:hours]
		}
	}
	return payload, nil
}

func parseFloatDefault(s string, d float64) float64 {
	if s == "" {
		return d
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return d
	}
	return v
}
