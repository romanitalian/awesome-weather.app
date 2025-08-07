package httpserver

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"awapp/backend/internal/cache"
	"awapp/backend/internal/config"
	"awapp/backend/internal/handlers"
)

type Server struct {
	http   *http.Server
	logger *slog.Logger
}

func New(cfg config.Config, logger *slog.Logger) *Server {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		now := time.Now().UTC().Format(time.RFC3339)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status": "ok",
			"time":   now,
		})
	})

	// Cache (optional)
	var c cache.BytesCache = cache.NoopCache{}
	if cfg.RedisAddr != "" {
		c = cache.NewRedisCache(cfg.RedisAddr, cfg.RedisPass, cfg.RedisDB)
	}

	// API v1
	mux.Handle("/api/v1/weather", handlers.NewWeatherHandler(logger, c))
	mux.Handle("/api/v1/geocode", handlers.NewGeocodeHandler(c))
	mux.Handle("/api/v1/geocode/reverse", handlers.NewReverseGeocodeHandler(c))
	mux.Handle("/api/v1/marine", handlers.NewMarineHandler(c))

	handler := corsMiddleware(mux)
	s := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           loggingMiddleware(logger, handler),
		ReadTimeout:       5 * time.Second,
		ReadHeaderTimeout: 3 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	return &Server{http: s, logger: logger}
}

func (s *Server) Start() error {
	s.logger.Info("listening", slog.String("addr", s.http.Addr))
	return s.http.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.http.Shutdown(ctx)
}

func loggingMiddleware(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		dur := time.Since(start)
		logger.Info("req",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.String("dur", dur.String()),
		)
	})
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin == "" {
			origin = "*"
		}
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Vary", "Origin")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
