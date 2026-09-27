// templates/openclaw/core/check-main-branch-push.ts
// Ported from templates/hooks/guard-main-branch-push.py
// PreToolUse:Bash — block dangerous git push commands.
//
// Blocks: git push origin main|master / git push -f / git push --force-with-lease
// Allows: git push origin <feature-branch> / git push --dry-run / git push <branch>

import type { CheckContext, CheckResult } from "./types.ts";
import { extractTarget } from "./normalize.ts";
import * as fs from "fs";
import * as path from "path";

function loadAllowedBranches(projectRoot: string | undefined): string[] {
  const defaultBranches = ["main", "master"];
  if (!projectRoot) return defaultBranches;
  const yamlPath = path.join(projectRoot, ".claude", "guard-rails.yaml");
  if (!fs.existsSync(yamlPath)) return defaultBranches;
  try {
    const text = fs.readFileSync(yamlPath, "utf8");
    const lines = text.split("\n");
    const branches: string[] = [];
    let inKey = false;
    for (const line of lines) {
      if (/^allowed_main_branches:/.test(line)) {
        inKey = true;
        continue;
      }
      if (inKey) {
        const m = line.match(/^\s+-\s+["']?([^"']+)["']?\s*$/);
        if (m) {
          branches.push(m[1].trim());
        } else if (/^[a-z_]+:/i.test(line.trim())) {
          inKey = false;
        }
      }
    }
    return branches.length ? branches : defaultBranches;
  } catch {
    return defaultBranches;
  }
}

function globMatch(pattern: string, text: string): boolean {
  if (pattern === text) return true;
  if (!pattern.includes("*")) return false;
  // Convert glob to regex: `*` → `.*`, escape other regex chars
  const escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&");
  const regex = new RegExp("^" + escaped.replace(/\*/g, ".*") + "$");
  return regex.test(text);
}

const PUSH_RE = /\bgit\s+push\b(?<flags>(?:\s+--?[a-z][\w-]*)*)\s+(?<rest>.+)$/i;
const FORCE_PATTERNS = [/\s-f\b/, /\s--force\b/, /\s--force-with-lease\b/, /\s--force-if-includes\b/];

export function checkMainBranchPush(ctx: CheckContext): CheckResult {
  const cmd = extractTarget(ctx);
  if (!cmd) return { block: false };

  const m = cmd.match(PUSH_RE);
  if (!m) return { block: false };

  const flags = m.groups?.flags ?? "";
  const rest = (m.groups?.rest ?? "").trim();

  // Strip dry-run early — allow preview pushes
  if (flags.includes("--dry-run") || flags.split(/\s+/).includes("-n")) {
    return { block: false };
  }

  // Detect force push
  const isForce = FORCE_PATTERNS.some((p) => p.test(flags));

  // Parse remote + ref from rest. Last token is ref (if not a flag).
  const tokens = rest.split(/\s+/).filter((t) => !t.startsWith("-"));
  if (tokens.length === 0) return { block: false };
  const ref = tokens[tokens.length - 1];

  const allowed = loadAllowedBranches(ctx.projectRoot);
  const blockedBranch = isForce || allowed.some((p) => globMatch(p, ref));

  if (blockedBranch) {
    const cmdPreview = cmd.slice(0, 200);
    return {
      block: true,
      severity: "critical",
      reason: `[guard-main-branch-push] BLOCKED: direct push to protected ref.\n  Cmd:    ${cmdPreview}\n  Ref:    ${ref}\n  Force:  ${isForce}\n  Allowed: ${allowed.join(", ")}\n  Action: open a PR instead. If you must bypass (hotfix), use\n          \`git push origin <branch> --force-with-lease\` only after\n          explicit AskUserQuestion approval.`,
    };
  }

  return { block: false };
}
