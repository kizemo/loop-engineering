# LoopX Sync Hooks

> Sub-project D · SessionStart 机会调度 + 3 detector + fail-closed + 一键回滚

## 文件清单

| 文件 | 用途 |
|---|---|
| `loopx-sync.sh` | orchestrator(SessionStart 入口) |
| `loopx-sync-check-interval.sh` | should-run 逻辑(≥7d) |
| `loopx-sync-snapshot.sh` | make / restore snapshot |
| `loopx-sync-detect-conflicts.sh` | 跑 3 detector |
| `loopx-sync-notify.sh` | banner + 桌面通知 + JSONL |
| `loopx-sync-restore.sh` | 一键回滚 |
| `loopx-sync-clear-lock.sh` | 接受新版本 + 清 lock |
| `loopx-sync-doctor.sh` | 手动排错报告 |
| `loopx-sync-test.sh` | 集成测试 |
| `_sync-fixtures/` | detector 测试 fixture |

## 装上

```bash
bash install.sh --with-loopx-sync
```

卸载:从 `~/.claude/settings.json` 的 `hooks.SessionStart` 数组里移除 loopx-sync.sh 项,重启 Claude Code。

## 手动命令

| 命令 | 用途 |
|---|---|
| `bash templates/hooks/loopx-sync.sh --force` | 立即跑一次 sync(绕过 interval) |
| `bash templates/hooks/loopx-sync-doctor.sh` | 看详细诊断报告 |
| `bash templates/hooks/loopx-sync-restore.sh` | 一键回滚 |
| `bash templates/hooks/loopx-sync-clear-lock.sh` | 接受新版本 |
| `bash templates/hooks/loopx-sync-test.sh` | 跑集成测试 |

## 详细文档

见 `docs/quality/PART-3-5-LOOPX-SYNC.md`