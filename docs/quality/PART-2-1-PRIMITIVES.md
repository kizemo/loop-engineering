# Part 2.1 · LoopX 5 原语理论(5 Primitives)

> **读者**:刚装好 loop-engineering、想系统性理解"5 原语到底是什么、本项目怎么用起来"的工程师
> **目标**:30 分钟读完 — 之后能对照 `loopx doctor --deep` 输出来调自己项目
> **数据截止**:2026-09-25 单日合成拦截日志(`_data-extract-notes.md` §1)
> **承接文档**:[README.md](README.md) · [Part 1](PART-1-DECISION-FRAMEWORK.md) · [Part 2.2](PART-2-2-SCENARIOS.md) · [Part 2.3](PART-2-3-ASSETS.md)

---

## 0. 5 原语统一结构

本节每个原语按同一模板讲解,跨原语跳读无学习成本:

```
### 原语 N · [英文名]([中文名])
#### 是什么
[LoopX 原始定义 2-3 句]
#### 本项目怎么实现
[CLAUDE.md + LoopX skill + hooks/playbooks 的具体配置,带相对路径链]
#### 怎么验证
[具体命令输出 / hook 测试命令 / 路径计数]
```

理论来源:LoopX 5 原语 = `Objective / Todo / Gate / Evidence / Quota`,见 spec §5.3。

---

### 原语 1 · Objective(目标)

#### 是什么

Agent **任何时候**都知道自己要做什么。每接到一条任务(`/loopx <goal text>`),首先把自然语言 goal 编译成一个**机器可读的 objective**(一段稳定文本 + stable goal-id),后续所有 Todo / Evidence / Quota 调用都挂在它下面。**没有 objective = 没有 goal = 不应该跑**(LoopX fail-closed)。

#### 本项目怎么实现

- **根 `CLAUDE.md` 顶部「会话级纪律」段**:明确当前任务的 objective(本页 = "写 Part 2.1,30 min 内"),并写明"完成就提交、不反复"
- **`templates/skills/loopx-project/SKILL.md`** 是 LoopX 的"目标编译 skill",带 `loopx start-goal --guided --project . --goal-text "<GOAL_TEXT>"` 命令(见 SKILL.md line 69)
- **`playbooks/B-long-research/TODO-TOPIC.md`** 是**长调研的 objective 模板**:写目标、范围、done 标准
- **`playbooks/B-long-research/LOOPX-CONNECT-CMD.md`** 教新项目怎么 `loopx connect`,落地 `.loopx/registry.json` 和 `.codex/goals/<goal-id>/ACTIVE_GOAL_STATE.md`

#### 怎么验证

```bash
loopx doctor --deep   # 期望输出含 "objective" / "goal_id" 字段非空
loopx --format json status --goal-id <STABLE_GOAL_ID>   # 期望返回 objective 文本 + stable id
```

读输出:`goal_id` 应是稳定的(如 `goal-2.13-...` 形式),`objective` 文本应能在 30 秒内复述。如果 `objective` 是空或 "null" → 回 `loopx connect` 重连。

---

### 原语 2 · Todo(待办)

#### 是什么

**多 Agent 不抢同一份代码**:每个 Agent 在改文件前,先在 `.codex/goals/<goal-id>/todos.md` 登记"我要改哪行、为什么",别的 Agent 看到有人 hold 就改别的文件或排队。Todo = lease(租约),超时自动释放。**没有 Todo = 不允许写代码**(spec §5.3 原语 2)。

#### 本项目怎么实现

- **`playbooks/B-long-research/SUB-AGENT-CONFIG.yaml`** 是 sub-agent 的"Todo 行为配置模板":3 个 sub-agent(github-data-fetcher / doc-fetcher / reddit-fetcher)各自登记 scope、避免重复抓同一仓库
- **`templates/skills/loopx-project/SKILL.md`** 在 `Todo` 命令段(line ~80)规定:Todo 命令必须带 `--agent-id <REGISTERED_AGENT_ID>`,防止"假冒别人 hold 文件"
- **`playbooks/A-pr-review/CLAUDE-MD-RULES.md`** 给 PR review agent 定义 Todo 粒度(一个 PR 一个 todo,跨 PR 不共享)
- **本项目当前实践**:单人接力,Todo 由 `handoff-<topic>-<date>.md` 承担,不直接用 LoopX Todo 命令(详见 SKILL.md §Todo;⚠️ 待 Sub-project D 校准 LoopX 上游用法)

