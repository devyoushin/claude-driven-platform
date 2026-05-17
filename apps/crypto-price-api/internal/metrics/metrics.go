package metrics

import "github.com/prometheus/client_golang/prometheus"

var (
	// HTTP 메트릭
	HTTPRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "crypto_price_api_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	HTTPRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "crypto_price_api_http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path", "status"},
	)

	// 가격 수집 메트릭
	PriceFetchTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "crypto_price_api_fetch_total",
			Help: "Total number of price fetches",
		},
		[]string{"symbol", "source"},
	)

	PriceFetchDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "crypto_price_api_fetch_duration_seconds",
			Help:    "Price fetch duration in seconds",
			Buckets: []float64{0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5},
		},
		[]string{"symbol"},
	)

	PriceFetchErrors = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "crypto_price_api_fetch_errors_total",
			Help: "Total number of price fetch errors",
		},
		[]string{"symbol", "source"},
	)

	// 비즈니스 메트릭 (현재 가격 - Grafana에서 활용)
	CryptoPrice = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "crypto_price_current",
			Help: "Current cryptocurrency price in USDT",
		},
		[]string{"symbol", "source"},
	)
)

func Init() {
	prometheus.MustRegister(
		HTTPRequestsTotal,
		HTTPRequestDuration,
		PriceFetchTotal,
		PriceFetchDuration,
		PriceFetchErrors,
		CryptoPrice,
	)
}
