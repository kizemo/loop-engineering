# Playbook B · 研究员式(跨天调研 + 写作)

> **循环长度**:长(跨天调研,2-3 天)
> **状态**:🟡 通用框架就绪,具体主题待用户补

---

## 一、目标

跨 2-3 天调研一个开源生态(例如 LoopX、auto-research、claude-mem 这一组)+ 写一篇博文。AI 每天自动抓 GitHub / 官方文档 / Reddit / HN / X 的更新,整理成 review-packet,你每天拍板。

**最小启动版**(本次提供):LoopX connect 命令模板 + 3 个 Sub-agent 配置。**具体调研主题由用户后补**,见 `TODO-TOPIC.md`。

---

## 二、叠法

```
你写好 CLAUDE.md(目标 + 范围 + 读者画像)
    ↓
loopx connect --goal-id GOAL-001 --objective "<主题>" --adapter-kind claude-goal-mode
    ↓
Sub-agent #1:抓 GitHub 数据(Projects MCP)
Sub-agent #2:抓官方文档(Firecrawl MCP)
Sub-agent #3:抓社区评测(Reddit MCP)
    ↓
Hook(UserPromptSubmit, async) 注入"今天配额剩多少"
Hook(Stop, exit 2) 阻止在 evidence 文件没产出前停
    ↓
24h 后:loopx review-packet 给你一份"它干了啥、卡在哪、该不该继续"
    ↓
你拍板:继续 / 改 scope / 收尾
```

---

## 三、文件清单(本目录)

| 文件 | 用途 |
|---|---|
| `README.md`(本文件) | Playbook B 总览 |
| `LOOPX-CONNECT-CMD.md` | `loopx connect` 调用模板(选 goal_id / objective / domain) |
| `SUB-AGENT-CONFIG.yaml` | 3 个 Sub-agent 配置(GitHub / 官方文档 / 社区) |
| `TODO-TOPIC.md` | **空文件**,用户后补具体调研主题 |

---

## 四、实施步骤

### 4.1 准备

1. 装好 LoopX(参考根目录 `README.md` §二)
2. 装好 3 个项目级 guard rails hook(`install.sh`)
3. 准备 3 个 MCP server:Projects MCP / Firecrawl MCP / Reddit MCP
4. 写项目级 CLAUDE.md:目标 + 范围 + 读者画像 + 调研问题清单

### 4.2 启动 LoopX goal

按 `LOOPX-CONNECT-CMD.md` 模板填具体主题,跑:

```bash
loopx connect --goal-id GOAL-001 \
    --objective "调研 <具体主题>" \
    --domain "AI Agent 生态分析" \
    --goal-doc "./goal-doc.md" \
    --adapter-kind claude-goal-mode
```

### 4.3 配置 Sub-agent

把 `SUB-AGENT-CONFIG.yaml` 内容粘到项目 `.claude/agents/` 下,根据具体 MCP 调整。

### 4.4 设置 Hook 配额提醒

在项目 `.claude/settings.json` 加:

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "bash .claude/hooks/inject-budget-context.sh"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash .claude/hooks/block-stop-when-incomplete.sh"
      }]
    }]
  }
}
```

### 4.5 启动循环

cc-haha 会自动按 LoopX goal + Sub-agent 调度,每天产出 review-packet,放在 `.loopx/review-packets/YYYY-MM-DD.md`。

---

## 五、每天 10 分钟的 review-packet 流程

1. 醒来 → `cat .loopx/review-packets/$(date +%Y-%m-%d).md`
2. 看 3 件事:
   - **它干了啥**:Sub-agent 各抓了什么新数据
   - **卡在哪**:有没有遇到调研盲点
   - **该不该继续**:是否要调 scope / 终止
3. 拍板:写入 `decision-YYYY-MM-DD.md`
4. LoopX 第二天按新 decision 继续

---

## 六、风险与避坑

1. **AI 跑偏** — CLAUDE.md 写"什么不算进度",例如"反复刷同一个仓库的 commit 不算产出"
2. **AI 烧光 token** — `--max-budget-usd` 严格限每天
3. **证据失踪** — 必须有 evidence 文件产出,否则 Stop hook 拦下
4. **Sub-agent 上下文丢** — 主 Agent 只看 Sub-agent 的输出,不读它们的推理过程(信息丢失是必然,接受)

---

## 七、Playbook B 主题后补(用户决定)

**当前 TODO**:`TODO-TOPIC.md` 是空文件。用户提一个调研方向(例:"调研 LoopX 跟 claude-mem 的边界"或"调研 auto-research 类工具在 2026-09 后的演化"),填进 TODO-TOPIC.md 后,即可按本目录配置实施。