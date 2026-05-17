# ADR-001: Multi-Account Architecture with Landing Zone

## Status
Accepted (2026-05-17)

## Context
포트폴리오 프로젝트로 실제 엔터프라이즈 수준의 AWS 멀티 계정 아키텍처를 구현한다.
단일 서비스를 운영한다고 가정하되, 보안과 네트워크 분리를 위해 계정을 분리한다.

## Decision

### Account 구조
| Account | 역할 | 주요 리소스 |
|---------|------|------------|
| Landing Zone | 외부 트래픽 진입점, 보안 | WAF, ALB, TGW, IGW |
| Service | 서비스 운영 | VPC, EKS, EC2, RDS, Backup |

### Network 설계
- **Landing Zone VPC**: `10.0.0.0/16`
- **Service VPC**: `10.10.0.0/16`
- **Transit Gateway**로 두 VPC 연결
- 각 VPC는 2개 AZ (ap-northeast-2a, 2c) 사용

### Service VPC Subnet 구조
| Subnet | AZ-a | AZ-c | 용도 |
|--------|------|------|------|
| Public | 10.10.1.0/24 | 10.10.2.0/24 | NAT GW, Bastion |
| Private (App) | 10.10.11.0/24 | 10.10.12.0/24 | EKS nodes, EC2 |
| Private (DB) | 10.10.21.0/24 | 10.10.22.0/24 | RDS |

### Landing Zone VPC Subnet 구조
| Subnet | AZ-a | AZ-c | 용도 |
|--------|------|------|------|
| Public | 10.0.1.0/24 | 10.0.2.0/24 | ALB, WAF |
| Private | 10.0.11.0/24 | 10.0.12.0/24 | TGW Attachment |

### 트래픽 흐름
```
User → CloudFront(optional) → WAF → ALB (Landing Zone)
  → TGW → Service VPC Private Subnet → EKS/EC2 → RDS
```

### Tag 정책
모든 리소스에 아래 태그 필수:
- `Project`: claude-driven-platform
- `Environment`: dev / staging / prod
- `ManagedBy`: terraform
- `Owner`: devyoushin
- `CostCenter`: 비용 추적용
- `Component`: landing-zone / service / monitoring

### 모니터링 (상세 설계 예정)
- AWS CloudWatch: 기본 인프라 메트릭
- Prometheus + Grafana: EKS 워크로드 메트릭
- AWS CloudWatch Container Insights: EKS 클러스터 메트릭
- SNS + Lambda: 알람 라우팅 (Slack/Email)

## Consequences
- 멀티 계정 → Terraform workspace 또는 디렉토리 분리 필요
- TGW 비용 발생 (시간당 + 데이터 처리량)
- 운영 복잡도 증가하지만 보안/네트워크 분리 확보
