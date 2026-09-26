---
name: guard-rails-summary
description: Summarize BLOCK events from the 5 project-level guard-rails hooks. Reads .loopx/guard-events-YYYY-MM-DD.jsonl files (one per day) and produces a markdown summary grouped by hook, tool, reason, and project. Use when the user asks "what did the hooks block today?", "any guard rail hits this week?", "show me guard-rails summary", or invokes this skill explicitly.
---

# guard-rails-summary

Read all `.loopx/guard-events-*.jsonl` files in the current project (or specified `--project-root`) and produce a markdown summary.

## Source of truth

The 5 project-level guard hooks (in `<project>/.claude/hooks/`) append a JSONL line on every BLOCK:

- `guard-secret-files.js` — Edit/Write to secret paths
- `guard-main-branch-push.py` — Bash `git push origin main`
- `guard-db-migration.sh` — Bash destructive migrations
- `guard-package-publish.sh` — Bash package publishes
- `guard-installer-path.sh` — Bash installer writes outside allowlist

Each event:

```json
{
  "ts": "2026-09-25T16:30:42Z",
  "hook": "guard-secret-files",
  "tool": "Edit",
  "input_summary": "file_path=src/.env",
  "reason": "writing to secret path",
  "exit_code": 2,
  "cwd": "F:/soft/00selfmade/rime_claude",
  "project": "rime-claude"
}
```

## How to run

```bash
# Default: scan cwd/.loopx/guard-events-*.jsonl
~/.claude/hooks/templates/loopx-guard-summary.sh

# Or specify project root
~/.claude/hooks/templates/loopx-guard-summary.sh --root F:/soft/00selfmade/rime_claude

# Or filter by date / hook
~/.claude/hooks/templates/loopx-guard-summary.sh --since 2026-09-20 --hook guard-secret-files
```

## Output format (markdown)

```
# Guard-Rails Summary

- project: `rime-claude`
- events_total: 12
- date_range: 2026-09-20 → 2026-09-25
- by_hook: { guard-secret-files: 5, guard-main-branch-push: 4, ... }

## By hook

### guard-secret-files (5)
- 2026-09-25T16:30:42Z — Edit — src/.env — writing to secret path
- ...

### guard-main-branch-push (4)
- 2026-09-24T11:00:00Z — Bash — git push origin main — direct push to protected ref
- ...

## Recommendations

- Hot patterns: ...
- Hooks with no events today: ...
```

## When to use this skill

- End-of-day review: "Did anything get blocked?"
- In a LoopX review packet: include `guard-rails-summary` output as one section
- When user explicitly asks to summarize or audit the hooks

## When NOT to use this

- ❌ Real-time hook invocations (hooks write to JSONL themselves; this skill READS)
- ❌ To bypass or modify hooks (use the hooks themselves)
- ❌ For projects without `.loopx/guard-events-*.jsonl` (skill will say "no events")

## Files

- `~/.claude/hooks/templates/loopx-guard-summary.sh` — the script
- `~/.claude/hooks/templates/guard-event-writer.{sh,py}` — the writers hooks call