// .opencode/tools/claude_audit.ts
// OpenCode tool definition for claude-audit-gate.
// Agents call this via task() to audit the current workspace diff.
// Delegates to scripts/run_claude_audit.ps1 — do NOT implement audit logic here.

import { z } from "zod";

const parameters = z.object({
  skipPreflight: z
    .boolean()
    .default(false)
    .describe("Skip auth and headless preflight checks"),
  skipClaude: z
    .boolean()
    .default(false)
    .describe("Skip Claude audit call — diff check only"),
  selfTest: z
    .boolean()
    .default(false)
    .describe("Create temp git repo for isolated smoke test"),
  useFixture: z
    .string()
    .optional()
    .describe("Path to local fixture JSON for gate logic testing"),
});

type Parameters = z.input<typeof parameters>;

export const tool = {
  name: "claude-audit",
  description:
    "Run Claude Code as an independent auditor on the current workspace git diff. " +
    "Exits 0 (PASS), 10 (non-blocking), 20 (blocking), 21 (auth), 22 (JSON), 23 (rate limit), 24 (no repo), 25 (no claude). " +
    "See docs/exit-codes.md for details.",
  parameters,

  execute: async (params: Parameters, context) => {
    const args: string[] = [];
    if (params.skipPreflight) args.push("-SkipPreflight");
    if (params.skipClaude) args.push("-SkipClaude");
    if (params.selfTest) args.push("-SelfTest");
    if (params.useFixture) {
      args.push("-UseFixture");
      args.push(params.useFixture);
    }

    const scriptPath = "scripts/run_claude_audit.ps1";
    const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" ${args.join(" ")}`;

    const result = await context.$exec(cmd);
    return {
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    };
  },
};
