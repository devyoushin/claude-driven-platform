# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /crypto-price-api ./cmd/server

# Runtime stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata
ENV TZ=Asia/Seoul

RUN adduser -D -g '' appuser
USER appuser

COPY --from=builder /crypto-price-api /usr/local/bin/crypto-price-api

EXPOSE 8080 9090

ENTRYPOINT ["crypto-price-api"]
