# Loop Engineering · LoopX Upstream Sync System Design Spec

> **状态**:DRAFT · **创建日期**:2026-09-27 · **粒度**:中(模块大纲 + 数据契约 + 失败模式)
> **范围**:Sub-project D · "end-user 装上 loop-engineering 后,LoopX 上游变更每周自动检测 + 冲突 fail-closed + 一键回滚"的同步系统
> **作者**:brainstorming session(7 个决策点对齐后)· 接力关系:本 spec 经用户审核后,交给 `superpowers:writing-plans` 制定实施计划

---

## 0. TL;DR(60 秒读完)

- **交付物**:1 个主文档 `PART-3-5-LOOPX-SYNC.md`(~250 行)+ 8 个 bash 模块 hook(~1100 行)+ 1 个 hook 层 README(~80 行)+ fixtures(~200 行)+ install.sh 集成,~1850 行
- **目标读者**:装上 loop-engineering 的 end-user(macOS / Linux / Windows Git Bash)
- **核心策略**:fail-closed(冲突 → 快照 → 跳过 update → lock + 通知 → user 决定回滚或接受)
- **触发机制**:SessionStart 机会调度 + ≥7 天间隔 + 手动 `loopx-sync.sh --force` 强制跑
- **冲突检测**:3 个 detector(interface 字段 / skill 命令 / hook 行为)全量检测,每个 detector 单文件 < 150 行
- **回滚范围**:`.loopx/state/` + `.loopx/registry.json` + `.codex/goals/` + `.claude/hooks/` + `.claude/guard-rails.yaml`(~50MB 快照)
- **不交付**:LoopX 上游本身改动 / loop-engineering 版本升级(走 Part 3 §3.2)/ 多人协同 / 自动反馈 LoopX
- **工作量**:~8-12 小时(8-task plan,subagent-driven,沿用 Sub-project B 流程)

---

## 1. 背景与目标

### 1.1 Sub-project D 上下文

承接 Sub-project B 完成后的"下一步"承诺:

- **handoff §7**:"Sub-project D · LoopX 上游同步策略 · 跟 LoopX 上游变更 + 升级指南详细文档 · 中等工作量 · 流程文档"
- **Part 3 §3.1**:"日常:LoopX release → 跑 `loopx update --execute --ref main`,重新跑 `loopx doctor --deep` 验 schema 字段未变"(目前手动)
- **Part 3 §3.3**:"Sub-project D 会做自动 weekly sync + 冲突检测(独立文档待写)"(目前未做)

### 1.2 痛点(为什么需要 sync 系统)

| 痛点 | 现状(手动) | 目标(自动) |
|---|---|---|
| 忘记跑 `loopx update` | 完全手动,大部分 end-user 装完就不动了 | SessionStart 每周自动触发 |
| update 后没验证 schema 字段 | 跑 `loopx doctor --deep` 看字段费眼,经常跳过 | interface_detect 自动 diff,变了就告警 |
| SKILL.md 命令漂移没人查 | grep SKILL.md 看命令列表纯人工 | skill_detect 自动 diff 新增/移除/重命名 |
| hook 行为漂移破坏下游契约 | 装新版后 hook 静默改 exit code,出 bug 才查 | hook_detect 跑 fixture 对比 exit code + JSONL |
| update 后挂了,回滚靠 git revert | 没有 loopx 安装前的快照,回滚不彻底 | snapshot 全量(.loopx + hooks),一键 restore |
| 冲突发生时没人通知 | 装了就用,出问题才发现 | SessionStart banner + 桌面通知 + JSONL |

### 1.3 用户原始目标(2026-09-27 校准)

1. **自动 weekly sync**:SessionStart 触发,≥7 天间隔
2. **3 个 detector 全开**:interface / skill / hook 都要查
3. **冲突 fail-closed**:拦下 + 通知 + 等 user 拍板,绝不静默 update
4. **一键回滚**:restore pre-sync snapshot,user 一行命令回原状
5. **跨平台零依赖**:不依赖 systemd / launchd / Task Scheduler,纯 SessionStart shim
6. **end-user 友好**:装上就不管,出问题有桌面通知 + SessionStart banner
7. **可手动 doctor**:`loopx-sync-doctor.sh` 任何时候可跑,看详细报告

