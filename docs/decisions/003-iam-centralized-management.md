# ADR-003: IAM 중앙 관리 — AWS Organizations + Identity Center

## Status
Accepted (2026-05-17)

## Context (문제 상황)

3개의 AWS 계정(Landing Zone, Service, Operations)을 운영하면서 IAM을 어떻게 관리할지 결정해야 했다.

고민 포인트:
- 계정이 3개인데 각각 IAM User를 만들면 관리가 파편화됨
- 누가 어떤 계정에 어떤 권한으로 접근하는지 추적이 어려움
- 계정이 추가될 때마다 IAM 설정을 반복해야 함
- 보안 감사(Audit) 시 전체 접근 현황 파악이 힘듦

## Decision (결정)

**Landing Zone Account에서 AWS Organizations + IAM Identity Center(SSO)로 전체 IAM을 중앙 관리한다.**

### 구조

```
┌─ Landing Zone Account ─────────────────────────────────────┐
│                                                            │
│  ┌─ AWS Organizations ──────────────────────────────────┐  │
│  │  Root                                                │  │
│  │  ├── Security OU                                     │  │
│  │  │   └── Landing Zone Account                        │  │
│  │  ├── Workload OU                                     │  │
│  │  │   └── Service Account                             │  │
│  │  └── Operations OU                                   │  │
│  │      └── Operations Account                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─ IAM Identity Center (SSO) ──────────────────────────┐  │
│  │                                                      │  │
│  │  Permission Sets:                                    │  │
│  │  ├── AdministratorAccess    → Landing Zone only      │  │
│  │  ├── ServiceDeployAccess    → Service Account        │  │
│  │  ├── ServiceReadOnly        → Service Account        │  │
│  │  ├── OperationsFullAccess   → Operations Account     │  │
│  │  └── ViewOnlyAccess         → All Accounts           │  │
│  │                                                      │  │
│  │  Groups:                                             │  │
│  │  ├── platform-admins   → AdministratorAccess         │  │
│  │  ├── developers        → ServiceDeployAccess         │  │
│  │  ├── sre-team          → OperationsFullAccess        │  │
│  │  └── viewers           → ViewOnlyAccess              │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Cross-Account Role 설계

```
사용자 → SSO Portal → AssumeRole → 대상 Account

Service Account에 생성되는 Role:
  - cdp-service-deploy-role     (EKS, EC2, RDS 관리)
  - cdp-service-readonly-role   (읽기 전용, Operations에서 사용)

Operations Account에 생성되는 Role:
  - cdp-ops-admin-role          (모니터링 스택 관리)
  - cdp-ops-metric-reader-role  (Service → Ops 메트릭 push용)
```

### Service Control Policies (SCP)

조직 수준에서 아래 정책 적용:
- 모든 계정: ap-northeast-2 리전만 허용 (리전 제한)
- 모든 계정: Root 사용자 사용 금지
- Service Account: IAM User 직접 생성 금지
- Operations Account: Service 리소스 삭제 권한 없음 (읽기 전용)

## Options Considered (검토한 옵션들)

### Option A: Organizations + Identity Center ✅ 선택

**장점:**
- SSO 포털 하나로 모든 계정 접근 관리
- Permission Set으로 역할 기반 접근 제어 (RBAC)
- SCP로 조직 단위 보안 정책 강제
- CloudTrail 중앙화로 전체 감사 추적 가능
- 계정 추가 시 OU에 넣기만 하면 정책 자동 상속
- AWS 공식 권장 패턴 (Well-Architected)

**단점:**
- 초기 설정 복잡도 (Organizations, Identity Center, Permission Set)
- Landing Zone 계정 장애 시 다른 계정 접근 영향 (하지만 기존 Role은 유지)

### Option B: 계정별 개별 IAM User

**장점:**
- 설정이 단순함

**단점:**
- IAM User 파편화 (계정마다 별도 credential)
- Access Key 관리 부담 (rotate 필요)
- 전체 현황 파악 불가
- 보안 감사 어려움
- AWS가 비권장하는 패턴

### Option C: 외부 IdP (Okta, Azure AD 등) 연동

**장점:**
- 기업 기존 인프라 활용 가능

**단점:**
- 포트폴리오 프로젝트에는 과도함
- 추가 비용 발생
- Option A에서 나중에 확장 가능 (Identity Center가 외부 IdP 연동 지원)

## Consequences (결과)

### Terraform 구현 사항
1. `landing-zone/organizations.tf` — Organizations + OU 구성
2. `landing-zone/identity-center.tf` — SSO + Permission Sets
3. `landing-zone/scp.tf` — Service Control Policies
4. `service/iam-cross-account.tf` — Cross-account roles
5. `operations/iam-cross-account.tf` — Cross-account roles

### 운영 흐름
```
1. 개발자가 SSO Portal (https://cdp.awsapps.com/start) 접속
2. 할당된 Account + Permission Set 선택
3. 임시 Credential 발급 (12시간 유효)
4. AWS Console 또는 CLI로 작업
```

### 보안 이점
- Access Key 장기 보관 없음 (임시 credential만 사용)
- MFA 중앙 강제 가능
- 퇴사자 처리 = Identity Center에서 사용자 비활성화 1건
- CloudTrail에 "누가 어떤 계정에서 뭘 했는지" 전부 기록

## References
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [SCP Examples](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html)