#### 怎么验证

```bash
loopx --format json status --goal-id <STABLE_GOAL_ID>   # 期望 user_todos[] / agent_todos[] 两层分开
```

输出含 `user_todos`(人给的)和 `agent_todos`(sub-agent 自登记)两组,**分别不超过当前 goal 的 sub-task 数**。如果两层没分开或乱成一锅 → sub-agent 配置错了,回去改 `SUB-AGENT-CONFIG.yaml` 的 `tools` / `description`。

---

### 原语 3 · Gate(人工门禁)

#### 是什么

**危险操作必须人拍板**:Agent 不能自己跑 `git push origin main` / `npm publish` / 写 `.env` 密钥 / 跑未审过的 DB migration。任何"改了不可逆"的操作前必须有人 review 或显式批准。Gate = 一组 pre-tool 拦截 hook。

#### 本项目怎么实现

- **5 道项目级 guard rail hook**(详见 spec §附录 A + Part 2.3 §1 速查表):
  - `templates/hooks/guard-main-branch-push.py` — 拦 `git push origin main`
  - `templates/hooks/guard-installer-path.sh` — 拦 Edit/Write 误写到项目根目录
  - `templates/hooks/guard-package-publish.sh` — 拦 `npm publish` / `cargo publish`
  - `templates/hooks/guard-secret-files.js` — 拦写 `.env` / `id_rsa` / `credentials.json`
  - `templates/hooks/guard-db-migration.sh` — 拦未带 `--review` 的 dbt/alembic 迁移
- **`templates/hooks/guard-rails-test.sh`** 是 5 hook 的**单元测试**:`bash .claude/hooks/guard-rails-test.sh` 跑 happy path + block path
- **安装方式**:`bash install.sh`(详见 Part 1 §1.3 迁移成本)

#### 怎么验证

```bash
bash .claude/hooks/guard-rails-test.sh                       # 跑 5 hook 单元测试,期望 PASS
ls .loopx/guard-events-*.jsonl 2>/dev/null | head -5        # 期望今日 JSONL 已生成
cat .loopx/guard-events-$(date +%Y-%m-%d).jsonl | wc -l     # 期望 ≥ 5(每 hook 至少 1 条 happy)
```

如果 `guard-rails-test.sh` 有 FAIL → 看 `templates/hooks/README.md` 修。如果 JSONL 文件数 = 0 → hook 没挂上,查 `settings.json` matcher。

---

### 原语 4 · Evidence(证据)

#### 是什么

**它做了啥、改了什么、跑过什么测试**:Agent 跑完任务必须留下可审计的痕迹(JSONL 日志 / commit hash / test 输出),人可以在 PR review 或事故复盘时回放"那一步是怎么跑的"。**没有 evidence = 任务不算完成**。

#### 本项目怎么实现

- **`templates/hooks/guard-event-writer.py` + `.sh`**:每次 hook 拦截后写一行 JSONL 到 `.loopx/guard-events-<date>.jsonl`(每 hook 一行:timestamp / hook_name / tool_name / block_reason / exit_code)
- **`templates/hooks/loopx-guard-summary.sh`**:`--root DIR --since YYYY-MM-DD --hook NAME --limit N`,把 JSONL 汇总成 markdown 表格(人 review 用)
- **`templates/skills/loopx-project/SKILL.md`**:在 `Evidence` 段(line ~700 附近)规定:`loopx review-packet --goal-id <GOAL_ID>` 把 todo / evidence / quota 打包成一页可读 review
- **本项目当前实践**:`handoff-<topic>-<date>.md` + `git log --oneline` 是接力证据;JSONL 是 hook 证据(详见 Part 2.2 场景 1 真实案例)

#### 怎么验证

```bash
cat .loopx/guard-events-$(date +%Y-%m-%d).jsonl | wc -l     # 今日拦截数(⚠️ 期望非 0)
templates/hooks/loopx-guard-summary.sh --since $(date +%Y-%m-%d) --limit 20
git log --oneline -20                                       # 期望每条 commit msg 引用 hook 名或 goal-id
```

数据样本(2026-09-25 单日合成日志,来源 `_data-extract-notes.md` §1):rime-claude 53 行 / cut-ad 46 行 / sandbox-verify 43 行,共 **142 行拦截事件**(media-to-doc-ui N/A)。如果今日 JSONL 是 0 行但你跑过被拦的命令 → 看 hook stderr 是否被静默吞了。

