# Project Status

> 마지막 업데이트: 2026-05-17

## 현재 진행 상황

### 완료됨 ✅

| # | 항목 | 설명 | 날짜 |
|---|------|------|------|
| 1 | 프로젝트 초기화 | 모노레포 구조, CLAUDE.md, README | 2026-05-17 |
| 2 | Terraform — Landing Zone | VPC, WAF, ALB, TGW | 2026-05-17 |
| 3 | Terraform — Service Account | VPC, EKS, EC2(ASG), RDS(Multi-AZ), Backup | 2026-05-17 |
| 4 | Terraform — Operations Account | EKS, Prometheus, Grafana, AlertManager, SNS | 2026-05-17 |
| 5 | Organizations + Identity Center | OU, SCP, SSO, CloudTrail | 2026-05-17 |
| 6 | CI/CD 파이프라인 | GitHub Actions (plan/apply/security/drift) | 2026-05-17 |

### 다음에 할 것 📋

| 우선순위 | 항목 | 메모 |
|----------|------|------|
| 1 | AWS 연결 및 terraform apply 테스트 | AWS 계정 + CLI 설정 필요 |
| 2 | 보안 강화 | Security Hub, GuardDuty, Config Rules |
| 3 | 샘플 애플리케이션 | EKS에 배포할 간단한 앱 + Dockerfile |
| 4 | Grafana 대시보드 | JSON으로 대시보드 정의 |
| 5 | Terraform 검증 | `terraform validate` + `terraform fmt` 로컬 확인 |

### 블로커 / 대기 중 ⏸️

| 항목 | 이유 | 해결 방법 |
|------|------|----------|
| terraform apply 불가 | AWS 권한 미설정 | AWS CLI configure 필요 |

---

## 아키텍처 요약 (현재)

```
3-Account Architecture (AWS ap-northeast-2)

Landing Zone ─── Security, IAM, WAF, ALB, TGW, Organizations
Service      ─── EKS, EC2, RDS, Backup
Operations   ─── Prometheus, Grafana, AlertManager
```

## 파일 구조 요약

```
claude-driven-platform/
├── .github/workflows/     ← CI/CD (4개 workflow)
├── infra/terraform/
│   ├── modules/           ← 공유 모듈 (vpc, tgw, tags)
│   ├── landing-zone/      ← 7개 파일 (vpc, waf, tgw, org, sso, scp, cloudtrail, oidc)
│   ├── service/           ← 9개 파일 (vpc, eks, ec2, rds, backup, ...)
│   └── operations/        ← 9개 파일 (vpc, eks, prometheus, alerting, ...)
├── docs/
│   ├── decisions/         ← ADR 4개 + INDEX
│   ├── history.md         ← 상세 작업 히스토리
│   └── ai-workflow.md     ← Claude 활용 방법론
├── STATUS.md              ← 이 파일 (현재 상태)
├── CLAUDE.md              ← Claude 컨텍스트
└── README.md              ← 프로젝트 소개
```

## 참고

- 상세 작업 히스토리: [docs/history.md](docs/history.md)
- 아키텍처 결정 목록: [docs/decisions/INDEX.md](docs/decisions/INDEX.md)
- Claude와의 협업 방법: [docs/ai-workflow.md](docs/ai-workflow.md)
