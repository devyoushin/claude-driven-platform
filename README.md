# Claude-Driven Platform

> End-to-end infrastructure built entirely through AI-native collaboration with Claude.

## What This Is

A portfolio project demonstrating how to build production-grade infrastructure using an AI-first workflow. Every component — from Terraform modules to monitoring dashboards — was designed and implemented collaboratively with Claude.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Monitoring Layer                │
│         Prometheus · Grafana · AlertManager      │
├─────────────────────────────────────────────────┤
│                Application Layer                 │
│              Kubernetes (EKS/GKE)                │
├─────────────────────────────────────────────────┤
│               Infrastructure Layer              │
│            Terraform (VPC · Compute · IAM)       │
└─────────────────────────────────────────────────┘
```

## Project Structure

```
├── infra/
│   ├── terraform/      # Cloud resource provisioning
│   ├── kubernetes/     # K8s manifests & Helm charts
│   └── docker/         # Container definitions
├── monitoring/
│   ├── prometheus/     # Metrics collection
│   ├── grafana/        # Dashboards
│   └── alerting/       # Alert rules & routing
├── docs/
│   ├── architecture.md # System design
│   ├── ai-workflow.md  # How Claude was used
│   └── decisions/      # Architecture Decision Records
└── scripts/            # Automation & bootstrap
```

## AI-Native Workflow

This project intentionally tracks *how* AI was used, not just *what* was built:

- **Git history** — Co-authored commits show Claude's involvement
- **ADRs** — Decision records capture the reasoning process
- **CLAUDE.md** — Project context given to the AI at each stage

## Getting Started

```bash
# Prerequisites
# - Terraform >= 1.5
# - kubectl
# - Helm 3
# - Docker

# Bootstrap (coming soon)
./scripts/bootstrap.sh
```

## License

MIT
