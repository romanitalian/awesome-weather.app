package httpserver

import (
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"

	"awapp/backend/internal/metrics"
)

type bucket struct {
	count int
	exp   time.Time
}

type rateLimiter struct {
	mu     sync.Mutex
	store  map[string]*bucket
	limit  int
	window time.Duration
	logger *slog.Logger
}

func newRateLimiter(limit int, windowSec int, logger *slog.Logger) *rateLimiter {
	rl := &rateLimiter{
		store:  make(map[string]*bucket),
		limit:  limit,
		window: time.Duration(windowSec) * time.Second,
		logger: logger,
	}

	// Запускаем очистку старых записей каждые 5 минут
	go rl.cleanup()

	return rl
}

func (r *rateLimiter) allow(key string) bool {
	if r.limit <= 0 {
		return true
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	b, ok := r.store[key]
	now := time.Now()

	if !ok || now.After(b.exp) {
		b = &bucket{count: 1, exp: now.Add(r.window)}
		r.store[key] = b
		return true
	}

	if b.count < r.limit {
		b.count++
		return true
	}

	// Rate limit exceeded
	ip, path := parseKey(key)
	metrics.RateLimitHits.WithLabelValues(ip, path).Inc()

	return false
}

func (r *rateLimiter) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		r.mu.Lock()
		now := time.Now()
		count := 0

		for key, b := range r.store {
			if now.After(b.exp) {
				delete(r.store, key)
				count++
			}
		}

		if count > 0 {
			r.logger.Info("Cleaned up expired rate limit entries", "count", count, "remaining", len(r.store))
		}
		r.mu.Unlock()
	}
}

func parseKey(key string) (ip, path string) {
	for i, char := range key {
		if char == '|' {
			return key[:i], key[i+1:]
		}
	}
	return key, ""
}

func clientIP(r *http.Request) string {
	// Проверяем заголовки в порядке приоритета
	headers := []string{
		"X-Real-IP",
		"X-Forwarded-For",
		"CF-Connecting-IP", // Cloudflare
	}

	for _, header := range headers {
		if ip := r.Header.Get(header); ip != "" {
			// X-Forwarded-For может содержать несколько IP через запятую
			if header == "X-Forwarded-For" {
				if comma := net.ParseIP(ip); comma != nil {
					return ip
				}
				// Берем первый IP из списка
				if len(ip) > 0 {
					return ip
				}
			}
			return ip
		}
	}

	// Fallback к RemoteAddr
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func rateLimitMiddleware(rl *rateLimiter, next http.Handler) http.Handler {
	if rl == nil || rl.limit <= 0 {
		return next
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := clientIP(r) + "|" + r.URL.Path

		if !rl.allow(key) {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", "60")
			w.WriteHeader(http.StatusTooManyRequests)

			// Простая JSON сериализация
			json := `{"error":"rate_limit_exceeded","message":"Too many requests","retry_after":60}`
			_, _ = w.Write([]byte(json))

			rl.logger.Warn("Rate limit exceeded",
				"ip", clientIP(r),
				"path", r.URL.Path,
				"user_agent", r.UserAgent(),
			)
			return
		}

		next.ServeHTTP(w, r)
	})
}