### 1.4 范围分解(本 spec 解决的子问题)

- ✅ 8 个 bash 模块的职责 + 接口 + 数据契约
- ✅ state.json / events.jsonl / banner.txt / snapshot 目录的 schema
- ✅ 3 个 detector 的检测方法 + 冲突判定规则
- ✅ fail-closed 流程的完整时序(快照 → update → detect → lock → notify → user)
- ✅ 失败模式 + 边界条件 + 缓解策略
- ✅ 测试计划(单元 + 集成 + 跨平台)
- ✅ 主文档结构(`PART-3-5-LOOPX-SYNC.md` 章节大纲)
- ✅ 实施阶段元信息(8 task 分解 + 工作量 + 依赖)

### 1.5 不交付(明确边界)

- ❌ LoopX 上游本身的开发 / 改 LoopX 源码
- ❌ loop-engineering 自身版本升级(走 `bash install.sh --upgrade`,Part 3 §3.2)
- ❌ 多人协同 / 团队同步(本设计 = 单机单 user)
- ❌ 跟 LoopX 提 PR / 自动反馈(本系统只检测,不回传)
- ❌ 监控仪表盘 / Web UI
- ❌ 自定义 detector 的复杂插件机制(只暴露一个简单 hook 点,详细机制待后续)

---

## 2. 架构

### 2.1 数据流 + 控制流总图

```
SessionStart hook ── 每次启动触发
       │
       ▼
loopx-sync-check-interval.sh ── last_sync > 7d ?
       │ no → 跳过(零开销)
       │ yes
       ▼
loopx-sync-snapshot.sh ── 快照到 .loopx/snapshots/YYYY-MM-DD-pre-sync/
       │
       ▼
loopx update --execute --ref main
       │
       ▼
loopx-sync-detect-conflicts.sh ── 跑 3 个 detector
   ├─ interface_detect(loopx doctor --deep 字段 diff)
   ├─ skill_detect(SKILL.md loopx* 命令 grep diff)
   └─ hook_detect(5 guard hook exit code + JSONL 格式 diff)
       │
       ├─ conflicts = 0
       │   → 更新 .loopx/sync-state.json(ok)+ 追加 sync-events.jsonl
       │   → 不生成 banner,无桌面通知
       │
       └─ conflicts > 0
           → 更新 state(locked, lock_reason=<drift 类型>)
           → loopx-sync-notify.sh
              ├─ 写 SessionStart banner 到 .loopx/sync-banner.txt
              ├─ 触发桌面通知(Win toast / macOS notification / Linux notify-send)
              └─ 追加 sync-events.jsonl
           → end-user 跑 loopx-sync-doctor.sh 看到 3 个 detector 结果
           → 决定:
              ├─ loopx-sync-restore.sh ← 一键回滚(还原 .loopx/ + 5 hook)
              └─ loopx-sync-clear-lock.sh ← 接受新版本 + 清 lock
```

### 2.2 8 模块职责表

