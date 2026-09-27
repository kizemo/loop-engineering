#!/usr/bin/env node
// templates/hooks/guard-package-publish.ts
// Project-level Guard Rail #4 of 5 — PreToolUse:Bash.
// THIN WRAPPER: reads stdin, calls IPC server, exits 2 (block) or 0 (allow).
// Core logic lives in templates/openclaw/core/check-package-publish.ts.

import { ipcCheck } from "../openclaw/ipc/client.ts";

(async () => {
  const chunks: Buffer[] = [];
  for await (const c of process.stdin) chunks.push(c as Buffer);
  const raw = Buffer.concat(chunks).toString("utf8");

  let ev: any;
  try {
    ev = raw.trim() ? JSON.parse(raw) : { tool_name: "unknown", tool_input: {} };
  } catch (e: any) {
    process.stderr.write(`[guard-package-publish] parse error: ${e.message}\n`);
    process.exit(0);
  }

  try {
    const r = await ipcCheck({
      toolName: ev.tool_name || ev.toolName || "unknown",
      params: ev.tool_input || ev.params || {},
      cwd: ev.cwd,
    });
    const blocker = r.results.find((x) => x.block);
    if (blocker) {
      process.stderr.write(blocker.reason ?? `[${blocker.check}] BLOCKED\n`);
      process.exit(2);
    }
    process.exit(0);
  } catch (e: any) {
    process.stderr.write(`[guard-package-publish] ipc-failed (fail-soft allow): ${e.message}\n`);
    process.exit(0);
  }
})();
