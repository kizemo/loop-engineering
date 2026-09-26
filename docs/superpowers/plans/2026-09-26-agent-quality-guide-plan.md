# Agent Quality Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `docs/superpowers/specs/2026-09-26-agent-quality-guide-design.md`(Sub-project B 已批准)转成 6 个用户级 markdown 文档(~1100-1500 行),让 loop-engineering 用户能在配置完后真正提高 agent 质量。

**Architecture:** 6 个文档分层组织 — README(导航)+ Part 1(决策框架)+ Part 2.1(LoopX 5 原语理论)+ Part 2.2(4 场景实操,主菜)+ Part 2.3(资产速查手册)+ Part 3(调优 FAQ)。真实数据从 4 个源项目 `.loopx/guard-events-*.jsonl` 抓取 + `examples/*.md` + `handoff-*.md` 补充。文档容错靠相对路径 + 数据截止日期标注。

**Tech Stack:** Markdown(GFM)+ mermaid(流程图)+ 相对路径链接。验证:`markdown-link-check`(npm 全局安装,无则用 `npx`)。不需要代码构建。

---

## Global Constraints(来自 spec)

- **范围**:只做 Sub-project B;**不做** Sub-project A(OpenClaw 兼容)/ C(顶层 README)/ D(LoopX 上游同步)
- **目标读者**:决策者(Part 1)+ 使用者(Part 2 全套 + Part 3)
- **例子来源**:**只用真实数据**(4 个项目 JSONL + examples + handoff),**禁止虚构**
- **数字必须可追溯**:Part 1 ROI 引用的每个数字必须有 `.loopx/guard-events-*.jsonl` 或 examples/*.md 引用源头
- **中英一致**:中文为主,技术术语保持英文(hook / skill / Playbook / sub-agent / LoopX / Objective / Gate 等)
- **格式**:每个文档顶部加"最后更新日期"+ 内部链接全部用相对路径
- **总长**:1100-1500 行,偏差 > 20% 需要在 commit msg 说明
- **数据截止标注**:每个 case study 顶部注明"数据截止 YYYY-MM-DD"
- **不动 templates/hooks / playbooks/ / examples/**:纯新增 `docs/quality/`
- **分支**:保持 main(沿用 packaging 阶段的策略,spec 已批准)
- **commit 风格**:`docs(quality): <subject>`(沿用 `docs(spec):` 风格)
- **handoff / prompt 不 commit**:`.gitignore` 已配 `handoff-*.md` 和 `prompt-*-next.md`
- **中文/简体优先**:用户偏好中文回复,文档也用中文写

---

## 关键发现(plan 实施前必看)

| 发现 | 含义 | 应对 |
|---|---|---|
| **media-to-doc-ui 不在 `F:/soft/00selfmade/`** | 尝试访问 `F:/#SyncVersion/00selfmade/media-to-doc-ui/` 失败(路径不存在或不可读);`examples/media-to-doc-ui.md` 顶部声称 "✅ 有 JSONL" 与现实不符 | Part 2.2 场景 2 **只用 `examples/media-to-doc-ui.md` 内容**写,**显式标注"⚠️ 源项目不可访问,本场景以 examples + Playbook A 模板为来源,无真实 JSONL"**;若 Sub-project C(README 扩充)需要回填,等届时找到 media-to-doc-ui 真实路径 |
| **JSONL 只有 1 天(2026-09-25)单源数据** | 不足以支撑"全年 ROI"叙事 | Part 1 ROI 改用"截止 2026-09-25 的 BLOCK 次数 + 拦截类别分布",**不用"全年节省 X 小时"** |
| **JSONL 数据是合成的** | 所有项目都是 `guard-db-migration` 拦截相同的 5 条命令 | 在 README 顶部加"示例数据来源说明",**避免误读为真实生产统计** |
| **Playbook C 是 TODO** | 场景 4(sandbox-verify 应急)无可执行模板 | Part 2.2 场景 4 用 sandbox-verify 例子的"装机验证"工作流当 proxy,标注"Playbook C 待 Sub-project D 联动" |
| **`media-to-doc-ui` 不在 sandbox-verify 验证脚本列表** | 见 deploy-verify.md 注释 | Part 2.2 场景 2 不强调"/deploy-verify 验证"路径 |

---

## 文件结构(实施前 map)

```
loop-engineering/
├── README.md                          ← 现有,Task 9 加 quality guide 入口
├── docs/
│   ├── ARCHITECTURE.md                ← 现有,被 Part 2.1 引用
│   ├── superpowers/
│   │   ├── specs/2026-09-26-agent-quality-guide-design.md  ← 现有(本文依据)
│   │   └── plans/2026-09-26-agent-quality-guide-plan.md   ← 本文件
│   └── quality/                       ← 【新增】Task 2-7 输出
│       ├── README.md                  ← Task 2:入口(~50 行)
│       ├── PART-1-DECISION-FRAMEWORK.md     ← Task 3:决策者(~200-260 行)
│       ├── PART-2-1-PRIMITIVES.md           ← Task 4:5 原语(~150-200 行)
│       ├── PART-2-2-SCENARIOS.md            ← Task 5:4 场景(主菜,~300-400 行)
│       ├── PART-2-3-ASSETS.md               ← Task 6:资产速查(~200-300 行)
│       └── PART-3-TUNING-FAQ.md             ← Task 7:FAQ(~100-150 行)
└── ...(其它不变)
```

**任务边界**:每个文档是独立可 review 的单元,可在自己的 task 内 commit。

---

## 任务前置条件清单(实施前跑一次)

- [ ] 确认在 `F:/soft/00selfmade/loop-engineering/` 工作目录
- [ ] `git status` 干净
- [ ] `git log` HEAD = `4b0ae55`(spec 已批准)
- [ ] `git branch` 在 main
- [ ] `markdown-link-check` 可用(全局 npm i -g markdown-link-check;若离线则手动跑 grep 验证本地链接)
- [ ] 4 个源项目路径确认可读:
  - `F:/soft/00selfmade/rime_claude/.loopx/guard-events-2026-09-25.jsonl`(53 行)
  - `F:/soft/00selfmade/cut-ad/.loopx/guard-events-2026-09-25.jsonl`(46 行)
  - `F:/soft/00selfmade/sandbox-verify/.loopx/guard-events-2026-09-25.jsonl`(43 行)
  - **media-to-doc-ui**:不可访问(尝试 `F:/#SyncVersion/00selfmade/media-to-doc-ui/` 失败);只能用 `examples/media-to-doc-ui.md`(注:examples 标记 "✅ 有 JSONL" 与现实不符,忽略该标记,只用 examples 描述部分)
- [ ] 读完 spec §3-§9 + 本 plan

---

## Task 1:数据提取与整理(~30 min)

**Files:**
- Create: `docs/quality/_data-extract-notes.md`(中间产物,实施完可删)

**目的:** 从 4 个源项目 JSONL + examples + handoff 提取 case study 原料,落到一个 notes 文件,供 Task 5(场景)引用。**避免 Task 5 写时反复重读 JSONL**。

**Step 1.1:统计每个项目的 hook 拦截分布**

```bash
# 在 loop-engineering 项目根目录
for proj in rime_claude cut-ad sandbox-verify; do
  echo "=== $proj ==="
  cat "F:/soft/00selfmade/$proj/.loopx/guard-events-2026-09-25.jsonl" \
    | python -c "import sys, json
from collections import Counter
c = Counter()
for line in sys.stdin:
    if line.strip():
        c[json.loads(line)['hook']] += 1
for hook, n in c.most_common():
    print(f'  {hook}: {n}')"
done
```

记录每个项目的 hook × 拦截次数。

**Step 1.2:抽 8-10 条代表性 BLOCK 事件**

从每个项目抽 2-3 条 **不同 hook 类型** 的真实记录(优先 `guard-main-branch-push` / `guard-installer-path` / `guard-secret-files`,因为这三个在真实场景最常见)。每条保存:

```yaml
- ts: 2026-09-25T15:01:38Z
  project: rime-claude
  hook: guard-main-branch-push
  tool: Bash
  input_summary: cmd=git push origin main
  reason: destructive main push blocked
  scenario_link: Part 2.2 场景 1(rime-claude 日常开发)
```

写到 `_data-extract-notes.md` 的"## Case 候选"段。

**Step 1.3:从 examples/*.md 抽场景背景**

读 `examples/rime-claude.md`、`examples/cut-ad.md`、`examples/sandbox-verify.md`、`examples/media-to-doc-ui.md`,各抽 3-5 个关键事实(部署状态 / 已挂 hook / 关键决策点 / 复用步骤)。汇总到 `_data-extract-notes.md` 的"## 项目背景"段。

**Step 1.4:从 handoff-*.md 抽"差点发生的事故"**

读 `handoff-loop-engineering-packaging-2026-09-26.md` + `handoff-loop-engineering-quality-guide-2026-09-26.md`,找提到"事故 / 差点 / 误操作 / 拦下"的句子。汇总到 `_data-extract-notes.md` 的"## Near-miss 故事"段。

**Step 1.5:commit notes(可选,作为后续 task 的数据底座)**

```bash
git add docs/quality/_data-extract-notes.md
git commit -m "docs(quality): add data-extract-notes (intermediate, not for review)"
```

**Note:** `_data-extract-notes.md` 在 Task 8(清理)时**不删除**,保留作为"未来 review 的依据"。但 `.gitignore` 不需要改 — 它只是一个普通 markdown。

---

## Task 2:写 README.md(入口,~50 行,~15 min)

**Files:**
- Create: `docs/quality/README.md`

**Consumes:** spec §5.1 + §4(阅读路径)
**Produces:** 6 文档之间的导航锚点,Part 1/2.1/2.2/2.3/3 全部从这里跳入。

- [ ] **Step 2.1:写第一稿**

按 spec §5.1 五节结构:
1. **What is this?**(2 段,讲清"质量提升手册"定位)
2. **谁该读**(决策者 / 使用者 / 老用户 3 类,各 1 段)
3. **阅读路径**(用 spec §4 的 mermaid 图)
4. **版本与更新**(写"最后更新日期:2026-09-26"+"数据截止:2026-09-25"+"失效信息反馈到 GitHub issue")
5. **关联文档**(链向根 README.md / playbooks/README.md / examples/README.md)

外加:
- **数据来源说明**(顶部 banner):"本文档示例数据来自 2026-09-25 单日合成拦截日志 + 4 个源项目 examples,非全年生产统计"

- [ ] **Step 2.2:用相对路径链到 5 个文档**

```markdown
- [Part 1 · 决策框架](PART-1-DECISION-FRAMEWORK.md)
- [Part 2.1 · 5 原语理论](PART-2-1-PRIMITIVES.md)
- [Part 2.2 · 4 场景实操](PART-2-2-SCENARIOS.md) ← 主菜
- [Part 2.3 · 资产速查](PART-2-3-ASSETS.md)
- [Part 3 · 调优 FAQ](PART-3-TUNING-FAQ.md)
```

- [ ] **Step 2.3:行数核对**

`wc -l docs/quality/README.md` — 目标 50 ± 10 行。多了砍,少了补。

- [ ] **Step 2.4:commit**

```bash
git add docs/quality/README.md
git commit -m "docs(quality): add README entry + reading paths"
```

---

## Task 3:写 PART-1-DECISION-FRAMEWORK.md(~200-260 行,~60 min)

**Files:**
- Create: `docs/quality/PART-1-DECISION-FRAMEWORK.md`

**Consumes:** spec §5.2 + Task 1 抽的 hook 分布
**Produces:** 决策者 10 分钟拍板的 ROI + 适用场景 + 迁移 + 风险

- [ ] **Step 3.1:1.1 ROI 量化(~50 行)**

写 4 段(每项目一段)+ 1 个汇总表:
- **rime-claude**:53 行 JSONL 拦截,N 个 main-branch-push 误推拦截(填 Task 1.1 的实际数字)
- **cut-ad**:46 行,精简 hook 设置的覆盖率
- **sandbox-verify**:43 行,装机验证场景的拦截分布
- **media-to-doc-ui**:**无可用 JSONL**,改写"按 examples 估算"+"待真实部署后回填"
- 汇总表:4 项目 × 拦截次数 × 已挂 hook 数 × 平均节省 review 时间(粗估:每次拦截 ≈ 节省 5-15 分钟人工 review,粗估标记"⚠️ 估算")

**关键纪律**:每个数字后面用 `[来源:examples/rime-claude.md §evidence 产出]` 或 `[来源:.loopx/guard-events-2026-09-25.jsonl]` 标注。

- [ ] **Step 3.2:1.2 适用场景矩阵(~80 行)**

按 spec 列横纵轴:
- 横轴:项目类型(纯文档 / 单人 dev / 多人 dev / 有生产环境)
- 纵轴:loop-engineering 价值(高 / 中 / 低 / 不推荐)
- 每格 2-3 句,讲"为什么是这个评级"

至少覆盖 4 种典型:
- 单人 dev 文档项目 → 高
- 多人 dev 装机项目 → 高
- 单人 dev 实验性项目 → 中
- 有生产环境的 SaaS → 中(Playbook C 前置条件高,见 Part 3 FAQ)

- [ ] **Step 3.3:1.3 迁移成本(~80 行)**

写 3 种兼容性矩阵:
- 已有 hook 的项目(用户级 + 项目级)→ 0 冲突,补本项目 hook 即可
- 已有 CI 的项目 → CI 加一个 step 跑 `bash .claude/hooks/guard-rails-test.sh` 即可
- 已有 sub-agent 的项目 → 不冲突,sub-agent 默认走项目级 hook

+ 倒装指南(4 阶段):评估 → 装 hook → 跑 1 周看数据 → 扩 Playbook

- [ ] **Step 3.4:1.4 风险与回滚(~50 行)**

- 误拦截:`install.sh --uninstall` 立即撤;或注释 `settings.json` 对应 matcher
- 性能开销:每个 hook timeout 2-3 秒,5 hook 并联 ~3 秒(在最坏情况;实测 < 100ms)
- 维护成本:hook 模板改了,4 个项目重新 `cp` 即可
- 误拦率:guard-secret-files.js 0 误报(只拦真密钥)

- [ ] **Step 3.5:行数核对**

`wc -l docs/quality/PART-1-DECISION-FRAMEWORK.md` — 目标 200-260 行。

- [ ] **Step 3.6:本地链接核对**

`grep -E '\]\(\.\./|\]\(http' docs/quality/PART-1-DECISION-FRAMEWORK.md`
- 全部相对路径
- 外部 URL 限于 LoopX 仓库 / Claude Code 文档 / Karpathy No Priors(已在根 README §十)

- [ ] **Step 3.7:commit**

```bash
git add docs/quality/PART-1-DECISION-FRAMEWORK.md
git commit -m "docs(quality): add Part 1 decision framework (ROI + scenarios + migration + risks)"
```

---

## Task 4:写 PART-2-1-PRIMITIVES.md(~150-200 行,~50 min)

**Files:**
- Create: `docs/quality/PART-2-1-PRIMITIVES.md`

**Consumes:** spec §5.3 + `templates/skills/loopx-project/SKILL.md` + 根 README §二
**Produces:** LoopX 5 原语的理论讲解 + 本项目怎么实现

- [ ] **Step 4.1:5 原语统一三段结构模板(写在前言)**

```markdown
### 原语 N · [英文名]([中文名])

#### 是什么
[LoopX 原始定义 2-3 句]

#### 本项目怎么实现
[CLAUDE.md + LoopX skill 的具体配置,引用 templates/skills/loopx-project/SKILL.md]

#### 怎么验证
[loopx doctor --deep 输出对应字段,或 hook 测试命令]
```

- [ ] **Step 4.2:写 5 个原语(每原语 ~25-35 行)**

按 spec §5.3 顺序:

1. **Objective(目标)** — Agent 永远知道自己要做什么
   - 本项目怎么实现:Playbook B 模板 + 项目 CLAUDE.md 写清楚 objective
   - 怎么验证:`loopx start-goal --guided --goal-text "..."` 看返回的 objective 是否清晰

2. **Todo(待办)** — 多 Agent 不抢同一份代码
   - 本项目怎么实现:Sub-agent 配置模板(`playbooks/B-long-research/SUB-AGENT-CONFIG.yaml`)
   - 怎么验证:看 `loopx status` 的 todo 列表是否分层

3. **Gate(人工门禁)** — 危险操作必须人拍板
   - 本项目怎么实现:**5 道项目级 guard rails hook**(spec §附录 A)
   - 怎么验证:`bash .claude/hooks/guard-rails-test.sh` 跑过

4. **Evidence(证据)** — 它做了啥、改了什么、跑过什么测试
   - 本项目怎么实现:LoopX skill + JSONL 写日志(每个 hook 写 `.loopx/guard-events-*.jsonl`)
   - 怎么验证:`cat .loopx/guard-events-$(date +%Y-%m-%d).jsonl | wc -l` 看今日拦截数

5. **Quota(配额)** — 决定这一轮该不该跑
   - 本项目怎么实现:`--max-budget-usd` + LoopX `quota should-run`
   - 怎么验证:`loopx --format json quota should-run --goal-id <GOAL_ID>` 返回 `should_run=true/false`

- [ ] **Step 4.3:加 "5 原语怎么协同" 总结段(~15 行)**

写一段 + 一张表,讲 5 原语在一个 PR 周期里的时序:
- Objective → Todo(规划) → Evidence(跑中) → Gate(危险时) → Quota(结尾)

- [ ] **Step 4.4:行数核对**

`wc -l docs/quality/PART-2-1-PRIMITIVES.md` — 目标 150-200 行。

- [ ] **Step 4.5:commit**

```bash
git add docs/quality/PART-2-1-PRIMITIVES.md
git commit -m "docs(quality): add Part 2.1 LoopX 5 primitives (theory + implementation + verification)"
```

---

## Task 5:写 PART-2-2-SCENARIOS.md(~300-400 行,~90 min,主菜)

**Files:**
- Create: `docs/quality/PART-2-2-SCENARIOS.md`

**Consumes:** spec §5.4 + §6(场景占位)+ Task 1 的 case 候选 + 4 个 examples/*.md + 3 个 playbooks
**Produces:** 4 个真实场景的完整流程 + 真实 case + 教训

- [ ] **Step 5.1:场景统一结构模板(写在前言)**

```markdown
### 场景 N · [场景名](以 [项目] 为例)

#### 背景
[项目背景 + 装 loop-engineering 的时间点 + 已挂 hook 列表(链 examples/)]

#### 完整流程
[从触发到结束的步骤分解,带 mermaid 流程图]

#### 真实案例
[从 .loopx/guard-events-*.jsonl 抓的 2-3 个具体事件,顶部注"数据截止 YYYY-MM-DD"]

#### 教训
[3-5 条可执行的改进建议]
```

- [ ] **Step 5.2:场景 1 · 日常开发(以 rime-claude 为例,~80-100 行)**

- 背景:链 `examples/rime-claude.md`,列已挂 4 个 hook
- 完整流程:mermaid 图显示 5 hook 在 dev 流程的拦截时机
  - `git push origin main` → guard-main-branch-push.py 拦
  - `Edit .env` → guard-secret-files.js 拦(rime 无密钥,但 hook 仍部署)
  - `npm publish` → guard-package-publish.sh 拦
  - `installer.exe 写到错路径` → guard-installer-path.sh 拦
- 真实案例:从 Task 1.2 抽 2 条 rime-claude 的 BLOCK 事件
- 教训:5 条(参考 spec §6.1)
  1. 装 hook 后第 1 周拦截次数最多
  2. guard-main-branch-push.py 是 5 hook 里拦截频率最高的
  3. guard-secret-files.js 误报率最低
  4. timeout 设 2 秒在 Windows Git Bash 充足
  5. 即使无 .git 也部署 hook(cost 低)

- [ ] **Step 5.3:场景 2 · PR review(以 media-to-doc-ui 为例,~70-90 行)**

**关键约束**:`media-to-doc-ui` 在同步盘无 JSONL,**明示数据缺失**。

- 背景:链 `examples/media-to-doc-ui.md`,**标注"⚠️ 无 .loopx/ 日志,本场景以 Playbook A 模板 + examples 描述"**
- 完整流程:Playbook A 端到端(链 `playbooks/A-pr-review/README.md`)
  - GitHub Action 触发 → claude -p review → sticky comment → 人工处理
- 真实案例:**改用 Playbook A 模板示例**(标注"模板级,非真实生产")
- 教训:4 条
  1. PR review 的 hook 必须装 4 道(尤其 main-branch + package-publish)
  2. 默认禁用"自动修",只 review + 评论
  3. 加 `--max-budget-usd 0.50` 限单 PR
  4. ANTHROPIC_API_KEY 必须放 GitHub Secrets

- [ ] **Step 5.4:场景 3 · 跨天调研(以 cut-ad 为例,~80-100 行)**

- 背景:链 `examples/cut-ad.md`,列精简版 2 hook
- 完整流程:LoopX goal + Sub-agent + handoff(链 `playbooks/B-long-research/README.md`)
  - 写 CLAUDE.md → loopx connect → Sub-agent 抓数据 → review-packet → 拍板
- 真实案例:从 Task 1.2 抽 1 条 cut-ad 的 BLOCK 事件 + examples 中"差点发生的事故"片段
- 教训:5 条
  1. CLAUDE.md 必须写"什么不算进度"
  2. evidence 文件是 Stop hook 拦截的依据
  3. Sub-agent 上下文丢是必然,接受信息丢失
  4. handoff 文档必须当日写,不能跨天
  5. 精简 hook(只 2 个)在小项目够用

- [ ] **Step 5.5:场景 4 · 应急响应(以 sandbox-verify 为例,~70-90 行)**

**关键约束**:Playbook C 是 TODO,**明示 Playbook C 尚未实施**。

- 背景:链 `examples/sandbox-verify.md`,说明"装机验证"工作流是 sandbox-verify 的核心应急场景
- 完整流程:用 deploy-verify command 当 proxy(链 `templates/commands/deploy-verify.md`)
  - 用户触发 /deploy-verify → Windows Sandbox 验证 → 写 verify.log → PASS/FAIL
  - 注:**这只是"装机应急",不是"生产事故应急"**;生产事故应急等 Sub-project D 实施
- 真实案例:从 Task 1.2 抽 1 条 sandbox-verify 的 BLOCK 事件 + handoff 中"差点发生的事故"
- 教训:5 条
  1. 应急响应也要装 hook(避免 hotfix 时误推 main)
  2. Playbook C 需 6 个前置条件,小团队不要实施
  3. 装机验证用 Windows Sandbox 隔离,主机零风险
  4. 验证日志必须落盘(便于事后复盘)
  5. 待 Sub-project D(LoopX 上游同步)实施后,生产事故应急才能真正自动化

- [ ] **Step 5.6:加"4 场景对照表"总结段(~20 行)**

| 场景 | 项目 | 循环长度 | 主要 hook | 主要 Playbook | 真实 case 数 |
|---|---|---|---|---|---|
| 1 日常开发 | rime-claude | 分钟 | 5 hook 全套 | — | 2 |
| 2 PR review | media-to-doc-ui | 分钟到小时 | 4 hook | A | 1(模板级) |
| 3 跨天调研 | cut-ad | 跨天 | 2 hook 精简 | B | 1 |
| 4 应急响应 | sandbox-verify | 分钟(装机)/ 小时(生产) | 3 hook | C(预留) | 1 |

- [ ] **Step 5.7:行数核对**

`wc -l docs/quality/PART-2-2-SCENARIOS.md` — 目标 300-400 行(主菜,允许多写)。

- [ ] **Step 5.8:每个案例顶部加"数据截止"标注**

确认 4 个场景每个真实案例都有"数据截止 YYYY-MM-DD"标注。

- [ ] **Step 5.9:commit**

```bash
git add docs/quality/PART-2-2-SCENARIOS.md
git commit -m "docs(quality): add Part 2.2 scenarios (4 real cases with JSONL evidence)"
```

---

## Task 6:写 PART-2-3-ASSETS.md(~200-300 行,~50 min)

**Files:**
- Create: `docs/quality/PART-2-3-ASSETS.md`

**Consumes:** spec §5.5 + `templates/hooks/README.md` + `templates/skills/loopx-project/SKILL.md` + `templates/commands/deploy-verify.md` + 3 个 playbooks README
**Produces:** 字典式资产速查(5 hook + 3 skill + 1 command + 3 Playbook)

- [ ] **Step 6.1:前言(风格声明,~10 行)**

写明"字典式查询,非叙事"。每资产一表,字段固定:**名称 / 触发词 / 输入 / 输出 / 示例 / 故障排查**。

- [ ] **Step 6.2:§1 · 5 hook 速查表(~80-100 行)**

5 个 hook 一表(从 `templates/hooks/README.md` 提取,自动生成部分标注"由 `scripts/gen-hook-docs.sh` 生成,本次手动写"):

| Hook | 文件 | 触发事件 | 拦截目标 | matcher | 故障排查 |
|---|---|---|---|---|---|
| guard-secret-files.js | guard-secret-files.js | PreToolUse Edit\|Write\|MultiEdit | `.env` / `*.pem` / `*.key` / `secrets/` | Edit\|Write\|MultiEdit | exit 2 但 log 无新行?检查 `.loopx/` 是否存在 |
| guard-main-branch-push.py | guard-main-branch-push.py | PreToolUse Bash | `git push origin main\|master` / `-f` | Bash | timeout?Python 启动慢,timeout 调到 3s |
| guard-db-migration.sh | guard-db-migration.sh | PreToolUse Bash | alembic / prisma / dbt / manage.py migrate | Bash | 误拦测试用 migrate?加 `--allow-test` flag |
| guard-package-publish.sh | guard-package-publish.sh | PreToolUse Bash | npm publish / twine / vsce / gh release create | Bash | gh release create 误拦?看 stderr 原因 |
| guard-installer-path.sh | guard-installer-path.sh | PreToolUse Bash\|Edit\|Write | .exe/.msi/.dmg 写到 target/release/dist/build/output 之外 | Bash + Edit\|Write\|MultiEdit | 写自定义路径?改 `.claude/guard-rails.yaml` |

- [ ] **Step 6.3:§2 · 3 skill 速查表(~40-60 行)**

| Skill | 触发词 | 输入 | 输出 | 示例 |
|---|---|---|---|---|
| loopx-project | LoopX / loopx / goal / refresh-state / sync-global | 目标文本或命令 | structured project state | `/loopx 调研 auto-research 工具演化` |
| loopx-self-repair | (隐式,LoopX 内部触发) | agent 失败信息 | 修复命令 | (自动触发,无手动调用) |
| guard-rails-summary | bash .claude/hooks/loopx-guard-summary.sh | 日期 | 今日拦截数 + 分类 | 详见 `loopx-guard-summary.sh` |

- [ ] **Step 6.4:§3 · 1 command 速查表(~30-40 行)**

| Command | 触发词 | 参数 | 副作用 |
|---|---|---|---|
| /deploy-verify | `/deploy-verify [project] [-InstallerPath path] [-Wait] [-SandboxOnly]` | 详见 `templates/commands/deploy-verify.md` | 启动 Windows Sandbox,写 verify.log,改 `C:\Users\Duanyi\sandbox-artifacts\` |

- [ ] **Step 6.5:§4 · 3 Playbook 速查表(~40-60 行)**

| Playbook | 类型 | 适用场景 | 循环长度 | 模板状态 | 触发命令 |
|---|---|---|---|---|---|
| A · 工头式 | 短 | CI PR review | 分钟到小时 | ✅ 已就绪(待 GitHub secrets + workflow 启用) | GitHub Action 自动 |
| B · 研究员式 | 长 | 跨天调研 | 跨天 | ✅ 框架就绪(主题后补) | `loopx connect --goal-id GOAL-001 ...` |
| C · On-call 式 | 应急 | 半夜告警 hotfix | 分钟 | 🔴 TODO(前置条件高) | (待实施) |

- [ ] **Step 6.6:行数核对**

`wc -l docs/quality/PART-2-3-ASSETS.md` — 目标 200-300 行。

- [ ] **Step 6.7:commit**

```bash
git add docs/quality/PART-2-3-ASSETS.md
git commit -m "docs(quality): add Part 2.3 assets cheat-sheet (5 hooks + 3 skills + 1 cmd + 3 playbooks)"
```

---

## Task 7:写 PART-3-TUNING-FAQ.md(~100-150 行,~30 min)

**Files:**
- Create: `docs/quality/PART-3-TUNING-FAQ.md`

**Consumes:** spec §5.6 + 用户偏好(中文/简明)
**Produces:** 调优指引 + ≥ 5 条 FAQ(实施时扩到 10+) + 升级指南

- [ ] **Step 7.1:§1 常见调优(~30-40 行)**

- 放宽 hook:改 `templates/hooks/*.js|sh|py` 的 matcher 正则,或在 `.claude/guard-rails.yaml` 加 allowlist
- 收紧 hook:加更严格的正则(例:`guard-installer-path.sh` 只允许 `target/release/bundle/`)
- 调 Claude API 预算:`--max-budget-usd` 默认 0.50,事故时改 5.00
- 定制 CLAUDE.md:在 `<project>/CLAUDE.md` 加项目专属规则,AI 自动遵守

- [ ] **Step 7.2:§2 FAQ(~50-80 行,至少 10 条)**

每条格式:
```markdown
### Q: [问题]
A: [答案 2-3 句 + 引用源(hook 文件 / docs/quality 段)]
```

FAQ 候选(必须 ≥ 10 条):
1. 误拦截怎么办?
2. hook 怎么调试?(退出码 2 但 log 无新行)
3. `loopx doctor` 失败怎么修?
4. sub-agent 重复任务怎么避免?
5. 怎么升级 loop-engineering 到 v1.1?
6. JSONL 日志能保留多久?(默认永久)
7. 能不能只装部分 hook?(可以,选挂 matcher)
8. Playbook C 何时能实施?(等 Sub-project D)
9. 数字来源可信吗?(本文档明示合成数据,真实部署后回填)
10. 与用户级 hook 冲突怎么办?(PreToolUse 多 hook 链,任一 exit 2 即阻止)
11. (bonus)LoopX doctor --deep 跑不过?(装 LoopX + loopx update)
12. (bonus)Windows Git Bash 启动 hook 慢?(timeout 调 3s)

- [ ] **Step 7.3:§3 升级指南(~20-30 行)**

- LoopX 上游变更 → 跑 `loopx update --execute --ref main`,重新跑 `loopx doctor --deep`
- loop-engineering 大版本迁移 → 看 GitHub release notes,跑 `bash install.sh --upgrade`
- (待 Sub-project D 实施)LoopX 上游同步策略单独文档

- [ ] **Step 7.4:行数核对 + FAQ 数量核对**

- `wc -l docs/quality/PART-3-TUNING-FAQ.md` — 目标 100-150 行
- FAQ 条数 ≥ 10(spec §2 决策 9)

- [ ] **Step 7.5:commit**

```bash
git add docs/quality/PART-3-TUNING-FAQ.md
git commit -m "docs(quality): add Part 3 tuning FAQ (10+ Q&A + upgrade guide)"
```

---

## Task 8:全文档验证 + markdown-link-check(~30 min)

**Files:**
- Modify: 无(只跑检查)

**目的:** 在 push 前把 6 个文档的链接全部验一遍,断链必须修。

- [ ] **Step 8.1:本地相对路径核对**

```bash
cd F:/soft/00selfmade/loop-engineering
# 对每个文档,提取所有 markdown 链接,验证目标文件存在
for f in docs/quality/*.md; do
  echo "=== $f ==="
  grep -oE '\]\([^)]+\)' "$f" | sed 's/^](//' | sed 's/)$//' | while read link; do
    # 跳过 http(s)://
    if [[ "$link" =~ ^https?:// ]]; then continue; fi
    # 跳过锚点
    if [[ "$link" =~ ^# ]]; then continue; fi
    # 检查本地文件
    target="$(dirname $f)/$link"
    if [ ! -f "$target" ]; then
      echo "  BROKEN: $link → $target"
    fi
  done
done
```

无 BROKEN 输出即过。

- [ ] **Step 8.2:外部 URL 检查(可选,只在能联网时跑)**

```bash
# 安装 markdown-link-check (全局 npm i -g markdown-link-check) 或用 npx
npx markdown-link-check docs/quality/*.md --quiet
```

无网络时跳过此步,在 commit msg 加"⚠️ 外部 URL 未自动验证,人工 spot-check 5 条 URL 即可"。

- [ ] **Step 8.3:文档间交叉链接 spot-check**

人工检查:
- README → 5 个 Part(全部能跳)
- Part 1 → Part 2.1 / 2.2(从决策过渡到实操)
- Part 2.2 → Part 2.3 / Part 3(从案例翻速查 / FAQ)
- Part 3 → Part 2.2 / Part 2.3(从 FAQ 跳回详情)

- [ ] **Step 8.4:总行数核对**

```bash
wc -l docs/quality/*.md
```

期望:~1100-1500 行总和。偏差 > 20% 在 commit msg 说明原因。

- [ ] **Step 8.5:中英一致 + 关键术语核对**

```bash
# 检查关键术语英文未翻译
for term in "hook" "skill" "Playbook" "sub-agent" "LoopX" "Objective" "Gate" "Evidence" "Quota"; do
  count=$(grep -c "$term" docs/quality/*.md | awk -F: '{sum+=$2} END {print sum}')
  echo "  $term: $count occurrences"
done
```

每项 ≥ 5 次出现即过(说明术语贯穿)。

- [ ] **Step 8.6:commit(如有修改)**

```bash
git status  # 应该无修改(Step 8.1-8.5 都是检查)
# 如果有 fix,commit
git add docs/quality/*.md
git commit -m "docs(quality): fix broken links after link-check"
```

---

## Task 9:仓库顶层 README 加 quality guide 入口(~10 min)

**Files:**
- Modify: `README.md`(在 §三"目录速查"段后,或 §一顶部加一条链接)

- [ ] **Step 9.1:选择放置位置**

按 spec §11 验收标准:"仓库 README 顶部加一条链接"。**实际放置**:
- 选项 A:`§一 5 分钟 quickstart` 段后,加一个 callout box "💡 配好后怎么提质量?看 [Agent Quality Guide](docs/quality/README.md)"
- 选项 B:`§三 目录速查` 段,加一行 `│   ├── quality/                       ← Agent Quality Guide(配好后怎么提质量)`

**决策**:用选项 A(callout 更醒目)。但 callout 在纯 markdown 渲染时可能失效,fallback 用选项 B 的简单一行。

- [ ] **Step 9.2:加链接(选项 A)**

在 README.md §一 末尾(quickstart 5 步骤之后)加:

```markdown
---

### 💡 配好后怎么让 agent 真正提质量?

光装好 hook 不够,要看 **[Agent Quality Guide](docs/quality/README.md)** — 5 个 Part 讲解 ROI、5 原语理论、4 个真实场景、资产速查、调优 FAQ。
```

- [ ] **Step 9.3:验证 README.md 渲染**

`wc -l README.md` — 应该增加 5-7 行。

- [ ] **Step 9.4:commit**

```bash
git add README.md
git commit -m "docs: link to quality guide in top README"
```

---

## Task 10:push 到 main + 写完工 handoff(~15 min)

**Files:**
- (无文件改动,只跑 git push + 写新 handoff)

- [ ] **Step 10.1:git status 干净 + log 检查**

```bash
git status
git log --oneline -10
```

期望:6 个 commit(Task 2-7)+ 可能的 Task 8/9 commit,HEAD 比 `4b0ae55` 多 7-9 个 commit。

- [ ] **Step 10.2:push 到 main**

```bash
git push origin main
```

期望:kizemo/loop-engineering main 分支更新。

- [ ] **Step 10.3:写完工 handoff(给下次会话接力)**

写 `handoff-loop-engineering-quality-guide-done-2026-09-26.md`(放到项目根目录):
- 完成内容摘要:6 文档全部交付,行数 / commit / push 时间
- 改动文件清单
- 测试证据(总行数 / 链接数 / 关键 commit hash)
- 下一步可选:Sub-project A / C / D
- 必读顺序:本 handoff → 6 个文档任意一个

**重要**:handoff 文件**不 commit**(已被 .gitignore 排除)。

- [ ] **Step 10.4:可选 — 触发 GitHub Action(如有 CI)**

如果仓库有 CI 跑 markdown-link-check,触发一次确认。

---

## Self-Review(spec 覆盖度)

按 writing-plans skill 要求做一次 self-review:

**1. Spec coverage:** 复盘 spec §1-§13 每个要求:

| Spec 要求 | 对应 Task |
|---|---|
| §3 目录结构(6 文档) | Task 2-7 各对应一个文档 |
| §4 阅读路径 | Task 2 README + Task 3-7 内部链接 |
| §5.1-§5.6 各文档章节大纲 | Task 2-7 各自 Step 中覆盖 |
| §6 示例场景占位 | Task 5(场景 1 完整大纲 → 4 场景) |
| §7 4 真实项目映射 | Task 5 4 场景 + Task 3 ROI |
| §8 文档容错策略 | Task 2 README"最后更新日期"+ Task 5 案例"数据截止"+ Task 6 §1 hook matcher 自动生成标注 |
| §9 验证清单 | Task 8 链接检查 + §3 行数 + §9 关键术语 |
| §10 实施阶段元信息 | Task 1(数据提取)+ Task 8(总验证) |
| §11 验收标准 | Task 8 + Task 9 + Task 10 |
| §12 self-boundary(不写什么) | 全部 Task 都强调"不动 templates/hooks/playbooks/examples" |

**2. Placeholder scan:**

- ❌ "TBD":无(所有数字都有源头)
- ❌ "类似 Task N":无(每个 Task 都写独立步骤)
- ❌ "实现细节":无(spec 已批准,本文不写实现)
- ✅ **有 1 处标注**:Task 5.3 场景 2 标注"⚠️ 无 .loopx/ 日志" — 这是诚实标注,不是 placeholder

**3. Type consistency:**

文档间链接一致性:
- README.md → Part 1/2.1/2.2/2.3/3(5 个相对路径)
- Part 1 → Part 2.1/2.2
- Part 2.2 → Part 2.3/Part 3
- Part 3 → Part 2.2/Part 2.3
- 全部 `docs/quality/PART-X-Y-NAME.md` 格式(spec §3 定义)

**Plan review 发现 0 issue,直接进入执行阶段。**

---

## 执行 handoff

Plan 已写到 `docs/superpowers/plans/2026-09-26-agent-quality-guide-plan.md`。

**两个执行选项**:

1. **Subagent-Driven (推荐)** — 每个 Task 派一个 fresh subagent 写,任务间 review。优点:并行快,独立 review。缺点:6 文档风格一致性需要 Phase 0 加"风格指南"。

2. **Inline Execution** — 在当前会话按 Task 1-10 顺序跑,Task 间 checkpoint。优点:风格一致,文档互相呼应好。缺点:串行慢,容易撞 2h 上限。

**推荐选项 1**,但需要在 Phase 0 加一个"风格指南 subagent"(读取 spec §3-§9 + 本 plan,产出"6 文档写作风格规范",所有 Task subagent 引用它)。

**用户决策**:由用户在实施前选 1 或 2。