| 模块 | 行数(估) | 职责 | 输入 | 输出 | exit code |
|---|---:|---|---|---|---|
| `loopx-sync.sh` | 80 | orchestrator,按顺序调 5 个子模块 | `$1`=--force(可选)| 调子模块,处理返回 | 0 / 2 |
| `loopx-sync-check-interval.sh` | 50 | 读 state.json,判断 last_sync + N 天 | state.json | stdout: `should_run: true/false` | 0 / 2 |
| `loopx-sync-snapshot.sh` | 120 | make snapshot(.loopx/ + hooks/)| `$1`=date(可选)| 快照目录 + manifest.json | 0 / 2 |
| `loopx-sync-detect-conflicts.sh` | 100 | 调 3 detector,合并结果 | snapshot_path, current_state | stdout: JSON {interface:[],skill:[],hook:[]} | 0 / 2 |
| `loopx-sync-notify.sh` | 80 | 写 banner.txt + 桌面通知 + JSONL | state.json + drift[] | 文件 + JSONL | 0 |
| `loopx-sync-restore.sh` | 150 | 从 snapshot 还原 .loopx/ + hooks/ | `$1`=snapshot_path | 还原报告 | 0 / 2 |
| `loopx-sync-clear-lock.sh` | 70 | 接受当前版本,清 state.lock_reason + 删 banner | state.json | 更新 state | 0 / 2 |
| `loopx-sync-doctor.sh` | 200 | 手动诊断:读 state + 跑 3 detector + 输出报告 | --verbose(可选)| markdown 报告 | 0 / 2 / 4 |

每个模块独立可测,orchestrator 只负责 dispatch。

---

## 3. 文件布局

### 3.1 项目内(本 spec 直接产出)

```
templates/hooks/                                       ← 项目内(已有 hooks/ 目录)
  loopx-sync.sh                                        ← orchestrator(SessionStart 入口)
  loopx-sync-check-interval.sh                         ← should-run 逻辑
  loopx-sync-snapshot.sh                               ← make / restore snapshot
  loopx-sync-detect-conflicts.sh                       ← 3 detector 调度
  loopx-sync-notify.sh                                 ← banner + 桌面通知
  loopx-sync-restore.sh                                ← rollback
  loopx-sync-clear-lock.sh                             ← accept 新版
  loopx-sync-doctor.sh                                 ← 手动排错 + 报告
  loopx-sync-test.sh                                   ← 单元 + 集成测试
  README-loopx-sync.md                                 ← hook 层文档(~80 行,给装的人看)
  _sync-fixtures/                                      ← detector 测试 fixture
    interface/
      doctor-deep-old.json                             ← pre-sync fixture
      doctor-deep-new-conflict.json                    ← 触发 conflict
      doctor-deep-new-ok.json                          ← 无冲突
    skill/
      SKILL-old.md
      SKILL-new-conflict.md
      SKILL-new-ok.md
    hook/
      guard-main-branch-push-old.txt                   ← pre-sync 行为
      guard-main-branch-push-new-conflict.txt          ← 触发 conflict

docs/quality/                                          ← 用户文档
  PART-3-5-LOOPX-SYNC.md                               ← 主文档(NEW,~250 行)
  _sync-examples/                                      ← doctor / restore 输出示例
    doctor-output-sample.md
    restore-output-sample.md

install.sh                                             ← 现有脚本 + 注册 SessionStart hook
```

### 3.2 gitignore 改动

```gitignore
# 追加到 .gitignore(若已有则不重)
.loopx/snapshots/
.loopx/sync-banner.txt
.loopx/sync-events.jsonl
.loopx/sync-state.json
```

理由:本地累积,避免污染 git;state.json 含个人路径不应入仓。

### 3.3 install.sh 改动

```bash
# 在 install.sh 末尾追加 Sub-project D 集成:
if [ "$WITH_LOOPX_SYNC" = "1" ] || [ "$WITH_LOOPX_SYNC" = "true" ]; then
  register_session_start_hook "loopx-sync.sh"
  echo "✓ LoopX sync 系统已启用(每周 SessionStart 自动触发)"
fi
```

`install.sh --with-loopx-sync` 是新 flag,默认不启用(向后兼容)。

---

## 4. 数据格式

### 4.1 `.loopx/sync-state.json`(单文件,常驻)

```json
{
  "schema_version": "1",
  "last_sync_iso": "2026-09-27T08:00:30Z",
  "last_status": "ok|conflict|error|running",
  "loopx_version_before": "1.4.2",
  "loopx_version_after": "1.5.0",
  "conflict_count": 0,
  "lock_reason": null|"interface_drift|skill_drift|hook_drift",
  "snapshot_path": ".loopx/snapshots/2026-09-27-pre-sync/",
  "snapshot_size_mb": 47,
  "warning_accumulator": 0,
  "install_iso": "2026-09-20T10:00:00Z"
}
```

