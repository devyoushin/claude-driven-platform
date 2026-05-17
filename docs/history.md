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

## 다음 단계 (예정)
- [ ] Terraform 기본 구성 (provider, backend, VPC module)
- [ ] EKS 클러스터 정의
- [ ] 모니터링 스택 배포
- [ ] CI/CD 파이프라인
