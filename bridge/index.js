#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { spawn } from "child_process";
import { existsSync, realpathSync } from "fs";
import path from "path";

const server = new Server(
  { name: "copilot-bridge", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const MAX_OUTPUT_CHARS = 80_000;

// ---------------------------------------------------------------------------
// Security configuration
// ---------------------------------------------------------------------------

// Allowed working directories. Set COPILOT_BRIDGE_ALLOWED_DIRS to a list of
// absolute paths separated by the OS path delimiter (`:` on Unix, `;` on
// Windows) to restrict where Copilot may operate. Defaults to the MCP
// server's own working directory if not set.
//
// Paths are resolved via realpathSync so symlinks cannot be used to escape
// the allowlist.
const ALLOWED_DIRS = (() => {
  const dirs = (process.env.COPILOT_BRIDGE_ALLOWED_DIRS || process.cwd())
    .split(path.delimiter)
    .map((d) => {
      const trimmed = d.trim();
      if (!trimmed) return null;
      try {
        return realpathSync(trimmed);
      } catch {
        return path.resolve(trimmed);
      }
    })
    .filter(Boolean);
  // Always keep at least the server's cwd so the array is never empty.
  return dirs.length > 0 ? dirs : [process.cwd()];
})();

/**
 * Return true only when p is equal to, or a descendant of, one of the
 * configured allowed directories. Symlinks in p are resolved before the
 * check to prevent symlink-based escape.
 */
function isAllowedPath(p) {
  let resolved;
  try {
    resolved = realpathSync(p);
  } catch {
    // Path doesn't exist yet; fall back to lexical resolution.
    resolved = path.resolve(p);
  }
  return ALLOWED_DIRS.some(
    (allowed) =>
      resolved === allowed || resolved.startsWith(allowed + path.sep)
  );
}

// Environment variables forwarded to the Copilot child process.
// Only variables necessary for the CLI to run are included; everything else
// (tokens, passwords, private config) is intentionally excluded to prevent
// accidental disclosure.
const BASE_ENV_KEYS = [
  "PATH",
  "HOME",
  "USERPROFILE", // Windows equivalent of HOME
  "USER",
  "USERNAME",    // Windows
  "SHELL",
  "TERM",
  "LANG",
  "LC_ALL",
  "LC_CTYPE",
  "TZ",
  "TMPDIR",
  "TEMP",        // Windows
  "TMP",         // Windows
];

function buildSafeEnv() {
  const env = {};
  for (const key of BASE_ENV_KEYS) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  // Forward GitHub / Copilot authentication variables so the CLI can
  // authenticate, but nothing else from the broader environment.
  for (const [key, val] of Object.entries(process.env)) {
    if (/^(GITHUB_|GH_|COPILOT_)/.test(key)) env[key] = val;
  }
  return env;
}

// Patterns that look like secrets. Occurrences in output are replaced with
// [REDACTED] to prevent accidental disclosure to the MCP caller.
const SECRET_PATTERNS = [
  /ghp_[A-Za-z0-9]{36}/g,
  /gho_[A-Za-z0-9]{36}/g,
  /ghu_[A-Za-z0-9]{36}/g,
  /ghs_[A-Za-z0-9]{36}/g,
  /github_pat_[A-Za-z0-9+/=_]{82}/g,
  /sk-[A-Za-z0-9]{48}/g,
];

function redactSecrets(text) {
  let result = text;
  for (const pattern of SECRET_PATTERNS) {
    result = result.replace(pattern, "[REDACTED]");
  }
  return result;
}

// ---------------------------------------------------------------------------

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
              "Absolute path of the directory Copilot should work in. Must be within an allowed directory (configure via COPILOT_BRIDGE_ALLOWED_DIRS). Defaults to the first allowed directory.",
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
  // Validate and resolve the working directory against the allowlist.
  let cwd;
  if (working_directory) {
    if (!isAllowedPath(working_directory)) {
      return {
        content: [
          {
            type: "text",
            text: "Error: working_directory is not within an allowed directory. Set COPILOT_BRIDGE_ALLOWED_DIRS to allow additional paths.",
          },
        ],
      };
    }
    if (!existsSync(working_directory)) {
      return {
        content: [
          {
            type: "text",
            text: "Error: working_directory does not exist.",
          },
        ],
      };
    }
    cwd = path.resolve(working_directory);
  } else {
    cwd = ALLOWED_DIRS[0];
  }

  return new Promise((resolve) => {
    const args = [
      "-p", prompt,
      "--allow-all-tools",
      "--add-dir", cwd,  // Scoped to the validated directory; --allow-all-paths is intentionally omitted
    ];

    const child = spawn("copilot", args, {
      cwd,
      env: buildSafeEnv(),  // Minimized environment — no full process.env pass-through
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

      // Redact secrets before returning output to the caller.
      output = redactSecrets(output);

      resolve({
        content: [
          {
            type: "text",
            text: output || redactSecrets(stderr) || `Copilot exited with code ${code}`,
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