**字段语义**:

- `last_sync_iso`:上次 sync 成功结束时间(状态=ok 或 conflict 都算成功结束)
- `last_status`:`ok`=无冲突 / `conflict`=检出冲突已 lock / `error`=sync 自身失败 / `running`=正在跑(防止重入)
- `lock_reason`:`null`=无锁 / 三选一表示哪个 detector 触发 lock
- `warning_accumulator`:warning 累积计数,达到 3 升级为 conflict(见 §6)
- `install_iso`:首次安装 sync 系统时间,用于"装上多久"

### 4.2 `.loopx/sync-events.jsonl`(append-only,审计)

```jsonl
{"ts":"2026-09-27T08:00:01Z","event":"sync_started","trigger":"SessionStart","loopx_from":"1.4.2","loopx_to":null}
{"ts":"2026-09-27T08:00:05Z","event":"snapshot_created","path":".loopx/snapshots/2026-09-27-pre-sync/","size_mb":47}
{"ts":"2026-09-27T08:00:30Z","event":"sync_completed","status":"ok","conflicts":0,"duration_s":29}
{"ts":"2026-09-27T08:00:31Z","event":"conflict_detected","detector":"interface","drift":["loopx doctor --deep:new field 'replan_after'","loopx quota should-run:removed field 'goal_boundary'"]}
{"ts":"2026-09-27T08:00:32Z","event":"lock_set","reason":"interface_drift","state_path":".loopx/sync-state.json"}
{"ts":"2026-09-27T09:15:22Z","event":"doctor_run","conflicts_shown":2,"action_required":true}
{"ts":"2026-09-27T09:20:11Z","event":"rollback_executed","snapshot_path":".loopx/snapshots/2026-09-27-pre-sync/","restored_files":12}
{"ts":"2026-09-27T09:25:01Z","event":"clear_lock_executed","accepted_version":"1.5.0"}
```

**字段约定**:

- `event`:snake_case 字符串,枚举见 §4.2.1
- `ts`:ISO 8601 UTC
- 其他字段:per event 类型,见 `loopx-sync-notify.sh` 写入处

**§4.2.1 event 枚举**:`sync_started` / `snapshot_created` / `sync_completed` / `conflict_detected` / `lock_set` / `doctor_run` / `rollback_executed` / `clear_lock_executed` / `error` / `timeout`

### 4.3 `.loopx/sync-banner.txt`(SessionStart 读取)

冲突时生成(无冲突则文件不存在 → SessionStart 零干扰):

```
[LoopX 上游] ⚠️ 已检出2 项冲突(2026-09-27 08:00,loopx 1.4.2→1.5.0)
[LoopX 上游] 跑 `bash templates/hooks/loopx-sync-doctor.sh` 查看详情
[LoopX 上游] 或 `bash templates/hooks/loopx-sync-restore.sh` 一键回滚
```

3 行固定格式,首行带 emoji + 时间 + 版本对比,后 2 行是引导命令。

### 4.4 `.loopx/snapshots/<date>-pre-sync/`(快照目录)

```
.loopx/snapshots/2026-09-27-pre-sync/
├── manifest.json                                       ← 元数据
├── loopx-state/                                        ← ~/.loopx/state/ 完整镜像(~10MB)
├── registry.json                                       ← .loopx/registry.json
├── codex-goals/                                        ← .codex/goals/ 完整镜像(~5MB)
└── claude-hooks/                                       ← .claude/hooks/ + .claude/guard-rails.yaml(~30MB)
```

`manifest.json`:

```json
{
  "snapshot_iso": "2026-09-27T08:00:05Z",
  "loopx_version": "1.4.2",
  "trigger": "weekly_sync|manual_restore|install",
  "files": ["loopx-state/state.json","registry.json","codex-goals/goal-001/ACTIVE_GOAL_STATE.md","claude-hooks/guard-main-branch-push.py",...],
  "total_size_mb": 47
}
```

