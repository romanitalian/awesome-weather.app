package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
)

var (
	// HTTP метрики
	HTTPRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	HTTPRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)

	// Внешние API метрики
	ExternalAPICallsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "external_api_calls_total",
			Help: "Total external API calls",
		},
		[]string{"api", "endpoint", "status"},
	)

	ExternalAPIDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "external_api_duration_seconds",
			Help:    "External API call duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"api", "endpoint"},
	)

	ExternalAPIErrors = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "external_api_errors_total",
			Help: "Total external API errors",
		},
		[]string{"api", "endpoint", "error_type"},
	)

	// Кэш метрики
	CacheHits = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_hits_total",
			Help: "Total cache hits",
		},
		[]string{"cache_type", "key_pattern"},
	)

	CacheMisses = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_misses_total",
			Help: "Total cache misses",
		},
		[]string{"cache_type", "key_pattern"},
	)

	CacheErrors = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_errors_total",
			Help: "Total cache errors",
		},
		[]string{"cache_type", "error_type"},
	)

	// Rate limiting метрики
	RateLimitHits = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "rate_limit_hits_total",
			Help: "Total rate limit hits",
		},
		[]string{"ip", "path"},
	)

	// Бизнес метрики
	WeatherRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "weather_requests_total",
			Help: "Total weather data requests",
		},
		[]string{"units", "cache_status"},
	)

	GeocodeRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geocode_requests_total",
			Help: "Total geocoding requests",
		},
		[]string{"type", "cache_status"},
	)

	MarineRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "marine_requests_total",
			Help: "Total marine weather requests",
		},
		[]string{"units", "cache_status"},
	)
)

func MustRegister(reg *prometheus.Registry) {
	reg.MustRegister(
		HTTPRequestsTotal,
		HTTPRequestDuration,
		ExternalAPICallsTotal,
		ExternalAPIDuration,
		ExternalAPIErrors,
		CacheHits,
		CacheMisses,
		CacheErrors,
		RateLimitHits,
		WeatherRequestsTotal,
		GeocodeRequestsTotal,
		MarineRequestsTotal,
	)
}
