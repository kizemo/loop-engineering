// templates/openclaw/core/check-package-publish.ts
// Ported from templates/hooks/guard-package-publish.sh
// PreToolUse:Bash — block accidental package publishes.
//
// Block:
//   npm publish / pnpm publish / yarn publish / bun publish
//   twine upload (PyPI)
//   cargo publish
//   vsce publish / ovsx publish (VSCode)
//   gh release create (without --draft)
//
// Allow:
//   --dry-run / --tag next / --draft

import type { CheckContext, CheckResult } from "./types.ts";
import { extractTarget } from "./normalize.ts";

const ALLOW_PATTERNS = [
  /--dry-run/,
  /\s-n\s/,
  /(npm|pnpm|yarn|bun)\s+pack/,
  /gh\s+release\s+create.*--draft/,
  /(vsce|ovsx)\s+(package|ls|show|unpublish)/,
  /twine\s+upload.*--repository\s+testpypi|twine\s+check/,
];

function matchAny(text: string, patterns: RegExp[]): RegExp | null {
  for (const p of patterns) {
    if (p.test(text)) return p;
  }
  return null;
}

export function checkPackagePublish(ctx: CheckContext): CheckResult {
  const cmd = extractTarget(ctx);
  if (!cmd) return { block: false };

  const cmdNorm = cmd.replace(/\s+/g, " ");

  // Allowlist short-circuits
  if (matchAny(cmdNorm, ALLOW_PATTERNS)) {
    return { block: false };
  }

  let blockedReason: string | null = null;

  // npm / pnpm / yarn / bun publish
  if (/(npm|pnpm|yarn|bun)\s+publish/.test(cmdNorm)) {
    if (!/(--dry-run|--tag\s+(next|beta|alpha))/.test(cmdNorm)) {
      blockedReason = "npm/pnpm/yarn/bun publish (without --dry-run or pre-release tag)";
    }
  }

  // twine upload (PyPI)
  if (!blockedReason && /\btwine\s+upload\b/.test(cmdNorm)) {
    if (!/\b--repository\s+testpypi\b/.test(cmdNorm)) {
      blockedReason = "twine upload (PyPI production)";
    }
  }

  // cargo publish
  if (!blockedReason && /\bcargo\s+publish\b/.test(cmdNorm)) {
    if (!/\b--dry-run\b/.test(cmdNorm)) {
      blockedReason = "cargo publish (without --dry-run)";
    }
  }

  // vsce / ovsx publish (VSCode marketplace)
  if (!blockedReason && /\b(vsce|ovsx)\s+publish\b/.test(cmdNorm)) {
    if (!/\b--dry-run\b/.test(cmdNorm)) {
      blockedReason = "vsce/ovsx publish (VSCode marketplace)";
    }
  }

  // gh release create (without --draft)
  if (!blockedReason && /\bgh\s+release\s+create\b/.test(cmdNorm)) {
    if (!/\b--draft\b/.test(cmdNorm)) {
      blockedReason = "gh release create (without --draft)";
    }
  }

  if (blockedReason) {
    const cmdPreview = cmd.slice(0, 200);
    return {
      block: true,
      severity: "critical",
      reason: `[guard-package-publish] BLOCKED: package publish detected.\n  Reason: ${blockedReason}\n  Cmd:    ${cmdPreview}\n  Required before retry:\n    1. Run with --dry-run first to verify artifacts.\n    2. Confirm version + tag with user via AskUserQuestion.\n    3. For VSCode: prefer --package-path or --dry-run before live publish.\n    4. For GitHub release: start with --draft, then publish from web UI.\n    5. Re-run only after explicit approval.`,
    };
  }

  return { block: false };
}
