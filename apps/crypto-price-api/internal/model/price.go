package model

import "time"

type Price struct {
	ID        int64     `json:"id" db:"id"`
	Symbol    string    `json:"symbol" db:"symbol"`
	Price     float64   `json:"price" db:"price"`
	Volume24h float64   `json:"volume_24h" db:"volume_24h"`
	Change24h float64   `json:"change_24h" db:"change_24h"`
	Source    string    `json:"source" db:"source"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type PriceResponse struct {
	Symbol    string  `json:"symbol"`
	Price     float64 `json:"price"`
	Volume24h float64 `json:"volume_24h"`
	Change24h float64 `json:"change_24h"`
	Source    string  `json:"source"`
	Timestamp string  `json:"timestamp"`
}

type PriceHistoryQuery struct {
	Symbol   string
	From     time.Time
	To       time.Time
	Interval string // "1m", "5m", "1h", "1d"
	Limit    int
}
