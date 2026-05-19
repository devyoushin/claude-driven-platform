# Build History

> 각 단계에서 무엇을 했고, 왜 했고, 어떤 명령어를 실행했는지 기록합니다.

---

## Step 1: 프로젝트 초기화 (2026-05-17)

### 목적
AI-native 인프라 포트폴리오 프로젝트의 뼈대를 만든다.

### 실행한 명령어

```bash
# 프로젝트 디렉토리 생성 및 git 초기화
mkdir -p ~/Desktop/claude-driven-platform
cd ~/Desktop/claude-driven-platform
git init
git branch -m main

# 디렉토리 구조 생성
mkdir -p docs/decisions infra/{terraform,kubernetes,docker} monitoring/{prometheus,grafana,alerting} scripts .claude
```

### 생성한 파일
| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | Claude에게 프로젝트 컨텍스트를 제공하는 파일 |
| `.gitignore` | tfstate, secrets, OS 파일 등 제외 |
| `README.md` | 프로젝트 소개 및 구조 설명 |
| `docs/ai-workflow.md` | Claude 활용 방식 문서화 |
| `docs/history.md` | 이 파일. 전체 작업 히스토리 |

### 결정 사항
- **클라우드**: AWS (EKS, VPC, IAM 중심)
- **IaC**: Terraform
- **컨테이너 오케스트레이션**: Kubernetes (EKS)
- **모니터링**: Prometheus + Grafana + AlertManager
- **브랜치 전략**: main 단일 브랜치에서 시작, 필요 시 feature branch

### 배운 점
- `CLAUDE.md`는 Claude Code가 프로젝트를 이해하는 데 사용하는 컨텍스트 파일
- `.gitignore`에 tfstate, .env 등 민감 파일을 미리 넣어두는 것이 중요
- 모노레포 구조로 인프라/모니터링/문서를 한곳에서 관리하면 포트폴리오로 보여주기 좋음

---

---

## Step 2: Terraform 코드 작성 - 멀티 계정 아키텍처 (2026-05-17)

### 목적
AWS 멀티 계정 구조(Landing Zone + Service)의 전체 Terraform 코드를 작성한다.

### 아키텍처 결정
- **ADR 문서**: `docs/decisions/001-multi-account-architecture.md`
- Landing Zone Account: 외부 트래픽 진입점 (WAF, ALB, TGW)
- Service Account: 서비스 운영 (VPC, EKS, EC2, RDS, Backup)
- Transit Gateway로 두 계정 VPC 연결

### 생성한 파일

#### 공유 모듈 (`infra/terraform/modules/`)
| 모듈 | 역할 |
|------|------|
| `tags/main.tf` | 일관된 태그 정책 (Project, Env, Owner 등) |
| `vpc/main.tf` | VPC + Subnet + NAT + Route Table |
| `vpc/variables.tf` | VPC 모듈 입력값 |
| `vpc/outputs.tf` | VPC 모듈 출력값 |
| `tgw/main.tf` | Transit Gateway + Attachment |
| `tgw/variables.tf` | TGW 모듈 입력값 |
| `tgw/outputs.tf` | TGW 모듈 출력값 |

#### Landing Zone (`infra/terraform/landing-zone/`)
| 파일 | 역할 |
|------|------|
| `provider.tf` | AWS provider + S3 backend |
| `variables.tf` | 변수 정의 |
| `main.tf` | VPC + TGW 모듈 호출 |
| `waf.tf` | WAFv2 + ALB + Security Group |
| `outputs.tf` | 출력값 |

#### Service (`infra/terraform/service/`)
| 파일 | 역할 |
|------|------|
| `provider.tf` | AWS provider + S3 backend |
| `variables.tf` | 변수 정의 (EKS, EC2, RDS 설정) |
| `main.tf` | VPC + TGW attachment |
| `eks.tf` | EKS cluster + Node Group + IAM |
| `ec2.tf` | Launch Template + ASG + IAM |
| `rds.tf` | PostgreSQL Multi-AZ + KMS + Monitoring |
| `backup.tf` | AWS Backup (Daily/Weekly/Monthly) |
| `outputs.tf` | 출력값 |
| `terraform.tfvars.example` | 변수 예시 파일 |

