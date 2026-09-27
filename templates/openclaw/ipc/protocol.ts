// templates/openclaw/ipc/protocol.ts
// IPC request/response schema. JSON-line-delimited.

export interface IpcRequest {
  id: string;
  action: "check";
  toolName: string;
  params: Record<string, unknown>;
  cwd?: string;
}

export interface IpcCheckResult {
  check: string;
  block: boolean;
  reason?: string;
  severity?: string;
}

export interface IpcResponse {
  id: string;
  results: IpcCheckResult[];
  error?: string;
  message?: string;
}

/**
 * Serialize a request as JSON + newline (line-delimited protocol).
 */
export function encode(req: IpcRequest): string {
  return JSON.stringify(req) + "\n";
}

/**
 * Parse a single response line.
 * Throws if the line is not valid JSON or doesn't have an id.
 */
export function decode(line: string): IpcResponse {
  const obj = JSON.parse(line);
  if (typeof obj !== "object" || obj === null) {
    throw new Error("ipc-decode: response is not an object");
  }
  return obj as IpcResponse;
}
