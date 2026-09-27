// templates/openclaw/core/check-db-migration.ts
// Ported from templates/hooks/guard-db-migration.sh
// PreToolUse:Bash — block irreversible database migrations.
//
// Blocks:
//   alembic upgrade <rev>            (without --sql dry-run)
//   python manage.py migrate         (without --plan)
//   prisma migrate deploy            (only allows `prisma migrate dev` for dev)
//   dbt run --select <tag>           (production tags blocked)
//   psql -c "DROP TABLE ..."
//
// Allowlist (always pass):
//   alembic upgrade --sql            (dry-run)
//   alembic history / alembic current
//   prisma migrate dev
//   dbt run --select tag:dev

import type { CheckContext, CheckResult } from "./types.ts";
import { extractTarget } from "./normalize.ts";

const ALLOW_PATTERNS = [
  /alembic\s+upgrade\s+--sql/,
  /alembic\s+(history|current|show|stamp|heads|branches)/,
  /prisma\s+migrate\s+(dev|status|diff|resolve)/,
  /prisma\s+migrate\s+deploy\s+--dry-run/,
  /manage\.py\s+migrate\s+--plan/,
  /dbt\s+(run|build)\s+--select\s+tag:dev/,
  /dbt\s+(parse|deps|compile|docs|seed|snapshot)/,
  /^\s*SELECT\s/i,
  /^\s*EXPLAIN\s/i,
  /^\\\d\s/,
  /^\\\(dt\|dv\)\s/,
];

function matchAny(text: string, patterns: RegExp[]): RegExp | null {
  for (const p of patterns) {
    if (p.test(text)) return p;
  }
  return null;
}

export function checkDbMigration(ctx: CheckContext): CheckResult {
  const cmd = extractTarget(ctx);
  if (!cmd) return { block: false };

  // Normalize whitespace
  const cmdNorm = cmd.replace(/\s+/g, " ");

  // Allowlist short-circuits
  if (matchAny(cmdNorm, ALLOW_PATTERNS)) {
    return { block: false };
  }

  // Blocklist checks
  let blockedReason: string | null = null;

  // alembic upgrade (without --sql)
  if (/\balembic\s+upgrade\b/.test(cmdNorm)) {
    if (!/alembic\s+upgrade.*--sql/.test(cmdNorm)) {
      blockedReason = "alembic upgrade without --sql dry-run";
    }
  }

  // Django migrate (without --plan)
  if (!blockedReason && /manage\.py\s+migrate\b/.test(cmdNorm)) {
    if (!/manage\.py\s+migrate\s+--plan\b/.test(cmdNorm)) {
      blockedReason = "python manage.py migrate without --plan";
    }
  }

  // prisma migrate deploy (production)
  if (!blockedReason && /\bprisma\s+migrate\s+deploy\b/.test(cmdNorm)) {
    if (!/--dry-run/.test(cmdNorm)) {
      blockedReason = "prisma migrate deploy (production)";
    }
  }

  // dbt run/build with prod tag
  if (!blockedReason && /\bdbt\s+(run|build)\b/.test(cmdNorm)) {
    if (/tag:prod/.test(cmdNorm)) {
      blockedReason = "dbt run/build with tag:prod";
    }
  }

  // Direct SQL DROP
  if (!blockedReason && /\b(DROP\s+(TABLE|DATABASE|SCHEMA))\b/i.test(cmdNorm)) {
    blockedReason = "DROP TABLE/DATABASE/SCHEMA detected";
  }

  if (blockedReason) {
    const cmdPreview = cmd.slice(0, 200);
    return {
      block: true,
      severity: "critical",
      reason: `[guard-db-migration] BLOCKED: irreversible DB migration.\n  Reason: ${blockedReason}\n  Cmd:    ${cmdPreview}\n  Required before retry:\n    1. Run dry-run/plan first (alembic upgrade --sql, manage.py migrate --plan,\n       prisma migrate deploy --dry-run, dbt run --select tag:dev).\n    2. Confirm with user via AskUserQuestion — show migration diff.\n    3. Ensure git working tree is clean (git status --porcelain empty).\n    4. Re-run with explicit approval.`,
    };
  }

  return { block: false };
}
