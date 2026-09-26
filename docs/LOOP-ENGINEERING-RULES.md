# Loop Engineering 在 Claude Code 的落地铁律

> 来源参考：`https://www.aiec.fun/loop-engineering：别再当ai的监工，让它自己跑起来/`
> 适用对象：Claude Code 重度用户
> 落地原则：把"问-答"模式升级为"自驱闭环"，沿用 Claude Code 现有能力，不引入新依赖

---

## 1. 五层 Loop × Claude Code 映射总表

| LE 层 | 触发频率 | Claude Code 落地工具 | 核心动作 |
|---|---|---|---|
| **L5 编排层** | 任务级 | `TaskCreate` + `task.md` + `Plan` agent | 目标拆解、子任务分配、依赖管理、结果汇总 |
| **L1 执行层** | 工具级 | `Read` → `Edit` / `Write` + `test-driven-development` skill | 执行→自检→修正（秒级） |
| **L2 审核层** | 里程碑 | `verification-before-completion` + `AskUserQuestion` + `requesting-code-review` | 产出检查 + 关键决策人工 Gatekeeper |
| **L3 沉淀层** | 任务完成 | `memory/YYYY-MM-DD.md` + `MEMORY.md` + `self-improving` | L0/L1/L2 分层沉淀 |
| **L4 进化层** | 重复/每周 | Skill 「已知陷阱」章节 + `.learnings/` 晋升 | 错误模式 → 规则更新（陷阱飞轮） |

**五组件对应关系**：

- Executor = 主 agent + sub-agent（`sessions_spawn` 对应 `Agent` tool）
- Reviewer = `verification-before-completion` skill + `requesting-code-review`
- Memory = `MEMORY.md`（长期）+ `memory/` 日志（短期）+ 会话上下文（即时）
- Gatekeeper = `settings.json` hooks + `AskUserQuestion` 红线检查
- Orchestrator = `TaskCreate` / `TaskList` / `TaskUpdate` + `dispatching-parallel-agents`

---

## 2. 12 条铁律（不可绕过）

### L5 编排层 — 任务开始前

1. **任务开始必建 `task.md`**——会话级 TODO 清单，所有里程碑必更新（已存在的防丢失规约升级为强制项）
2. **复杂任务必用 `TaskCreate` 拆解**——≥3 步的任务必须建任务列表，标依赖关系
3. **复杂任务先读 `MEMORY.md`**——避免重复已沉淀的错误模式
4. **跨会话长任务必建 `handoff-<topic>-<date>.md`**——撞墙征兆出现或会话结束前必写

### L1 执行层 — 执行中

5. **Read→Edit 必先 Read 完整文件**——禁止「瞄一眼就改」，必须看到完整上下文（你 CLAUDE.md 已含 Burst 红线，升级为铁律）
6. **代码改动后必跑测试**——遵循 `test-driven-development` skill，verify 通过再继续
7. **单回合 diff ≤ 500 行**——超量主动拆小（你已有，预防 400 错误）

### L2 审核层 — 提交前

8. **完成前必跑 `verification-before-completion`**——禁止口头「完成」，必须有命令输出证据
9. **关键决策必走 Gatekeeper 红线**——`AskUserQuestion` 二次确认的场景：
   - 生产环境 / main 分支 / 公开内容发布
   - 数据删除 / 文件删除（已有）
   - 系统配置 / `settings.json` 修改
   - 密钥、Token、对外通信
   - 子 agent 数 ≥ 3（400 oversized 触发器）

### L3 沉淀层 — 任务完成后

10. **每个里程碑必更新 `task.md` / `handoff-*.md`**——已读文件 + 决策 + 进度
11. **错误必写 `.learnings/ERRORS.md`**——含现象 / 原因 / 修复 / 防重犯验证
12. **跨任务模式 ≥3 次必晋升 `MEMORY.md`**——同一错误 / 最佳实践出现 3 次，自动从单条日志升级到长期记忆

### L4 进化层 — 持续运转

- **每个 Skill 必须含「已知陷阱」章节**——新建 Skill 的硬性模板要求
- **每周复盘 `.learnings/`**——主动把单条经验晋升到 `AGENTS.md` / `TOOLS.md`

---

## 3. 可落地文件模板

### 3.1 项目根目录 `CLAUDE.md` 增量

在已有项目 `CLAUDE.md` 末尾追加：