### 네트워크 설계
```
Landing Zone VPC: 10.0.0.0/16
  - Public:  10.0.1.0/24 (AZ-a), 10.0.2.0/24 (AZ-c)
  - Private: 10.0.11.0/24 (AZ-a), 10.0.12.0/24 (AZ-c)

Service VPC: 10.10.0.0/16
  - Public:      10.10.1.0/24 (AZ-a), 10.10.2.0/24 (AZ-c)
  - Private App: 10.10.11.0/24 (AZ-a), 10.10.12.0/24 (AZ-c)
  - Private DB:  10.10.21.0/24 (AZ-a), 10.10.22.0/24 (AZ-c)
```

### 태그 정책
모든 리소스에 아래 태그 자동 적용:
- `Project` = claude-driven-platform
- `Environment` = dev/staging/prod
- `ManagedBy` = terraform
- `Owner` = devyoushin
- `CostCenter` = platform
- `Component` = landing-zone / service

### 나중에 실행할 명령어 (AWS 권한 설정 후)
```bash
# 1. S3 backend 버킷 생성 (최초 1회)
aws s3 mb s3://claude-platform-tfstate --region ap-northeast-2
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-2

# 2. Landing Zone 배포
cd infra/terraform/landing-zone
terraform init
terraform plan
terraform apply

# 3. Service 배포 (Landing Zone의 TGW ID 필요)
cd ../service
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에 transit_gateway_id 값 설정
terraform init
terraform plan
terraform apply
```

### 배운 점
- VPC 모듈을 재사용 가능하게 만들면 Landing Zone/Service 둘 다에 적용 가능
- NAT Gateway는 AZ별로 하나씩 두는 것이 HA(High Availability) 패턴
- EKS subnet에는 `kubernetes.io/cluster/*` 태그가 필요 (ALB Ingress Controller용)
- RDS는 `multi_az = true`로 자동 failover 구성
- IMDSv2 강제 (`http_tokens = "required"`)는 보안 best practice
- AWS Backup의 `selection_tag`으로 태그 기반 자동 백업 대상 선정 가능
- `default_tags` in provider로 모든 리소스에 기본 태그 적용 (모듈 태그와 merge됨)

---

## Step 3: Operations Account — 모니터링 스택 (2026-05-17)

### 목적
별도 Operations Account에 Prometheus + Grafana + AlertManager 기반 모니터링 환경을 구성한다.
(ADR-002에서 결정한 "모니터링 계정 분리" 구현)

### 아키텍처 결정
- 모니터링을 Service Account와 분리 → 서비스 장애 시에도 모니터링 독립 동작
- EKS 위에 kube-prometheus-stack Helm chart로 통합 배포
- Cross-account로 Service Account 메트릭 수집 (IRSA + AssumeRole)
- 알람: SNS → Email + Slack(Lambda)

### 생성한 파일 (`infra/terraform/operations/`)

| 파일 | 역할 |
|------|------|
| `provider.tf` | AWS + Kubernetes + Helm provider, S3 backend |
| `variables.tf` | 변수 정의 (EKS, Grafana, 알람 설정) |
| `main.tf` | VPC + TGW attachment |
| `eks.tf` | 모니터링 전용 EKS + Node Group + IAM |
| `monitoring-stack.tf` | kube-prometheus-stack Helm 배포, EBS CSI, StorageClass |
| `alerting.tf` | SNS Topics + Slack Lambda + CloudWatch Dashboard |
| `iam-cross-account.tf` | Service Account 읽기 전용 접근, Prometheus IRSA |
| `outputs.tf` | 출력값 (Grafana 접근 방법 등) |
| `terraform.tfvars.example` | 변수 예시 파일 |

### 모니터링 스택 구성

```
┌─ Operations EKS ──────────────────────────────┐
│                                               │
│  Namespace: monitoring                        │
│  ┌─────────────┐  ┌─────────┐  ┌──────────┐  │
│  │ Prometheus  │  │ Grafana │  │AlertMgr  │  │
│  │ (30d 보관)  │  │ (대시보드)│  │(알람 라우팅)│  │
│  └──────┬──────┘  └────┬────┘  └─────┬────┘  │
│         │              │             │        │
│         │ scrape       │ query       │ notify │
└─────────┼──────────────┼─────────────┼────────┘
          │              │             │
          ▼              │             ▼
  Service Account        │        SNS Topics
  (10.10.0.0/16)         │        ├── Email
  via TGW                │        └── Lambda → Slack
                         │
                    Port-forward
                    또는 Internal ALB
```

### 알람 흐름
```
메트릭 이상 감지 → Prometheus Alert Rule 발동
  → AlertManager 수신
    → severity=critical: SNS(critical) → Email + Slack
    → severity=warning:  SNS(alerts) → Email
```

