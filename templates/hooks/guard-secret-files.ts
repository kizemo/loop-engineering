#!/usr/bin/env node
// templates/hooks/guard-secret-files.ts
// Project-level Guard Rail #1 of 5 — PreToolUse:Edit|Write|MultiEdit.
// THIN WRAPPER: reads stdin, calls IPC server, exits 2 (block) or 0 (allow).
// Core logic lives in templates/openclaw/core/check-secret-path.ts.
//
// Why IPC: 常驻 server 持有 core,5 hook 启动延迟 < 50ms(对比原 node 启动 ~80ms)。
// Fallback:IPC 失败 → exit 0 + stderr warning(fail-soft,避免单点失败)。
//
// Claude Code settings.json 注册:
//   { "matcher": "Edit|Write|MultiEdit",
//     "hooks": [{ "type": "command",
//                 "command": "node <project>/.claude/hooks/guard-secret-files.ts" }] }

import { ipcCheck } from "../openclaw/ipc/client.ts";

(async () => {
  const chunks: Buffer[] = [];
  for await (const c of process.stdin) chunks.push(c as Buffer);
  const raw = Buffer.concat(chunks).toString("utf8");

  let ev: any;
  try {
    ev = raw.trim() ? JSON.parse(raw) : { tool_name: "unknown", tool_input: {} };
  } catch (e: any) {
    process.stderr.write(`[guard-secret-files] parse error: ${e.message}\n`);
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
    // Fail-soft: IPC unavailable → allow + log warning.
    // install.sh 在 install 时启动 server,正常情况下不会到这里。
    process.stderr.write(`[guard-secret-files] ipc-failed (fail-soft allow): ${e.message}\n`);
    process.exit(0);
  }
})();
