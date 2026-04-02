# Contributing to delegate-claude-to-copilot

Thanks for your interest in contributing! 🎉

## Getting started

1. **Fork** the repository and clone it locally.
2. Make sure you have the prerequisites installed:

   ```bash
   claude --version   # Claude Code CLI
   copilot --version  # GitHub Copilot CLI
   node --version     # Node.js ≥ 18
   npm --version
   ```

3. Install bridge dependencies:

   ```bash
   cd bridge && npm install
   ```

## Making changes

- Keep changes small and focused — one concern per PR.
- If you add a new feature, update the relevant docs (`README.md`, `HOW-TO-INSTALL-MANUALLY.md`).
- Make sure the install script still works: `./install.sh --dry-run`.
- Follow the existing code style (ES modules, `set -euo pipefail` in shell scripts).

## Reporting issues

Open a [GitHub issue](https://github.com/StreetStripe/delegate-claude-to-copilot/issues) with:

- A clear description of the problem or suggestion.
- Steps to reproduce (if it's a bug).
- Your environment (OS, Node version, Claude Code version, Copilot CLI version).

## Code of conduct

Be kind, constructive, and respectful. We're all here to make Claude + Copilot better together.

## License

By contributing you agree that your contributions will be licensed under the [MIT License](LICENSE).
