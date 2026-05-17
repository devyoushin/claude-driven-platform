package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/devyoushin/claude-driven-platform/apps/crypto-price-api/internal/model"

	_ "github.com/lib/pq"
)

type PostgresRepository struct {
	db *sql.DB
}

func NewPostgresRepository(dsn string) (*PostgresRepository, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}

	return &PostgresRepository{db: db}, nil
}

func (r *PostgresRepository) Close() error {
	return r.db.Close()
}

func (r *PostgresRepository) Migrate() error {
	query := `
	CREATE TABLE IF NOT EXISTS prices (
		id BIGSERIAL PRIMARY KEY,
		symbol VARCHAR(20) NOT NULL,
		price DECIMAL(20, 8) NOT NULL,
		volume_24h DECIMAL(20, 2) DEFAULT 0,
		change_24h DECIMAL(10, 4) DEFAULT 0,
		source VARCHAR(50) NOT NULL,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_prices_symbol_created ON prices (symbol, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_prices_created_at ON prices (created_at);
	`
	_, err := r.db.Exec(query)
	return err
}

func (r *PostgresRepository) SavePrice(ctx context.Context, p *model.Price) error {
	query := `
	INSERT INTO prices (symbol, price, volume_24h, change_24h, source, created_at)
	VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.db.ExecContext(ctx, query, p.Symbol, p.Price, p.Volume24h, p.Change24h, p.Source, p.CreatedAt)
	return err
}

func (r *PostgresRepository) GetLatestPrice(ctx context.Context, symbol string) (*model.Price, error) {
	query := `
	SELECT id, symbol, price, volume_24h, change_24h, source, created_at
	FROM prices
	WHERE symbol = $1
	ORDER BY created_at DESC
	LIMIT 1
	`
	var p model.Price
	err := r.db.QueryRowContext(ctx, query, symbol).Scan(
		&p.ID, &p.Symbol, &p.Price, &p.Volume24h, &p.Change24h, &p.Source, &p.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return &p, err
}

func (r *PostgresRepository) GetLatestPrices(ctx context.Context) ([]model.Price, error) {
	query := `
	SELECT DISTINCT ON (symbol) id, symbol, price, volume_24h, change_24h, source, created_at
	FROM prices
	ORDER BY symbol, created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var prices []model.Price
	for rows.Next() {
		var p model.Price
		if err := rows.Scan(&p.ID, &p.Symbol, &p.Price, &p.Volume24h, &p.Change24h, &p.Source, &p.CreatedAt); err != nil {
			return nil, err
		}
		prices = append(prices, p)
	}
	return prices, rows.Err()
}

func (r *PostgresRepository) GetPriceHistory(ctx context.Context, q *model.PriceHistoryQuery) ([]model.Price, error) {
	query := `
	SELECT id, symbol, price, volume_24h, change_24h, source, created_at
	FROM prices
	WHERE symbol = $1 AND created_at BETWEEN $2 AND $3
	ORDER BY created_at DESC
	LIMIT $4
	`
	rows, err := r.db.QueryContext(ctx, query, q.Symbol, q.From, q.To, q.Limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var prices []model.Price
	for rows.Next() {
		var p model.Price
		if err := rows.Scan(&p.ID, &p.Symbol, &p.Price, &p.Volume24h, &p.Change24h, &p.Source, &p.CreatedAt); err != nil {
			return nil, err
		}
		prices = append(prices, p)
	}
	return prices, rows.Err()
}

func (r *PostgresRepository) Ping(ctx context.Context) error {
	return r.db.PingContext(ctx)
}
