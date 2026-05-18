# Claude-Driven Platform

> End-to-end AWS infrastructure built entirely through AI-native collaboration with Claude.

## What This Is

A portfolio project demonstrating how to build production-grade infrastructure using an AI-first workflow. Every component — from Terraform modules to monitoring dashboards to microservices — was designed and implemented collaboratively with Claude.

## Tech Stack

| Category | Technologies |
|----------|-------------|
| Cloud | AWS (ap-northeast-2), Multi-Account, Organizations |
| IaC | Terraform 1.5+, S3 Backend |
| Container | EKS, Docker, Helm 3 |
| Compute | EC2 (ASG), EKS Managed Node Groups |
| Database | RDS PostgreSQL (Multi-AZ), AWS Backup |
| Network | VPC, Transit Gateway, WAF, ALB |
| Security | IAM Identity Center (SSO), SCP, GuardDuty, Security Hub, Config Rules |
| CI/CD | GitHub Actions, OIDC (Keyless Auth) |
| Monitoring | Prometheus, Grafana, AlertManager, CloudWatch, SNS |
| App | Go 1.22 (crypto-price-api), Python 3.12 / FastAPI (crypto-alert-service) |

## Architecture

> AWS Multi-Account (ap-northeast-2) · Terraform IaC · Transit Gateway

```
                         ┌──────────────────────────────────────┐
                         │   AWS Organizations (Landing Zone)   │
                         │   IAM Identity Center (SSO)          │
                         │   Organizations Policies             │
                         └──────────────────┬───────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    │                       │                       │
                    ▼                       ▼                       ▼
┌───────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐
│   Landing Zone Account    │ │   Service Account       │ │  Operations Account     │
│   (Security)              │ │   (Workload)            │ │  (Observability)        │
├───────────────────────────┤ ├─────────────────────────┤ ├─────────────────────────┤
│                           │ │                         │ │                         │
│  Internet                 │ │  VPC 10.10.0.0/16       │ │  VPC 10.20.0.0/16       │
│    │                      │ │  ┌─────────────────┐   │ │  ┌─────────────────┐   │
│    ▼                      │ │  │ Public Subnet   │   │ │  │ Private Subnet  │   │
│  ┌─────┐    ┌─────┐      │ │  │ (NAT GW)       │   │ │  │                 │   │
│  │ WAF │───▶│ ALB │      │ │  ├─────────────────┤   │ │  │ Prometheus      │   │
│  └─────┘    └──┬──┘      │ │  │ Private App    │   │ │  │ Grafana         │   │
│               │          │ │  │                 │   │ │  │ AlertManager    │   │
│  VPC 10.0.0.0/16         │ │  │ EKS Cluster    │   │ │  │ CloudWatch      │   │
│               │          │ │  │ EC2 (ASG)      │   │ │  │                 │   │
│  ┌────────────┴────────┐ │ │  ├─────────────────┤   │ │  └─────────────────┘   │
│  │ TGW Attachment      │ │ │  │ Private DB     │   │ │                         │
│  └────────────┬────────┘ │ │  │                 │   │ │  SNS → Slack/Email     │
│               │          │ │  │ RDS (Multi-AZ) │   │ │                         │
│  GuardDuty (Org)         │ │  └─────────────────┘   │ └────────────┬────────────┘
│  Security Hub (Org)      │ │                         │              │
│  Config Rules (Org)      │ │  AWS Backup (Daily/     │              │
│  CloudTrail (Org)        │ │  Weekly/Monthly)        │              │
│                           │ └────────────┬────────────┘              │
└───────────────┼──────────┘              │                          │
                │                         │                          │
                └─────────────────────────┼──────────────────────────┘
                                          │
                              ┌───────────┴─────────────┐
                              │    Transit Gateway       │
                              │    (Cross-Account Hub)   │
                              └─────────────────────────┘
```

### Account 역할

| Account | 역할 | VPC CIDR | 핵심 리소스 |
|---------|------|----------|------------|
| Landing Zone | 보안, IAM 중앙관리, 외부 진입점 | 10.0.0.0/16 | WAF, ALB, TGW, Organizations, Identity Center, GuardDuty, Security Hub, Config Rules |
| Service | 서비스 워크로드 운영 | 10.10.0.0/16 | EKS, EC2(ASG), RDS(Multi-AZ), Backup |
| Operations | 모니터링, 옵저버빌리티 | 10.20.0.0/16 | Prometheus, Grafana, AlertManager, CloudWatch, SNS |

### IAM 전략

- **AWS Organizations**: Landing Zone에서 전체 계정 거버넌스 (OU 3개, SCP 5개)
- **IAM Identity Center (SSO)**: 사람은 Landing Zone을 통해서만 접근 (Permission Set 4개)
- **Cross-Account Roles**: 계정 간 서비스 접근은 AssumeRole 기반
- **최소 권한 원칙**: Operations → Service는 읽기 전용

## Applications

```
┌─ crypto-price-api (Go) ─────────────────────┐
│ • Binance 실시간 가격 수집 (10초 간격)       │
│ • REST: GET /prices, /prices/{symbol}        │
│ • RDS 저장, Custom Prometheus metrics        │
│ • HPA: CPU 70% 기준 2~10 pods               │
└──────────────────────┬───────────────────────┘
                       │ HTTP (내부)
┌──────────────────────▼───────────────────────┐
│ crypto-alert-service (Python/FastAPI)        │
│ • 알림 CRUD (POST/GET/DELETE /alerts)        │
│ • 30초마다 조건 평가 → SNS/Slack 발송        │
│ • HPA: CPU 70% 기준 2~5 pods                │
└──────────────────────────────────────────────┘
```

## CI/CD Pipeline

