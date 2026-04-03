# Privacy Policy

**Last updated:** 2025-04-03

## What this software does

`delegate-claude-to-copilot` is a local MCP (Model Context Protocol) bridge that forwards coding tasks from Claude Code to the GitHub Copilot CLI installed on your machine. It runs entirely on your local computer.

## Data collected

This software collects **no data**. It does not have analytics, telemetry, tracking, or any remote data collection of its own.

## Data forwarded to third parties

When you use this bridge, the **prompt text** and **working directory path** you provide are passed to the locally installed GitHub Copilot CLI. The Copilot CLI then sends this data to **GitHub's AI services** (operated by GitHub / Microsoft) to generate a response.

Specifically:
- Your task prompt is sent to GitHub Copilot's servers.
- The Copilot CLI may read files in the specified working directory and send file contents to GitHub's servers as context.
- The Copilot CLI operates with `--allow-all-tools` and `--allow-all-paths` flags, which grant it broad access to read/write files and run shell commands in the working directory.

**This bridge does not add, modify, or intercept any data** in transit between your machine and GitHub's services beyond what the Copilot CLI itself handles.

## Third-party privacy policies

Because your data is processed by GitHub Copilot, you should review:

- [GitHub General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- [GitHub Copilot Trust Center](https://resources.github.com/copilot-trust-center/)
- [GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)

## Data storage

This software stores no data on disk beyond what is required for operation (npm package files). Conversation data, prompts, and outputs are held only in memory for the duration of a single tool call and are not persisted, logged, or cached.

## Your choices

- **Don't install it.** This bridge is entirely opt-in.
- **Uninstall at any time.** Run `claude mcp remove copilot-bridge` and delete the bridge files.
- **Review Copilot's privacy controls.** GitHub Copilot has its own data retention and telemetry settings — configure them via your GitHub account.

## Contact

For questions or concerns about this privacy policy, please open an issue at:
https://github.com/StreetStripe/delegate-claude-to-copilot/issues

Or contact the maintainer via GitHub: [@StreetStripe](https://github.com/StreetStripe)
