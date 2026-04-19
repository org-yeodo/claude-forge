#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# 플랫폼 감지
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
        ARCH="$(uname -m)"
    elif grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        PLATFORM="wsl"
        ARCH="$(uname -m)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
        ARCH="$(uname -m)"
    else
        PLATFORM="unknown"
        ARCH="$(uname -m)"
    fi
}

detect_platform

cat << 'BANNER'

   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐
   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤
   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘

   Production-grade Claude Code Framework
   github.com/sangrokjung/claude-forge

BANNER
echo "플랫폼: $PLATFORM ($ARCH)"
echo ""

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 의존성 확인
check_deps() {
    echo "의존성 확인 중..."
    local missing=()

    command -v node >/dev/null || missing+=("node")
    command -v jq >/dev/null || missing+=("jq")
    command -v git >/dev/null || missing+=("git")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}누락된 의존성: ${missing[*]}${NC}"
        echo ""
        case "$PLATFORM" in
            macos)
                echo "설치 방법: brew install ${missing[*]}"
                ;;
            wsl|linux)
                echo "설치 방법: sudo apt install ${missing[*]}"
                echo "  또는: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
                ;;
            *)
                echo "패키지 매니저로 설치하세요"
                ;;
        esac
        echo ""
        echo -e "${YELLOW}도움이 필요하신가요? github.com/sangrokjung/claude-forge/issues${NC}"
        exit 1
    fi

    echo -e "${GREEN}모든 의존성 확인 완료${NC}"
}

# 2. git 서브모듈 초기화 (cc-chips)
init_submodules() {
    echo ""
    echo "git 서브모듈 초기화 중..."

    cd "$REPO_DIR"
    git submodule update --init --recursive 2>/dev/null && \
        echo -e "${GREEN}서브모듈 초기화 완료 (cc-chips)${NC}" || \
        echo -e "${YELLOW}서브모듈 초기화 건너뜀 (이미 초기화되었을 수 있음)${NC}"
}

# 3. 기존 설정 백업
backup() {
    if [ -d "$CLAUDE_DIR" ]; then
        local backup_dir="$CLAUDE_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        echo ""
        echo -e "${YELLOW}기존 ~/.claude 폴더가 발견되었습니다${NC}"
        read -p "$backup_dir 에 백업하시겠습니까? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mv "$CLAUDE_DIR" "$backup_dir"
            echo -e "${GREEN}$backup_dir 에 백업 완료${NC}"
        else
            echo "백업 건너뜀. 기존 파일이 덮어쓰여질 수 있습니다."
        fi
    fi
}

