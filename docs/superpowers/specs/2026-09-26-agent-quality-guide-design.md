# Loop Engineering · Agent Quality Guide Design Spec

> **状态**:DRAFT · **创建日期**:2026-09-26 · **粒度**:中(章节大纲 + 关键决策 + 1-2 示例)
> **范围**:Sub-project B · "如何通过 loop-engineering 提高 agent 执行任务的质量"多文档手册
> **作者**:brainstorming session · 接力关系:本 spec 经用户审核后,交给 `superpowers:writing-plans` 制定实施计划

---

## 0. TL;DR(1 分钟读完)

- **交付物**:`docs/quality/` 下 6 个 markdown 文档,总长 ~1100-1500 行
- **目标读者**:决策者(Part 1)+ 使用者(Part 2 全套 + Part 3)
- **真实案例**:从 rime-claude / media-to-doc-ui / cut-ad / sandbox-verify 这 4 个 `.loopx/guard-events-*.jsonl` 抓取
- **不交付**:代码改动 / hook 改动 / LoopX 上游同步(都是其他 sub-project)
- **工作量**:~12-18 小时(中等粒度 spec,实施阶段填充细节)

---

## 1. 背景与目标

### 1.1 用户原始目标(2026-09-26 重新校准)

用户重定义 loop-engineering 的项目目标为 4 条:

1. **针对 Agents 架构的 loop engineering 优化内容**,打包成可复用项目,任何 Claude Code 软件可安装与配置
2. **尽可能兼容 OpenClaw**(391k⭐ 本地 AI agent 框架)
3. **详细撰写部署、使用手册**,尤其在配置好后,**如何通过这个项目提高 agent 执行任务的质量**
4. **以公开仓库的形式发布在 git**,**通过项目文档详细说明项目的定位、作用、价值、安装与部署、使用方法**

### 1.2 范围分解(4 个 sub-projects)

| Sub-project | 包含目标 | 改动类型 | 优先级 |
|---|---|---|---|
| **A · 多 agent 框架兼容层** | 1 + 2 | 代码 + 架构 | 后 |
| **B · agent 质量提升手册** ⬅ **本 spec** | 3 | 纯文档 | 🥇 先 |
| **C · README 扩充 + 安装手册** | 4 | 纯文档 | 后 |
| **D · LoopX 上游同步策略** | (隐含) | 流程文档 | 后 |

**为什么 B 先**:A 是代码 + 架构,需要深入研究 OpenClaw hooks 格式,设计工作量大;B 是纯文档,1-2 周可交付,完成后立刻让现有 4 个下游项目受益。

### 1.3 本 spec 解决的子问题

- ✅ 设计 6 个文档的结构 + 章节大纲 + 阅读路径
- ✅ 关键决策清单(目标读者 / 深度 / 结构 / 例子来源 / 详细度)
- ✅ 示例场景占位(场景 1 完整大纲 + 场景 2-4 提纲)
- ✅ 文档容错策略(链接失效 / 上游变更 / 数据过时)
- ✅ 验证清单(发布前过哪些检查)
- ✅ 实施阶段元信息(数据依赖 / 验收标准 / 工作量)

---

## 2. 关键决策汇总(已通过 brainstorming)

| # | 决策 | 选择 | 替代方案(已否决) |
|---|---|---|---|
| 1 | 目标读者 | 决策者 + 使用者两者都要 | 只给使用者 / 只给决策者 |
| 2 | 第 2 部分结构 | 混合(5 原语 → 4 场景 → 资产) | 纯场景 / 纯 5 原语 / 纯资产 |
| 3 | 产出形式 | 多文档(`docs/quality/` 索引) | 单文档 / 双文档 |
| 4 | 例子来源 | 4 个真实项目 | 虚构 / 混合 |
| 5 | Part 1 重点 | 全面(ROI + 适用场景 + 迁移成本 + 风险) | 只 ROI / 只适用场景 / 只迁移 |
| 6 | spec 详细度 | 中粒度 + 提纲(~500-800 行) | 粗 / 细 |
| 7 | Part 2.1 结构 | 每原语统一三段(是什么/怎么实现/怎么验证) | 自由发挥 |
| 8 | Part 2.3 风格 | 参考手册(字典式查询) | 叙事性 |
| 9 | Part 3 FAQ 数量 | ≥ 5 条(实施时扩展到 10+) | 严格 ≥ 10 条 |
| 10 | 文档容错 | 5 条策略(见 §8) | 简单加"最后更新日期" |

