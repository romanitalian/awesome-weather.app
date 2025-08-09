package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type GeocodeHandler struct {
	Client *http.Client
	Cache  interface {
		GetBytes(context.Context, string) ([]byte, bool, error)
		SetBytes(context.Context, string, []byte, time.Duration) error
	}
}

func NewGeocodeHandler(cache interface {
	GetBytes(context.Context, string) ([]byte, bool, error)
	SetBytes(context.Context, string, []byte, time.Duration) error
}) *GeocodeHandler {
	return &GeocodeHandler{Client: &http.Client{Timeout: 6 * time.Second}, Cache: cache}
}

func (h *GeocodeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		writeError(w, http.StatusBadRequest, "bad_request", "missing q", nil)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()
	key := "geocode:v1:" + strings.ToLower(q)
	if b, ok, _ := h.Cache.GetBytes(ctx, key); ok {
		writeJSONBytes(w, http.StatusOK, b)
		return
	}
	u, _ := url.Parse("https://geocoding-api.open-meteo.com/v1/search")
	p := u.Query()
	p.Set("name", q)
	p.Set("count", "10")
	p.Set("language", "en")
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
    if err != nil { writeError(w, http.StatusBadGateway, "upstream_error", "geocoding upstream failed", map[string]string{"error": err.Error()}); return }
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
