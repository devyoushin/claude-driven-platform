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

## 다음 단계 (예정)
- [ ] CI/CD 파이프라인 (GitHub Actions → terraform plan/apply)
- [ ] 실제 AWS 연결 및 terraform apply 테스트
- [ ] 보안 강화 (Security Hub, GuardDuty, Config Rules)
- [ ] 샘플 애플리케이션 배포 (EKS)