### 나중에 실행할 명령어 (AWS 권한 설정 후)
```bash
# 4. Operations 배포 (Landing Zone의 TGW ID + Service Account ID 필요)
cd infra/terraform/operations
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 설정:
#   - transit_gateway_id: Landing Zone에서 가져옴
#   - service_account_id: Service Account의 AWS Account ID
#   - grafana_admin_password: 원하는 비밀번호
#   - alert_email: 알람 수신 이메일
#   - slack_webhook_url: (선택) Slack incoming webhook URL

terraform init
terraform plan
terraform apply

# 5. Grafana 접속 확인
aws eks update-kubeconfig --name cdp-ops-monitoring --region ap-northeast-2
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# 브라우저에서 http://localhost:3000 접속 (admin / 설정한 비밀번호)
```

### 배운 점
- `kube-prometheus-stack` Helm chart = Prometheus + Grafana + AlertManager + node-exporter 한방 설치
- IRSA (IAM Roles for Service Accounts)로 Pod 단위 IAM 권한 부여 가능
- EBS CSI Driver가 있어야 PersistentVolume (gp3) 사용 가능
- Cross-account 메트릭 수집은 TGW 네트워크 + IAM AssumeRole 두 가지 다 필요
- AlertManager → SNS 연동으로 AWS 네이티브 알람 채널 활용
- Lambda로 Slack webhook 호출하면 별도 서버 없이 알람 전달 가능
- CloudWatch Dashboard는 cross-account 메트릭도 한 화면에 표시 가능

---

## Step 4: Organizations + Identity Center + CloudTrail (2026-05-17)

### 목적
Landing Zone에서 AWS Organizations + IAM Identity Center(SSO)로 전체 계정의 IAM을 중앙 관리한다.
(ADR-003에서 결정한 "중앙 집중식 IAM 관리" 구현)

### 생성한 파일 (`infra/terraform/landing-zone/`)

| 파일 | 역할 |
|------|------|
| `organizations.tf` | AWS Organizations + OU(Security/Workload/Operations) + Member Accounts |
| `scp.tf` | Service Control Policies (리전 제한, Root 금지, IAM User 금지, CloudTrail 보호, Tag Policy) |
| `identity-center.tf` | IAM Identity Center — Groups, Permission Sets, Account Assignments |
| `cloudtrail.tf` | 조직 전체 감사 로그 (S3 + CloudWatch Logs, 90일 Glacier 아카이빙) |

### OU 구조
```
Root
├── Security OU
│   └── Landing Zone Account (관리 계정)
├── Workload OU
│   └── Service Account (cdp-service)
└── Operations OU
    └── Operations Account (cdp-operations)
```

### Permission Sets 매핑
| Group | Permission Set | Target Account | 용도 |
|-------|---------------|----------------|------|
| platform-admins | AdministratorAccess | Landing Zone | 전체 관리 |
| developers | ServiceDeployAccess | Service | EKS/EC2 배포 (삭제 불가) |
| sre-team | OperationsFullAccess | Operations | 모니터링 관리 |
| sre-team | ServiceReadOnly | Service | 서비스 읽기 (디버깅) |
| viewers | ViewOnlyAccess | All | 감사/조회 전용 |

### SCP 적용 내역
| SCP | 적용 대상 | 효과 |
|-----|----------|------|
| Region Restriction | Workload, Operations OU | ap-northeast-2만 허용 |
| Deny Root | Workload, Operations OU | Root 사용자 모든 작업 거부 |
| Deny IAM User Creation | Workload, Operations OU | IAM User 생성 불가 (SSO 강제) |
| Protect CloudTrail | Workload, Operations OU | CloudTrail 삭제/중지 방지 |
| Tag Policy | Root (전체) | 필수 태그 강제 |

### CloudTrail 설정
- 조직 전체 Trail (모든 계정의 API 호출 기록)
- S3에 저장 + 90일 후 Glacier로 아카이빙 + 365일 후 삭제
- CloudWatch Logs로도 전달 (실시간 모니터링 가능)

### 나중에 실행할 명령어 (AWS 권한 설정 후)
```bash
# Landing Zone 배포 시 (Step 2에서 이미 정의한 순서에 추가)
cd infra/terraform/landing-zone

# organizations, identity-center, scp, cloudtrail이 함께 배포됨
terraform init
terraform plan -var="service_account_email=cdp-service@yourdomain.com" \
              -var="operations_account_email=cdp-ops@yourdomain.com"
terraform apply

# 배포 후 SSO Portal 접속
# https://cdp.awsapps.com/start 에서 로그인
```

