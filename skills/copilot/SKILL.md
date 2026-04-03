---
name: copilot
description: Default executor for coding tasks. Delegate code changes, debugging, refactoring, test work, and repository shell tasks to GitHub Copilot through the configured copilot-bridge MCP server.
argument-hint: <task>
user-invocable: true
disable-model-invocation: false
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
