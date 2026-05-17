# ADR-004: CI/CD — GitHub Actions + OIDC 기반 Terraform 자동화

## Status
Accepted (2026-05-17)

## Context (문제 상황)

Terraform 코드를 수동으로 `terraform apply` 하면:
- 누가 언제 어떤 변경을 적용했는지 추적 어려움
- 잘못된 코드가 바로 프로덕션에 적용될 위험
- 팀원 간 state 충돌 가능성
- 보안 검사 누락 가능

## Decision (결정)

**GitHub Actions로 Terraform CI/CD 파이프라인을 구축하고, OIDC로 AWS에 인증한다.**

### 파이프라인 흐름

```
개발자 작업 → Feature Branch → PR 생성
                                  │
                    ┌──────────────┼──────────────────┐
                    │              │                  │
                    ▼              ▼                  ▼
              terraform-plan  terraform-security  cost-estimate
              (변경 계획)     (tfsec + checkov)   (Infracost)
                    │              │                  │
                    └──────────────┼──────────────────┘
                                  │
                          PR Comment에 결과 표시
                                  │
                            리뷰 & Approve
                                  │
                              Merge to main
                                  │
                          terraform-apply
                    (Landing Zone → Service → Operations)
                                  │
                            Deploy 완료
```

### Daily Drift Detection
```
매일 KST 09:00 → terraform plan (변경 감지)
  → drift 발견 시 → GitHub Issue 자동 생성
```

### Workflow 구성

| Workflow | Trigger | 역할 |
|----------|---------|------|
| `terraform-plan.yml` | PR to main | Plan 결과를 PR 코멘트로 표시 |
| `terraform-apply.yml` | Push to main / Manual | 순서대로 Apply (Environment 승인 필요) |
| `terraform-security.yml` | PR to main | tfsec, Checkov, fmt check, 비용 추정 |
| `drift-detection.yml` | Daily cron / Manual | Drift 감지 → Issue 생성 |

### 인증: GitHub OIDC (Access Key 없음)

```
GitHub Actions Runner
    │
    │ OIDC Token 요청
    ▼
AWS IAM OIDC Provider
    │
    │ AssumeRoleWithWebIdentity
    ▼
계정별 IAM Role (최소 권한)
```

- Access Key/Secret 없이 인증 (보안 강화)
- 토큰은 Job 실행 시 자동 발급, 만료됨
- 각 계정별로 별도 Role (Landing Zone / Service / Operations)

### 변경 감지 (paths-filter)

모듈이 변경되면 의존하는 모든 환경의 plan이 실행됨:
- `modules/` 변경 → Landing Zone + Service + Operations 모두 plan
- `service/` 변경 → Service만 plan
- `operations/` 변경 → Operations만 plan

## Options Considered

### Option A: GitHub Actions + OIDC ✅ 선택
**장점:** 무료 (public repo), GitHub 네이티브, Access Key 불필요, PR 연동 자연스러움
**단점:** GitHub 의존

### Option B: Terraform Cloud
**장점:** State 관리 내장, 전용 UI
**단점:** 무료 티어 제한, 별도 서비스 의존

### Option C: AWS CodePipeline
**장점:** AWS 네이티브
**단점:** 설정 복잡, GitHub 연동 번거로움, UI 불편

## Consequences

### GitHub Secrets 설정 필요
```
AWS_ROLE_LANDING_ZONE  = arn:aws:iam::111111111111:role/cdp-github-actions-landing-zone
AWS_ROLE_SERVICE       = arn:aws:iam::222222222222:role/cdp-github-actions-service
AWS_ROLE_OPERATIONS    = arn:aws:iam::333333333333:role/cdp-github-actions-operations
INFRACOST_API_KEY      = (optional) Infracost API key
```

### GitHub Environments 설정 필요
- `landing-zone` — Required reviewers 설정
- `service` — Required reviewers 설정
- `operations` — Required reviewers 설정

### 보안 이점
- Long-lived credentials 제거
- PR 없이 직접 apply 불가능
- 모든 변경은 Git history에 기록
- 보안 스캔이 merge 전에 실행

## References
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
