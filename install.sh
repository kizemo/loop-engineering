#!/usr/bin/env bash
# Loop Engineering · 一键安装到目标项目(Linux/macOS)
#
# Usage:
#   ./install.sh --target /path/to/project
#   ./install.sh --target /path/to/project --skip-skills
#
# 默认行为:
#   1. cp 10 个 hook 模板 → <target>/.claude/hooks/
#   2. cp 3 个 LoopX skill → ~/.codex/skills/
#   3. cp deploy-verify command → ~/.claude/commands/
#   4. 输出"已装,跑 `bash <target>/.claude/hooks/guard-rails-test.sh` 验证"

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
TARGET=""
SKIP_SKILLS=0
SKIP_COMMANDS=0

usage() {
    cat <<EOF
Usage: $0 --target <project_path> [--skip-skills] [--skip-commands]

Options:
    --target <path>      目标项目根路径(必填)
    --skip-skills        跳过 skill 安装
    --skip-commands      跳过 slash command 安装
    -h, --help           显示本帮助

Examples:
    $0 --target ~/projects/my-app
    $0 --target ~/projects/my-app --skip-skills
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="${2:-}"
            shift 2
            ;;
        --skip-skills)
            SKIP_SKILLS=1
            shift
            ;;
        --skip-commands)
            SKIP_COMMANDS=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Error: --target is required" >&2
    usage
    exit 2
fi

if [[ ! -d "$TARGET" ]]; then
    echo "Error: target directory does not exist: $TARGET" >&2
    exit 2
fi

# 1. cp hooks
echo "[1/3] Installing 10 hooks to $TARGET/.claude/hooks/"
mkdir -p "$TARGET/.claude/hooks"
cp "$SCRIPT_DIR/templates/hooks/"*.{js,py,sh,md} "$TARGET/.claude/hooks/" 2>/dev/null || \
    cp -r "$SCRIPT_DIR/templates/hooks/." "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.{sh,py,js} 2>/dev/null || true
echo "  ok"

# 2. cp skills
if [[ $SKIP_SKILLS -eq 0 ]]; then
    SKILL_DEST="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
    echo "[2/3] Installing 3 skills to $SKILL_DEST"
    mkdir -p "$SKILL_DEST"
    for skill_dir in "$SCRIPT_DIR/templates/skills/"*/; do
        skill_name="$(basename "$skill_dir")"
        mkdir -p "$SKILL_DEST/$skill_name"
        cp "$skill_dir"SKILL.md "$SKILL_DEST/$skill_name/SKILL.md" 2>/dev/null && \
            echo "  installed $skill_name" || \
            echo "  warning: $skill_name has no SKILL.md, skipped"
    done
else
    echo "[2/3] Skills skipped (--skip-skills)"
fi

# 3. cp commands
if [[ $SKIP_COMMANDS -eq 0 ]]; then
    CMD_DEST="${CLAUDE_COMMANDS_DIR:-$HOME/.claude/commands}"
    echo "[3/3] Installing deploy-verify command to $CMD_DEST"
    mkdir -p "$CMD_DEST"
    cp "$SCRIPT_DIR/templates/commands/deploy-verify.md" "$CMD_DEST/deploy-verify.md"
    echo "  ok"
else
    echo "[3/3] Commands skipped (--skip-commands)"
fi

echo ""
echo "=================================================="
echo "✓ Installation complete"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Verify hooks:"
echo "     bash $TARGET/.claude/hooks/guard-rails-test.sh"
echo ""
echo "  2. Edit $TARGET/.claude/settings.json to attach hooks to your project"
echo "     (See templates/hooks/README.md for the settings.json schema)"
echo ""
echo "  3. Initialize LoopX in the target project:"
echo "     cd $TARGET"
echo "     loopx doctor"
echo ""
echo "Docs: $SCRIPT_DIR/README.md"