5개의 GitHub Actions 워크플로우가 전체 Terraform + App 라이프사이클을 자동화합니다.

| Workflow | Trigger | 역할 |
|----------|---------|------|
| `terraform-plan` | PR (infra 변경) | 환경별 plan → PR 코멘트 |
| `terraform-apply` | Push to main (infra 변경) | 순차 apply (LZ → Service → Ops), Environment 승인 게이트 |
| `terraform-security` | PR (infra 변경) | tfsec, Checkov, fmt check, Infracost |
| `drift-detection` | 매일 09:00 KST (cron) | plan -detailed-exitcode, drift 감지 시 Issue 자동 생성 |
| `app-build-deploy` | Push to main (apps 변경) | Go/Python test → Docker build → ECR push → Helm deploy |

모든 AWS 인증은 **OIDC (keyless)** 방식 — Secret 저장 불필요.

## Monitoring

```
수집 대상 (ServiceMonitor): 5개
  - Service EKS 워크로드
  - Node Exporter (EC2)
  - RDS PostgreSQL (postgres-exporter)
  - crypto-price-api (custom metrics)
  - crypto-alert-service (custom metrics)

알람 규칙 (PrometheusRule): 22개
  - infra-alerts: CPU, Memory, Disk, Network, NodeDown
  - eks-alerts: Pod, Deployment, HPA, PV
  - rds-alerts: Connection, SlowQuery, Deadlock, Bloat

대시보드 (Grafana): 3개
  - Cluster Overview
  - RDS PostgreSQL
  - Landing Zone Traffic

알림 라우팅 (AlertManager):
  - Critical → 30분 그룹 대기 → SNS
  - Warning → 4시간 그룹 대기 → SNS
  - 억제 규칙: NodeDown 시 하위 알람 자동 억제
```

## Security

```
GuardDuty (Organization-wide):
  - S3 Protection, EKS Audit Logs, Malware Protection (EBS)
  - 멤버 계정 자동 등록, HIGH/CRITICAL findings → SNS 알림

Security Hub (Organization-wide):
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v1.4.0
  - CRITICAL/HIGH findings → SNS 알림

AWS Config (Organization-wide):
  - Managed Rules 13개 (S3, RDS, EC2, IAM, CloudTrail, VPC, EKS)
  - NON_COMPLIANT → SNS 알림

SCP (Service Control Policies): 5개
  - 리전 제한 (ap-northeast-2 only)
  - Root 사용 차단, IAM User 생성 차단
  - CloudTrail 보호, 태그 정책
```

## Project Structure

```
claude-driven-platform/
├── .github/workflows/          ← CI/CD (5개 workflow)
│   ├── terraform-plan.yml
│   ├── terraform-apply.yml
│   ├── terraform-security.yml
│   ├── drift-detection.yml
│   └── app-build-deploy.yml
├── apps/
│   ├── crypto-price-api/       ← Go 서비스 (cmd/internal + Dockerfile + Helm)
│   └── crypto-alert-service/   ← Python 서비스 (app + Dockerfile + Helm)
├── infra/terraform/
│   ├── modules/                ← 공유 모듈 (vpc, tgw, tags)
│   ├── landing-zone/           ← VPC, WAF, ALB, TGW, Orgs, SSO, SCP, GuardDuty, Security Hub, Config
│   ├── service/                ← VPC, EKS, EC2(ASG), RDS, Backup
│   └── operations/             ← VPC, EKS, Prometheus Helm, AlertManager, SNS, Cross-account IAM
├── monitoring/
│   ├── helm/                   ← kube-prometheus-stack values
│   ├── prometheus/             ← ServiceMonitor + PrometheusRule CRDs
│   ├── grafana/dashboards/     ← Grafana 대시보드 JSON (3개)
│   └── alerting/               ← AlertManager 라우팅 설정
├── docs/
│   ├── decisions/              ← ADR 4개 + INDEX
│   ├── history.md              ← 상세 작업 히스토리
│   └── ai-workflow.md          ← Claude 활용 방법론
├── STATUS.md                   ← 프로젝트 진행 현황
├── CLAUDE.md                   ← Claude 컨텍스트
└── README.md                   ← 이 파일
```

## Architecture Decision Records

주요 의사결정은 ADR로 기록합니다. → [전체 목록 (INDEX)](docs/decisions/INDEX.md)

| # | Title | Category | Summary |
|---|-------|----------|---------|
| [001](docs/decisions/001-multi-account-architecture.md) | Multi-Account Architecture | Infra/Network | 3계정 구조 + TGW 연결 |
| [002](docs/decisions/002-monitoring-account-separation.md) | Monitoring Account Separation | Monitoring | 모니터링 장애 격리를 위한 계정 분리 |
| [003](docs/decisions/003-iam-centralized-management.md) | Centralized IAM | Security/IAM | Organizations + Identity Center SSO |
| [004](docs/decisions/004-cicd-github-actions.md) | GitHub Actions + OIDC CI/CD | CI/CD | PR plan/scan, merge apply, daily drift detection |

## AI-Native Workflow

This project intentionally tracks *how* AI was used, not just *what* was built:

- **Git history** — Co-authored commits show Claude's involvement
- **ADRs** — Decision records capture the reasoning process
- **CLAUDE.md** — Project context given to the AI at each stage
- **docs/history.md** — Every command executed, every decision explained
- **docs/ai-workflow.md** — Claude collaboration methodology

## Getting Started

```bash
# Prerequisites
# - AWS CLI v2 + configured credentials (3 accounts)
# - Terraform >= 1.5
# - kubectl
# - Helm 3
# - Docker
# - Go 1.22+ (for crypto-price-api)
# - Python 3.12+ (for crypto-alert-service)

# See docs/history.md for detailed step-by-step execution guide
```

## License

MIT
