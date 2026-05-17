# Architecture Decision Records

> 프로젝트의 모든 아키텍처 의사결정을 추적합니다.
> 새 ADR 추가 시 이 인덱스도 함께 업데이트하세요.

## Status Legend

| 상태 | 의미 |
|------|------|
| ✅ Accepted | 채택되어 현재 적용 중 |
| 🔄 Superseded | 이후 결정으로 대체됨 (대체한 ADR 번호 표기) |
| ❌ Deprecated | 더 이상 유효하지 않음 |
| 🤔 Proposed | 검토 중, 아직 미확정 |

---

## By Category

### Infrastructure / Network

| # | Title | Status | Summary |
|---|-------|--------|---------|
| [001](001-multi-account-architecture.md) | Multi-Account Architecture | ✅ Accepted | Landing Zone + Service + Operations 3계정 구조, TGW 연결 |

### Security / IAM

| # | Title | Status | Summary |
|---|-------|--------|---------|
| [003](003-iam-centralized-management.md) | Centralized IAM Management | ✅ Accepted | Organizations + Identity Center로 SSO 기반 중앙 관리 |

### Monitoring / Observability

| # | Title | Status | Summary |
|---|-------|--------|---------|
| [002](002-monitoring-account-separation.md) | Monitoring Account Separation | ✅ Accepted | 모니터링을 별도 Operations Account로 분리, 장애 격리 |

### CI/CD

| # | Title | Status | Summary |
|---|-------|--------|---------|
| — | (예정) | — | GitHub Actions 기반 Terraform 자동화 |

### Application

| # | Title | Status | Summary |
|---|-------|--------|---------|
| — | (예정) | — | — |

---

## Chronological (전체 목록)

| # | Date | Title | Status | Category |
|---|------|-------|--------|----------|
| [001](001-multi-account-architecture.md) | 2026-05-17 | Multi-Account Architecture | ✅ Accepted | Infra/Network |
| [002](002-monitoring-account-separation.md) | 2026-05-17 | Monitoring Account Separation | ✅ Accepted | Monitoring |
| [003](003-iam-centralized-management.md) | 2026-05-17 | Centralized IAM Management | ✅ Accepted | Security/IAM |

---

## How to Write an ADR

새로운 결정이 필요할 때:

1. 다음 번호로 파일 생성: `NNN-short-title.md`
2. 아래 템플릿 사용
3. 이 INDEX.md에 추가 (카테고리별 + 전체 목록 모두)

### Template

```markdown
# ADR-NNN: 제목

## Status
Proposed / Accepted / Superseded by [XXX] / Deprecated

## Context (문제 상황)
어떤 상황에서 어떤 결정이 필요했는가?

## Decision (결정)
무엇을 선택했는가? 구조/다이어그램 포함.

## Options Considered (검토한 옵션들)
각 옵션의 장단점 비교.

## Consequences (결과)
이 결정으로 인해 해야 할 것, 비용, 리스크.

## References
관련 문서/링크.
```
