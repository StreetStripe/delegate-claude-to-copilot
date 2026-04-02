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

This registers the bridge as `npx @streetstripe/copilot-mcp-bridge` — npm fetches the package on demand so there are no local source files to maintain.

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
copilot -p "Reply with exactly OK" --allow-all-tools --allow-all-paths -s
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

## 📄 License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**Contributions are very welcome!** 🎉

Whether it's a bug fix, a feature idea, docs improvement, or just a question — open an issue or submit a PR.<br>
Let's make Claude + Copilot better together.

</div>