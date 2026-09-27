// templates/openclaw/ipc/server.ts
// Long-running IPC server for loop-engineering guard rails.
// Listens on Unix socket (Linux/macOS) or named pipe (Windows).
// Receives JSON-line requests, runs all 5 guard rail checks, returns JSON-line response.
//
// Usage: node templates/openclaw/ipc/server.ts
// Output: emits {ready:true, pid, socket, pid_file} to stdout on startup.

import * as net from "net";
import * as fs from "fs";
import { platform } from "process";

import { checks } from "../core/index.ts";
import { normalize } from "../core/normalize.ts";
import type { IpcRequest, IpcResponse } from "./protocol.ts";
import { decode } from "./protocol.ts";
import { defaultSocketPath, defaultPidFilePath } from "./platform.ts";

const SOCKET = process.env.LOOPX_GUARD_SOCK || defaultSocketPath();
const PID_FILE = process.env.LOOPX_GUARD_PID || defaultPidFilePath();
const MAX_LINE_BYTES = 1024 * 1024; // 1 MiB safety limit

const server = net.createServer((socket) => {
  let buf = "";
  socket.on("data", (chunk) => {
    buf += chunk.toString("utf8");
    if (buf.length > MAX_LINE_BYTES) {
      // Prevent runaway buffers
      try {
        socket.write(JSON.stringify({ error: "line-too-long" }) + "\n");
      } catch {}
      socket.destroy();
      return;
    }
    let nl: number;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      handleLine(socket, line);
    }
  });
  socket.on("error", () => {});  // swallow client errors
});

function handleLine(socket: net.Socket, line: string): void {
  let req: IpcRequest;
  try {
    req = JSON.parse(line) as IpcRequest;
  } catch {
    writeResponse(socket, { id: "?", error: "parse-failed", message: "invalid JSON", results: [] });
    return;
  }

  try {
    const ctx = normalize({
      toolName: req.toolName,
      params: req.params,
      cwd: req.cwd,
    });
    const results = Object.entries(checks).map(([name, fn]) => ({
      check: name,
      ...fn(ctx),
    }));
    writeResponse(socket, { id: req.id, results });
  } catch (e: any) {
    writeResponse(socket, { id: req.id, error: "core-failed", message: e?.message ?? String(e), results: [] });
  }
}

function writeResponse(socket: net.Socket, resp: IpcResponse): void {
  try {
    socket.write(JSON.stringify(resp) + "\n");
  } catch {
    socket.destroy();
  }
}

// Startup: clean stale socket (Unix only — Windows pipes auto-clean on server exit)
if (platform !== "win32") {
  try { fs.unlinkSync(SOCKET); } catch { /* ignore */ }
}

// Restrict socket permissions on Unix (only owner can connect)
function restrictPermissions(): void {
  if (platform === "win32") return;
  try {
    fs.chmodSync(SOCKET, 0o600);
  } catch { /* best effort */ }
}

server.listen(SOCKET, () => {
  restrictPermissions();
  try {
    fs.writeFileSync(PID_FILE, String(process.pid));
  } catch (e: any) {
    process.stderr.write(`[ipc-server] WARN: cannot write pid file ${PID_FILE}: ${e.message}\n`);
  }
  // Output ready signal for install.sh to capture
  process.stdout.write(JSON.stringify({
    ready: true,
    pid: process.pid,
    socket: SOCKET,
    pid_file: PID_FILE,
  }) + "\n");
});

function shutdown(signal: string): void {
  process.stderr.write(`[ipc-server] received ${signal}, shutting down\n`);
  server.close(() => {
    if (platform !== "win32") {
      try { fs.unlinkSync(SOCKET); } catch {}
    }
    try { fs.unlinkSync(PID_FILE); } catch {}
    process.exit(0);
  });
  // Force-exit after 5s if connections hang
  setTimeout(() => process.exit(0), 5000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("exit", () => {
  try { fs.unlinkSync(PID_FILE); } catch {}
});