### 배운 점
- Organizations에서 `feature_set = "ALL"`이어야 SCP 사용 가능
- SCP는 "허용"이 아닌 "거부"로 가드레일을 만드는 개념
- `NotAction`을 사용해야 Global 서비스(IAM, CloudFront 등)가 차단되지 않음
- Identity Center Permission Set에 `DenyDestructive` 문을 넣으면 실수 방지
- CloudTrail은 `is_organization_trail = true`로 모든 멤버 계정에 자동 적용
- Tag Policy의 `enforced_for`로 특정 리소스 유형에만 태그 강제 가능
- S3 Lifecycle로 Glacier 전환하면 로그 장기보관 비용 절감

---

## Step 5: CI/CD 파이프라인 — GitHub Actions (2026-05-17)

### 목적
Terraform 변경을 자동화된 파이프라인으로 관리한다. PR 시 Plan/보안 검사, merge 시 자동 Apply.

### 생성한 파일

| 파일 | Trigger | 역할 |
|------|---------|------|
| `.github/workflows/terraform-plan.yml` | PR to main | 변경된 환경만 plan → PR 코멘트 |
| `.github/workflows/terraform-apply.yml` | Push to main / Manual | 순차 apply (LZ→Service→Ops) |
| `.github/workflows/terraform-security.yml` | PR to main | tfsec, Checkov, fmt, 비용 추정 |
| `.github/workflows/drift-detection.yml` | Daily 09:00 KST | Drift 감지 → Issue 자동 생성 |
| `infra/terraform/landing-zone/github-oidc.tf` | - | GitHub OIDC Provider + IAM Role |

### 파이프라인 흐름
```
Feature Branch → PR 생성
  → terraform plan (변경 환경만)
  → tfsec + Checkov 보안 스캔
  → Infracost 비용 추정
  → PR 코멘트로 결과 확인
  → 리뷰 & Approve
  → Merge to main
  → terraform apply (Landing Zone → Service → Operations 순)
  → GitHub Environment 승인 필요
```

### 인증 방식: OIDC (Access Key 없음)
```
GitHub Actions → OIDC Token → AWS IAM OIDC Provider → AssumeRole
```
- Long-lived Access Key 불필요 (보안 강화)
- 각 계정별 별도 Role로 최소 권한
- GitHub repo에 대한 trust 조건 설정

### 나중에 설정할 것 (AWS 연결 후)
```bash
# 1. GitHub Secrets 설정
gh secret set AWS_ROLE_LANDING_ZONE --body "arn:aws:iam::111111111111:role/cdp-github-actions-landing-zone"
gh secret set AWS_ROLE_SERVICE --body "arn:aws:iam::222222222222:role/cdp-github-actions-service"
gh secret set AWS_ROLE_OPERATIONS --body "arn:aws:iam::333333333333:role/cdp-github-actions-operations"

# 2. GitHub Environments 설정 (수동 - Settings > Environments)
# landing-zone: Required reviewers 추가
# service: Required reviewers 추가
# operations: Required reviewers 추가

# 3. (선택) Infracost API Key
gh secret set INFRACOST_API_KEY --body "ico-xxxxx"
```

### 배운 점
- GitHub OIDC는 Access Key를 완전히 제거할 수 있는 AWS 공식 권장 방식
- `dorny/paths-filter`로 변경된 디렉토리만 감지하면 불필요한 plan 실행 방지
- `terraform plan -detailed-exitcode`는 exit code 2 = 변경 있음 (drift 감지에 활용)
- GitHub Environment의 "Required reviewers"로 apply 전 수동 승인 게이트 구현
- tfsec + Checkov 조합으로 IaC 보안 검사 커버리지 극대화
- Infracost로 PR 단계에서 비용 영향 미리 확인 가��

---

## Step 6: 모니터링 CRD 및 설정 파일 작성 (2026-05-17)

### 목적
Prometheus/Grafana/AlertManager의 실제 설정을 CRD 기반으로 관리한다.
무엇을 수집하고, 어떤 조건에서 알람을 보내고, 대시보드에 무엇을 보여줄지 정의.

### 생성한 파일

