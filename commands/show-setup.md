---
description: 현재 Claude Forge 설치 상태와 프로젝트 정보를 보여줍니다.
argument-hint: ""
allowed-tools: ["Bash", "Read", "Glob"]
---

# /show-setup

현재 Claude Forge 설치 상태와 프로젝트 정보를 종합적으로 보여줍니다.

## Instructions

### 1. Claude Forge 설치 현황

1. Count agents in ~/.claude/agents/
2. Count commands in ~/.claude/commands/
3. Count skills in ~/.claude/skills/
4. Count hooks in ~/.claude/hooks/
5. Count rules in ~/.claude/rules/

### 2. 현재 프로젝트 상태 (프로젝트 폴더에서 실행 시)

1. 프로젝트 타입 감지 (package.json / go.mod / Cargo.toml / pyproject.toml)
2. Git 상태 (브랜치, 마지막 커밋, 변경 파일 수)
3. CLAUDE.md 존재 여부
4. 테스트 설정 존재 여부

### 3. 추천 다음 작업

현재 프로젝트 상태에 따라 가장 적합한 다음 커맨드를 추천합니다:

- 변경 파일이 있으면 -> `/handoff-verify`
- CLAUDE.md가 없으면 -> `/init-project`
- 테스트가 없으면 -> `/tdd`
- 모두 정상이면 -> `/plan [다음 기능]`

## Output Format

```
My Claude Forge Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agents:   XX
Commands: XX
Skills:   XX
Hooks:    XX
Rules:    XX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

현재 프로젝트: [프로젝트명]
  타입: [Node.js / Go / Python / ...]
  브랜치: [main]
  마지막 커밋: [커밋 메시지]
  변경 파일: [N]개

추천 다음 작업: [커맨드]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
github.com/sangrokjung/claude-forge
```

## Clipboard

After displaying the summary, copy the text to the system clipboard:
- macOS: `pbcopy`
- Linux/WSL: `xclip -selection clipboard` or `xsel --clipboard`

Tell the user the summary has been copied to clipboard and is ready to share on X/Twitter or other social platforms.
