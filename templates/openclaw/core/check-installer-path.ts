// templates/openclaw/core/check-installer-path.ts
// Ported from templates/hooks/guard-installer-path.sh
// PreToolUse:Bash|Edit|Write — block installer writes outside allowlist paths.
//
// Why: 装机项目(rime_claude / media-to-doc-ui / cut-ad)在 Windows 上生成
// .exe / .msi / .dmg / .deb / .AppImage,如果 Claude 把二进制写到
// C:\Windows / C:\Program Files\ / /usr/bin/ 就会污染系统路径。
//
// Default allowlist: target/ / release/ / dist/ / build/ / output/ / out/

import type { CheckContext, CheckResult } from "./types.ts";
import { extractTarget } from "./normalize.ts";
import * as fs from "fs";
import * as path from "path";

const DEFAULT_ALLOW_PATHS = ["target/", "release/", "dist/", "build/", "output/", "out/"];

const INSTALLER_EXT_RE = /\.(exe|msi|dmg|deb|rpm|AppImage|pkg)$/i;

// Unified greedy regex: matches path-like tokens ending in installer ext
const PATH_TOKEN_RE = /[A-Za-z]:[/\\][^\s]+\.(exe|msi|dmg|deb|rpm|AppImage|pkg)|[/\\][^\s]+\.(exe|msi|dmg|deb|rpm|AppImage|pkg)|[A-Za-z0-9_./-]+\.(exe|msi|dmg|deb|rpm|AppImage|pkg)/gi;

function loadAllowPaths(projectRoot: string | undefined): string[] {
  const paths = [...DEFAULT_ALLOW_PATHS];
  if (!projectRoot) return paths;
  const yamlPath = path.join(projectRoot, ".claude", "guard-rails.yaml");
  if (!fs.existsSync(yamlPath)) return paths;
  try {
    const text = fs.readFileSync(yamlPath, "utf8");
    const lines = text.split("\n");
    let inKey = false;
    for (const line of lines) {
      if (/^installer_allow_paths:/.test(line)) {
        inKey = true;
        continue;
      }
      if (inKey) {
        const m = line.match(/^\s+-\s+["']?(.+?)["']?\s*$/);
        if (m) {
          let p = m[1];
          // Strip surrounding quotes
          if (p.length >= 2 && (p[0] === '"' || p[0] === "'") && p[p.length - 1] === p[0]) {
            p = p.slice(1, -1);
          }
          if (p) paths.push(p);
        } else if (/^[a-z_]+:/i.test(line.trim())) {
          inKey = false;
        }
      }
    }
    return paths;
  } catch {
    return paths;
  }
}

function normalizeRelative(candidate: string): string {
  // Strip leading ./
  let c = candidate.replace(/^\.\//, "");

  // Convert Windows paths: C:/foo/bar.exe → strip drive + first dir
  // Convert Unix paths: /foo/bar.exe → strip leading /
  if (/^[A-Z]:\//.test(c)) {
    c = c.replace(/^[A-Z]:\/[^/]+\//, "");
  } else if (c.startsWith("/")) {
    c = c.replace(/^\/[^/]+\//, "");
  }
  return c;
}

function isAllowed(candidate: string, allowPaths: string[]): boolean {
  const candNorm = candidate.replace(/^\.\//, "");
  const candRel = normalizeRelative(candNorm);
  for (const ap of allowPaths) {
    const apPattern = ap.replace(/\/$/, "");
    // Match against raw or relative path
    if (candNorm === apPattern) return true;
    if (candNorm.startsWith(apPattern + "/")) return true;
    if (candNorm.includes("/" + apPattern + "/")) return true;
    if (candRel.startsWith(apPattern + "/")) return true;
    if (candRel.includes("/" + apPattern + "/")) return true;
  }
  return false;
}

export function checkInstallerPath(ctx: CheckContext): CheckResult {
  const target = extractTarget(ctx);
  if (!target) return { block: false };

  // Normalize backslashes
  const normalized = target.replace(/\\/g, "/");

  // Find all installer file paths in input
  const candidates = new Set<string>();
  let m: RegExpExecArray | null;
  PATH_TOKEN_RE.lastIndex = 0;
  while ((m = PATH_TOKEN_RE.exec(normalized)) !== null) {
    if (m[0]) candidates.add(m[0]);
  }

  if (candidates.size === 0) return { block: false };

  const allowPaths = loadAllowPaths(ctx.projectRoot);

  for (const candidate of candidates) {
    if (!isAllowed(candidate, allowPaths)) {
      return {
        block: true,
        severity: "critical",
        reason: `[guard-installer-path] BLOCKED: installer artifact outside allowlist.\n  Path:    ${candidate}\n  Allow:   ${allowPaths.join(" ")}\n  Required before retry:\n    1. Move installer output to one of the allowed dirs:\n       ${allowPaths.join(" ")}\n    2. Or update <project>/.claude/guard-rails.yaml:\n         installer_allow_paths:\n           - <your/custom/path>/\n    3. If user explicitly approves writing to a system path (e.g. C:\\\\Program Files\\\\),\n       AskUserQuestion first; this hook intentionally blocks unattended writes.`,
      };
    }
  }

  return { block: false };
}
