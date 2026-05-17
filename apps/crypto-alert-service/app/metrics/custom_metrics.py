"""Custom Prometheus metrics for alert service"""

from prometheus_client import Counter, Gauge, Histogram


# 알림 생성 카운터
alerts_created_total = Counter(
    "crypto_alert_created_total",
    "Total alerts created",
    ["symbol", "condition"],
)

# 알림 발동 카운터
alerts_triggered_total = Counter(
    "crypto_alert_triggered_total",
    "Total alerts triggered",
    ["symbol", "condition", "channel"],
)

# 현재 활성 알림 수
active_alerts_gauge = Gauge(
    "crypto_alert_active_count",
    "Number of currently active alerts",
)

# 알림 평가 소요 시간
alert_evaluation_duration = Histogram(
    "crypto_alert_evaluation_duration_seconds",
    "Time spent evaluating all alerts",
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)


def init():
    """Initialize metrics (called on startup)"""
    pass