| 파일 | 역할 |
|------|------|
| `monitoring/helm/kube-prometheus-stack-values.yaml` | Helm chart 전체 values (Terraform set 대체) |
| `monitoring/prometheus/servicemonitors/eks-service-account.yaml` | Service EKS 워크로드 스크래핑 |
| `monitoring/prometheus/servicemonitors/node-exporter.yaml` | Operations 노드 메트릭 |
| `monitoring/prometheus/servicemonitors/rds-exporter.yaml` | RDS PostgreSQL + Exporter Deployment |
| `monitoring/prometheus/rules/infra-alerts.yaml` | Node 알람 (CPU/Memory/Disk/Network/Down) |
| `monitoring/prometheus/rules/eks-alerts.yaml` | K8s 알람 (Pod/Deployment/HPA/PV) |
| `monitoring/prometheus/rules/rds-alerts.yaml` | DB 알람 (Connection/Slow Query/Deadlock) |
| `monitoring/grafana/dashboards/cluster-overview.json` | EKS 클러스터 현황 대시보드 |
| `monitoring/grafana/dashboards/rds-overview.json` | RDS PostgreSQL 상세 대시보드 |
| `monitoring/grafana/dashboards/landing-zone-traffic.json` | ALB/WAF 트래픽 대시보드 |
| `monitoring/alerting/alertmanager-config.yaml` | AlertManager 라우팅/수신자/억제 규칙 |
| `monitoring/README.md` | 모니터링 구조 설명 + 배포 방법 |

### CRD 종류 및 역할
```
ServiceMonitor (monitoring.coreos.com/v1)
  → "무엇을 수집할지" 정의 (target, interval, path)

PrometheusRule (monitoring.coreos.com/v1)
  → "어떤 조건에서 알람을 발생시킬지" 정의 (expr, for, severity)

ConfigMap (grafana_dashboard label)
  → Grafana sidecar가 자동 로드하는 대시보드 JSON
```

### AlertManager 라우팅 구조
```
모든 알람
  ├── severity=critical → critical-alerts (Email + Slack, 30분 반복)
  ├── component=database → database-alerts (DB 전용 채널)
  ├── component=infrastructure → infra-alerts
  ├── component=kubernetes → platform-alerts
  ├── severity=warning → warning-alerts (4시간 반복)
  ├── alertname=Watchdog → null (무시)
  └── 나머지 → default

억제 규칙 (Inhibit):
  - NodeDown이면 해당 노드의 다른 알람 억제
  - Critical이면 같은 대상의 Warning 억제
```

### 나중에 실행할 명령어
```bash
# CRD 리소스 적용
kubectl apply -f monitoring/prometheus/servicemonitors/
kubectl apply -f monitoring/prometheus/rules/

# Grafana 대시보드 ConfigMap 생성
kubectl create configmap grafana-dashboard-cluster \
  --from-file=monitoring/grafana/dashboards/cluster-overview.json \
  -n monitoring
kubectl label configmap grafana-dashboard-cluster grafana_dashboard=1 -n monitoring

# RDS Exporter 시크릿 생성
kubectl create secret generic rds-exporter-credentials \
  --from-literal=uri="rds-endpoint:5432/cdpdb?sslmode=require" \
  --from-literal=username="monitoring_user" \
  --from-literal=password="password" \
  -n monitoring
```

### 배운 점
- kube-prometheus-stack의 `*SelectorNilUsesHelmValues: false`로 설정해야 커스텀 CRD를 수집함
- ServiceMonitor의 `relabelings`로 cross-cluster 라벨(cluster, account) 추가 가능
- PrometheusRule에 `for` 필드로 flapping 방지 (일시적 스파이크 무시)
- AlertManager `inhibit_rules`로 상위 알람 발생 시 하위 알람 억제 (노이즈 감소)
- Grafana sidecar가 `grafana_dashboard=1` 라벨이 있는 ConfigMap을 자동 로드
- RDS Exporter는 별도 Deployment로 배포하고 ServiceMonitor로 연결
- `metricRelabelings`로 불필요한 메트릭 drop하여 카디널리티 관리

---

## Step 7: 샘플 마이크로서비스 — crypto-price-api + crypto-alert-service (2026-05-17)

### 목적
EKS에 배포할 실제 애플리케이션 두 개를 작성한다. 인프라만이 아닌 "실제 서비스 운영" 시나리오를 보여준다.

### 생성한 파일

