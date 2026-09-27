#!/usr/bin/env node
// tests/openclaw/run-check.ts
// CLI runner for core check logic. Mirrors the contract of the original
// Claude Code hook scripts (stdin JSON in, exit code out) so we can run
// the same fixtures against both old and new implementations.
//
// Usage:
//   echo '{"tool_name":"Bash","tool_input":{"command":"..."}}' | node run-check.ts
//
// Exit codes:
//   0 — all checks pass (allow)
//   2 — at least one check blocked (block, stderr contains reason)
//   1 — invalid input / internal error

import { normalize, checks } from "../../templates/openclaw/core/index.ts";

async function main(): Promise<void> {
  const chunks: Buffer[] = [];
  for await (const c of process.stdin) chunks.push(c as Buffer);
  const raw = Buffer.concat(chunks).toString("utf8");

  let event: unknown;
  try {
    event = raw.trim() ? JSON.parse(raw) : {};
  } catch (e: any) {
    process.stderr.write(`[run-check] parse error: ${e.message}\n`);
    process.exit(1);
  }

  const ctx = normalize(event as any);
  if (!ctx.cwd && process.env.LOOPX_GUARD_CWD) {
    ctx.cwd = process.env.LOOPX_GUARD_CWD;
  }

  for (const [name, fn] of Object.entries(checks)) {
    const r = fn(ctx);
    if (r.block) {
      process.stderr.write(r.reason ?? `[${name}] BLOCKED\n`);
      process.exit(2);
    }
  }

  process.exit(0);
}

main().catch((e) => {
  process.stderr.write(`[run-check] unexpected error: ${e?.message ?? e}\n`);
  process.exit(1);
});