```markdown
## Loop Engineering 铁律（项目级强制）

### L5 编排层（任务开始）
- 任务开始必建 `task.md`，每个里程碑更新进度
- ≥3 步任务必须用 TaskCreate 拆解，标依赖
- 长会话开始必读 `MEMORY.md` 防重复犯错

### L1 执行层（执行中）
- Read→Edit 必先 Read 完整文件
- 代码改动必跑测试（pnpm test / uv run pytest）
- 单回合 diff ≤ 500 行，超量主动拆

### L2 审核层（提交前）
- 完成前必跑 verification-before-completion
- 生产/主分支/公开发布/数据删除 → 必 AskUserQuestion
- 子 agent 并发 ≤ 2

### L3 沉淀层（完成后）
- 里程碑必更新 task.md / handoff-*.md
- 错误必写 .learnings/ERRORS.md（现象/原因/修复/防重犯）
- 同一模式 ≥3 次自动晋升 MEMORY.md

### L4 进化层（持续）
- 每个 Skill 含「已知陷阱」章节
- 每周复盘 .learnings/ → 主动晋升 AGENTS.md / TOOLS.md
```

### 3.2 Skill 模板（含「已知陷阱」章节）

在每个 `SKILL.md` 文件统一追加此章节：

```markdown
## 已知陷阱（陷阱飞轮入口）

<!--
陷阱飞轮：每次本 Skill 引发错误，append 一条。Recurrence-Count ≥ 3 自动晋升到 MEMORY.md。
条目格式：
- [日期] 现象：一句话描述错误
        原因：为什么会犯
        正确做法：应该怎么做
        验证：怎么确认不会重犯
        Recurrence-Count: N
-->

<!-- 示例条目（首次使用可删） -->
- [2026-07-17] 现象：示例
        原因：示例
        正确做法：示例
        验证：示例
        Recurrence-Count: 1
```

### 3.3 `~/.claude/settings.json` hooks 模板

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"const fs=require('fs');const p=process.env.CLAUDE_PROJECT_DIR;if(!p)process.exit(0);const f=p+'/task.md';if(!fs.existsSync(f))process.exit(0);const t=fs.readFileSync(f,'utf-8');if(!/\\b(in_progress|done)\\b/i.test(t))console.error('[Loop-L3] task.md 未更新进度，请追加里程碑');\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"const cmd=process.env.CLAUDE_TOOL_INPUT?.command||'';if(/rm\\s+-rf|Drop\\s+Table|DELETE\\s+FROM/i.test(cmd)){console.error('[Gatekeeper] 高危操作必须 AskUserQuestion 二次确认');process.exit(2);}\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"const p=process.env.CLAUDE_PROJECT_DIR;if(!p)process.exit(0);const f=p+'/task.md';if(!fs.existsSync(f))process.exit(0);const t=fs.readFileSync(f,'utf-8');if(/\\[ \\]/.test(t))console.error('[Loop-L2] task.md 仍有未完成项，请用 verification-before-completion 自检');\""
          }
        ]
      }
    ]
  }
}
```

> 说明：上面三段 hook 是「最简骨架」，对应 L3 沉淀提醒、L2 审核提醒、Gatekeeper 高危拦截。生产环境需按团队规范补充。

---

## 4. 落地路线图（参考文章 4 级渐进）

| 阶段 | 时间 | 落地动作 | 验收标准 |
|---|---|---|---|
| **L1 单任务闭环** | 本周 | 改造 1 个高频任务 SKILL.md，加「已知陷阱」章节；建项目 `task.md` | 每次执行有自检 + 日志 + 沉淀 |
| **L2 跨任务学习** | 2 周内 | `~/.claude/settings.json` 装 hooks 骨架；建 `.learnings/` 目录 | 同一错误第 3 次自动触发晋升 |
| **L3 多 Agent 协作** | 1 个月内 | 子 agent 任务必带「自检报告」返回；建 `shared/` 经验目录 | 子 agent 产出被接受率可统计 |
| **L4 系统级进化** | 长期 | 每月 Skill 自动归档建议；每周复盘 `MEMORY.md` | 新人（新会话）继承历史经验 |

---

## 5. 与现有 CLAUDE.md 的衔接

你 `~/.claude/CLAUDE.md` 已有：
- 会话健康 5 类错误红线（**保留**，与本方案 L1/L2 正交）
- 防丢失 7 条工程实践（**保留**，与本方案 L3 重叠但更具体）
- 安全红线 3 条（**保留**，与本方案 Gatekeeper 重叠但视角不同）

**建议合并策略**：在 `~/.claude/CLAUDE.md` 末尾追加一个 `## Loop Engineering 铁律` 章节，引用本文档路径，避免规则重复维护。

---

## 6. 一句话总结

> 给 Claude 一条轨道：每个节点要知道现在做什么、输入输出是什么、谁检查、出错了怎么办、什么可以沉淀、什么必须等人确认。

把「问-答」单次调用改造成「执行→审核→沉淀→进化→编排」五层闭环——不是让 Claude 更聪明，而是让使用方式更系统。