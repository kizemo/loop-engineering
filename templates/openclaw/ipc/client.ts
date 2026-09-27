// templates/openclaw/ipc/client.ts
// IPC client library. Connect to a running server, send a check request,
// read the JSON response, resolve to a typed IpcResponse.
//
// Used by:
//   - templates/hooks/guard-*.ts (CC thin wrappers, Task 2)
//   - tests/openclaw/run-check.ts (dev/CI tooling)

import * as net from "net";
import { randomUUID } from "crypto";

import type { IpcRequest, IpcResponse } from "./protocol.ts";
import { encode } from "./protocol.ts";
import { defaultSocketPath } from "./platform.ts";

export interface IpcCheckOptions {
  toolName: string;
  params: Record<string, unknown>;
  cwd?: string;
  timeoutMs?: number;
  socketPath?: string;
}

export async function ipcCheck(opts: IpcCheckOptions): Promise<IpcResponse> {
  const socketPath = opts.socketPath ?? process.env.LOOPX_GUARD_SOCK ?? defaultSocketPath();
  const timeoutMs = opts.timeoutMs ?? 5000;
  const req: IpcRequest = {
    id: randomUUID(),
    action: "check",
    toolName: opts.toolName,
    params: opts.params,
    cwd: opts.cwd,
  };

  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    let buf = "";
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error(`ipc-timeout after ${timeoutMs}ms (socket=${socketPath})`));
    }, timeoutMs);

    socket.on("connect", () => {
      try {
        socket.write(encode(req));
      } catch (e: any) {
        clearTimeout(timer);
        socket.destroy();
        reject(e);
      }
    });

    socket.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      const nl = buf.indexOf("\n");
      if (nl !== -1) {
        clearTimeout(timer);
        const line = buf.slice(0, nl);
        try {
          const resp = JSON.parse(line) as IpcResponse;
          resolve(resp);
        } catch (e: any) {
          reject(new Error(`ipc-parse-failed: ${e.message}`));
        }
        socket.end();
      }
    });

    socket.on("error", (e) => {
      clearTimeout(timer);
      reject(new Error(`ipc-connect-failed: ${e.message} (socket=${socketPath})`));
    });

    socket.on("close", () => {
      clearTimeout(timer);
    });
  });
}