#### crypto-price-api (Go)
| 파일 | 역할 |
|------|------|
| `apps/crypto-price-api/cmd/server/main.go` | 엔트리포인트, 서버 시작 |
| `apps/crypto-price-api/internal/api/handlers.go` | REST 핸들러 (GET /prices, /prices/{symbol}) |
| `apps/crypto-price-api/internal/api/middleware.go` | 로깅, 메트릭 미들웨어 |
| `apps/crypto-price-api/internal/collector/binance.go` | Binance WebSocket 가격 수집 |
| `apps/crypto-price-api/internal/models/price.go` | 데이터 모델 |
| `apps/crypto-price-api/internal/store/postgres.go` | PostgreSQL 저장소 |
| `apps/crypto-price-api/internal/metrics/prometheus.go` | Custom Prometheus 메트릭 |
| `apps/crypto-price-api/Dockerfile` | Multi-stage 빌드 (golang → alpine) |
| `apps/crypto-price-api/helm/` | Helm chart (Deployment, Service, HPA, ServiceMonitor) |
| `apps/crypto-price-api/go.mod` / `go.sum` | Go 의존성 |
| `apps/crypto-price-api/configs/config.yaml` | 앱 설정 |

#### crypto-alert-service (Python/FastAPI)
| 파일 | 역할 |
|------|------|
| `apps/crypto-alert-service/app/main.py` | FastAPI 앱 + 알림 평가 루프 |
| `apps/crypto-alert-service/app/models.py` | SQLAlchemy 모델 (Alert) |
| `apps/crypto-alert-service/app/schemas.py` | Pydantic 스키마 |
| `apps/crypto-alert-service/app/database.py` | 비동기 DB 세션 |
| `apps/crypto-alert-service/app/evaluator.py` | 조건 평가 + SNS/Slack 발송 |
| `apps/crypto-alert-service/Dockerfile` | Multi-stage 빌드 (python-slim) |
| `apps/crypto-alert-service/helm/` | Helm chart |
| `apps/crypto-alert-service/requirements.txt` | Python 의존성 |
| `apps/crypto-alert-service/configs/config.yaml` | 앱 설정 |

#### CI/CD & 로컬 개발
| 파일 | 역할 |
|------|------|
| `docker-compose.yml` | 로컬 개발 환경 (PostgreSQL + 두 서비스) |
| `.github/workflows/app-ci.yml` | Go test/lint, Python test/lint, Docker build, Helm lint |
| `.github/workflows/app-deploy.yml` | ECR push + Helm upgrade (EKS 배포) |

### 서비스 간 통신
```
crypto-price-api (Go, :8080)
  ├── GET /prices         → 전체 가격 목록
  ├── GET /prices/{symbol} → 특정 코인 가격
  ├── GET /health         → 헬스체크
  └── :9090/metrics       → Prometheus 메트릭

crypto-alert-service (Python, :8000)
  ├── POST /alerts        → 알림 생성
  ├── GET /alerts         → 알림 목록
  ├── DELETE /alerts/{id} → 알림 삭제
  └── 내부: 30초마다 price-api 호출 → 조건 평가 → SNS/Slack
```

### 배운 점
- Go의 `net/http` + `gorilla/mux`로 간단한 REST API 구현 가능
- FastAPI의 `BackgroundTasks`로 주기적 평가 루프를 별도 goroutine 없이 실행
- Docker multi-stage 빌드로 Go 바이너리 이미지 ~20MB, Python 이미지 ~150MB
- Helm chart에 ServiceMonitor CRD를 포함하면 앱 배포만으로 모니터링 자동 연동
- docker-compose의 `depends_on.condition: service_healthy`로 의존성 순서 보장

---

## Step 8: Terraform 포맷팅 및 검증 (2026-05-18)

### 목적
전체 Terraform 파일에 `terraform fmt`를 적용하고, lifecycle 설정 등의 경고를 수정한다.

### 변경 내역
- 전체 landing-zone, service, operations, modules 파일에 `terraform fmt` 적용
- `cloudtrail.tf`: S3 lifecycle_configuration에 빈 `filter {}` 블록 추가 (AWS provider 5.x 경고 해소)
- 주석 앞 이중 공백(`  #`) → 단일 공백(` #`)으로 통일

### 수정된 파일 (13개)
`cloudtrail.tf`, `identity-center.tf`, `scp.tf`, `vpc/main.tf`, `alerting.tf`, `iam-cross-account.tf`, `main.tf`, `monitoring-stack.tf`, `variables.tf`, `backup.tf`, `ec2.tf`, `rds.tf`, `go.mod`

