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

## 다음 단계 (예정)
- [ ] 모니터링 스택 (Prometheus + Grafana on EKS, CloudWatch)
- [ ] CI/CD 파이프라인 (GitHub Actions)
- [ ] 실제 AWS 연결 및 terraform apply 테스트
- [ ] 보안 강화 (Security Hub, GuardDuty)
