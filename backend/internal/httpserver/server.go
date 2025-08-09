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
	"awapp/backend/internal/metrics"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Server struct {
	http   *http.Server
	logger *slog.Logger
}

func New(cfg config.Config, logger *slog.Logger) *Server {
	mux := http.NewServeMux()
	// Metrics registry
	reg := prometheus.NewRegistry()
	metrics.MustRegister(reg)
	mux.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
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
		c = cache.NewRedisCache(cfg.RedisAddr, cfg.RedisPass, cfg.RedisDB, logger)
		logger.Info("Using Redis cache", "addr", cfg.RedisAddr, "db", cfg.RedisDB)
	} else {
		logger.Info("Using no-op cache (Redis not configured)")
	}

	// API v1
	mux.Handle("/api/v1/weather", handlers.NewWeatherHandler(logger, c))
	mux.Handle("/api/v1/geocode", handlers.NewGeocodeHandler(c))
	mux.Handle("/api/v1/geocode/reverse", handlers.NewReverseGeocodeHandler(c))
	mux.Handle("/api/v1/marine", handlers.NewMarineHandler(c))
	mux.Handle("/api/v1/tides", handlers.NewTidesHandler(c))
	mux.Handle("/api/v1/history", handlers.NewHistoryHandler(c))
	mux.Handle("/api/v1/alerts", handlers.NewAlertsHandler(c))

	// Optional rate limiting
	var handler http.Handler = mux
	if cfg.RateLimitRequests > 0 {
		rl := newRateLimiter(cfg.RateLimitRequests, cfg.RateLimitWindowSec, logger)
		handler = rateLimitMiddleware(rl, handler)
		logger.Info("Rate limiting enabled",
			"requests", cfg.RateLimitRequests,
			"window_sec", cfg.RateLimitWindowSec,
		)
	} else {
		logger.Info("Rate limiting disabled")
	}

	handler = corsMiddleware(handler)
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
		// wrap to capture status
		rw := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)
		dur := time.Since(start)
		logger.Info("req",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.String("dur", dur.String()),
		)
		metrics.HTTPRequestsTotal.WithLabelValues(r.Method, r.URL.Path, http.StatusText(rw.status)).Inc()
		metrics.HTTPRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(dur.Seconds())
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

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}
