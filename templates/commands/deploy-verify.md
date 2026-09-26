---
description: Deploy & verify installer via Windows Sandbox (rime-claude / weavepage)
---

# /deploy-verify

Run installer verification in **Windows Sandbox** (isolation guarantees the host is not modified). Wraps `F:\soft\00selfmade\sandbox-verify\{rime-claude,weavepage}\{rime,weavepage}-verify.ps1` with project auto-detection and installer-path inference.

## Usage

```
/deploy-verify                                  # auto-detect project from cwd
/deploy-verify rime-claude                      # explicit project
/deploy-verify weavepage                        # explicit project
/deploy-verify rime-claude -InstallerPath "F:\path\to\fluxing-0.21.0.1-installer.exe"
/deploy-verify rime-claude -SandboxOnly         # rime only: layout + PE check, no install
/deploy-verify weavepage -OldInstaller "..." -NewInstaller "..."  # weavepage scenario A (upgrade)
/deploy-verify rime-claude -Wait                # block until verify.log appears (default: NoWait)
```

## What it does

1. **Resolve project**: explicit arg wins; else cwd pattern (`*rime_claude*` → rime-claude; `*weavepage*` or `*tiptap_app*` → weavepage). Errors if neither.
2. **Resolve InstallerPath**: explicit arg wins; else glob the project's build output dir and pick the file with newest mtime. Patterns:
   - rime: `F:\soft\00selfmade\rime_claude\output\archives\fluxing-*-installer.exe` then `release\fluxing-*-installer.exe`
   - weavepage: `F:\soft\00selfmade\tiptap_app\release\WeavePage_*-setup.exe` then `release\WeavePage_*-update.exe`
3. **Stage installer** in `C:\Users\Duanyi\sandbox-artifacts\{project}\installers\`
4. **Launch Windows Sandbox** via `WindowsSandbox.exe <wsb-path>` (mapped folders = staged installer + artifacts root)
5. **Sandbox-internal script** runs: install → snapshot verify → uninstall → screenshot → write `verify.log`
6. **Wait for log** (only when `-Wait`): poll up to 10 min (rime) / 15 min (weavepage). Print colored [PASS]/[FAIL] summary.

Default behavior: **NoWait** (returns immediately after launching). First run should keep this so the user can see the Sandbox window.

## Project map (project key → subdir / verify script)

| project key  | subdir under sandbox-verify | verify script              | build output root             |
|--------------|------------------------------|----------------------------|-------------------------------|
| `rime-claude`| `rime-claude/`               | `rime-verify.ps1`          | `F:\soft\00selfmade\rime_claude` |
| `weavepage`  | `weavepage/`                 | `weavepage-verify.ps1`     | `F:\soft\00selfmade\tiptap_app`   |

> **Note**: `media-to-doc-ui` does NOT have a verify script under sandbox-verify. If you need MTD verification, set it up first by mirroring the rime-claude/ pattern (see `F:\soft\00selfmade\sandbox-verify\README.md`).

## Log locations

- rime: `C:\Users\Duanyi\sandbox-artifacts\rime\logs\verify.log`
- weavepage: `C:\Users\Duanyi\sandbox-artifacts\weavepage\logs\verify.log`
- Screenshots: `<same root>\screenshots\screenshot.png`

## Implementation

- Dispatcher: `C:\Users\Duanyi\.local\bin\deploy-verify.ps1` (PowerShell, BOM-encoded UTF-8)
- Forwarded: `F:\soft\00selfmade\sandbox-verify\{subdir}\{verify-script}.ps1`

## When NOT to use this

- ❌ Testing dev build with debug logs → use the project's own dev/test workflow directly
- ❌ Cross-platform packaging test → Windows Sandbox is Windows-only
- ❌ Long-running soak test → Sandbox resets on close (max ~hour)
- ❌ Anything that needs persisted state → Sandbox is ephemeral

## Related

- Sandbox-verify README: `F:\soft\00selfmade\sandbox-verify\README.md`
- User memory: `feedback_win11_sandbox_vmcompute_restart.md` (Win11 24H2 vmcompute flake)
- Handoff: `E:\办公文件\H AI\项目研究\handoff-loop-engineering-p1-4-2026-09-25.md`