**保留策略**:默认保留 5 份,旧于 30 天的自动删;`~/.claude/loopx-sync.yaml` 可改。

---

## 5. 冲突检测(3 个 detector)

### 5.1 interface_detect(接口字段 diff)

**检测对象**:`loopx doctor --deep` 输出 JSON 的所有字段名 + 类型

**方法**:

1. 跑 `loopx --format json doctor --deep > current-doctor.json`
2. `jq -r 'paths(scalars) as $p | "\($p | join(".")) \(.[$p] | type)"' current-doctor.json` → 字段路径+类型列表
3. 与 pre-sync snapshot 的 `loopx-state/state.json`(同样格式提取)diff
4. 字段差异处理:
   - **新增字段** = error(下游可能依赖,需确认)
   - **缺失字段** = error(下游可能依赖,可能已删)
   - **类型变化**(string → number 等)= error(契约破坏)
   - **值变化但类型同** = warning(可能不破坏契约,但行为可能变)

**冲突输出**:

```json
{
  "detector": "interface",
  "errors": [
    "loopx doctor --deep:new field 'replan_after' at .diagnostics[0]",
    "loopx quota should-run:removed field 'goal_boundary'"
  ],
  "warnings": []
}
```

### 5.2 skill_detect(SKILL.md 命令 grep diff)

**检测对象**:`templates/skills/loopx-project/SKILL.md` 中所有 `loopx <cmd>` 命令 + flag

**方法**:

1. `grep -oE 'loopx [a-z][a-z-]+' SKILL.md | sort -u` → pre-sync 命令列表
2. 当前 SKILL.md 跑同样命令 → 当前列表
3. diff:
   - **新增命令** = error(下游可能依赖)
   - **移除命令** = error(下游可能在用)
   - **重命名命令** = error(grep 表现为先增后删,合并提示)
   - **flag 变化**(`loopx cmd --new-flag`)= warning(累积 3 升级为 error)

### 5.3 hook_detect(5 guard hook 行为 diff)

**检测对象**:5 个 guard hook 的 exit code + JSONL 输出格式

| Hook | 测试输入 | 期望 exit | 期望 JSONL 行 |
|---|---|---|---|
| guard-main-branch-push.py | `git push origin main` | 2 | 1 行 hook_name+block_reason |
| guard-installer-path.sh | `Edit /installer.exe` | 2 | 1 行 hook_name+block_reason |
| guard-package-publish.sh | `npm publish` | 2 | 1 行 hook_name+block_reason |
| guard-secret-files.js | `Write .env` | 2 | 1 行 hook_name+block_reason |
| guard-db-migration.sh | `dbt run --no-review` | 2 | 1 行 hook_name+block_reason |

**方法**:

1. 对每个 hook,跑 fixture 输入 + 捕获 exit code + 捕获 stdout/stderr
2. 与 pre-sync snapshot 中的 `_sync-fixtures/hook/*.txt`(已知期望输出)diff
3. 差异处理:
   - **exit code 变化** = error(契约破坏)
   - **JSONL 字段缺失** = error(下游解析会挂)
   - **stdout 文案变化** = warning(可能不破坏,但 UI 提示变了)

### 5.4 冲突判定 + warning 累积

```bash
# 简化伪代码,实际在 loopx-sync-detect-conflicts.sh
errors=$(detector_output | jq '.errors | length')
warnings=$(detector_output | jq '.warnings | length')

if [ "$errors" -gt 0 ]; then
  conflict=true
  lock_reason=$detector_name
else
  new_accumulator=$((state.warning_accumulator + warnings))
  if [ "$new_accumulator" -ge 3 ]; then
    conflict=true
    lock_reason="warning_threshold"
  fi
fi
```

- 任 1 个 detector 报 error → 立即 conflict + lock
- 全 detector 只 warning → 累积,达 3 升级为 conflict(避免慢慢漂移没人管)
- detector 自身 fail(脚本崩)→ 不算 conflict,只记 `event:error`,state=error,不 lock(避免 detector bug 误锁)

