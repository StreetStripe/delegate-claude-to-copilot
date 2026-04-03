#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MODE=0
DRY_RUN=0
NPX_MODE=0

for arg in "$@"; do
  case "$arg" in
    --default)
      DEFAULT_MODE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --npx)
      NPX_MODE=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--default] [--npx] [--dry-run]

Options:
  --default  Also install the user-level CLAUDE.md instructions that make Copilot
             the default coding delegate. If ~/.claude/CLAUDE.md already exists,
             the instructions will be prepended to it.
  --npx      Use the published npm package (@streetstripe/copilot-mcp-bridge)
             instead of copying the bridge source locally.
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

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BRIDGE_DIR="$CLAUDE_HOME/copilot-mcp"
SKILL_DIR="$CLAUDE_HOME/skills/copilot"
USER_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
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

write_file() {
  local target="$1"
  local content="$2"

  run mkdir -p "$(dirname "$target")"
  backup_file "$target"
  
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] Writing to $target"
  else
    printf '%s\n' "$content" > "$target"
  fi
}

prepend_file() {
  local target="$1"
  local content="$2"

  if [ ! -f "$target" ]; then
    write_file "$target" "$content"
    return
  fi

  backup_file "$target"
  
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] Prepending to $target"
  else
    local temp_file
    temp_file=$(mktemp)
    printf '%s\n\n%s\n' "$content" "$(cat "$target")" > "$temp_file"
    mv "$temp_file" "$target"
  fi
}

register_bridge() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] claude mcp remove copilot-bridge"
    if [ "$NPX_MODE" -eq 1 ]; then
      say "[dry-run] claude mcp add --scope user copilot-bridge -- npx --yes @streetstripe/copilot-mcp-bridge"
    else
      say "[dry-run] claude mcp add --scope user copilot-bridge -- node $BRIDGE_DIR/index.js"
    fi
    return
  fi

  claude mcp remove copilot-bridge >/dev/null 2>&1 || true
  if [ "$NPX_MODE" -eq 1 ]; then
    claude mcp add --scope user copilot-bridge -- npx --yes @streetstripe/copilot-mcp-bridge
  else
    claude mcp add --scope user copilot-bridge -- node "$BRIDGE_DIR/index.js"
  fi
}

# --- Content Definitions ---

read -r -d '' CONTENT_PACKAGE_JSON <<'EOF'
{
  "name": "copilot-mcp-bridge",
  "version": "1.0.0",
  "type": "module",
  "main": "index.js",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
EOF

read -r -d '' CONTENT_INDEX_JS <<'EOF'
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { spawn } from "child_process";
import { existsSync } from "fs";

const server = new Server(
  { name: "copilot-bridge", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const MAX_OUTPUT_CHARS = 80_000;

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "delegate_to_copilot",
      description:
        "Delegate a coding task to GitHub Copilot CLI. Use this to outsource code generation, bug fixes, refactoring, shell commands, or any task where a second AI agent opinion is useful. Copilot can read/write files and run shell commands in the given directory.",
      inputSchema: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description: "The task or question to send to Copilot",
          },
          working_directory: {
            type: "string",
            description:
              "Absolute path of the directory Copilot should work in. Defaults to the current working directory of the MCP server.",
          },
        },
        required: ["prompt"],
      },
      annotations: {
        title: "Delegate to Copilot",
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: true,
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "delegate_to_copilot") {
    throw new Error(`Unknown tool: ${request.params.name}`);
  }

  const { prompt, working_directory } = request.params.arguments;
  const cwd =
    working_directory && existsSync(working_directory)
      ? working_directory
      : process.cwd();

  return new Promise((resolve) => {
    const args = [
      "-p", prompt,
      "--allow-all-tools",
      "--allow-all-paths",
      "--add-dir", cwd,
    ];

    const child = spawn("copilot", args, {
      cwd,
      env: process.env,
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (data) => (stdout += data.toString()));
    child.stderr.on("data", (data) => (stderr += data.toString()));

    child.on("close", (code) => {
      let output = stdout
        .replace(/\nTotal usage est:[\s\S]*$/, "")
        .trim();

      if (output.length > MAX_OUTPUT_CHARS) {
        const half = Math.floor(MAX_OUTPUT_CHARS / 2);
        output =
          output.slice(0, half) +
          `\n\n[… truncated ${output.length - MAX_OUTPUT_CHARS} characters …]\n\n` +
          output.slice(-half);
      }

      resolve({
        content: [
          {
            type: "text",
            text: output || stderr || `Copilot exited with code ${code}`,
          },
        ],
      });
    });

    child.on("error", (err) => {
      resolve({
        content: [{ type: "text", text: `Failed to start Copilot: ${err.message}` }],
      });
    });
  });
});

