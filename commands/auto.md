---
allowed-tools: Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(npx:*), Bash(go:*), Bash(cargo:*), Bash(make:*), Bash(python:*), Read, Write, Edit, Glob, Grep, Task
description: 계획부터 PR까지 원버튼 자동 실행. 중간에 멈추지 않습니다.
argument-hint: [작업 설명] [--mode feature|bugfix|refactor]
---

# /auto - 원스톱 자동 워크플로우 (v6)

개별 커맨드를 하나씩 호출하는 대신, 전체 파이프라인을 한 번에 자동 실행합니다.
CRITICAL 보안 이슈에서만 중단하며, 그 외에는 끝까지 진행합니다.

---

## 0단계: 인자 파싱

$ARGUMENTS에서 옵션을 추출한다:

| 인자 | 기본값 | 설명 |
|------|--------|------|
| `--mode` | feature | 실행 모드: feature / bugfix / refactor |
| 나머지 텍스트 | - | 작업 설명 (필수) |

작업 설명이 없으면 에러를 출력하고 종료한다:

```
사용법: /auto [작업 설명]

예시:
  /auto 로그인 페이지 만들기
  /auto --mode bugfix 결제 금액이 0원으로 표시되는 버그
  /auto --mode refactor 인증 모듈 정리
```

---

## 1단계: 모드별 파이프라인 결정

### feature 모드 (기본)

```
plan -> tdd -> code-review -> handoff-verify -> commit-push-pr
```

1. **plan**: 구현 계획 수립. 사용자 확인 없이 자동 확정.
2. **tdd**: 테스트 먼저 작성 후 구현. RED -> GREEN -> IMPROVE 사이클.
3. **code-review**: 작성한 코드의 보안 + 품질 검사. CRITICAL/HIGH 이슈는 자동 수정.
4. **handoff-verify**: 빌드/테스트/린트 자동 검증. 실패 시 자동 수정 후 재검증 (최대 5회).
5. **commit-push-pr**: 커밋 메시지 자동 생성, 푸시, PR 생성.

### bugfix 모드

```
explore -> tdd -> handoff-verify -> quick-commit
```

1. **explore**: 관련 코드 탐색으로 버그 원인 파악.
2. **tdd**: 버그를 재현하는 테스트 작성 후 수정.
3. **handoff-verify**: 빌드/테스트 검증 (--once 모드).
4. **quick-commit**: 자동 생성된 커밋 메시지로 빠른 커밋 + 푸시.

### refactor 모드

```
refactor-clean -> code-review -> handoff-verify -> commit-push-pr
```

1. **refactor-clean**: 사용하지 않는 코드, 중복 제거, 구조 개선.
2. **code-review**: 리팩토링 결과 검사.
3. **handoff-verify**: 기존 기능이 깨지지 않았는지 검증.
4. **commit-push-pr**: 커밋 + PR (--squash 권장).

---

## 2단계: 환경 확인

파이프라인 시작 전 기본 환경을 확인한다:

1. Git 레포 확인 (`git rev-parse --is-inside-work-tree`)
2. 프로젝트 타입 감지 (package.json / go.mod / Cargo.toml / pyproject.toml)
3. 패키지 매니저 감지 (pnpm-lock.yaml / yarn.lock / bun.lockb / npm)

Git 레포가 아니면 안내 후 중단.

---

## 3단계: 파이프라인 실행

각 단계를 순차적으로 실행한다.
ultrawork 모드를 사용하여 중간에 멈추지 않는다.

### 단계 전환 규칙

- 각 단계 완료 후 즉시 다음 단계로 진행한다.
- 사용자 확인을 요청하지 않는다.
- CRITICAL 보안 이슈 발견 시에만 중단하고 사용자에게 보고한다.

### plan 단계 자동 확정 (feature 모드)

일반적으로 `/plan`은 사용자 확인을 기다리지만, `/auto` 모드에서는:
1. 계획을 수립한다.
2. 계획을 출력한다 (사용자가 볼 수 있도록).
3. 자동으로 확정하고 다음 단계로 진행한다.

### 에러 처리

- **Fixable 에러** (린트, import, 타입 단순 오류): 자동 수정 후 계속 진행.
- **Non-fixable 에러** (로직 오류, 아키텍처 문제): 해당 단계에서 최대 3회 재시도 후 실패 보고.
- **CRITICAL 보안 이슈**: 즉시 중단, 사용자에게 보고.

---

## 4단계: 결과 요약

전체 파이프라인이 완료되면 한 번에 요약을 출력한다:

### 성공 시

```
======================================================================
  Auto Complete (v6) - [mode] 모드
======================================================================

  작업: [작업 설명]

  실행 결과:
    [1] Plan         DONE   [N]개 단계 계획
    [2] TDD          DONE   [N]개 테스트, [N]% 커버리지
    [3] Code Review  DONE   CRITICAL 0 / HIGH 0
    [4] Verify       PASS   빌드+테스트+린트 통과
    [5] Commit & PR  DONE   PR #[번호]: [URL]

======================================================================
```

### 부분 실패 시

```
======================================================================
  Auto Incomplete (v6) - [mode] 모드
======================================================================

  작업: [작업 설명]

  실행 결과:
    [1] Plan         DONE
    [2] TDD          DONE
    [3] Code Review  WARN   HIGH 2건 (자동 수정됨)
    [4] Verify       FAIL   테스트 2개 실패
    [5] Commit & PR  SKIP   (검증 실패로 스킵)

  실패 상세:
    - src/auth.ts:45 - 타입 불일치 (자동 수정 실패)
    - src/auth.test.ts:30 - 예상값 불일치

  수동 수정 후:
    /handoff-verify -> /commit-push-pr

======================================================================
```

---

## 사용 예시

```bash
# 새 기능 (기본 모드)
/auto 로그인 페이지 만들기

# 버그 수정
/auto --mode bugfix 결제 금액이 0원으로 표시되는 버그

# 코드 정리
/auto --mode refactor 인증 모듈 정리

# 자연어로 작업 설명
/auto 사용자가 비밀번호를 5번 틀리면 계정을 10분 잠금하는 기능
/auto --mode bugfix 이미지 업로드 시 CORS 에러
/auto --mode refactor API 호출 로직을 커스텀 훅으로 분리
```

---

## 주의사항

- `/auto`는 각 단계의 세부 동작을 개별 커맨드(`/plan`, `/tdd` 등)에 위임합니다.
- 중간 과정이 모두 출력되므로 진행 상황을 실시간으로 확인할 수 있습니다.
- CRITICAL 보안 이슈 외에는 멈추지 않으므로, 민감한 작업은 개별 커맨드를 사용하세요.
- 각 단계를 더 세밀하게 제어하고 싶다면 개별 커맨드를 순서대로 사용하세요.