---

### 原语 5 · Quota(配额)

#### 是什么

**决定这一轮该不该跑**:在每次 turn 开头,Agent 必须问 LoopX "我现在还有 token 吗?还在预算内吗?",如果没 → 立即停,不要硬撑。Quota = `max-budget-usd` + per-turn token limit + per-goal 时间窗。**没有 quota check = 不允许进 turn**(fail-closed)。

#### 本项目怎么实现

- **`--max-budget-usd`**:装 `install.sh` 时写入 `settings.json`,作为 Anthropic API 的硬上限(超出自动 429)
- **`loopx quota should-run`**:turn 开头必跑,SIGSTOP-or-GO 信号。命令格式(SKILL.md line 322 / 328):

  ```bash
  loopx --format json --registry "$HOME/.codex/loopx/registry.global.json" quota should-run --goal-id <STABLE_GOAL_ID>
  loopx --format json --registry "$HOME/.codex/loopx/registry.global.json" quota should-run --goal-id <STABLE_GOAL_ID> --agent-id <REGISTERED_AGENT_ID>
  ```

  返回 `should_run=true/false` + 剩余 quota + `goal_boundary` 信号(详见 SKILL.md line 484)
- **`templates/skills/loopx-project/SKILL.md` §quota**(line ~410-660):规定 turn 边界、scheduler_hint 处理、replan obligation 等
- **本项目当前实践**:sub-agent 接力靠 `handoff-<topic>-<date>.md` 自管理时间(⚠️ 待 Sub-project D 校准 LoopX quota 集成深度)

#### 怎么验证

```bash
loopx doctor --deep                                         # 期望 quota 配置节非空
loopx --format json quota should-run --goal-id <GOAL_ID>    # 期望 should_run=true
```

如果 `should_run=false` → 立即停手,不要继续调 API;回 `loopx status` 看 `must_advance` 字段,完成当前 step 的 replan obligation 再退出。如果 `doctor --deep` 报 quota 未配 → `install.sh` 没跑过或 `--max-budget-usd` 被注释。

---

## 6. 5 原语怎么协同(一个 PR 周期)

5 原语不是孤立的,它们在一个 PR 生命周期里有**严格的时序**:

| 阶段 | 原语 | 触发点 | 失败后果 |
|---|---|---|---|
| 1. 规划 | **Objective → Todo** | `/loopx <goal text>` 触发 start-goal;Todo 在改第一行代码前登记 | 没 objective → 任务被拒;Todo 冲突 → 等别人释放 lease |
| 2. 跑中 | **Evidence** | 每个 hook 拦截 / 每个 file edit / 每个 test run 都写 JSONL 或 git commit | Evidence 缺失 → PR review 没法回放 → 被退 |
| 3. 危险时 | **Gate** | 试图 push main / publish / 写密钥 / 跑 migration 时 hook 拦下 | Gate 拦下 → 提示"请人工 review";Agent 不能自己 override |
| 4. 结尾 | **Quota** | 每个 turn 开头跑 `quota should-run`;turn 结束跑 `quota must-advance` | Quota 用完 → 自动停 turn;replan obligation 未完成 → 不算 done |

**核心闭环**:`Objective` 定义目标 → `Todo` 拆解 + 抢 lease → `Evidence` 留痕 → `Gate` 拦危险 → `Quota` 控预算 → 写完 commit → 跑 review-packet → 下一轮接力读 `handoff-*.md`。

**失败模式**:如果跳过任意一个原语(典型反模式),后果是:
- 跳过 Objective → Agent 跑偏,用户回来发现"为啥在做 X?"
- 跳过 Todo → 多 Agent 撞文件,后写的覆盖先写的
- 跳过 Gate → 误推 main / 误发包,事故
- 跳过 Evidence → PR review 没法回放,反复问"这步做了啥"
- 跳过 Quota → token 超支 / 任务跑到一半没钱了

---

## 7. 下一步

- **看 4 场景怎么用这 5 原语**:[Part 2.2](PART-2-2-SCENARIOS.md)(主菜)
- **查 hook / skill / playbook 怎么配**:[Part 2.3](PART-2-3-ASSETS.md)
- **遇到误拦截 / 想调 hook**:[Part 3](PART-3-TUNING-FAQ.md)
- **理论来源**:LoopX 项目本体(详细命令见 `templates/skills/loopx-project/SKILL.md`),5 hook 实现见 `templates/hooks/`