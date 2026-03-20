#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MODE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --default)
      DEFAULT_MODE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--default] [--dry-run]

Options:
  --default  Also install the user-level CLAUDE.md instructions that make Copilot
             the default coding delegate. If ~/.claude/CLAUDE.md already exists,
             an example file will be written instead of overwriting it.
  --dry-run  Show what would be done without modifying files.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BRIDGE_DIR="$CLAUDE_HOME/copilot-mcp"
SKILL_DIR="$CLAUDE_HOME/skills/copilot"
USER_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
EXAMPLE_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.copilot-example.md"
BACKUP_DIR="$CLAUDE_HOME/backups/copilot-bridge-setup/$(date +%Y%m%d-%H%M%S)"

say() {
  printf '%s\n' "$1"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

backup_file() {
  local target="$1"
  [ -f "$target" ] || return 0

  local relative_target
  if [[ "$target" == "$HOME/"* ]]; then
    relative_target="${target#"$HOME"/}"
  else
    relative_target="${target#/}"
  fi
  local backup_target="$BACKUP_DIR/$relative_target"
  run mkdir -p "$(dirname "$backup_target")"
  run cp "$target" "$backup_target"
}

install_file() {
  local source="$1"
  local target="$2"

  run mkdir -p "$(dirname "$target")"
  backup_file "$target"
  run cp "$source" "$target"
}

register_bridge() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] claude mcp remove copilot-bridge"
    say "[dry-run] claude mcp add --scope user copilot-bridge -- node $BRIDGE_DIR/index.js"
    return
  fi

  claude mcp remove copilot-bridge >/dev/null 2>&1 || true
  claude mcp add --scope user copilot-bridge -- node "$BRIDGE_DIR/index.js"
}

install_default_policy() {
  if [ -f "$USER_CLAUDE_MD" ]; then
    say "Found existing $USER_CLAUDE_MD"
    say "Writing example policy to $EXAMPLE_CLAUDE_MD instead of overwriting your file."
    install_file "$TEMPLATES_DIR/CLAUDE.md" "$EXAMPLE_CLAUDE_MD"
  else
    install_file "$TEMPLATES_DIR/CLAUDE.md" "$USER_CLAUDE_MD"
  fi
}

require_command claude
require_command copilot
require_command node
require_command npm

say "Installing Claude Code -> Copilot bridge files..."
install_file "$TEMPLATES_DIR/bridge/package.json" "$BRIDGE_DIR/package.json"
install_file "$TEMPLATES_DIR/bridge/index.js" "$BRIDGE_DIR/index.js"
install_file "$TEMPLATES_DIR/skills/copilot/SKILL.md" "$SKILL_DIR/SKILL.md"

say "Installing bridge dependencies..."
if [ "$DRY_RUN" -eq 1 ]; then
  say "[dry-run] npm install --prefix $BRIDGE_DIR"
else
  npm install --prefix "$BRIDGE_DIR"
fi

say "Registering copilot-bridge in Claude Code..."
register_bridge

if [ "$DEFAULT_MODE" -eq 1 ]; then
  say "Installing default delegation policy..."
  install_default_policy
fi

say ""
say "Done."
say ""
say "Next steps:"
say "1. Run: copilot login"
say "2. Verify: claude mcp list"
say "3. Test: claude -p \"/copilot Reply with exactly OK\""

if [ "$DEFAULT_MODE" -eq 1 ]; then
  say "4. If you already had ~/.claude/CLAUDE.md, manually merge ~/.claude/CLAUDE.copilot-example.md"
fi