---

## 6. 失败模式 + 缓解

| 失败 | 严重度 | 系统反应 |
|---|---|---|
| SessionStart hook 超时(>3s) | 低 | 跳过本轮,下轮再试;JSONL 记 `event:timeout` |
| snapshot 创建失败(磁盘满) | 中 | 中止 sync,state=error,通知 user 删旧快照 |
| `loopx update` 失败(网络不通) | 中 | 此时 snapshot 已建,restore snapshot(其实无变化),state=error |
| `loopx update` 失败(版本不可达) | 中 | 同上,state=error |
| detector 脚本自身 fail | 低 | state=error,不 lock;JSONL 记 fail 堆栈 |
| doctor 跑时 sync 进行中 | 低 | 拒绝,提示 `状态=running,等 X 秒` |
| restore 跑时无 snapshot | 低 | 拒绝,提示 `无快照可还原,请接受当前版本` |
| restore 跑时当前已是最新版 | 低 | 提示 `已是 pre-sync 版本,无操作必要` |
| 桌面通知失败(Win toast API 不可用) | 低 | 仅写 banner + JSONL,跳过桌面通知,日志记 warning |
| 用户手动改了 .loopx/sync-state.json | 中 | 不防御,JSONL 仍 append 正确事件;下次 sync 重写 state |
| 跨平台 bash 差异(msys 没有 `realpath`) | 中 | 用 `python3 -c "import os; print(os.path.realpath(...))"` 或 wrapper 函数 |
| state.json schema 损坏 | 中 | 视为首次安装,重建 state(空 last_sync → 立即跑一次) |

---

## 7. 测试计划

### 7.1 单元测试(per 模块,每模块 ≥1 case)

| 模块 | 测试 case |
|---|---|
| check-interval | (1) now > last_sync+7d → run · (2) now < 7d → skip · (3) state.json 不存在 → run(首次)· (4) state.status=running → skip(防重入) |
| snapshot | (1) make + restore roundtrip,文件完整性 · (2) manifest.json 字段正确 · (3) 磁盘满 → exit 2 |
| detect-conflicts | (1) 干净 fixture → conflict=0 · (2) interface 漂移 fixture → conflict=1 · (3) skill 漂移 fixture → conflict=1 · (4) hook 漂移 fixture → conflict=1 · (5) detector 自身崩 → state=error(不 lock) |
| notify | (1) banner.txt 3 行格式正确 · (2) 桌面通知失败 → 仅 banner + JSONL · (3) JSONL event 字段全 |
| restore | (1) 完整 snapshot 还原 · (2) 缺 snapshot → exit 2 + 友好提示 · (3) 还原后 state.json 更新 |
| clear-lock | (1) 清 lock_reason · (2) 删 banner.txt · (3) state.last_status=ok |
| doctor | (1) 干净 state → 输出"无冲突" · (2) conflict state → 输出 3 个 detector 详情 · (3) --verbose 模式附加 raw JSONL 末 10 行 |

### 7.2 集成测试(全链路)

| 测试 case | 流程 |
|---|---|
| happy path | 干净 state → 跑 sync → conflict=0 → state=ok → 无 banner |
| fail-closed path | 模拟 interface 漂移 → state.lock_reason=set → banner 生成 → 跑 restore → state 清 lock + version 回滚到 pre-sync |
| warning 累积 | 3 次 sync 每次 1 warning → 第 3 次升级为 conflict + lock |
| 间隔跳过 | 跑 2 次 sync(间隔 < 7d)→ 第 2 次因 last_sync < 7d 跳过 |
| accept 新版 | conflict 后跑 clear-lock → state 清 lock + 更新 loopx_version_after 为 accepted |
| 重入保护 | 同时跑 2 个 sync.sh → 第 2 个因 state.status=running 立即 exit |

