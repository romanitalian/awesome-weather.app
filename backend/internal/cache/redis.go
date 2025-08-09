package cache

import (
	"context"
	"log/slog"
	"strings"
	"time"

	"awapp/backend/internal/metrics"

	"github.com/redis/go-redis/v9"
)

type RedisCache struct {
	client *redis.Client
	logger *slog.Logger
}

func NewRedisCache(addr string, password string, db int, logger *slog.Logger) *RedisCache {
	c := redis.NewClient(&redis.Options{Addr: addr, Password: password, DB: db})
	return &RedisCache{client: c, logger: logger}
}

func (r *RedisCache) GetBytes(ctx context.Context, key string) ([]byte, bool, error) {
	start := time.Now()

	b, err := r.client.Get(ctx, key).Bytes()

	// Определяем паттерн ключа для метрик
	keyPattern := getKeyPattern(key)

	if err == redis.Nil {
		// Cache miss
		metrics.CacheMisses.WithLabelValues("redis", keyPattern).Inc()
		r.logger.Debug("Cache miss", "key", key, "pattern", keyPattern)
		return nil, false, nil
	}

	if err != nil {
		// Cache error
		metrics.CacheErrors.WithLabelValues("redis", "get_error").Inc()
		r.logger.Error("Cache get error", "key", key, "error", err)
		return nil, false, err
	}

	// Cache hit
	metrics.CacheHits.WithLabelValues("redis", keyPattern).Inc()
	r.logger.Debug("Cache hit", "key", key, "pattern", keyPattern, "duration", time.Since(start))

	return b, true, nil
}

func (r *RedisCache) SetBytes(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	keyPattern := getKeyPattern(key)

	err := r.client.Set(ctx, key, value, ttl).Err()
	if err != nil {
		metrics.CacheErrors.WithLabelValues("redis", "set_error").Inc()
		r.logger.Error("Cache set error", "key", key, "error", err)
		return err
	}

	r.logger.Debug("Cache set", "key", key, "pattern", keyPattern, "ttl", ttl)
	return nil
}

// getKeyPattern извлекает паттерн из ключа кэша для группировки метрик
func getKeyPattern(key string) string {
	parts := strings.Split(key, ":")
	if len(parts) >= 2 {
		return parts[0] + ":" + parts[1] // например "weather:v1" или "geocode:v1"
	}
	return "unknown"
}

// Ping проверяет соединение с Redis
func (r *RedisCache) Ping(ctx context.Context) error {
	return r.client.Ping(ctx).Err()
}

// Close закрывает соединение с Redis
func (r *RedisCache) Close() error {
	return r.client.Close()
}
