# Loop Engineering · 复用项目

> 把"AI Agent 的持续运行"当软件工程问题解的开源工具集 — 5 道项目级 guard rails hook + LoopX 控制面 + 3 种 Playbook 框架。

**80 字摘要**:LoopX 提出的 loop engineering(把 AI Agent 持续运行当软件工程问题解)在 cc-haha(Claude Code)上落地的可复用工具集,Apache-2.0 开源。一行命令装好 5 hook + 3 skill + deploy-verify,从此你写的每一行代码都被确定性门禁守护,AI 永远不能擅自下班。

**关键词**:loop engineering、Claude Code、cc-haha、Hooks、PreToolUse、Stop、guard rails、LoopX、Objective、Gate、Evidence、Quota

---

## 一、5 分钟 quickstart

### 在目标项目里装好(Windows)

```powershell
# 1. clone 本仓库
git clone https://github.com/<your-org>/loop-engineering.git
cd loop-engineering

# 2. 一键安装到目标项目
pwsh -File .\install.ps1 -TargetProject 'C:\path\to\your-project'

# 3. 验证
bash .\templates\hooks\guard-rails-test.sh
```

### 在目标项目里装好(Linux/macOS)

```bash
git clone https://github.com/<your-org>/loop-engineering.git
cd loop-engineering
./install.sh --target /path/to/your-project
bash ./templates/hooks/guard-rails-test.sh
```

装完后,目标项目 `.claude/hooks/` 会出现 10 个文件(5 hook + 3 helper + 1 test + 1 README),并自动接管"危险操作必须人工拍板"的门禁职责。

### 💡 配好后怎么让 agent 真正提质量?

光装好 hook 不够,要看 **[Agent Quality Guide](docs/quality/README.md)** — 5 个 Part 讲解 ROI、5 原语理论、4 个真实场景、资产速查、调优 FAQ。

---

## 二、项目目标

**Loop engineering 是什么**:LoopX(GitHub 6k⭐)提出的工程范式 — 不是让模型更聪明,而是把"AI Agent 的持续运行"当作可被工程化管理的循环过程,跟开发团队一样分任务、看进度、拍板、写日报、算工资。

**LoopX 5 原语**:
| 原语 | 它解决什么 | 本项目怎么实现 |
|---|---|---|
| **Objective(目标)** | Agent 永远知道自己要做什么 | Playbook B 模板 + CLAUDE.md 约束 |
| **Todo(待办)** | 多 Agent 不抢同一份代码 | Sub-agent 配置模板 + claim/lease |
| **Gate(人工门禁)** | 危险操作必须人拍板 | **5 道项目级 guard rails hook** |
| **Evidence(证据)** | 它做了啥、改了什么、跑过什么测试 | LoopX skill + JSONL 写日志 |
| **Quota(配额)** | 决定这一轮该不该跑 | `--max-budget-usd` + LoopX `should_run` |

**本项目定位**:不是 LoopX 本体(那是上游),而是 **"LoopX 在 Claude Code 生态里落地"的可复用工具集**。

---

## 三、目录速查

```
loop-engineering/
├── README.md                          ← 你在这里
├── LICENSE                            ← Apache-2.0
├── .gitignore
├── install.sh / install.ps1           ← 一键安装脚本
│
├── docs/
│   ├── ARCHITECTURE.md                ← 5 hook 架构图 + 数据流
│   ├── CLAUDE-CORE-MD-EXTRACT.md      ← 全局 CLAUDE.md 的 loop engineering 抽离
│   └── LOOP-ENGINEERING-RULES.md      ← 铁律方案(单源引用)
│
├── templates/
│   ├── hooks/                         ← 5 guard rails hook + 3 helper + 1 test + README
│   ├── skills/                        ← LoopX SKILL.md(3 个)
│   ├── commands/                      ← deploy-verify slash command
│   └── blog-post/                     ← 博文写作 SOP + HTML 模板
│
├── playbooks/
│   ├── README.md                      ← 3 种 Playbook 总览
│   ├── A-pr-review/                   ← 工头式:CI 自动审 PR(只 review 不改)
│   ├── B-long-research/               ← 研究员式:跨天调研自动化(框架,主题后补)
│   └── C-oncall/                      ← On-call 式:生产事故自愈(留 TODO)
│
└── examples/                          ← 4 个已部署项目示例
    ├── rime-claude.md
    ├── media-to-doc-ui.md
    ├── cut-ad.md
    └── sandbox-verify.md
```

---

## 四、5 道项目级 guard rails hook

