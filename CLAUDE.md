# Claude-Driven Platform

## Project Overview
AI-native infrastructure portfolio — every component from initial architecture to monitoring/alerting is built collaboratively with Claude.

## Goals
- Demonstrate end-to-end infrastructure provisioning using IaC (Terraform)
- Set up container orchestration on AWS EKS
- Implement observability stack (Prometheus + Grafana + AlertManager)
- Document the AI-native workflow at every step

## Cloud
- Provider: AWS
- Region: ap-northeast-2 (Seoul)
- Key services: VPC, EKS, ECR, IAM, CloudWatch

## Conventions
- Commit messages in English
- All infrastructure as code (no manual console clicks)
- Architecture decisions documented in `docs/decisions/`
- Each major change should include a brief note on how Claude assisted

## Structure
- `infra/terraform/` — Cloud infrastructure provisioning
- `infra/kubernetes/` — K8s manifests and Helm charts
- `infra/docker/` — Dockerfiles
- `monitoring/` — Observability stack configs
- `docs/` — Architecture docs, ADRs, AI workflow notes
- `scripts/` — Automation scripts
