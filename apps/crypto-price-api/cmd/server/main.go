package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/handler"
	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/metrics"
	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/repository"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// Config
	port := getEnv("PORT", "8080")
	metricsPort := getEnv("METRICS_PORT", "9090")
	dbDSN := os.Getenv("DATABASE_URL")
	fetchInterval := getEnvDuration("FETCH_INTERVAL", 10*time.Second)

	// Initialize
	metrics.Init()

	repo, err := repository.NewPostgresRepository(dbDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer repo.Close()

	if err := repo.Migrate(); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	h := handler.NewHandler(repo)

	// Start price fetcher
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.StartPriceFetcher(ctx, fetchInterval)

	// API Router
	r := mux.NewRouter()
	r.HandleFunc("/health", h.Health).Methods("GET")
	r.HandleFunc("/ready", h.Ready).Methods("GET")
	r.HandleFunc("/api/v1/prices", h.GetPrices).Methods("GET")
	r.HandleFunc("/api/v1/prices/{symbol}", h.GetPrice).Methods("GET")
	r.HandleFunc("/api/v1/prices/{symbol}/history", h.GetPriceHistory).Methods("GET")

	// Metrics server (separate port)
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promhttp.Handler())
	metricsServer := &http.Server{Addr: ":" + metricsPort, Handler: metricsMux}
	go func() {
		log.Printf("Metrics server listening on :%s", metricsPort)
		if err := metricsServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("Metrics server error: %v", err)
		}
	}()

	// API server
	apiServer := &http.Server{
		Addr:         ":" + port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("API server listening on :%s", port)
		if err := apiServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("API server error: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	cancel() // Stop price fetcher
	apiServer.Shutdown(shutdownCtx)
	metricsServer.Shutdown(shutdownCtx)
	log.Println("Server stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		d, err := time.ParseDuration(v)
		if err == nil {
			return d
		}
	}
	return fallback
}
