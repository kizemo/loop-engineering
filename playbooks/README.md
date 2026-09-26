# 3 种 Playbook 总览

> Loop Engineering 在 cc-haha 上落地的 3 种典型叠法。每种都对应不同的"循环长度"和"适用场景"。

---

## 一、3 种 Playbook 对照

| 维度 | A · 工头式 | B · 研究员式 | C · On-call 式 |
|---|---|---|---|
| **循环长度** | 短(单 PR,分钟到小时) | 长(跨天调研,2-3 天) | 应急(告警触发,分钟级) |
| **触发器** | GitHub PR 创建 | LoopX goal connect + `/loop` | PagerDuty 告警(MCP) |
| **AI 职责** | 只 review + 提评论 | 调研 + 抓数据 + 写证据 | 诊断 + 写 hotfix + 提 PR |
| **人介入点** | review 报 BLOCK 时 | 每天 review-packet 拍板 | Slack 二次确认 + merge |
| **实现成本** | 中 | 中 | 高 |
| **前置条件** | GitHub repo + Actions secrets | LoopX 装好 + MCP 接好 | 生产环境 + SRE 同事 |
| **风险** | 低(只 review 不改) | 中(AI 可能跑偏) | 高(误拦/误修代价大) |

---

## 二、选哪个?

| 你的情况 | 推荐 |
|---|---|
| 你有 GitHub 项目,想让 PR 自动 review | **Playbook A** |
| 你有长期调研任务(写系列博文、跟进开源项目) | **Playbook B** |
| 你有持续运行的业务系统,半夜不想被叫醒 | **Playbook C** |
| 你是个人开发者,只想把 guard rails 装上 | **不需要 Playbook**,只跑 `install.sh` 就够 |

---

## 三、5 原语对照(每个 Playbook)

### Playbook A · 工头式

| 原语 | 谁实现 |
|---|---|
| Objective | CLAUDE.md 写"代码风格 + 安全规范" |
| Todo | TaskList:review → fix → test → commit |
| Gate | PreToolUse Hook 拦 rm / push-to-main / publish |
| Evidence | PostToolUse Hook 记每条 git commit 到 Slack |
| Quota | `--max-budget-usd 0.50` 限单 PR |

### Playbook B · 研究员式

| 原语 | 谁实现 |
|---|---|
| Objective | LoopX `goal_id` + CLAUDE.md |
| Todo | LoopX `todo claim/update` + TaskList |
| Gate | LoopX `gate` + PreToolUse Hook |
| Evidence | LoopX `evidence` + review-packet + auto memory |
| Quota | LoopX `should_run` + `--max-budget-usd` |

### Playbook C · On-call 式

| 原语 | 谁实现 |
|---|---|
| Objective | CLAUDE.md 写"SRE 黄金信号 + 事故分级" |
| Todo | TaskList:诊断 / 修 / 测 / 报告 |
| Gate | PreToolUse Hook(直推 main / 删库 / 改 DNS)+ SRE Slack 确认 |
| Evidence | PostToolUse Hook 记所有 commit + diff |
| Quota | Routines 设"半夜模式每天最多烧 $5" |

---

## 四、各 Playbook 状态

| Playbook | 状态 | 备注 |
|---|---|---|
| **A · 工头式** | 🟡 框架已就绪 | `.github/workflows/pr-review.yml.template` 已写,接入 settings 待用户实施 |
| **B · 研究员式** | 🟡 通用框架就绪,主题待补 | Sub-agent 配置模板已写,具体调研主题由用户后补 |
| **C · On-call 式** | 🔴 留 TODO | 前置条件高(生产环境 + SRE 同事),不推荐小团队实施 |

详见各子目录的 README.md。