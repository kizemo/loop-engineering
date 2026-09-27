// templates/openclaw/core/types.ts
// Shared types for loop-engineering guard rails core logic.
// Pure types — no I/O, no platform-specific code.

export type ToolName =
  | "exec"
  | "write"
  | "edit"
  | "read"
  | "apply_patch"
  | "web_fetch"
  | "web_search";

export interface CheckResult {
  block: boolean;
  reason?: string;
  severity?: "info" | "warning" | "critical";
}

export interface CheckContext {
  toolName: ToolName;
  params: Record<string, unknown>;
  cwd?: string;
  projectRoot?: string;
}

export type CheckFunction = (ctx: CheckContext) => CheckResult;

export type CheckName =
  | "secret-files"
  | "main-branch-push"
  | "db-migration"
  | "package-publish"
  | "installer-path";

export interface HookEvent {
  toolName: string;
  params: Record<string, unknown>;
  cwd?: string;
}
