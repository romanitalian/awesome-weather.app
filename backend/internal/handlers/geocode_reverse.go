package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

type ReverseGeocodeHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewReverseGeocodeHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *ReverseGeocodeHandler {
	return &ReverseGeocodeHandler{Client: &http.Client{Timeout: 6 * time.Second}, Cache: cache}
}

func (h *ReverseGeocodeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, lon, err := parseLatLon(q.Get("lat"), q.Get("lon"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid lat/lon", nil)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()
	key := fmt.Sprintf("geocode:rev:v1:%.2f:%.2f", lat, lon)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}
	u, _ := url.Parse("https://geocoding-api.open-meteo.com/v1/reverse")
	p := u.Query()
	p.Set("latitude", fmt.Sprintf("%f", lat))
	p.Set("longitude", fmt.Sprintf("%f", lon))
	p.Set("language", "en")
	u.RawQuery = p.Encode()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	resp, err := h.Client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", "reverse geocoding upstream failed", map[string]string{"error": err.Error()})
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		writeError(w, http.StatusBadGateway, "upstream_status", "upstream status not ok", map[string]string{"status": http.StatusText(resp.StatusCode)})
		return
	}
	var payload map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadGateway, "upstream_decode", "upstream decode failed", map[string]string{"error": err.Error()})
		return
	}
	b, _ := json.Marshal(payload)
	_ = h.Cache.SetBytes(ctx, key, b, 7*24*time.Hour)
	writeJSONBytes(w, http.StatusOK, b)
}