---

## 3. 目录结构

```
docs/quality/
├── README.md                       ← 入口 + 阅读路径 + 版本 (~50 行)
├── PART-1-DECISION-FRAMEWORK.md    ← 决策者读 (~200-260 行)
├── PART-2-1-PRIMITIVES.md          ← 上层:LoopX 5 原语 (~150-200 行)
├── PART-2-2-SCENARIOS.md           ← 中层:4 场景实操,主菜 (~300-400 行)
├── PART-2-3-ASSETS.md              ← 下层:5 hook + 3 skill + 1 cmd + 3 Playbook 速查 (~200-300 行)
└── PART-3-TUNING-FAQ.md            ← 调优 + FAQ (~100-150 行)
```

**总长**:**~1100-1500 行**(6 个文档),主入口 1 份,主菜 1 份(Part 2.2 4 场景)。

---

## 4. 阅读路径

```
决策者                使用者
  │                    │
  ▼                    ▼
README.md ────────→ README.md
  │                    │
  ▼                    ├─→ Part 1(可选,确认 ROI 后可跳)
Part 1                │
  │                    ├─→ Part 2.1(5 原语理论,15 min)
  ▼                    │
拍板                  ├─→ Part 2.2(4 场景实操,30 min,主菜)
                      │
                      ├─→ Part 2.3(资产参考手册,按需跳读)
                      │
                      └─→ Part 3(调优 FAQ,遇问题时翻)
```

**3 条核心阅读路径**:
1. **决策者 10 min**:`README → Part 1`(读完 ROI + 适用场景 + 风险就能拍板)
2. **使用者 60 min 入门**:`README → Part 2.1 → Part 2.2`(理论 → 4 场景实操)
3. **使用者深度使用**:`Part 2.3` + `Part 3`(按需跳读)

---

## 5. 6 个文件的章节大纲

### 5.1 README.md(入口,~50 行)

| 节 | 章节名 | 内容要点 |
|---|---|---|
| 1 | **What is this?** | 一句话:loop-engineering 的"质量提升手册",讲配置好后如何用 |
| 2 | **谁该读** | 决策者(10 min 拍板)/ 使用者(30-60 min 入门)/ 老用户(按需跳 Part 2.3) |
| 3 | **阅读路径** | 见本 spec §4,3 条核心路径 |
| 4 | **版本与更新** | 跟 loop-engineering v1.x 同步;失效信息反馈到 GitHub issue |
| 5 | **关联文档** | 链向 README.md / playbooks/ / examples/ |

### 5.2 PART-1-DECISION-FRAMEWORK.md(决策者,~200-260 行)

| 节 | 章节名 | 目标行数 | 内容要点 |
|---|---|---|---|
| 1.1 | **ROI 量化** | ~50 | 用 4 个真实项目数据: hook 拦截次数 / 节省人工 review 时间(估计)/ 节省事故成本(估计) |
| 1.2 | **适用场景矩阵** | ~80 | 横轴:项目类型(纯文档 / 单人 / 多人 / 有生产环境)/ 纵轴:loop-engineering 价值(高/中/低/不推荐) |
| 1.3 | **迁移成本** | ~80 | 兼容性矩阵(已有 hook 的项目 / 已有 CI 的项目 / 已有 sub-agent 的项目)+ 倒装指南(分 4 阶段引入) |
| 1.4 | **风险与回滚** | ~50 | 误拦截 / 性能开销 / 维护成本 / 怎么撤(`install.sh --uninstall`) |

### 5.3 PART-2-1-PRIMITIVES.md(上层 5 原语理论,~150-200 行)

**统一结构**(每原语一节,跨原语跳读无学习成本):

```
### 1. Objective
#### 是什么      [LoopX 原始定义 2-3 句]
#### 本项目怎么实现 [CLAUDE.md + LoopX skill 的具体配置]
#### 怎么验证     [loopx doctor --deep 输出对应字段]
```

