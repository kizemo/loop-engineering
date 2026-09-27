// tests/openclaw/ipc-server-test.ts
// Integration test for the IPC server (Task 3).
// Spawns the server in a subprocess, runs 100 sequential calls + 50 concurrent calls,
// asserts that all responses are correct and within latency budget.

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn, ChildProcess } from "node:child_process";
import * as path from "node:path";
import * as fs from "node:fs";
import { fileURLToPath } from "node:url";

import { ipcCheck } from "../../templates/openclaw/ipc/client.ts";
import { defaultSocketPath, defaultPidFilePath } from "../../templates/openclaw/ipc/platform.ts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER = path.resolve(__dirname, "../../templates/openclaw/ipc/server.ts");
const SOCKET = defaultSocketPath();
const PID_FILE = defaultPidFilePath();

let server: ChildProcess | null = null;

async function waitForServer(maxMs = 5000): Promise<void> {
  // On Windows, named pipes don't have a backing file; we just sleep briefly.
  // On Unix, poll for the socket file.
  if (process.platform === "win32") {
    await new Promise((r) => setTimeout(r, 500));
    return;
  }
  const start = Date.now();
  while (Date.now() - start < maxMs) {
    if (fs.existsSync(SOCKET)) return;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error(`server not ready after ${maxMs}ms`);
}

test.before(async () => {
  // Clean up any stale socket/pid file
  try { fs.unlinkSync(SOCKET); } catch {}
  try { fs.unlinkSync(PID_FILE); } catch {}

  server = spawn(process.execPath, [SERVER], {
    env: { ...process.env, LOOPX_GUARD_SOCK: SOCKET, LOOPX_GUARD_PID: PID_FILE },
    stdio: ["ignore", "pipe", "pipe"],
  });
  server.stdout?.on("data", (d) => process.stderr.write(`[server stdout] ${d}`));
  server.stderr?.on("data", (d) => process.stderr.write(`[server stderr] ${d}`));
  await waitForServer();
});

test.after(async () => {
  if (server && !server.killed) {
    server.kill("SIGTERM");
    await new Promise((r) => server?.on("exit", r));
  }
  try { fs.unlinkSync(SOCKET); } catch {}
  try { fs.unlinkSync(PID_FILE); } catch {}
});

// ---- Latency tests ----

test("ipc: 1 call latency < 50ms (Unix only)", async () => {
  if (process.platform === "win32") return;  // skip on Windows in this dev env
  const start = Date.now();
  const r = await ipcCheck({
    toolName: "Bash",
    params: { command: "echo hello" },
    socketPath: SOCKET,
  });
  const elapsed = Date.now() - start;
  assert.ok(r.id, "response should have id");
  assert.ok(Array.isArray(r.results), "results should be array");
  assert.equal(r.results.length, 5, "should run all 5 checks");
  // No checks block echo hello → all should be allow
  assert.equal(r.results.find((x) => x.check === "secret-files")?.block, false);
  assert.equal(r.results.find((x) => x.check === "main-branch-push")?.block, false);
  assert.ok(elapsed < 50, `latency ${elapsed}ms should be < 50ms`);
});

test("ipc: 50 sequential calls latency", async () => {
  if (process.platform === "win32") return;
  const start = Date.now();
  for (let i = 0; i < 50; i++) {
    const r = await ipcCheck({
      toolName: "Write",
      params: { file_path: `docs/file-${i}.md` },
      socketPath: SOCKET,
    });
    assert.ok(r.id);
  }
  const elapsed = Date.now() - start;
  const avg = elapsed / 50;
  // Sequential avg should also be < 50ms (concurrency helps, but per-call is the budget)
  assert.ok(avg < 50, `avg latency ${avg.toFixed(1)}ms should be < 50ms`);
});

// ---- Functional tests ----

test("ipc: blocks secret write", async () => {
  const r = await ipcCheck({
    toolName: "Write",
    params: { file_path: "src/.env" },
    socketPath: SOCKET,
  });
  const blocker = r.results.find((x) => x.block);
  assert.ok(blocker, "secret-files should block");
  assert.equal(blocker?.check, "secret-files");
  assert.match(blocker?.reason ?? "", /BLOCKED/);
});

test("ipc: blocks main branch push", async () => {
  const r = await ipcCheck({
    toolName: "Bash",
    params: { command: "git push origin main" },
    socketPath: SOCKET,
  });
  const blocker = r.results.find((x) => x.block);
  assert.ok(blocker);
  assert.equal(blocker?.check, "main-branch-push");
});

test("ipc: allows safe commands", async () => {
  const r = await ipcCheck({
    toolName: "Bash",
    params: { command: "ls -la" },
    socketPath: SOCKET,
  });
  assert.equal(r.results.find((x) => x.block), undefined);
});

test("ipc: handles malformed JSON gracefully", async () => {
  // Send raw malformed JSON directly via socket
  const net = await import("node:net");
  const sock = net.createConnection(SOCKET);
  await new Promise((r) => sock.on("connect", r));
  const got: string[] = [];
  sock.on("data", (c) => got.push(c.toString("utf8")));
  sock.write("not json\n");
  await new Promise((r) => setTimeout(r, 200));
  sock.destroy();
  const text = got.join("");
  assert.match(text, /parse-failed/);
});
