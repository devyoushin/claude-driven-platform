# AI-Native Workflow

## Philosophy

This project treats Claude not as a code generator, but as a collaborative architect. The human provides intent, constraints, and judgment — Claude provides implementation, pattern knowledge, and consistency.

## How Claude Is Used at Each Stage

### 1. Architecture Design
- Discuss trade-offs (e.g., EKS vs GKE, Helm vs raw manifests)
- Generate Architecture Decision Records
- Validate designs against best practices

### 2. Infrastructure Provisioning
- Write Terraform modules with proper state management
- Review security configurations (IAM, network policies)
- Ensure idempotency and drift detection

### 3. Application Deployment
- Design Kubernetes resource definitions
- Configure health checks, resource limits, autoscaling
- Set up CI/CD pipelines

### 4. Monitoring & Alerting
- Define SLIs/SLOs
- Create Prometheus recording/alerting rules
- Build Grafana dashboards
- Configure alert routing and escalation

## Tools & Integration

- **Claude Code CLI** — Primary interface for all development
- **CLAUDE.md** — Persistent project context
- **Co-authored commits** — Attribution in git history
