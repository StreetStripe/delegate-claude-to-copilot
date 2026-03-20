# delegate-claude-to-copilot

license

Use GitHub Copilot as Claude Code's coding delegate through a small MCP bridge.

This repo gives you:

- a local Claude Code MCP bridge that forwards tasks to the GitHub Copilot CLI
- a reusable `/copilot` Claude skill
- an optional default policy that tells Claude Code to delegate coding tasks to Copilot first

## Highlights

- Simple local setup
- No cloud service in the middle beyond the tools you already use
- Works with the existing Claude Code MCP flow
- Safe to adopt incrementally: install only the bridge, or also enable default delegation

## What this does

This repository does **not** replace Claude Code's underlying model.

Instead, it wires Claude Code to GitHub Copilot through an MCP server named `copilot-bridge`. Claude can then call Copilot as a tool for coding tasks.

If you also install the included personal skill and user instructions, Claude Code will prefer Copilot for code changes, debugging, refactoring, tests, and implementation-oriented shell work.

## Quick start

### 1. Make sure the required tools are installed

```bash
claude --version
copilot --version
node --version
npm --version
```

### 2. Authenticate GitHub Copilot

```bash
copilot login
```

### 3. Install the bridge and `/copilot` skill

#### Option A: you can use the /copilot skill on demand

```bash
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash
```

#### Option B: you make Copilot the default coding delegate

```bash
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash -s -- --default
```

If you already have a `~/.claude/CLAUDE.md`, the installer will prepend the necessary instructions to your existing file.

### 4. Verify the setup

```bash
claude mcp list
claude -p "/copilot Reply with exactly OK"
```

Expected output should include:

```text
copilot-bridge: node /Users/.../.claude/copilot-mcp/index.js - ✓ Connected
OK
```

## What gets installed

The installer script (`install.sh`) places these files into your home directory:

- `~/.claude/copilot-mcp/package.json`
- `~/.claude/copilot-mcp/index.js`
- `~/.claude/skills/copilot/SKILL.md`

It also registers this Claude Code MCP server:

- `copilot-bridge`

Running `./install.sh --default` additionally installs or updates:

- `~/.claude/CLAUDE.md` (prepended if it already exists)

## Manual setup

If you want the complete copy-pasteable setup process instead of the installer, see:

`[HOW-TO-INSTALL-MANUALLY.md](HOW-TO-INSTALL-MANUALLY.md)`

## How the default delegation works

The default behavior is implemented with two Claude-side pieces:

- a personal skill at `~/.claude/skills/copilot/SKILL.md`
- a personal instruction file at `~/.claude/CLAUDE.md`

That means:

- you can still use Claude directly for non-coding tasks
- you can tell Claude not to use Copilot for a specific session or task
- you can remove the default behavior without uninstalling the bridge itself

## Troubleshooting

### Claude cannot see `copilot-bridge`

Run:

```bash
claude mcp list
```

If the bridge is missing, rerun:

```bash
./install.sh
```

### Copilot is installed but fails to answer

Re-authenticate:

```bash
copilot login
```

Then test again:

```bash
copilot -p "Reply with exactly OK" --allow-all-tools --allow-all-paths -s
```

### Default delegation is not happening

Check:

- `~/.claude/skills/copilot/SKILL.md`
- `~/.claude/CLAUDE.md`

And verify with:

```bash
claude -p "/copilot Reply with exactly OK"
```

## License

MIT. See `[LICENSE](LICENSE)`.