### 배운 점
- `terraform fmt`는 HCL 코드의 정렬과 들여쓰기를 자동으로 표준화
- S3 lifecycle rule에 `filter {}`가 없으면 AWS provider 5.x에서 경고 발생
- CI/CD에서 `terraform fmt -check`를 넣으면 포맷 불일치를 PR 단계에서 잡을 수 있음

---

## Step 9: 보안 강화 — GuardDuty + Security Hub + Config Rules (2026-05-18)

### 목적
AWS 보안 서비스 3종을 Organization 전체에 활성화하여 위협 탐지, 보안 포스처 관리, 컴플라이언스를 자동화한다.

### 생성한 파일 (`infra/terraform/landing-zone/`)

| 파일 | 역할 |
|------|------|
| `guardduty.tf` | GuardDuty Organization-wide 위협 탐지 |
| `security-hub.tf` | Security Hub 보안 포스처 관리 + 표준 활성화 |
| `config-rules.tf` | AWS Config 녹화 + 컴플라이언스 규칙 13개 |

### GuardDuty 설정
- **탐지 범위**: S3 Logs, EKS Audit Logs, Malware Protection (EBS)
- **Organization 설정**: 신규 계정 자동 등록 (`auto_enable_organization_members = "ALL"`)
- **멤버 계정**: Service Account, Operations Account 등록
- **알림**: HIGH/CRITICAL (severity ≥ 7) → EventBridge → SNS

### Security Hub 설정
- **보안 표준 2개**:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v1.4.0
- **Organization**: 신규 계정 자동 등록
- **알림**: CRITICAL/HIGH findings (NEW status) → EventBridge → SNS

### AWS Config 설정
- **Config Recorder**: 전체 리소스 유형 + Global 리소스 포함
- **Delivery Channel**: S3 (KMS 암호화, Glacier 90일, 삭제 365일)
- **Organization Aggregator**: 전 계정 / 전 리전 Config 데이터 수집
- **Managed Rules 13개**:

| # | Rule | 검사 대상 |
|---|------|----------|
| 1 | S3 Public Read Prohibited | S3 퍼블릭 읽기 차단 |
| 2 | S3 Server-Side Encryption | S3 암호화 활성화 |
| 3 | RDS Storage Encrypted | RDS 스토리지 암호화 |
| 4 | RDS Multi-AZ Support | RDS 고가용성 |
| 5 | RDS Public Access Check | RDS 퍼블릭 접근 차단 |
| 6 | EC2 IMDSv2 Check | IMDSv2 필수 |
| 7 | EBS Encryption by Default | EBS 기본 암호화 |
| 8 | Root Account MFA | 루트 계정 MFA |
| 9 | IAM Password Policy | IAM 비밀번호 정책 |
| 10 | CloudTrail Enabled | CloudTrail 활성화 |
| 11 | VPC Flow Logs Enabled | VPC Flow Logs |
| 12 | Restricted SSH | SSH 0.0.0.0/0 차단 |
| 13 | EKS Secrets Encrypted | EKS Secrets 암호화 |

- **알림**: NON_COMPLIANT 변경 → EventBridge → SNS

### SNS 토픽 구성 (보안 알림)
```
cdp-landing-guardduty-findings    → GuardDuty HIGH/CRITICAL
cdp-landing-securityhub-findings  → Security Hub CRITICAL/HIGH
cdp-landing-config-compliance     → Config NON_COMPLIANT
```

### 수정된 파일
- `outputs.tf`: GuardDuty, Security Hub, Config 관련 출력값 6개 추가

### 배운 점
- GuardDuty/Security Hub/Config 모두 Organizations 위임 관리자 패턴으로 중앙 관리 가능
- `aws_guardduty_organization_configuration`의 `auto_enable_organization_members`로 신규 계정 자동 보호
- Security Hub Standards는 리전별 ARN이 다르므로 `var.region` 변수 활용
- Config Rules의 `maximum_execution_frequency`는 주기적 평가 규칙에만 필요 (변경 트리거 규칙은 불필요)
- EventBridge → SNS 패턴으로 세 서비스의 알림을 통합 관리
- Config Aggregator로 멀티 계정/멀티 리전 컴플라이언스를 한 곳에서 확인

---

## Step 10: 로컬 테스트 검증 — docker-compose (2026-05-19)

### 목적
AWS 없이 로컬 환경에서 두 마이크로서비스가 정상 동작하는지 검증한다.
Docker build → PostgreSQL 연동 → API 호출 → Prometheus 메트릭까지 전체 파이프라인 확인.

