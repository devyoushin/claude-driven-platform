package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/metrics"
	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/model"
	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/repository"

	"github.com/gorilla/mux"
)

var defaultSymbols = []string{"BTCUSDT", "ETHUSDT", "SOLUSDT", "XRPUSDT", "ADAUSDT"}

type Handler struct {
	repo *repository.PostgresRepository
}

func NewHandler(repo *repository.PostgresRepository) *Handler {
	return &Handler{repo: repo}
}

// Health check
func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// Readiness check (DB 연결 확인)
func (h *Handler) Ready(w http.ResponseWriter, r *http.Request) {
	if err := h.repo.Ping(r.Context()); err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{"status": "not ready", "error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

// GET /api/v1/prices - 전체 최신 가격
func (h *Handler) GetPrices(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	defer func() {
		metrics.HTTPRequestDuration.WithLabelValues("GET", "/api/v1/prices", "200").Observe(time.Since(start).Seconds())
		metrics.HTTPRequestsTotal.WithLabelValues("GET", "/api/v1/prices", "200").Inc()
	}()

	prices, err := h.repo.GetLatestPrices(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var resp []model.PriceResponse
	for _, p := range prices {
		resp = append(resp, model.PriceResponse{
			Symbol:    p.Symbol,
			Price:     p.Price,
			Volume24h: p.Volume24h,
			Change24h: p.Change24h,
			Source:    p.Source,
			Timestamp: p.CreatedAt.Format(time.RFC3339),
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// GET /api/v1/prices/{symbol} - 특정 심볼 가격
func (h *Handler) GetPrice(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	symbol := mux.Vars(r)["symbol"]

	price, err := h.repo.GetLatestPrice(r.Context(), symbol)
	if err != nil {
		metrics.HTTPRequestsTotal.WithLabelValues("GET", "/api/v1/prices/{symbol}", "500").Inc()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if price == nil {
		metrics.HTTPRequestsTotal.WithLabelValues("GET", "/api/v1/prices/{symbol}", "404").Inc()
		http.Error(w, "symbol not found", http.StatusNotFound)
		return
	}

	metrics.HTTPRequestDuration.WithLabelValues("GET", "/api/v1/prices/{symbol}", "200").Observe(time.Since(start).Seconds())
	metrics.HTTPRequestsTotal.WithLabelValues("GET", "/api/v1/prices/{symbol}", "200").Inc()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(model.PriceResponse{
		Symbol:    price.Symbol,
		Price:     price.Price,
		Volume24h: price.Volume24h,
		Change24h: price.Change24h,
		Source:    price.Source,
		Timestamp: price.CreatedAt.Format(time.RFC3339),
	})
}

// GET /api/v1/prices/{symbol}/history - 가격 히스토리
func (h *Handler) GetPriceHistory(w http.ResponseWriter, r *http.Request) {
	symbol := mux.Vars(r)["symbol"]
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit == 0 || limit > 1000 {
		limit = 100
	}

	to := time.Now()
	from := to.Add(-24 * time.Hour)
	if fromStr := r.URL.Query().Get("from"); fromStr != "" {
		if t, err := time.Parse(time.RFC3339, fromStr); err == nil {
			from = t
		}
	}

	prices, err := h.repo.GetPriceHistory(r.Context(), &model.PriceHistoryQuery{
		Symbol: symbol,
		From:   from,
		To:     to,
		Limit:  limit,
	})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(prices)
}

// StartPriceFetcher - 주기적으로 Binance에서 가격 수집
func (h *Handler) StartPriceFetcher(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// 시작 시 즉시 한 번 실행
	h.fetchPrices(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			h.fetchPrices(ctx)
		}
	}
}

func (h *Handler) fetchPrices(ctx context.Context) {
	for _, symbol := range defaultSymbols {
		start := time.Now()

		price, err := fetchBinancePrice(symbol)
		if err != nil {
			log.Printf("Failed to fetch %s: %v", symbol, err)
			metrics.PriceFetchErrors.WithLabelValues(symbol, "binance").Inc()
			continue
		}

		price.Source = "binance"
		price.CreatedAt = time.Now()

		if err := h.repo.SavePrice(ctx, price); err != nil {
			log.Printf("Failed to save %s: %v", symbol, err)
			continue
		}

		metrics.PriceFetchDuration.WithLabelValues(symbol).Observe(time.Since(start).Seconds())
		metrics.CryptoPrice.WithLabelValues(symbol, "binance").Set(price.Price)
		metrics.PriceFetchTotal.WithLabelValues(symbol, "binance").Inc()
	}
}

func fetchBinancePrice(symbol string) (*model.Price, error) {
	url := fmt.Sprintf("https://api.binance.com/api/v3/ticker/24hr?symbol=%s", symbol)

	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var data struct {
		Symbol             string `json:"symbol"`
		LastPrice          string `json:"lastPrice"`
		Volume             string `json:"volume"`
		PriceChangePercent string `json:"priceChangePercent"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, err
	}

	price, _ := strconv.ParseFloat(data.LastPrice, 64)
	volume, _ := strconv.ParseFloat(data.Volume, 64)
	change, _ := strconv.ParseFloat(data.PriceChangePercent, 64)

	return &model.Price{
		Symbol:    data.Symbol,
		Price:     price,
		Volume24h: volume,
		Change24h: change,
	}, nil
}
