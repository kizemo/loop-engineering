# Playbook C · On-call 式 · TODO

> **循环长度**:应急(告警触发,分钟级)
> **状态**:🔴 留 TODO,**前置条件高,小团队不推荐实施**

---

## 为什么留 TODO?

Playbook C 的前置条件对小团队太重:

| 前置条件 | 要求 |
|---|---|
| **生产环境** | 有持续运行的业务系统,且不允许半夜宕机 |
| **SRE 同事** | 至少 1 人能在 Slack 收到"AI 已自动诊断"通知后做二次确认 |
| **PagerDuty MCP** | 接 PagerDuty 告警 → cc-haha 自动触发 |
| **Grafana MCP** | AI 能拉指标 |
| **Git log MCP** | AI 能查最近部署 |
| **Runbook** | 已有结构化事故处理手册 |
| **热修复分支流程** | AI 提 PR,SRE 确认后 merge,不能直推 main |

缺任何一项,**误操作的代价远高于"半夜被叫醒 30 分钟"**。

---

## 当准备好之后,实施步骤(预留)

1. 接 PagerDuty MCP + Grafana MCP + Git log MCP
2. 写 SRE 事故分级 CLAUDE.md(从 SEV1 到 SEV4)
3. 部署 `.github/workflows/incident-response.yml`(类比 Playbook A,但触发器是 PagerDuty webhook)
4. 写 Sub-agent 配置:指标拉取 + 日志分析 + runbook 检索
5. 加 3 道 hook:
   - PreToolUse 拦"直推 main" / "删库" / "改 DNS"
   - Stop 拦"测试没跑前停"
   - PostToolUse 记所有 commit + diff 到 Slack
6. 跑 dry-run:用历史事故数据测一遍,看 AI 诊断 + 修是否合理
7. 设 Quota"反着算":平时严格(< $5/天),事故时放宽(允许烧 $50)
8. 演练:SRE 同事在 Slack 收到通知后必须人工确认,不能 auto-merge

---

## 风险

| 风险 | 后果 | 缓解 |
|---|---|---|
| AI 误诊断 | 改坏文件 / 删错数据库 | PreToolUse hook 拦高危操作 + SRE 确认 |
| AI 修错代码 | 引入新 bug | 强制跑测试 + SRE 二次 review |
| token 烧光 | 自动 hotfix 中途停 | 事故时 Quota 放宽,但设硬上限 |
| MCP 故障 | 触发不了 AI | PagerDuty 仍有 fallback 到人工 |

---

## 何时再考虑 Playbook C

- 你有持续运行的 SaaS / 销售 BI / 内部系统
- 半夜被叫醒 ≥ 1 次/月
- 团队有 SRE 或 on-call 轮值
- 已经写过 ≥ 5 次事故 runbook

任一项不满足,先做 Playbook A 或 B。

---

## 状态

🔴 **本目录不提供模板文件**。等用户决定"真的要实施"后,再从 Playbook A 和 B 的模板派生。具体实施代码预计需要 1-2 天。

详见根 README §五"3 种 Playbook"。