### 실행한 명령어

```bash
# 1. Docker 이미지 빌드
docker compose build

# 2. 전체 스택 실행 (PostgreSQL → Go API → Python Alert Service)
docker compose up -d

# 3. 컨테이너 상태 확인
docker compose ps
# 결과: 3개 컨테이너 모두 Up 상태

# 4. Health Check 테스트
curl -s http://localhost:8080/health   # → {"status": "ok"}
curl -s http://localhost:8080/ready    # → {"status": "ready"}
curl -s http://localhost:8000/health   # → {"status": "ok"}

# 5. 가격 수집 확인 (Binance 실시간 데이터)
curl -s http://localhost:8080/api/v1/prices | python3 -m json.tool
# 결과: BTC, ETH, SOL, XRP, ADA 5개 심볼 실시간 가격 수집 중

# 6. 개별 심볼 조회
curl -s http://localhost:8080/api/v1/prices/BTCUSDT | python3 -m json.tool

# 7. Alert 생성 테스트
curl -s -X POST http://localhost:8000/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "condition": "above",
    "target_price": 100000,
    "notification_channel": "slack",
    "notification_target": "https://hooks.slack.com/test",
    "repeat": true,
    "cooldown_minutes": 30
  }' | python3 -m json.tool
# 결과: Alert ID 반환, status: active

# 8. Alert 목록 조회
curl -s http://localhost:8000/api/v1/alerts | python3 -m json.tool

# 9. Prometheus 메트릭 확인
curl -s http://localhost:9091/metrics | head -20
# 결과: crypto_price_api_fetch_duration_seconds, crypto_price 등 커스텀 메트릭 정상 노출

# 10. 정리
docker compose down
```

### 테스트 결과

| 테스트 항목 | 결과 |
|------------|------|
| Docker build (Go multi-stage) | Pass |
| Docker build (Python multi-stage) | Pass |
| PostgreSQL healthcheck 연동 | Pass |
| Go API — `/health`, `/ready` | Pass |
| Python API — `/health` | Pass |
| Binance 실시간 가격 수집 (30초 간격) | Pass — BTC, ETH, SOL, XRP, ADA |
| 개별 심볼 조회 (`/api/v1/prices/BTCUSDT`) | Pass |
| Alert CRUD (`POST/GET /api/v1/alerts`) | Pass |
| 서비스 간 통신 (Python → Go HTTP) | Pass |
| Prometheus custom metrics (`:9091/metrics`) | Pass |

### 버그 수정 (2건)

1. **`app/main.py` readiness check**: `conn.execute("SELECT 1")` → `conn.execute(text("SELECT 1"))`
   - SQLAlchemy 2.x에서는 raw SQL string 직접 전달이 deprecated됨. `text()` 래핑 필수.

2. **`app/api/routes.py` 미사용 import**: `from pydantic import BaseModel, EmailStr` → `EmailStr` 제거
   - 실제 코드에서 사용하지 않는 import. `pydantic[email]` 없이 설치 시 import 에러 가능.

### docker-compose 구성 요약

```yaml
services:
  postgres:        # PostgreSQL 16 + healthcheck
  crypto-price-api:  # Go, depends_on: postgres(healthy)
  crypto-alert-service:  # Python, depends_on: postgres(healthy) + price-api(started)

# 포트 매핑
# localhost:5432 → PostgreSQL
# localhost:8080 → Go API
# localhost:9091 → Go Prometheus metrics (컨테이너 내 9090)
# localhost:8000 → Python API + /metrics
```

### 배운 점
- docker-compose의 `depends_on.condition: service_healthy`로 PostgreSQL이 완전히 준비된 후 앱 시작
- Go 앱은 `DATABASE_URL`에 `?sslmode=disable` 필요 (로컬 PostgreSQL은 SSL 미설정)
- Python 앱은 asyncpg 드라이버라 DSN 형식이 다름 (`postgresql+asyncpg://`)
- Binance API는 인증 없이 실시간 가격 조회 가능 (`/api/v3/ticker/24hr`)
- SQLAlchemy 2.x에서 raw SQL은 반드시 `text()` 래핑 필요 (1.x에서는 string 직접 전달 가능했음)
- Prometheus metrics 포트를 API 포트와 분리하면 metrics endpoint가 외부에 노출되지 않음

---

## 다음 단계 (예정)
- [ ] 실제 AWS 연결 및 terraform apply 테스트
- [ ] Terraform에서 monitoring/ 파일 참조하도록 연결
