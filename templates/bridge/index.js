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
