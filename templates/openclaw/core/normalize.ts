// templates/openclaw/core/normalize.ts
// Input normalization: maps Claude Code and OpenClaw tool names to canonical names,
// flattens nested tool_input wrappers, extracts command/path fields.

import type { ToolName, HookEvent, CheckContext } from "./types.ts";

export const TOOL_ALIAS: Record<string, ToolName> = {
  // Claude Code tools → canonical
  "Bash": "exec",
  "Execute": "exec",
  "Read": "read",
  "Write": "write",
  "Edit": "edit",
  "MultiEdit": "edit",
  "ApplyPatch": "apply_patch",
  "WebFetch": "web_fetch",
  "WebSearch": "web_search",
  // OpenClaw tools → canonical (mostly identical)
  "exec": "exec",
  "process": "exec",
  "terminal": "exec",
  "code_execution": "exec",
  "read": "read",
  "write": "write",
  "edit": "edit",
  "apply_patch": "apply_patch",
  "web_fetch": "web_fetch",
  "web_search": "web_search",
};

export function normalizeToolName(name: string): ToolName {
  return (TOOL_ALIAS[name] ?? name) as ToolName;
}

/**
 * Normalize input from either Claude Code ({tool_name, tool_input: {...}}) or
 * OpenClaw ({toolName, params: {...}}) format into a CheckContext.
 */
export function normalize(event: HookEvent | { tool_name?: string; tool_input?: Record<string, unknown> }): CheckContext {
  // Detect CC format (snake_case tool_name) vs OpenClaw (camelCase toolName)
  const isCC = "tool_name" in event && !("toolName" in event);
  const toolName = isCC
    ? String(event.tool_name ?? "unknown")
    : String((event as HookEvent).toolName ?? "unknown");
  const params = isCC
    ? (event.tool_input ?? {})
    : ((event as HookEvent).params ?? {});
  const cwd = (event as any).cwd;

  return {
    toolName: normalizeToolName(toolName),
    params,
    cwd,
  };
}

/**
 * Extract the relevant string field for matching.
 * - For "edit"/"write"/"apply_patch": params.file_path (CC) or params.path (OC)
 * - For "exec": params.command
 */
export function extractTarget(ctx: CheckContext): string {
  const p = ctx.params as Record<string, unknown>;
  switch (ctx.toolName) {
    case "exec":
      return String(p.command ?? "");
    case "edit":
    case "write":
    case "apply_patch":
      return String(p.file_path ?? p.path ?? "");
    default:
      return "";
  }
}
