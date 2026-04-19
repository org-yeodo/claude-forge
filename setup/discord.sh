#!/bin/bash
# Discord 봇 연결 초기 설정
# 사용법: ./setup/discord.sh
# install.sh 실행 시 자동 호출되거나 단독 실행 가능

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DISCORD_ENV="$HOME/.claude/channels/discord/.env"
ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"
ALIAS_LINE="alias claude-discord='claude --channels plugin:discord@claude-plugins-official'"

echo -e "${CYAN}▶ Discord Bot 설정${NC}"

# 1. bun 설치
export PATH="$HOME/.bun/bin:$PATH"
if command -v bun &>/dev/null; then
  echo -e "  ${GREEN}↩${NC}  bun 이미 설치됨 ($(bun --version))"
else
  read -rp "  bun이 없습니다. 지금 설치하시겠습니까? [Y/n] " yn
  if [[ ! "$yn" =~ ^[Nn]$ ]]; then
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    echo -e "  ${GREEN}✓${NC}  bun 설치 완료"
  else
    echo -e "  ${YELLOW}⚠${NC}  bun 없이는 Discord 봇이 실행되지 않습니다."
  fi
fi

# 2. 봇 토큰 저장
if [ -f "$DISCORD_ENV" ] && grep -q "DISCORD_BOT_TOKEN=" "$DISCORD_ENV"; then
  echo -e "  ${GREEN}↩${NC}  Discord 봇 토큰 이미 설정됨"
else
  echo ""
  echo "  Discord Developer Portal → Bot → Reset Token 에서 토큰을 복사하세요."
  read -rp "  봇 토큰 입력 (건너뛰려면 엔터): " token
  if [ -n "$token" ]; then
    mkdir -p "$HOME/.claude/channels/discord"
    echo "DISCORD_BOT_TOKEN=$token" > "$DISCORD_ENV"
    chmod 600 "$DISCORD_ENV"
    echo -e "  ${GREEN}✓${NC}  토큰 저장 완료 (~/.claude/channels/discord/.env)"
  else
    echo -e "  ${YELLOW}↩${NC}  토큰 설정 건너뜀 — 나중에 /discord:configure <token> 으로 설정 가능"
  fi
fi

# 3. alias 추가
add_alias() {
  local rc="$1"
  [ -f "$rc" ] || return
  if grep -qF "$ALIAS_LINE" "$rc"; then
    echo -e "  ${GREEN}↩${NC}  alias 이미 존재 ($rc)"
  else
    echo "" >> "$rc"
    echo "# claude-kit: Discord bot 채널로 Claude Code 실행" >> "$rc"
    echo "$ALIAS_LINE" >> "$rc"
    echo -e "  ${GREEN}✓${NC}  alias 추가 ($rc) — 새 터미널에서 claude-discord 로 실행 가능"
  fi
}

[ -f "$ZSHRC" ] && add_alias "$ZSHRC"
[ -f "$BASHRC" ] && add_alias "$BASHRC"

echo ""
echo -e "  다음 단계:"
echo "  1. claude-discord  (또는 claude --channels plugin:discord@claude-plugins-official)"
echo "  2. Discord에서 봇에게 DM → 페어링 코드 수신"
echo "  3. /discord:access pair <코드>"
echo ""