| 节 | 章节名 | 原语定义 |
|---|---|---|
| 1 | **Objective(目标)** | Agent 永远知道自己要做什么 |
| 2 | **Todo(待办)** | 多 Agent 不抢同一份代码 |
| 3 | **Gate(人工门禁)** | 危险操作必须人拍板 |
| 4 | **Evidence(证据)** | 它做了啥、改了什么、跑过什么测试 |
| 5 | **Quota(配额)** | 决定这一轮该不该跑 |

### 5.4 PART-2-2-SCENARIOS.md(中层 4 场景实操,~300-400 行,**主菜**)

**统一结构**(每场景一节):

```
### 场景 N · [场景名](以 [项目] 为例)
#### 背景     [项目背景 + 装 loop-engineering 的时间点]
#### 完整流程 [从触发到结束的步骤分解,带 mermaid 图]
#### 真实案例 [从 .loopx/guard-events-*.jsonl 抓的 2-3 个具体事件]
#### 教训     [3-5 条可执行的改进建议]
```

| 场景 | 章节名 | 主对照项目 | 子段落 |
|---|---|---|---|
| 1 | **日常开发** | rime-claude | 5 hook 在开发流程的拦截时机 |
| 2 | **PR review** | media-to-doc-ui | Playbook A 端到端 |
| 3 | **跨天调研** | cut-ad | LoopX goal + sub-agent + handoff |
| 4 | **应急响应** | sandbox-verify | Playbook C 自动化诊断 |

### 5.5 PART-2-3-ASSETS.md(下层资产参考手册,~200-300 行)

**风格**:字典式查询,不是叙事。每资产一表。

| 节 | 章节名 | 表格列 |
|---|---|---|
| 1 | **5 hook 速查表** | hook 名 / 拦截目标 / 配置选项 / 输出格式 / 故障排查 |
| 2 | **3 skill 速查表** | skill 名 / 触发词 / 输入 / 输出 / 示例 |
| 3 | **1 command 速查表** | command 名 / 触发词 / 参数 / 副作用 |
| 4 | **3 Playbook 速查表** | playbook 名 / 类型 / 适用场景 / 配置 / 触发命令 |

**自动生成**(实施阶段):`scripts/gen-hook-docs.sh` 从源码提取 matcher / 拦截目标 / 输出 schema,避免文档漂移。

### 5.6 PART-3-TUNING-FAQ.md(调优 + FAQ,~100-150 行)

| 节 | 章节名 | 内容要点 |
|---|---|---|
| 1 | **常见调优** | 怎么放宽/收紧 hook / 怎么调 Claude API 预算 / 怎么定制 CLAUDE.md |
| 2 | **FAQ(≥ 5 条,实施时扩到 10+)** | 误拦截怎么办 / hook 怎么调试 / LoopX doctor 失败 / sub-agent 重复任务 / 怎么升级 loop-engineering |
| 3 | **升级指南** | LoopX 上游变更怎么同步 / loop-engineering 大版本怎么迁 |

---

## 6. 示例场景占位

### 6.1 场景 1 完整大纲(rimed-claude · 日常开发)

```markdown
## 场景 1 · 日常开发(以 rime-claude 为例)

### 背景
rime-claude 是 Rime 输入法 installer 项目(Tauri + Inno Setup)。
2026-08 装 loop-engineering 后,5 hook 接管 CI 门禁。

### 完整流程
[开发者提交代码] → guard-main-branch-push.py 拦截 force push
→ guard-secret-files.js 拦截 .env 误提交
→ guard-installer-path.sh 拦截 installer 写到错路径
→ guard-package-publish.sh 拦截 npm publish 误触发
→ guard-db-migration.sh 拦截 alembic upgrade head 误用 prod tag

### 真实案例(待实施阶段从 .loopx/guard-events-*.jsonl 抓)
案例 A: 某次 PR 试图把 .env 加入 commit,被 guard-secret-files.js 拦截,
拦截时间:2026-08-15,事件 ID:xxx,影响:避免密钥泄漏到 GitHub。
案例 B: 某次 installer 编译后被自动放到 target/ 而不是 target/release/dist/,
被 guard-installer-path.sh 拦截,时间:2026-08-22,影响:避免 installer 路径错误。

### 教训
1. 装 hook 后第 1 周拦截次数最多(因为开发者还没习惯)
2. guard-main-branch-push.py 是 5 hook 里拦截频率最高的(每周 2-3 次)
3. guard-secret-files.js 是 5 hook 里误报率最低的(0 误报,只拦了真正的事故)
```

