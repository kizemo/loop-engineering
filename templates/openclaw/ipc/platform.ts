// templates/openclaw/ipc/platform.ts
// Cross-platform IPC transport selection (Unix socket vs Windows named pipe).

import { platform } from "process";
import * as os from "os";
import * as path from "path";

/**
 * Default socket/pipe path for the guard rail IPC server.
 * - Linux/macOS: Unix domain socket
 * - Windows: named pipe
 */
export function defaultSocketPath(): string {
  if (platform === "win32") {
    return "\\\\.\\pipe\\loopx-guard";
  }
  // Unix: XDG_RUNTIME_DIR > TMPDIR > /tmp
  const xdg = process.env.XDG_RUNTIME_DIR;
  if (xdg) return path.join(xdg, "loopx-guard.sock");
  const tmp = process.env.TMPDIR || os.tmpdir();
  return path.join(tmp, "loopx-guard.sock");
}

/**
 * Default PID file path. On Windows, use %TEMP% since pipe names can't be files.
 */
export function defaultPidFilePath(): string {
  if (platform === "win32") {
    return path.join(process.env.TEMP || os.tmpdir(), "loopx-guard.pid");
  }
  return defaultSocketPath() + ".pid";
}

/**
 * Check if the current platform supports IPC (always true on Linux/macOS/Windows).
 */
export function platformSupportsIPC(): boolean {
  return ["linux", "darwin", "win32"].includes(platform);
}
