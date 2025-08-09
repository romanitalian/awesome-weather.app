package config

import (
	"os"
)

type Config struct {
	Env       string
	HTTPAddr  string
	LogLevel  string
	RedisAddr string
	RedisDB   int
	RedisPass string
    // Rate limiting (optional)
    RateLimitRequests  int // number of requests per window per IP+path
    RateLimitWindowSec int // window size in seconds
}

func FromEnv() Config {
	cfg := Config{
		Env:       valueOrDefault(os.Getenv("APP_ENV"), "dev"),
		HTTPAddr:  valueOrDefault(os.Getenv("HTTP_ADDR"), ":8080"),
		LogLevel:  valueOrDefault(os.Getenv("LOG_LEVEL"), "info"),
		RedisAddr: valueOrDefault(os.Getenv("REDIS_ADDR"), ""),
		RedisDB:   intFromEnv("REDIS_DB", 0),
		RedisPass: os.Getenv("REDIS_PASSWORD"),
        RateLimitRequests:  intFromEnv("RATE_LIMIT_REQUESTS", 0),
        RateLimitWindowSec: intFromEnv("RATE_LIMIT_WINDOW_SEC", 60),
	}
	return cfg
}

func valueOrDefault(v string, d string) string {
	if v == "" {
		return d
	}
	return v
}

func intFromEnv(name string, d int) int {
	v := os.Getenv(name)
	if v == "" {
		return d
	}
	n := 0
	for i := 0; i < len(v); i++ {
		c := v[i]
		if c < '0' || c > '9' {
			return d
		}
		n = n*10 + int(c-'0')
	}
	return n
}