| Hook | 文件类型 | 拦截目标 |
|---|---|---|
| `guard-secret-files.js` | Node.js | Edit/Write/MultiEdit 到 `.env` / `*.pem` / `*.key` / `secrets/` |
| `guard-main-branch-push.py` | Python | Bash `git push origin main\|master` 或 force push |
| `guard-db-migration.sh` | Bash | `alembic upgrade head` / `prisma migrate deploy` / `dbt run tag:prod` |
| `guard-package-publish.sh` | Bash | `npm publish` / `twine upload` / `vsce publish` / `gh release create` |
| `guard-installer-path.sh` | Bash | installer 写到 `target/release/dist/build/output` 之外的路径 |

每个 hook 在 exit 2 之前调 `guard-event-writer.{sh,py}` 写 `.loopx/guard-events-YYYY-MM-DD.jsonl`(LoopX 可消费的结构化日志)。

**与用户级 hook 协作**:用户级 hook 拦通用危险(`rm -rf` / `DROP`),本项目 hook 补项目级细节(写 secret / 推 main / 安装包路径),**两层不重叠**。

详细架构图见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

---

## 五、3 种 Playbook

| Playbook | 类型 | 适用场景 | 实现成本 |
|---|---|---|---|
| **A · 工头式** | 短循环 | CI 上每个 PR 自动 review | 中(GitHub Actions + claude CLI) |
| **B · 研究员式** | 长循环 | 跨 2-3 天调研 + 写博文 | 中(LoopX goal + Sub-agent) |
| **C · On-call 式** | 应急循环 | 半夜告警自动诊断 + hotfix | 高(需生产环境 + SRE 同事) |

**Playbook A** 和 **B** 已写好模板,见 `playbooks/A-pr-review/` 和 `B-long-research/`。**C** 留 TODO,前置条件高(需要生产环境 + PagerDuty MCP),不推荐小团队实施。

---

## 六、跟 LoopX / cc-haha / Claude Code 的关系

```
LoopX 项目(上游)             本项目               cc-haha / Claude Code(下游)
─────────────────         ────────────         ─────────────────────────
Objective 原语       ───▶ Playbook B 模板  ───▶  CLAUDE.md / AGENTS.md
Todo 原语           ───▶ Sub-agent 配置   ───▶  /loop + TaskList
Gate 原语           ───▶ 5 guard hook     ───▶  PreToolUse Hooks + 权限
Evidence 原语       ───▶ JSONL 日志       ───▶  LoopX skill + review-packet
Quota 原语          ───▶ /max-budget-usd  ───▶  + LoopX should_run
                  ────────────
                  本项目 = LoopX 在 cc-haha 上的"项目级封装"
```

---

## 七、安装后的日常使用

### 跑全量 hook 单测

```bash
bash .claude/hooks/guard-rails-test.sh
```

### 看今天的 guard 拦截记录

```bash
bash .claude/hooks/loopx-guard-summary.sh
```

### 触发 LoopX doctor(确认 9/9 required check 全过)

```bash
loopx doctor --deep
```

### 部署 installer 到 Windows Sandbox 验证

```powershell
/deploy-verify rime-claude
```

---

## 八、贡献与扩展

- **新增 guard rails hook**:抄 `templates/hooks/guard-secret-files.js` 的结构,改 matcher + 拦截逻辑,在 `guard-rails-test.sh` 加 happy + block 两个 case
- **新增 Playbook**:在 `playbooks/` 新建子目录,README.md 写"目标 + 叠法 + 5 原语对照"
- **更新 LoopX skill**:`cp ~/.codex/skills/loopx-project/SKILL.md templates/skills/loopx-project/` 后 commit

详细贡献指南见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §扩展点。

---

## 九、版本与状态

- **当前版本**:v1.0(2026-09-26)
- **来源**:从用户 4 个已部署项目(rime-claude / media-to-doc-ui / cut-ad / sandbox-verify)的 152/152 通过测试沉淀
- **协议**:Apache-2.0(参考 LoopX 同协议)
- **依赖**:bash 4.x+,可选 Python 3.11+、Node.js 22+、PowerShell 7+、`loopx` CLI

---

## 十、参考资料

- [LoopX 仓库](https://github.com/loopx-project/loopx)— 6k stars,Apache-2.0
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)— 官方 Hooks 文档
- [Claude Code Overview](https://code.claude.com/docs/en/overview)— 7 层循环原语
- [Karpathy No Priors 2026-03](https://no-priors.com/)— "auto research = objective + metric + boundaries + go" 论述

---

*本项目从用户 2026-08-07 起的 loop engineering 探索沉淀而来(详见 `E:\办公文件\H AI\项目研究\handoff-loop-engineering-*.md` 系列)。*