# 4. 심볼릭 링크 생성 (WSL 크로스 파일시스템은 복사 사용)
link_files() {
    echo ""

    local use_copy=false
    if [[ "$PLATFORM" == "wsl" ]] && [[ "$REPO_DIR" == /mnt/* ]]; then
        echo -e "${YELLOW}WSL에서 Windows 파일시스템 경로 감지. 심볼릭 링크 대신 복사를 사용합니다.${NC}"
        echo "  팁: 심볼릭 링크를 사용하려면 저장소를 ~/claude-forge 로 이동하세요."
        use_copy=true
    fi

    if [ "$use_copy" = true ]; then
        echo "설정 파일 복사 중..."
    else
        echo "심볼릭 링크 생성 중..."
    fi

    mkdir -p "$CLAUDE_DIR"

    # 디렉토리
    for dir in agents rules commands scripts skills hooks cc-chips cc-chips-custom; do
        if [ -d "$REPO_DIR/$dir" ]; then
            rm -rf "$CLAUDE_DIR/$dir" 2>/dev/null || true
            if [ "$use_copy" = true ]; then
                cp -r "$REPO_DIR/$dir" "$CLAUDE_DIR/$dir"
                echo "  복사: $dir/"
            else
                ln -sf "$REPO_DIR/$dir" "$CLAUDE_DIR/$dir"
                echo "  링크: $dir/"
            fi
        fi
    done

    # 파일
    for file in settings.json; do
        if [ -f "$REPO_DIR/$file" ]; then
            rm -f "$CLAUDE_DIR/$file" 2>/dev/null || true
            if [ "$use_copy" = true ]; then
                cp "$REPO_DIR/$file" "$CLAUDE_DIR/$file"
                echo "  복사: $file"
            else
                ln -sf "$REPO_DIR/$file" "$CLAUDE_DIR/$file"
                echo "  링크: $file"
            fi
        fi
    done
}

# 5. CC CHIPS 커스텀 오버레이 적용
apply_cc_chips_custom() {
    local custom_dir="$REPO_DIR/cc-chips-custom"
    if [ -d "$custom_dir" ]; then
        echo ""
        echo "CC CHIPS 커스텀 오버레이 적용 중..."
        local target="$CLAUDE_DIR/cc-chips"

        if [ -f "$custom_dir/engine.sh" ] && [ -d "$target" ]; then
            cp "$custom_dir/engine.sh" "$target/engine.sh"
            chmod +x "$target/engine.sh"
            echo -e "  ${GREEN}✓${NC} engine.sh (모델 감지 + 세션 ID + 캐시 통계)"
        fi

        if [ -d "$custom_dir/themes" ] && [ -d "$target/themes" ]; then
            cp "$custom_dir/themes/"*.sh "$target/themes/" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} themes/ (통계 칩 색상)"
        fi

        echo -e "${GREEN}CC CHIPS 커스텀 오버레이 적용 완료!${NC}"
    fi
}

# 6. MCP 서버 설치
install_mcp_servers() {
    echo ""
    echo "MCP 서버 설치 중..."

    if ! command -v claude >/dev/null; then
        echo -e "${YELLOW}Claude CLI를 찾을 수 없습니다. MCP 서버 설치를 건너뜁니다.${NC}"
        echo "Claude CLI를 먼저 설치한 후 이 스크립트를 다시 실행하세요."
        return 0
    fi

    read -p "권장 MCP 서버를 설치하시겠습니까? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "MCP 서버 설치를 건너뜁니다."
        return 0
    fi

    local mcp_json="$REPO_DIR/mcp-servers.json"
    if [ -f "$mcp_json" ] && command -v jq >/dev/null; then
        echo "  mcp-servers.json 에서 설치 중..."

        # 핵심 서버 (API 키 불필요)
        local core_servers=("context7" "sequential-thinking" "memory" "youtube-transcript" "remotion" "playwright" "desktop-commander")
        for server in "${core_servers[@]}"; do
            local cmd
            cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
            if [ -n "$cmd" ]; then
                echo "  $server 설치 중..."
                eval "$cmd" 2>/dev/null && \
                    echo -e "  ${GREEN}✓${NC} $server" || \
                    echo -e "  ${YELLOW}!${NC} $server (이미 설치됨 또는 실패)"
            fi
        done

        # 선택 서버
        echo ""
        echo -e "${YELLOW}선택 서버 (인증이 필요할 수 있음):${NC}"

        local optional_servers=("exa" "gmail" "google-calendar" "n8n-mcp" "hyperbrowser" "stitch" "sentry" "supabase" "github")
        for server in "${optional_servers[@]}"; do
            local cmd
            cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
            if [ -n "$cmd" ]; then
                read -p "  $server 설치하시겠습니까? (y/n) " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (이미 설치됨 또는 실패)"
                fi
            fi
        done

        # 한국 공공데이터 서버
        echo ""
        read -p "  한국 공공데이터 서버 설치하시겠습니까? (국세청, 국민연금, 공무원연금, 금융위, 기상청) (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for server in "data-go-nts" "data-go-nps" "data-go-pps" "data-go-fsc" "data-go-msds"; do
                local cmd
                cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
                if [ -n "$cmd" ]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (이미 설치됨 또는 실패)"
                fi
            done
        fi

        # 금융 데이터 서버
        echo ""
        read -p "  금융 데이터 서버 설치하시겠습니까? (CoinGecko, Alpha Vantage, FRED, 한국주식) (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for server in "coingecko" "alpha-vantage" "fred" "korea-stock"; do
                local cmd
                cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
                if [ -n "$cmd" ]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (이미 설치됨 또는 실패)"
                fi
            done
        fi
    else
        # mcp-servers.json 없을 때 최소 설치
        echo "  핵심 MCP 서버 설치 중..."

        claude mcp add context7 -- npx -y @upstash/context7-mcp 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} context7" || echo -e "  ${YELLOW}!${NC} context7"

        claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} playwright" || echo -e "  ${YELLOW}!${NC} playwright"

        claude mcp add memory -- npx -y @modelcontextprotocol/server-memory 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} memory" || echo -e "  ${YELLOW}!${NC} memory"

        claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} sequential-thinking" || echo -e "  ${YELLOW}!${NC} sequential-thinking"
    fi

    echo ""
    echo -e "${GREEN}MCP 서버 설치 완료!${NC}"
    echo "'claude mcp list' 명령어로 설치된 서버를 확인하세요."
}

# 7. 외부 스킬 설치 (npx skills)
install_external_skills() {
    echo ""
    echo "외부 스킬 설치 중..."

    if ! command -v npx >/dev/null; then
        echo -e "${YELLOW}npx를 찾을 수 없습니다. 외부 스킬 설치를 건너뜁니다.${NC}"
        return 0
    fi

    read -p "외부 스킬을 설치하시겠습니까? (Superpowers, Humanizer, UI/UX Pro Max, Find Skills) (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "외부 스킬 설치를 건너뜁니다."
        return 0
    fi

    echo "  Superpowers 설치 중 (스킬 14개)..."
    npx -y skills add obra/superpowers -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} superpowers" || echo -e "  ${YELLOW}!${NC} superpowers (실패)"

    echo "  Humanizer 설치 중..."
    npx -y skills add blader/humanizer -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} humanizer" || echo -e "  ${YELLOW}!${NC} humanizer (실패)"

    echo "  UI/UX Pro Max 설치 중..."
    npx -y skills add nextlevelbuilder/ui-ux-pro-max-skill -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} ui-ux-pro-max" || echo -e "  ${YELLOW}!${NC} ui-ux-pro-max (실패)"

    echo "  Find Skills 설치 중..."
    npx -y skills add vercel-labs/skills -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} find-skills" || echo -e "  ${YELLOW}!${NC} find-skills (실패)"

    echo ""
    echo -e "${GREEN}외부 스킬 설치 완료!${NC}"
}

# 8. 쉘 alias 설정
setup_shell_aliases() {
    echo ""
    echo "쉘 alias 설정 중..."

    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -z "$shell_rc" ]; then
        echo -e "${YELLOW}.zshrc 또는 .bashrc를 찾을 수 없습니다. alias 설정을 건너뜁니다.${NC}"
        return 0
    fi

    local marker="# Claude Code aliases"
    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $(basename "$shell_rc") 에 alias가 이미 설정되어 있습니다"
        return 0
    fi

    cat >> "$shell_rc" << 'ALIASES'

# Claude Code aliases
alias cc='claude'
alias ccr='claude --resume'
ALIASES

    echo -e "  ${GREEN}✓${NC} $(basename "$shell_rc") 에 alias 추가 완료"
    echo "    cc  → claude"
    echo "    ccr → claude --resume"
}

# 9. 설치 검증
verify() {
    echo ""
    echo "설치 검증 중..."

    local errors=0

    for item in agents rules commands scripts skills cc-chips cc-chips-custom hooks settings.json; do
        if [ -L "$CLAUDE_DIR/$item" ] && [ ! -e "$CLAUDE_DIR/$item" ]; then
            echo -e "  ${RED}✗${NC} $item (손상된 심볼릭 링크)"
            errors=$((errors + 1))
        elif [ -L "$CLAUDE_DIR/$item" ] || [ -e "$CLAUDE_DIR/$item" ]; then
            echo -e "  ${GREEN}✓${NC} $item"
        else
            echo -e "  ${RED}✗${NC} $item (찾을 수 없음)"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

# 10. forge 메타데이터 기록
write_meta() {
    echo ""
    echo "forge 메타데이터 기록 중..."

    local install_mode="symlink"
    if [ ! -L "$CLAUDE_DIR/agents" ] && [ -d "$CLAUDE_DIR/agents" ]; then
        install_mode="copy"
    fi

    local version="1.0.0"
    if [ -f "$REPO_DIR/.claude-plugin/plugin.json" ] && command -v jq >/dev/null; then
        version=$(jq -r '.version // "1.0.0"' "$REPO_DIR/.claude-plugin/plugin.json")
    fi

    local git_commit=""
    local remote_url=""
    if command -v git >/dev/null && [ -d "$REPO_DIR/.git" ]; then
        git_commit=$(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "")
        remote_url=$(cd "$REPO_DIR" && git remote get-url origin 2>/dev/null || echo "")
    fi

    local now
    now=$(date +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

    local installed_at="$now"
    if [ -f "$CLAUDE_DIR/.forge-meta.json" ] && command -v jq >/dev/null; then
        local prev_installed
        prev_installed=$(jq -r '.installed_at // ""' "$CLAUDE_DIR/.forge-meta.json")
        if [ -n "$prev_installed" ] && [ "$prev_installed" != "null" ]; then
            installed_at="$prev_installed"
        fi
    fi

    jq -n \
      --arg repo_path "$REPO_DIR" \
      --arg install_mode "$install_mode" \
      --arg installed_at "$installed_at" \
      --arg updated_at "$now" \
      --arg version "$version" \
      --arg git_commit "$git_commit" \
      --arg remote_url "$remote_url" \
      --arg platform "$PLATFORM" \
      '{
        repo_path: $repo_path,
        install_mode: $install_mode,
        installed_at: $installed_at,
        updated_at: $updated_at,
        version: $version,
        git_commit: $git_commit,
        remote_url: $remote_url,
        platform: $platform
      }' > "$CLAUDE_DIR/.forge-meta.json"

    chmod 600 "$CLAUDE_DIR/.forge-meta.json"
    echo -e "  ${GREEN}✓${NC} .forge-meta.json"
}

# 11. Discord 봇 설정
install_discord() {
    local discord_script="$REPO_DIR/setup/discord.sh"
    if [ -f "$discord_script" ]; then
        echo ""
        read -p "Discord 봇 연결을 지금 설정하시겠습니까? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$discord_script"
        else
            echo "나중에 ./setup/discord.sh 로 실행할 수 있습니다."
        fi
    fi
}

# 12. Work Tracker 설치 (Supabase 연동)
install_work_tracker() {
    local wt_script="$REPO_DIR/setup/work-tracker-install.sh"
    if [ -f "$wt_script" ]; then
        echo ""
        read -p "Work Tracker를 설치하시겠습니까? (Claude Code 사용량 추적 → Supabase) (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            REPO_DIR="$REPO_DIR" bash "$wt_script"
        else
            echo "Work Tracker 설치를 건너뜁니다."
        fi
    fi
}

# 메인
main() {
    check_deps
    init_submodules
    backup
    link_files
    apply_cc_chips_custom

    if verify; then
        echo ""
        echo -e "${GREEN}심볼릭 링크 생성 완료!${NC}"

        # forge 메타데이터 기록
        write_meta

        # 쉘 alias 설정
        setup_shell_aliases

        # MCP 서버 설치
        install_mcp_servers

        # 외부 스킬 설치
        install_external_skills

        # Work Tracker 설치
        install_work_tracker

        # Discord 봇 설정
        install_discord

        echo ""
        cat << COMPLETE

  ${GREEN}╔══════════════════════════════════════════════════════╗
  ║           Claude Forge 설치 완료!                    ║
  ╠══════════════════════════════════════════════════════╣
  ║  11 agents · 36+ commands · 6-layer security        ║
  ╚══════════════════════════════════════════════════════╝${NC}

  처음이신가요? 이것만 하세요:
    1. 새 터미널을 열고 'claude' 실행
    2. ${GREEN}/guide${NC} 입력 — 3분 인터랙티브 가이드

  자주 쓰는 TOP 5:
    /plan           AI가 구현 계획을 세워줍니다
    /tdd            테스트 먼저 만들고 코드 작성
    /code-review    코드 보안+품질 검사
    /handoff-verify 빌드/테스트/린트 자동 검증
    /auto           계획부터 PR까지 원버튼 자동

  ${YELLOW}★ Star: github.com/sangrokjung/claude-forge${NC}
  ${YELLOW}? Issues: github.com/sangrokjung/claude-forge/issues${NC}

COMPLETE
    else
        echo ""
        echo -e "${RED}오류가 발생하여 설치가 완료되지 않았습니다${NC}"
        exit 1
    fi
}

main "$@"
