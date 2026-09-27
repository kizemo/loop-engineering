# Part 3.5 · LoopX 上游同步系统

> **承接**:[Part 3 §3.1](PART-3-TUNING-FAQ.md#31-loopx-上游变更同步)(LoopX 上游变更同步)
> **目标读者**:装上 loop-engineering 的 end-user,想知道"LoopX 升级后 hook 还正常吗,怎么知道/怎么办"
> **安装**:`bash install.sh --with-loopx-sync`

---

## §1 为什么需要 sync(2 段)

LoopX 是 loop-engineering 的上游(提供 `loopx doctor / quota / update` 等命令)。LoopX 每次 release 可能改 schema 字段、新增/移除命令、调整 hook 行为契约。如果不验证就 update,下游 hook 会静默挂掉(silent break)。

loop-engineering Sub-project D 提供自动 weekly sync:SessionStart 触发 → snapshot 当前状态 → 跑 `loopx update` → 3 个 detector 验证下游契约 → 冲突 fail-closed 拦下 + 通知 + 一键回滚。

---

## §2 weekly 流程图

```
[SessionStart] ─→ [check-interval] (≥7d?)
   │ no → skip(零开销)
   │ yes
   ▼
[snapshot] ─→ [loopx update] ─→ [3 detector]
   │                                  │ conflicts=0
   │                                  ▼
   │                            state=ok(无通知)
   │                                  │ conflicts>0
   │                                  ▼
   │                         [notify: banner + 桌面 + JSONL]
   │                                  ▼
   │                         state.lock_reason=set
   ▼
[user 跑 doctor] → 决定 → 回滚 / 接受 / 手动 reconfigure
```

---

## §3 装上 + 配置(5 min)

```bash
bash install.sh --with-loopx-sync
```

可选配置:`~/.claude/loopx-sync.yaml`:

```yaml
sync_interval_days: 7       # 默认 7
snapshot_keep: 5            # 默认保留 5 份
desktop_notify: true        # 默认 true
```

验证:`bash templates/hooks/loopx-sync-doctor.sh` 跑一次,期望输出 "✓ 当前状态正常"。

---

## §4 冲突后怎么办(decision tree)

```
[检出冲突]
   │
   ├─ 跑 bash templates/hooks/loopx-sync-doctor.sh 看 3 个 detector 结果
   │
   ├─ 决策 A:一键回滚(适用:严重漂移 / 不熟悉新版本)
   │    bash templates/hooks/loopx-sync-restore.sh
   │
   ├─ 决策 B:接受新版本(适用:已读 changelog + 自愿升级)
   │    bash templates/hooks/loopx-sync-clear-lock.sh
   │
   └─ 决策 C:手动 reconfigure
        # 修 .claude/guard-rails.yaml 等,再跑 clear-lock
```

详细 doctor 输出示例见 [`_sync-examples/doctor-output-sample.md`](_sync-examples/doctor-output-sample.md)。

---

## §5 跨平台 shim 说明

为什么不依赖 systemd / launchd / Task Scheduler?

- **零平台依赖**:不写系统级配置,不需要 sudo
- **可移植**:Windows / macOS / Linux 同一份代码
- **机会调度**:SessionStart 触发 = 用户每次启动 Claude Code 才跑;不开 Claude = 不跑(对低频用户友好)

**何时跑不到**:
- 容器内(无 SessionStart)
- CI 环境(无 Claude Code 启动)
- 用户 1 个月没开 Claude(超过 7d 后下次启动立即跑)

---

## §6 高级:定制检测阈值

| 配置 | 默认 | 说明 |
|---|---|---|
| `warning_accumulator_threshold` | 3 | warning 累积到此数升级为 conflict |
| `snapshot_keep` | 5 | 旧于此份数的快照自动删 |
| `disabled_detectors` | `[]` | 列表,可填 `interface` / `skill` / `hook` 关闭单个 detector |

高级配置写 `~/.claude/loopx-sync.yaml` 后重启 Claude Code 生效。

---

## §7 FAQ(8 条)

### Q1: 怎么手动立刻跑一次 sync?

```bash
bash templates/hooks/loopx-sync.sh --force
```

### Q2: 桌面通知能关吗?

在 `~/.claude/loopx-sync.yaml` 设 `desktop_notify: false`。

### Q3: 快照占多少空间?

每份 ~50MB(.loopx state + hooks),默认保留 5 份 = ~250MB。

### Q4: 我已经手动 `loopx update` 过,sync 系统会重复吗?

不会。sync 系统先读 state.json,如果你刚手动 update 过,doctor 输出还是新的,detector 不会无故报 conflict。

### Q5: 怎么加入自己的 detector?

写一个 bash 脚本,接受 `--old <path> --new <path>`,输出 JSON `{"errors":["..."],"warnings":["..."]}`,放到 `templates/hooks/_sync-fixtures/detectors/<your-detector>.sh`,然后改 `loopx-sync-detect-conflicts.sh` 调用它。

### Q6: sync 系统跑挂了,怎么关掉?

从 `~/.claude/settings.json` 的 `hooks.SessionStart` 数组里移除 loopx-sync.sh 项,重启 Claude Code。

### Q7: state.json 损坏了怎么办?

自动重建为首次安装状态,下次 sync 重跑(因为 last_sync=空 → 立即跑)。

### Q8: warning 累积到 3 一定要回滚吗?

不一定。warning 升级为 conflict 只是触发 banner,你可以跑 doctor 看 detail,可能只是字段值变了不影响契约。

---

## 关联文档

- [Part 3 §3.1](PART-3-TUNING-FAQ.md#31-loopx-上游变更同步) — 上游变更同步(原 Part 3 内容)
- [Part 2.1 · 5 原语统一结构](PART-2-1-PRIMITIVES.md#0-5-原语统一结构) — LoopX 5 原语理论
- [Part 2.3 §1](PART-2-3-ASSETS.md#1--5-hook-速查表) — hook 速查表
- [spec §5](../superpowers/specs/2026-09-27-loopx-upstream-sync-design.md#5-冲突检测3-个-detector) — 详细设计
