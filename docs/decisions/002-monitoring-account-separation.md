# ADR-002: 모니터링 스택을 별도 Operations Account로 분리

## Status
Accepted (2026-05-17)

## Context (문제 상황)

모니터링 스택(Prometheus, Grafana, AlertManager)을 어디에 배치할지 결정해야 했다.

현재 아키텍처:
- **Landing Zone Account**: 외부 트래픽 진입점, WAF/ALB, 보안 역할
- **Service Account**: 서비스 운영 (EKS, EC2, RDS)

모니터링을 기존 계정에 넣으면 역할이 혼재된다:
- Landing Zone은 "보안 게이트웨이"인데 모니터링은 보안이 아님
- Service Account에 넣으면 서비스 장애 시 모니터링도 같이 죽을 수 있음

## Decision (결정)

**별도 Operations Account를 신설하여 모니터링/옵저버빌리티 전용으로 사용한다.**

```
┌─ Landing Zone ──────────┐
│  WAF / ALB / TGW        │  ← 보안, 외부 트래픽 관리
└────────┬────────────────┘
         │
    Transit Gateway
         │
┌────────┴─────────┬──────────────────────┐
│                  │                      │
▼                  ▼                      │
┌─ Service ───┐    ┌─ Operations ────────────┐
│ EKS, EC2    │    │ Prometheus + Grafana     │
│ RDS, Backup │    │ AlertManager → SNS       │
│             │───▶│ Centralized Logging      │
│ (메트릭 수집 │    │ CloudWatch Dashboard     │
│  대상)       │    │                          │
└─────────────┘    └──────────────────────────┘
```

## Options Considered (검토한 옵션들)

### Option A: Operations Account 신설 ✅ 선택
- 모니터링 전용 계정 추가
- TGW로 Service Account에서 메트릭 수집

**장점:**
- 관심사 완벽 분리 (Security / Service / Operations)
- 서비스 장애 시에도 모니터링 독립적으로 동작
- 서비스 계정이 추가되어도 모니터링은 한곳에서 통합 관리
- 엔터프라이즈 AWS Well-Architected 패턴과 일치
- 포트폴리오로서 3-account 아키텍처가 더 설득력 있음

**단점:**
- 계정 관리 오버헤드 증가
- TGW 비용 소폭 증가
- Cross-account 메트릭 수집 설정 복잡도

### Option B: Service Account에 포함
- 같은 VPC 내에 모니터링 Pod 배포

**장점:**
- 네트워크 구성 단순
- 메트릭 수집 지연 최소

**단점:**
- 서비스 장애 = 모니터링 장애 (단일 장애점)
- Service Account의 역할이 모호해짐
- 리소스 경합 가능성

### Option C: Landing Zone에 포함
- 보안 계정에 모니터링 추가

**장점:**
- 계정 수 유지

**단점:**
- Landing Zone의 역할은 "보안 게이트웨이"이지 "옵저버빌리티"가 아님
- 책임 범위(Blast Radius) 혼재
- 보안팀과 운영팀의 권한 분리 불가

## Consequences (결과)

### 해야 할 것
1. Operations Account용 Terraform 코드 추가 (`infra/terraform/operations/`)
2. TGW에 Operations VPC attachment 추가
3. Cross-account 메트릭 수집 구성 (Prometheus remote_write 또는 ADOT)
4. Operations VPC CIDR 할당 (10.20.0.0/16)
5. ADR-001 아키텍처 다이어그램 업데이트

### 비용 영향
- TGW attachment 추가: ~$36/월
- Operations Account EKS (모니터링용): ~$73/월 (EKS) + 노드 비용
- 전체적으로 모니터링 인프라 비용 별도 추적 가능 (CostCenter 태그 활용)

### 보안 고려사항
- Operations Account는 Service Account에 대해 **읽기 전용** 접근만 허용
- CloudWatch cross-account 역할은 최소 권한 원칙 적용
- 메트릭 데이터는 TGW 내부 트래픽으로 인터넷 미경유

## References
- [AWS Well-Architected: Multi-Account Strategy](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html)
- [AWS Observability Best Practices](https://aws-observability.github.io/observability-best-practices/)
