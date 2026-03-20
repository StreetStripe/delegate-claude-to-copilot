# Claude Code with GitHub Copilot setup

This guide explains how to make Claude Code delegate work to GitHub Copilot through an MCP bridge.

It also includes the optional setup to make Copilot the default executor for coding tasks inside Claude Code.

## What this setup does

This setup does **not** replace Claude Code's underlying model.

Instead, it adds a Claude Code MCP server called `copilot-bridge` that forwards tasks to the GitHub Copilot CLI, then optionally adds a Claude skill and user instructions so Claude prefers Copilot for coding work.

## Prerequisites

Make sure both CLIs are installed and available in your shell:

```bash
claude --version
copilot --version
```

You should also be signed in to GitHub Copilot:

```bash
copilot login
```

## Step 1: create the Claude-side bridge directory

Create a directory for the bridge code:

```bash
mkdir -p ~/.claude/copilot-mcp
cd ~/.claude/copilot-mcp
```

Create `package.json` with the MCP SDK dependency:

```json
{
  "name": "copilot-mcp-bridge",
  "version": "1.0.0",
  "type": "module",
  "main": "index.js",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

Install dependencies:

```bash
npm install
```

## Step 2: create the bridge implementation

Create `~/.claude/copilot-mcp/index.js` with the following content:

```js
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
      const output = stdout
        .replace(/\nTotal usage est:[\s\S]*$/, "")
        .trim();

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
```

## Step 3: register the bridge in Claude Code

You can do this either with the CLI or by editing `~/.claude.json`.

### Option A: register with the Claude CLI

```bash
claude mcp add --scope user copilot-bridge -- node ~/.claude/copilot-mcp/index.js
```

### Option B: register manually in `~/.claude.json`

Add this under the top-level `mcpServers` object:

```json
{
  "mcpServers": {
    "copilot-bridge": {
      "type": "stdio",
      "command": "node",
      "args": [
        "/Users/YOUR_USERNAME/.claude/copilot-mcp/index.js"
      ],
      "env": {}
    }
  }
}
```

Replace `YOUR_USERNAME` with the actual home directory path on the machine.

## Step 4: verify that Claude sees the bridge

Run:

```bash
claude mcp list
```

Expected result should include something like:

```text
copilot-bridge: node /Users/.../.claude/copilot-mcp/index.js - ✓ Connected
```

## Step 5: verify the bridge end-to-end

Run a direct Claude test that only uses the Copilot bridge:

```bash
claude -p "Use the MCP tool copilot-bridge delegate_to_copilot with prompt 'Reply with exactly OK' and working_directory '$PWD'. Return only the tool result text." --allowedTools mcp__copilot-bridge__delegate_to_copilot
```

Expected output:

```text
OK
```

At this point, Claude Code can delegate tasks to Copilot through MCP.

## Step 6: add a reusable `/copilot` skill

Create the skill directory:

```bash
mkdir -p ~/.claude/skills/copilot
```

Create `~/.claude/skills/copilot/SKILL.md`:

```md
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
```

This gives users a direct command inside Claude Code:

```text
/copilot fix the failing test in backend
```

## Step 7: make Copilot the default for coding tasks

If you want Claude Code to delegate coding tasks to Copilot automatically, create `~/.claude/CLAUDE.md`:

```md
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
```

Important: this changes Claude Code's behavior through personal instructions and a skill. It does **not** swap Claude's base model for Copilot.

## Step 8: verify default delegation

Run a simple prompt from inside a repository:

```bash
claude -p "/copilot Reply with exactly OK"
```

Expected output:

```text
OK
```

You can also verify the default policy without explicitly calling `/copilot` by using a debug log:

```bash
log=/tmp/claude-copilot-proof.log
rm -f "$log"

claude -p "For this coding task, return the exact first line of the CLAUDE.md file in the current working directory and nothing else." --allowedTools mcp__copilot-bridge__delegate_to_copilot --debug-file "$log"

grep -nE 'copilot-bridge|delegate_to_copilot|MCP server' "$log"
```

If the default delegation is working, you should see `copilot-bridge` connection activity in the debug log, and the final response should contain the requested file content.

## Troubleshooting

### `copilot` command not found

Make sure GitHub Copilot CLI is installed and available in `PATH`:

```bash
copilot --version
```

### Copilot is installed but not authenticated

Re-run:

```bash
copilot login
```

Then verify:

```bash
copilot -p "Reply with exactly OK" --allow-all-tools --allow-all-paths -s
```

### `claude mcp list` does not show `copilot-bridge`

Re-add it:

```bash
claude mcp remove copilot-bridge
claude mcp add --scope user copilot-bridge -- node ~/.claude/copilot-mcp/index.js
```

### Claude does not use Copilot by default

Check both of these files:

- `~/.claude/skills/copilot/SKILL.md`
- `~/.claude/CLAUDE.md`

Common causes:

- the skill still contains `disable-model-invocation: true`
- the skill name or allowed tool is wrong
- the bridge is not connected
- Claude has not reloaded user skills yet

If needed, restart Claude Code and run:

```bash
claude mcp list
```

## Summary

The complete setup has four moving parts:

1. GitHub Copilot CLI authenticated locally
2. A Claude MCP bridge that shells out to `copilot`
3. A personal Claude skill that wraps the bridge
4. Optional user-level instructions that make Copilot the default for coding tasks

That combination gives teammates a reproducible way to keep Claude Code as the main interface while routing implementation work through GitHub Copilot.