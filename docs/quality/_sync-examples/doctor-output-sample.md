# Doctor 输出示例 · 冲突状态

```bash
$ bash templates/hooks/loopx-sync-doctor.sh

## LoopX Sync Doctor 报告

| 字段 | 值 |
|---|---|
| last_sync_iso | 2026-09-27T08:00:30Z |
| last_status | conflict |
| loopx 版本 | 1.4.2 → 1.5.0 |
| conflict_count | 2 |
| lock_reason | interface_drift |
| snapshot | .loopx/snapshots/2026-09-27-080030-pre-sync/ |

### ⚠️ 检测到冲突

**lock_reason**: interface_drift

### 决策选项

- **回滚**(`bash templates/hooks/loopx-sync-restore.sh`):还原到 snapshot 版本,适合不熟悉新版本
- **接受**(`bash templates/hooks/loopx-sync-clear-lock.sh`):已读 changelog,自愿升级
- **手动 reconfigure**:修 .claude/guard-rails.yaml 等

exit code: 2
```
