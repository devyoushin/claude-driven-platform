# Claude-Driven Platform

> End-to-end infrastructure built entirely through AI-native collaboration with Claude.

## What This Is

A portfolio project demonstrating how to build production-grade infrastructure using an AI-first workflow. Every component — from Terraform modules to monitoring dashboards — was designed and implemented collaboratively with Claude.

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
└───────────────┼──────────┘ │  └─────────────────┘   │ └────────────┬────────────┘
                │            │                         │              │
                │            │  AWS Backup (Daily/     │              │
                │            │  Weekly/Monthly)        │              │
                │            └────────────┬────────────┘              │
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
| Landing Zone | 보안, IAM 중앙관리, 외부 진입점 | 10.0.0.0/16 | WAF, ALB, TGW, Organizations, Identity Center |
| Service | 서비스 워크로드 운영 | 10.10.0.0/16 | EKS, EC2, RDS, Backup |
| Operations | 모니터링, 옵저버빌리티 | 10.20.0.0/16 | Prometheus, Grafana, AlertManager, CloudWatch |

### IAM 전략
- **AWS Organizations**: Landing Zone에서 전체 계정 거버넌스
- **IAM Identity Center (SSO)**: 사람은 Landing Zone을 통해서만 접근
- **Cross-Account Roles**: 계정 간 서비스 접근은 AssumeRole 기반
- **최소 권한 원칙**: Operations → Service는 읽기 전용

## Project Structure

```
├── infra/
│   ├── terraform/
│   │   ├── modules/          # Reusable modules (VPC, TGW, Tags, ...)
│   │   ├── landing-zone/     # Security account resources
│   │   ├── service/          # Workload account resources
│   │   └── operations/       # Monitoring account resources
│   ├── kubernetes/           # K8s manifests & Helm charts
│   └── docker/               # Container definitions
├── monitoring/
│   ├── prometheus/           # Metrics collection configs
│   ├── grafana/              # Dashboard definitions
│   └── alerting/             # Alert rules & routing
├── docs/
│   ├── decisions/            # Architecture Decision Records
│   ├── history.md            # Step-by-step build log
│   └── ai-workflow.md        # How Claude was used
└── scripts/                  # Automation & bootstrap
```

## AI-Native Workflow

This project intentionally tracks *how* AI was used, not just *what* was built:

- **Git history** — Co-authored commits show Claude's involvement
- **ADRs** — Decision records capture the reasoning process
- **CLAUDE.md** — Project context given to the AI at each stage
- **docs/history.md** — Every command executed, every decision explained

## Getting Started

```bash
# Prerequisites
# - AWS CLI v2 + configured credentials
# - Terraform >= 1.5
# - kubectl
# - Helm 3
# - Docker

# See docs/history.md for detailed step-by-step execution guide
```

## Architecture Decision Records

| # | Title | Status |
|---|-------|--------|
| [001](docs/decisions/001-multi-account-architecture.md) | Multi-Account Architecture with Landing Zone | Accepted |
| [002](docs/decisions/002-monitoring-account-separation.md) | Monitoring stack in dedicated Operations Account | Accepted |
| [003](docs/decisions/003-iam-centralized-management.md) | Centralized IAM via Organizations + Identity Center | Accepted |

## License

MIT
