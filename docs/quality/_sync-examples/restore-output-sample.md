# Restore 输出示例 · 成功回滚

```bash
$ bash templates/hooks/loopx-sync-restore.sh

→ 还原 .loopx/snapshots/2026-09-27-080030-pre-sync/ → .claude/hooks + .loopx
restored: 4
snapshot: .loopx/snapshots/2026-09-27-080030-pre-sync/

✓ 回滚完成。下次 SessionStart banner 会清掉。
```

`restored: 4` 表示还原了 4 个分组(loopx state + registry + codex goals + hooks)。
