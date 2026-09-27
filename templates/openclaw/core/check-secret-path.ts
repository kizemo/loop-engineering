// templates/openclaw/core/check-secret-path.ts
// Ported from templates/hooks/guard-secret-files.js
// PreToolUse:Edit|Write|MultiEdit — block writes to secret paths.
//
// Default secret path patterns (override via <project>/.claude/guard-rails.yaml):
//   *.env / *.env.* / *.pem / *.key / *.p12 / *.pfx
//   secrets/ / credentials.* / *.sqlite3 / *.db
//   .aws/* / .ssh/* / .gnupg/*
//   **/id_rsa* / **/id_dsa* / **/id_ed25519*

import type { CheckContext, CheckResult } from "./types.ts";
import { extractTarget } from "./normalize.ts";
import * as fs from "fs";
import * as path from "path";

const DEFAULT_PATTERNS: RegExp[] = [
  // Dotenv family
  /(^|\/)\.env(\..+)?$/i,
  /(^|\/)\.envrc$/i,
  // Crypto material
  /\.(pem|key|p12|pfx|crt|cer)$/i,
  // SSH / GPG / AWS
  /(^|\/)\.ssh\//i,
  /(^|\/)\.aws\//i,
  /(^|\/)\.gnupg\//i,
  /(^|\/)(id_rsa|id_dsa|id_ed25519|id_ecdsa)(\.pub)?$/i,
  // Database files
  /\.(sqlite3?|db|sqlitedb)$/i,
  // Credentials naming
  /(^|\/)credentials(\..+)?$/i,
  /(^|\/)secrets(\..+)?\.(json|ya?ml|toml|env)$/i,
  // Service account files
  /service[_-]?account.*\.json$/i,
  /gcp[_-]?key.*\.json$/i,
  /firebase[_-]?adminsdk.*\.json$/i,
];

function loadExtraPatterns(projectRoot: string | undefined): RegExp[] {
  if (!projectRoot) return [];
  const yamlPath = path.join(projectRoot, ".claude", "guard-rails.yaml");
  if (!fs.existsSync(yamlPath)) return [];
  try {
    const text = fs.readFileSync(yamlPath, "utf8");
    const lines = text.split("\n");
    const extras: RegExp[] = [];
    let inKey = false;
    for (const line of lines) {
      if (/^secrets_extra_patterns:/.test(line)) {
        inKey = true;
        continue;
      }
      if (inKey) {
        const m = line.match(/^\s+-\s+["'](.+?)["']\s*$/);
        if (m) {
          try { extras.push(new RegExp(m[1])); } catch { /* invalid regex */ }
        } else if (/^[a-z_]+:/i.test(line.trim())) {
          inKey = false;
        }
      }
    }
    return extras;
  } catch {
    return [];
  }
}

export function checkSecretFiles(ctx: CheckContext): CheckResult {
  const filePath = extractTarget(ctx);
  if (!filePath) return { block: false };

  // Normalize: Windows backslashes → forward slashes
  const normalized = filePath.replace(/\\/g, "/");
  const basename = path.basename(normalized).toLowerCase();

  const allPatterns = [
    ...DEFAULT_PATTERNS,
    ...loadExtraPatterns(ctx.projectRoot),
  ];

  const matched = allPatterns.find(
    (re) => re.test(normalized) || re.test(basename)
  );

  if (matched) {
    return {
      block: true,
      severity: "critical",
      reason: `[guard-secret-files] BLOCKED: writing to secret path.\n  Path:    ${filePath}\n  Pattern: ${matched}\n  Action:  Ask user to confirm intent; for test fixtures use a non-secret filename\n           (e.g. fixtures/test_secret_sample.json, NOT real .env). Retry only\n           after explicit approval.`,
    };
  }

  return { block: false };
}