const transport = new StdioServerTransport();
await server.connect(transport);
EOF

read -r -d '' CONTENT_SKILL_MD <<'EOF'
---
name: copilot
description: Default executor for coding tasks. Delegate code changes, debugging, refactoring, test work, and repository shell tasks to GitHub Copilot through the configured copilot-bridge MCP server.
argument-hint: <task>
allowed-tools: mcp__copilot-bridge__delegate_to_copilot
---

Use this skill as the default path for coding work.

Take the provided task text and call `mcp__copilot-bridge__delegate_to_copilot` exactly once.

Guidelines:
- Pass the full user request as the `prompt`.
- Set `working_directory` to the current project directory when available.
- Do not rewrite the task unless a tiny clarification is needed for accuracy.
- Return Copilot's result directly, with only minimal framing if needed.
- Use this automatically for coding tasks unless the user explicitly asks to stay in Claude, the request is clearly non-coding, or the bridge is unavailable.
EOF

read -r -d '' CONTENT_CLAUDE_MD <<'EOF'
For coding tasks, default to delegating the work to GitHub Copilot via the personal `copilot` skill.

Treat the following as coding tasks:
- writing or editing code
- debugging build, test, lint, or runtime failures
- refactoring
- generating tests
- running repository shell commands in service of implementation

Behavior:
- Invoke the `copilot` skill first for coding tasks, even if the user does not explicitly mention Copilot.
- Use Claude directly for non-coding tasks such as explanation, planning, summarization, and configuration questions that do not require repository implementation.
- If the user explicitly asks not to use Copilot, follow that instruction.
- If Copilot delegation fails or is unavailable, state that clearly and then continue in Claude if appropriate.
EOF

# --- Main Execution ---

require_command claude
require_command copilot
require_command node
if [ "$NPX_MODE" -eq 1 ]; then
  require_command npx
else
  require_command npm
fi

say "Installing Claude Code -> Copilot bridge files..."
if [ "$NPX_MODE" -eq 1 ]; then
  say "Using published npm package — skipping local bridge file copy."
else
  write_file "$BRIDGE_DIR/package.json" "$CONTENT_PACKAGE_JSON"
  write_file "$BRIDGE_DIR/index.js" "$CONTENT_INDEX_JS"
fi
write_file "$SKILL_DIR/SKILL.md" "$CONTENT_SKILL_MD"

if [ "$NPX_MODE" -eq 1 ]; then
  say "Skipping local npm install (npx will fetch the package on demand)."
else
  say "Installing bridge dependencies..."
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] npm install --prefix $BRIDGE_DIR"
  else
    npm install --prefix "$BRIDGE_DIR"
  fi
fi

say "Registering copilot-bridge in Claude Code..."
register_bridge

if [ "$DEFAULT_MODE" -eq 1 ]; then
  say "Installing default delegation policy..."
  if [ -f "$USER_CLAUDE_MD" ]; then
    say "Found existing $USER_CLAUDE_MD"
    say "Prepending policy to existing file..."
    prepend_file "$USER_CLAUDE_MD" "$CONTENT_CLAUDE_MD"
  else
    write_file "$USER_CLAUDE_MD" "$CONTENT_CLAUDE_MD"
  fi
fi

say ""
say "Done."
say ""
say "Next steps:"
say "1. Run: copilot login"
say "2. Verify: claude mcp list"
say "3. Test: claude -p \"/copilot Reply with exactly OK\""