### 7.3 跨平台 CI(GitHub Actions matrix)

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
```

- 全跑 `bash templates/hooks/loopx-sync-test.sh`
- 全跑 `bash templates/hooks/loopx-sync.sh --force`(强制,绕过 interval check)
- 全跑 happy path + fail-closed path 集成测试

### 7.4 不测

- ❌ LoopX 实际 update 行为(那由 LoopX 团队负责)
- ❌ 桌面通知 API 在所有 Windows 版本上的兼容性(只测当前 GH Action runner)
- ❌ 真实跨用户并发(本设计 = 单机单 user)

---

## 8. 主文档结构(`docs/quality/PART-3-5-LOOPX-SYNC.md`)

```markdown
# Part 3.5 · LoopX 上游同步系统

> 承接: Part 3 §3.1(LoopX 上游变更同步)+ §3.3(自动 weekly sync + 冲突检测)

## §1 为什么需要 sync(2 段)
- 背景:LoopX 是上游,变更会破坏下游契约
- 现状:手动 sync 容易忘,sync 后没有冲突验证

## §2 weekly 流程图(mermaid)
- 从 SessionStart 到 banner 触发的完整流程(参考 §2.1 ASCII 图改 mermaid)

## §3 装上 + 配置(5 min)
- `bash install.sh --with-loopx-sync` 一键启用
- 配置:`~/.claude/loopx-sync.yaml`(sync_interval_days / snapshot_keep / desktop_notify)
- 验证:`bash templates/hooks/loopx-sync-doctor.sh` 跑一次

## §4 冲突后怎么办(decision tree)
- 跑 doctor → 看 3 个 detector 结果
- 决策 A:一键回滚 → `loopx-sync-restore.sh`(适用:严重漂移 / 不熟悉新版本)
- 决策 B:接受新版本 → `loopx-sync-clear-lock.sh`(适用:已读 changelog + 自愿升级)
- 决策 C:手动 reconfigure → 修 .claude/guard-rails.yaml 等

## §5 跨平台 shim 说明(短)
- 为什么用 SessionStart 机会调度(零平台依赖)
- 何时跑不到(无网络 / 容器内 / CI 环境)

## §6 高级:定制检测阈值(短)
- warning 累积阈值(default=3 → 升级为 conflict)
- 快照保留数(default=5 → 删旧)
- detector 单独禁用