### 6.2 场景 2-4 提纲(实施阶段填充)

- **场景 2(media-to-doc-ui · PR review)**:Playbook A 触发 → claude -p review → sticky comment → 人工处理
- **场景 3(cut-ad · 跨天调研)**:大需求 → LoopX goal 拆 sub-agent → 跨天续做 → handoff 接力
- **场景 4(sandbox-verify · 应急响应)**:半夜告警 → Playbook C 自动诊断 → 人拍板 hotfix → 自动化回归测试

---

## 7. 4 个真实项目映射

| 项目 | 类型 | Part 2.2 重点场景 | Part 1 数据引用 |
|---|---|---|---|
| **rime-claude** | Rime 输入法 installer(Win Tauri) | 场景 1:日常开发 | 5 hook 拦截频次 |
| **media-to-doc-ui** | Tauri 桌面应用 | 场景 2:PR review | Playbook A review 准确率 |
| **cut-ad** | 视频处理 Python | 场景 3:跨天调研 | LoopX sub-agent 完成率 |
| **sandbox-verify** | 装机验证工具 | 场景 4:应急响应 | Playbook C 自动化覆盖率 |

---

## 8. 文档容错策略(error handling)

| 风险 | 缓解 |
|---|---|
| **链接失效** | README 顶部加"最后更新日期"+ 每个内部链接用相对路径 |
| **LoopX 上游变更** | Part 3 FAQ 加"loop-engineering 升级后怎么同步 LoopX 变更"+ 链向 Sub-project D |
| **4 个项目案例过时** | 每个案例顶部注明"数据截止 YYYY-MM",每年 review 一次 |
| **hook matcher 漂移** | Part 2.3 hook 速查表的 matcher 从源码自动生成(`scripts/gen-hook-docs.sh`) |
| **用户对"提高质量"无感** | Part 1 ROI 必须用数字,而非"更好 / 更安全"这种模糊词 |

---

## 9. 验证清单(testing)

每个文档发布前必须过:

- [ ] **链接有效** — `markdown-link-check docs/quality/*.md`(CI 跑)
- [ ] **代码示例可跑** — Part 2.2 的每个 bash/python 命令,跑一次确认不退化
- [ ] **数字真实** — Part 1 ROI 引用的"拦截次数"必须能追溯到 `.loopx/guard-events-*.jsonl`
- [ ] **章节链接通顺** — 从 README 进入每个文档的跳转,3 次内可达
- [ ] **中英一致** — 中文为主,技术术语保持英文(hook / skill / Playbook / sub-agent 等)

---

## 10. 实施阶段元信息

### 10.1 工作量

~12-18 小时,分阶段:
1. 数据采集:4-6 小时(从 4 个项目抓 `.loopx/guard-events-*.jsonl` + handoff)
2. 文档撰写:6-8 小时(6 个文档)
3. 验证与发布:2-4 小时(markdown-link-check + 链接 review + commit + push)

### 10.2 数据依赖

- 4 个项目 `.loopx/guard-events-*.jsonl` 真实日志
- 4 个项目 `handoff-*.md` 接力文档(找事故案例)
- LoopX 上游 API/CLI 当前版本(用于 Part 2.1 验证段)

### 10.3 外部依赖

- LoopX 上游 API 稳定(否则 Part 2.1 "怎么验证"段要重写)
- Claude CLI 可用(用于 Part 2.2 场景 2 端到端示例)
- GitHub Actions 可用(用于 Part 2.2 场景 2 流程图)

### 10.4 风险与回滚

