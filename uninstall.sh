#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cat << 'BANNER'

   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐
   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤
   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘

   Uninstaller

BANNER

echo -e "${YELLOW}This will remove all Claude Forge symlinks from $CLAUDE_DIR${NC}"
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

REMOVED=0
SKIPPED=0

remove_item() {
    local path="$1"
    local label="$2"

    if [ -L "$path" ]; then
        local target
        target="$(readlink "$path")"
        # Only remove symlinks pointing into this repo
        if [[ "$target" == "$REPO_DIR"* ]]; then
            rm "$path"
            echo -e "  ${GREEN}✓${NC} Removed: $label"
            REMOVED=$((REMOVED + 1))
        else
            echo -e "  ${YELLOW}↷${NC} Skipped (points elsewhere): $label"
            SKIPPED=$((SKIPPED + 1))
        fi
    elif [ -e "$path" ]; then
        echo -e "  ${YELLOW}↷${NC} Skipped (real file/dir, not a symlink): $label"
        SKIPPED=$((SKIPPED + 1))
    fi
}

echo ""
echo "Removing symlinks..."

for item in agents rules commands scripts skills hooks cc-chips cc-chips-custom; do
    remove_item "$CLAUDE_DIR/$item" "$item/"
done

remove_item "$CLAUDE_DIR/settings.json" "settings.json"

# Remove forge metadata
if [ -f "$CLAUDE_DIR/.forge-meta.json" ]; then
    rm "$CLAUDE_DIR/.forge-meta.json"
    echo -e "  ${GREEN}✓${NC} Removed: .forge-meta.json"
    REMOVED=$((REMOVED + 1))
fi

echo ""
echo "──────────────────────────────────────────"
echo -e "  Removed ${GREEN}$REMOVED${NC} · Skipped ${YELLOW}$SKIPPED${NC}"
echo ""

# Remove shell aliases
remove_aliases() {
    local shell_rc=""
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -z "$shell_rc" ]; then
        return 0
    fi

    local marker="# Claude Code aliases"
    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        # Remove the alias block (marker line + next 2 lines)
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "/$marker/,+2d" "$shell_rc"
        else
            sed -i "/$marker/,+2d" "$shell_rc"
        fi
        echo -e "  ${GREEN}✓${NC} Removed aliases from $(basename "$shell_rc")"
    fi
}

read -p "Remove shell aliases (cc, ccr) from shell config? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    remove_aliases
fi

# Remove Discord setup
remove_discord() {
    local discord_dir="$HOME/.claude/channels/discord"
    local discord_env="$discord_dir/.env"
    local discord_alias="alias claude-discord="
    local discord_comment="# claude-kit: Discord bot 채널로 Claude Code 실행"

    if [ -f "$discord_env" ] || [ -d "$discord_dir" ]; then
        read -p "Remove Discord bot config (~/.claude/channels/discord/)? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$discord_dir"
            echo -e "  ${GREEN}✓${NC} Removed: ~/.claude/channels/discord/"
        fi
    fi

    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [ -f "$rc" ] || continue
        if grep -qF "$discord_alias" "$rc" 2>/dev/null; then
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "/$discord_comment/d; /$discord_alias/d" "$rc"
            else
                sed -i "/$discord_comment/d; /$discord_alias/d" "$rc"
            fi
            echo -e "  ${GREEN}✓${NC} Removed discord alias from $(basename "$rc")"
        fi
    done
}

remove_discord

echo ""
echo -e "${GREEN}Claude Forge uninstalled.${NC}"
echo "Your ~/.claude directory is intact — only forge symlinks were removed."