## §7 FAQ(8-10 条)
- Q1: 怎么手动立刻跑一次?(=`bash templates/hooks/loopx-sync.sh --force`)
- Q2: 桌面通知能关吗?(= 关 ~/.claude/loopx-sync.yaml 的 desktop_notify)
- Q3: 快照占多少空间?(~50MB × 保留数)
- Q4: 我已经手动 `loopx update` 过,sync 系统会重复吗?(= 不会,先检查 state)
- Q5: 怎么加入自己的 detector?(= 写一个 .sh 接受 input 路径,输出 0/2,放到 _sync-fixtures/detectors/)
- Q6: sync 系统跑挂了,怎么关掉?(= 卸载 SessionStart hook 挂载)
- Q7: state.json 损坏了怎么办?(= 自动重建为首次安装状态,下次 sync 重跑)
- Q8: warning 累积到 3 一定要回滚吗?(= 不一定,只是触发 banner,可以跑 doctor 看 detail)
```

---

## 9. 交付节奏(8 task plan)

| Task | 标题 | 产出 | 估时 |
|---|---|---|---|
| 1 | 写 spec(本文档)+ 用户审核 | 本文件 + commit | 已完成 |
| 2 | interval + snapshot 模块 | loopx-sync-check-interval.sh + loopx-sync-snapshot.sh + 单测 | 1.5h |
| 3 | 3 detector + detect 调度器 | loopx-sync-detect-conflicts.sh + 3 detector 子脚本 + fixtures | 3h |
| 4 | notify + SessionStart 集成 | loopx-sync-notify.sh + install.sh --with-loopx-sync 改动 + cross-platform notify | 2h |
| 5 | doctor + restore + clear-lock | loopx-sync-doctor.sh + loopx-sync-restore.sh + loopx-sync-clear-lock.sh | 2.5h |
| 6 | 集成测试 + 跨平台 CI | loopx-sync-test.sh + GH Actions matrix workflow | 1.5h |
| 7 | 主文档 PART-3-5-LOOPX-SYNC.md | ~250 行 markdown | 1.5h |
| 8 | 全验证 + push | wc + grep + GH Actions 通过 + push origin/main | 1h |

**总估时**:~13h(实测 subagent-driven 通常 70% 时间,即 ~9h)
**总代码量**:~1850 行(bash ~1100 + docs ~250 + fixtures ~200 + 测试 ~200)
**实施模式**:Subagent-Driven(沿用 Sub-project B 流程)

---

## 10. 风险 + 缓解

| 风险 | 严重度 | 缓解 |
|---|---|---|
| SessionStart 触发每次启动,可能太频繁 | 中 | check-interval 模块强制 ≥7d 间隔,跳过不写日志 |
| `loopx update` 在用户机器上不可达(中国网络/防火墙) | 中 | detector 不强依赖 update 成功;失败 → state=error + 不锁,下周再试 |
| detector 误报(用户改了 SKILL.md 算漂移?) | 高 | detector 只跑 `templates/skills/loopx-project/SKILL.md`(loop-engineering 仓库内的),跳过用户项目内副本 |
| 快照累积占磁盘(50MB × 5 = 250MB) | 低 | 默认保留 5 份,旧于 30 天自动删;`loopx-sync.yaml` 可改 |
| LoopX 改了脚本路径(比如 SKILL.md 改名 / hook 文件搬位置) | 中 | skill_detect 找不到文件 → state=error(不 lock);interface_detect 抓 doctor 输出新增字段(如 skill path 字段变)→ conflict + lock |
| 用户装了但没启用 SessionStart hook | 低 | install.sh 装时强制注册;若用户主动卸载,sync 系统降级为手动(`loopx-sync.sh --manual`) |
| 跨平台 bash 差异 | 中 | 全程用 POSIX bash + 避开 msys/GNU-only 命令;CI 矩阵三平台验证 |
| install.sh 改动破坏旧用户 | 中 | 新 flag `--with-loopx-sync` 默认不启用,向后兼容 100% |
| detector 自身 bug 触发误锁 | 中 | detector 失败 → state=error 而非 conflict,不锁;下周 detector 修了自动恢复 |
| 真实生产数据回填前 JSONL 数字是合成的 | 低 | 本 spec 不引入新数字;若 Part 3.5 文档需要 ROI 数据,明示"[来源:合成]" |

---

## 11. 关联交付(本 spec 之外,给读者索引)

| 文件 | 用途 | 何时用 |
|---|---|---|
| Sub-project B spec | 整个 loop-engineering 项目设计基线 | 任何修订前先看 |
| Sub-project B plan | Sub-project B 10-task 流程 | 复盘 SDD 流程 |
| `docs/quality/PART-3-TUNING-FAQ.md` | Part 3 上半部(Q&A) | 修订 Part 3.5 时衔接 |
| `templates/skills/loopx-project/SKILL.md` | LoopX skill 实际定义 | detector 命中后查看命令定义 |
| `templates/hooks/README.md` | 已有 hooks 文档 | 注册 SessionStart hook 时参考 |

---

## 12. 关联 spec / plan / 文档 commit 路径

- **本 spec**:`docs/superpowers/specs/2026-09-27-loopx-upstream-sync-design.md`
- **实施 plan**(待写):`docs/superpowers/plans/2026-09-27-loopx-upstream-sync-plan.md`
- **进度 ledger**(待建):`.superpowers/sdd/2026-09-27-loopx-upstream-sync-plan/progress.md`
- **handoff**(完工后):`handoff-loop-engineering-loopx-sync-done-YYYY-MM-DD.md`

---

*本文档由 Sub-project D brainstorming session(7 个决策点对齐)产出,接力关系:经用户审核 → superpowers:writing-plans → 8-task 实施 → push origin/main*