| 风险 | 严重度 | 缓解 |
|---|---|---|
| 4 个项目真实拦截数据不足 | 中 | 用 loop-engineering 自身 152/152 测试数据 + handoff 中的"差点发生的事故"补充 |
| LoopX 上游 API breaking change | 中 | Part 2.1 留"API 兼容性矩阵"子段,实施时确认 |
| Part 3 FAQ 凑不够 10 条 | 低 | 降低到 5 条(用户已在 §2 决策 9 接受) |
| 文档过大读不完 | 低 | 已通过"混合结构"分散,主入口 1 份 + 主菜 1 份 |

**回滚**:spec 不实施,仓库无任何变更(纯文档,git 历史干净)。

---

## 11. 验收标准(spec 实施完成的标志)

- [ ] 6 个文档全部在 `docs/quality/` 下,通过 markdown-link-check
- [ ] Part 1 ROI 引用的每个数字都有 `.loopx/guard-events-*.jsonl` 引用源头
- [ ] Part 2.2 4 个场景每个至少有 1 个真实案例(从 4 个项目抓)
- [ ] Part 2.3 速查表的 matcher / 配置选项与源码一致(`scripts/gen-hook-docs.sh` 自动生成)
- [ ] Part 3 FAQ ≥ 5 条(实施时扩到 10+)
- [ ] 仓库 README 顶部加一条链接到 `docs/quality/README.md`
- [ ] Part 3.3 升级指南引用 Sub-project D 文档(待 D 实施)

---

## 12. spec self-boundary(本 spec 不写什么)

**不写**:
- ❌ 完整的 hook 拦截逻辑(那是 `templates/hooks/*` 源码)
- ❌ LoopX 5 原语的理论基础(那是 LoopX 仓库 README)
- ❌ 4 个项目的完整 case study(那是 `examples/*.md`)
- ❌ 仓库顶层 README 改动(那是 Sub-project C)
- ❌ OpenClaw 兼容性(那是 Sub-project A)

**只写**:
- ✅ 多文档结构的章节大纲
- ✅ 每个章节的要点(3-5 句)
- ✅ 1-2 个示例场景占位(实施时填实)
- ✅ 实施阶段的元信息(数据依赖 / 验收标准 / 风险)

---

## 13. 下一步(交给 writing-plans skill)

**本 spec 经用户审核后,交接给 `superpowers:writing-plans` 制定详细实施计划**,包括:

1. 每个文件的写作任务拆解(谁写 / 何时写 / 怎么验证)
2. 数据采集的顺序(从哪个项目先抓 / 抓哪些字段)
3. 实施的时间线(估时 vs 实际)
4. 中间检查点(每完成 1 个文档,验证清单跑一次)

**关键交接信息**:
- 6 个文件的路径 + 章节大纲(本 spec §3 + §5)
- 实施阶段元信息(本 spec §10)
- 验收标准(本 spec §11)
- 容错 + 验证策略(本 spec §8 + §9)

---

## 附录 A · 与已有仓库资产的关系

| 现有资产 | 在本手册的引用位置 |
|---|---|
| `templates/hooks/guard-*.{js,sh,py}` | Part 2.3 §1 hook 速查表(自动生成) |
| `templates/skills/loopx-project/SKILL.md` | Part 2.1 5 原语每节"本项目怎么实现"段 |
| `templates/commands/deploy-verify/` | Part 2.3 §3 command 速查表 |
| `playbooks/A-pr-review/*` | Part 2.2 场景 2 |
| `playbooks/B-long-research/*` | Part 2.2 场景 3 |
| `playbooks/C-oncall/TODO.md` | Part 2.2 场景 4(注意:C 还是 TODO,要标注) |
| `examples/rime-claude.md` 等 4 个 | Part 2.2 4 个场景的"背景"段 |
| `docs/ARCHITECTURE.md` | Part 2.1 引用(讲解 5 hook 数据流) |

**复用原则**:不重复造轮子。本手册是"导航 + 解读",真实技术细节链向 `templates/` `playbooks/` `docs/` 已有资产。

---

## 附录 B · 修订历史

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-26 | DRAFT | 初版,经 brainstorming 4 个 section 全部确认 |

---

*本 spec 由 brainstorming 流程产出,经 5 轮澄清 + 4 轮 section 确认。最终交付:6 个文档,~1100-1500 行,~12-18 小时工作量。*
