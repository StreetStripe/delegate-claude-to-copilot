<div align="center">

# 🔀 delegate-claude-to-copilot

**Free Copilot, but you *really* like working with Claude Code?<br>Bridge them.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![npm](https://img.shields.io/npm/v/@streetstripe/copilot-mcp-bridge)](https://www.npmjs.com/package/@streetstripe/copilot-mcp-bridge)
[![Claude Code](https://img.shields.io/badge/Claude_Code-MCP-blueviolet)](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
[![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-CLI-brightgreen)](https://docs.github.com/en/copilot)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin_Marketplace-ff69b4)](https://github.com/StreetStripe/delegate-claude-to-copilot)

A tiny MCP bridge that lets Claude Code delegate coding tasks to GitHub Copilot.

</div>

---

## ✨ What you get

| Component | Description |
|---|---|
| **`copilot-bridge`** | Local MCP server forwarding tasks from Claude Code → Copilot CLI |
| **`/copilot` skill** | Reusable Claude skill you invoke on demand |
| **Default policy** *(opt-in)* | Makes Claude Code prefer Copilot for all coding work automatically |

> [!NOTE]
> This does **not** replace Claude's model. It wires Claude Code to Copilot via MCP so Claude can call Copilot as a tool for code changes, debugging, refactoring, tests, and implementation-oriented shell work.

## 🔒 Data flow & privacy

When you use this bridge, your **prompt text** and **working directory** are forwarded to the locally installed GitHub Copilot CLI, which sends them to **GitHub's AI services** for processing. No data is collected, stored, or logged by this bridge itself.

Copilot runs with `--allow-all-tools` and access scoped to the validated working directory only (see **Security** below).

See [PRIVACY.md](PRIVACY.md) for the full privacy policy and links to [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## 🛡️ Security

The MCP endpoint is treated as an authorization boundary. Three defences are active by default:

| Defence | What it does |
|---|---|
| **Path allowlisting** | `working_directory` must be at or below one of the directories in `COPILOT_BRIDGE_ALLOWED_DIRS`. Requests outside that set are rejected before Copilot is invoked. |
| **Environment minimization** | Only a safe allow-list of env vars (`PATH`, `HOME`, …) plus `GITHUB_*` / `GH_*` / `COPILOT_*` auth variables are forwarded to the child process. Everything else in the MCP server's environment (other tokens, passwords, private config) is excluded. |
| **Output redaction** | Common secret patterns (GitHub PATs, `sk-…` API keys, etc.) are replaced with `[REDACTED]` in the output returned to the caller. |

### Configuring allowed directories

Set the `COPILOT_BRIDGE_ALLOWED_DIRS` environment variable to a colon-separated list of absolute paths:

```bash
# Allow two project roots (Unix — use `;` as separator on Windows)
COPILOT_BRIDGE_ALLOWED_DIRS=/home/alice/projects:/home/alice/scratch
```

If the variable is not set, the bridge defaults to the MCP server's own working directory (`process.cwd()`), which is typically the most restrictive safe default.

## 🚀 Quick start

### Prerequisites

```bash
claude --version   # Claude Code CLI
copilot --version  # GitHub Copilot CLI
node --version     # Node.js ≥ 18
npm --version
```

### Setup

```bash
# 1. Authenticate Copilot
copilot login

# 2a. Install bridge + /copilot skill (on-demand mode)
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash

# 2b. …or make Copilot the default coding delegate
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash -s -- --default
```

### Alternative: install via npm

If you prefer using the published npm package instead of local file copies:

```bash
# Install with npx-based bridge (no local source files needed)
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash -s -- --npx

# Or combine with default delegation
curl -fsSL https://raw.githubusercontent.com/StreetStripe/delegate-claude-to-copilot/main/install.sh | bash -s -- --npx --default
```

This registers the bridge as `npx --yes @streetstripe/copilot-mcp-bridge` (non-interactive) — npm fetches the package on demand so there are no local source files to maintain.

> Existing `~/.claude/CLAUDE.md`? The installer prepends — it won't clobber your config.

### Verify

```bash
claude mcp list                              # should show copilot-bridge ✓
claude -p "/copilot Reply with exactly OK"   # should return OK
```

## 📦 What gets installed

```text
~/.claude/
├── copilot-mcp/
│   ├── package.json
│   └── index.js          ← MCP server
├── skills/copilot/
│   └── SKILL.md           ← /copilot skill definition
└── CLAUDE.md              ← (--default only) delegation instructions
```

Plus a registered Claude Code MCP server entry: **`copilot-bridge`**.

## 🧩 Install as a Claude Code plugin

If you use [Claude Code plugins](https://code.claude.com/docs/en/plugins), install directly from the marketplace:

```bash
/plugin install copilot-bridge@StreetStripe/delegate-claude-to-copilot
```

Or test locally during development:

```bash
claude --plugin-dir ./path/to/delegate-claude-to-copilot
```

The plugin provides:
- **`/copilot-bridge:copilot`** skill
- **`copilot-bridge`** MCP server (via `npx copilot-mcp-bridge`)

> Requires `copilot` CLI to be installed and authenticated (`copilot login`).

## 🧩 Manual setup

Prefer copy-paste over an installer? See **[HOW-TO-INSTALL-MANUALLY.md](HOW-TO-INSTALL-MANUALLY.md)**.

## ⚙️ How default delegation works

Two Claude-side pieces drive the behavior:

- `~/.claude/skills/copilot/SKILL.md` — skill definition
- `~/.claude/CLAUDE.md` — personal instruction file

This means:

- Claude still handles non-coding tasks directly
- You can override per session or per task
- Removing `CLAUDE.md` disables auto-delegation without uninstalling the bridge

## 🏪 Claude Code Plugin Marketplace

This project is packaged for the [Claude Code Plugin Marketplace](https://code.claude.com/docs/en/plugin-marketplaces). The manifest at [`claude-plugin.json`](claude-plugin.json) describes the MCP server, its tools, installation methods, and skill metadata so the plugin can be discovered and installed directly from Claude Code.

## 🤝 Works great with ruflo

This project pairs nicely with **[ruflo](https://github.com/ruvnet/ruflo)** — an agentic software factory for ultra-fast, AI-native development. Use ruflo's orchestration layer alongside this bridge to supercharge your Claude + Copilot workflow.

## 🔧 Troubleshooting

<details>
<summary><b>Claude cannot see <code>copilot-bridge</code></b></summary>

```bash
claude mcp list        # check status
./install.sh           # reinstall if missing
```
</details>

<details>
<summary><b>Copilot is installed but fails to answer</b></summary>

```bash
copilot login          # re-authenticate
copilot -p "Reply with exactly OK" --allow-all-tools -s
```
</details>

<details>
<summary><b>Default delegation is not happening</b></summary>

Verify both files exist:

```bash
cat ~/.claude/skills/copilot/SKILL.md
cat ~/.claude/CLAUDE.md
claude -p "/copilot Reply with exactly OK"
```
</details>

## 💡 Example prompts

These examples demonstrate core functionality:

```bash
# 1. Simple verification
claude -p "/copilot Reply with exactly OK"

# 2. Code generation
claude -p "/copilot Create a Python function that reads a CSV file and returns the top 5 rows as a list of dicts"

# 3. Refactoring
claude -p "/copilot Refactor the function in src/utils.js to use async/await instead of callbacks"

# 4. Bug fix
claude -p "/copilot Fix the off-by-one error in the pagination logic in src/api.ts"

# 5. Test generation
claude -p "/copilot Write unit tests for the User model in tests/test_user.py using pytest"
```

## 🆘 Support

- **Issues & bug reports:** [GitHub Issues](https://github.com/StreetStripe/delegate-claude-to-copilot/issues)
- **Discussions & questions:** [GitHub Discussions](https://github.com/StreetStripe/delegate-claude-to-copilot/discussions)
- **Maintainer:** [@StreetStripe](https://github.com/StreetStripe)
- **Security vulnerabilities:** Please report privately via [GitHub Security Advisories](https://github.com/StreetStripe/delegate-claude-to-copilot/security/advisories)

## 📄 License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**Contributions are very welcome!** 🎉

Whether it's a bug fix, a feature idea, docs improvement, or just a question — open an issue or submit a PR.<br>
Let's make Claude + Copilot better together.

</div>