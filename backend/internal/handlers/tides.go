package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"

	"awapp/backend/internal/models"
)

type TidesRS struct {
	Source string                `json:"source"`
	Issued string                `json:"issued"`
	Data   models.TidesNormalized `json:"data"`
}

type TidesHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewTidesHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *TidesHandler {
	return &TidesHandler{Client: &http.Client{Timeout: 8 * time.Second}, Cache: cache}
}

func (h *TidesHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, lon, err := parseLatLon(q.Get("lat"), q.Get("lon"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid lat/lon", nil)
		return
	}
	apiKey := os.Getenv("WORLDTIDES_API_KEY")
	if apiKey == "" {
		writeError(w, http.StatusNotImplemented, "not_configured", "tides provider key is not configured", nil)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	key := fmt.Sprintf("tides:v1:%.2f:%.2f", lat, lon)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}
	rs, err := h.fetchWorldTides(ctx, apiKey, lat, lon)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "tides upstream failed", map[string]string{"error": err.Error()})
		return
	}
	out, _ := json.Marshal(rs)
	_ = h.Cache.SetBytes(ctx, key, out, 6*time.Hour)
	writeJSONBytes(w, http.StatusOK, out)
}

type worldTidesRS struct {
	Status string `json:"status"`
	Extremes []struct{
		Dt string `json:"date"`
		Height float64 `json:"height"`
		Type string `json:"type"`
	} `json:"extremes"`
}

func (h *TidesHandler) fetchWorldTides(ctx context.Context, key string, lat, lon float64) (TidesRS, error) {
	u, _ := url.Parse("https://www.worldtides.info/api/v3")
	p := u.Query()
	p.Set("extremes", "")
	p.Set("lat", fmt.Sprintf("%f", lat))
	p.Set("lon", fmt.Sprintf("%f", lon))
	p.Set("length", "48")
	p.Set("key", key)
	u.RawQuery = p.Encode()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
    var resp *http.Response
    var err error
    for attempt := 0; attempt < 2; attempt++ {
        resp, err = h.Client.Do(req)
        if err == nil && resp.StatusCode == http.StatusOK { break }
        if resp != nil { resp.Body.Close() }
        select { case <-time.After(time.Duration(200*(attempt+1)) * time.Millisecond): case <-ctx.Done(): }
    }
    if err != nil { return TidesRS{}, err }
    defer resp.Body.Close()
    if resp.StatusCode != http.StatusOK {
        b, _ := io.ReadAll(resp.Body)
        return TidesRS{}, errors.New(fmt.Sprintf("status %d: %s", resp.StatusCode, string(b)))
    }
	var payload worldTidesRS
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return TidesRS{}, err
	}
	out := models.TidesNormalized{Latitude: lat, Longitude: lon, Units: models.TideUnits{Height: "m"}}
	for _, e := range payload.Extremes {
		out.Extremes = append(out.Extremes, models.TideExtremum{Time: e.Dt, Height: e.Height, Type: e.Type})
	}
	return TidesRS{Source: "worldtides", Issued: time.Now().UTC().Format(time.RFC3339), Data: out}, nil
}
