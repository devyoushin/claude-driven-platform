# Monitoring Stack

> Operations Account EKS 위에 배포되는 모니터링 설정 파일들

## 구조

```
monitoring/
├── helm/
│   └── kube-prometheus-stack-values.yaml   # Helm chart 전체 values
├── prometheus/
│   ├── servicemonitors/                    # 메트릭 수집 대상 (CRD)
│   │   ├── eks-service-account.yaml        # Service Account EKS 워크로드
│   │   ├── node-exporter.yaml              # Operations 노드
│   │   └── rds-exporter.yaml               # RDS PostgreSQL + Exporter 배포
│   └── rules/                              # 알람 규칙 (CRD)
│       ├── infra-alerts.yaml               # Node CPU/Memory/Disk/Network
│       ├── eks-alerts.yaml                 # Pod/Deployment/HPA/PV
│       └── rds-alerts.yaml                 # Connection/Performance/Storage
├── grafana/
│   └── dashboards/                         # 대시보드 JSON
│       ├── cluster-overview.json           # EKS 클러스터 전체 현황
│       ├── rds-overview.json               # RDS PostgreSQL 상세
│       └── landing-zone-traffic.json       # ALB/WAF 트래픽
└── alerting/
    └── alertmanager-config.yaml            # AlertManager 라우팅/수신자
```

## 배포 방법

```bash
# 1. Helm values로 kube-prometheus-stack 배포 (Terraform에서 수행)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/helm/kube-prometheus-stack-values.yaml

# 2. CRD 리소스 적용
kubectl apply -f monitoring/prometheus/servicemonitors/
kubectl apply -f monitoring/prometheus/rules/

# 3. Grafana 대시보드는 sidecar가 ConfigMap에서 자동 로드
# 또는 수동 import:
kubectl create configmap grafana-dashboard-cluster \
  --from-file=monitoring/grafana/dashboards/cluster-overview.json \
  -n monitoring
kubectl label configmap grafana-dashboard-cluster grafana_dashboard=1 -n monitoring

# 4. RDS Exporter credentials 설정
kubectl create secret generic rds-exporter-credentials \
  --from-literal=uri="your-rds-endpoint:5432/cdpdb?sslmode=require" \
  --from-literal=username="monitoring_user" \
  --from-literal=password="your-password" \
  -n monitoring
```

## 알람 흐름

```
메트릭 수집 (ServiceMonitor)
  → Prometheus 저장 (30일)
    → PrometheusRule 평가
      → AlertManager 수신
        → Route Tree로 분류
          → severity=critical → SNS(critical) → Email + Slack
          → severity=warning  → SNS(alerts)   → Email
          → component=database → DB 전용 채널
```

## 알람 규칙 요약

| 카테고리 | 알람 | Severity | 조건 |
|----------|------|----------|------|
| Node | NodeHighCpuUsage | warning | CPU > 80% (5분) |
| Node | NodeCriticalCpuUsage | critical | CPU > 95% (3분) |
| Node | NodeHighMemoryUsage | warning | Memory > 85% (5분) |
| Node | NodeDiskSpaceCritical | critical | Disk > 90% (5분) |
| Node | NodeDown | critical | 메트릭 수집 불가 (2분) |
| EKS | PodCrashLoopBackOff | critical | CrashLoop 5분 지속 |
| EKS | PodPendingTooLong | warning | Pending 10분 |
| EKS | DeploymentGenerationMismatch | critical | Rollout 실패 15분 |
| EKS | HPAMaxedOut | warning | Max replica 15분 |
| RDS | RDSConnectionsCritical | critical | 연결 > 95% |
| RDS | RDSDeadlocks | warning | Deadlock 발생 |
| RDS | RDSExporterDown | critical | Exporter 3분 다운 |
