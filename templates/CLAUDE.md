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
