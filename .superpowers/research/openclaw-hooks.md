# OpenClaw Hooks & Skills · 研究笔记

> **抓取日期**:2026-09-27
> **来源**:docs.openclaw.ai + github.com/openclaw/openclaw
> **用途**:Sub-project A 兼容层设计输入
> **基线版本**:OpenClaw 391k⭐(2026-09 抓)

---

## 0. TL;DR

- **OpenClaw ≠ Claude Code**。架构哲学接近(都是 AI agent loop),但 hook 协议完全不兼容
- **Hook 触发面**:OpenClaw hook = 内部事件(lifecycle/compaction/gateway) + Plugin hooks = 工具调用拦截,**两层分开**
- **工具名映射**:Claude Code `Bash/Edit/Write` ↔ OpenClaw `exec/write/edit`,但 schema 差异大(`exec` params vs `Bash` tool_input)
- **Skills 格式接近**:都基于 AgentSkills spec,frontmatter 几乎相同;OpenClaw 多 `metadata.openclaw.events` 用于 hook 注册
- **返回协议**:Claude Code exit 2/stdout JSON deny ↔ OpenClaw `{ block: true, blockReason }` 对象返回
- **关键挑战**:同一段 hook 逻辑要在两个 runtime 都被识别 — 必须有**双格式 emit** 或 **adapter 层**

---

## 1. OpenClaw 架构速览

### 1.1 三层概念

| 概念 | 作用 | Claude Code 对应 |
|---|---|---|
| **Gateway(网关)** | 长跑进程,管理 session/agent/hook 调度 | Claude Code runtime |
| **Workspace(工作区)** | Gateway 加载 hook/skill 的目录 | `.claude/` 目录 |
| **Plugin(插件)** | TypeScript 模块,注册 typed hook | 无直接对应(Claude Code 是 shell hook) |

### 1.2 三种自动化机制

| 机制 | 用途 | 触发 |
|---|---|---|
| **Internal hooks** | Lifecycle 事件响应(session 启动/重置/compaction/message) | 事件名:`command:new` / `command:reset` / `message:received` / `gateway:startup` 等 |
| **Plugin hooks** | **工具调用拦截/重写/审批** | 事件名:`before_tool_call` / `after_tool_call` / `message_sending` / `model_call_started` 等 |
| **Cron / Webhook** | 定时任务 + 外部触发 | 无直接对应 |

**关键认知**:OpenClaw **没有 PreToolUse** 这种通用事件名 — 它是 `before_tool_call`(属于 plugin hook,必须在 plugin 模块里注册)。

---

## 2. OpenClaw 内部 Hooks(internal hooks)

### 2.1 文件布局

```
~/.openclaw/hooks/<hook-name>/        # Gateway 主机层
├── HOOK.md                           # 配置 + 文档
└── handler.{ts,js}                   # 实际处理逻辑

<workspace>/hooks/<hook-name>/        # Workspace 层(需显式启用)
├── HOOK.md
└── handler.{ts,js}
```

### 2.2 HOOK.md frontmatter schema

```yaml
---
name: my-hook                              # 可选,默认 = 目录名
description: "..."                         # 可选,报告显示用
homepage: https://example.com/...          # 可选,文档链接
metadata:
  openclaw:
    events: ["command:new", "message:received"]   # 必填(至少 1 个)用于注册
    export: default                        # 可选,handler 导出名(默认 default)
    hookKey: my-hook                       # 可选,config entry key
    emoji: "🔗"                            # 可选,显示用
    os: [darwin, linux, win32]             # 可选,平台过滤
    requires:
      bins: [node]                         # 必需在 PATH
      anyBins: [python, python3]
      env: [MY_API_KEY]
      config: [plugins.entries.foo.enabled]
    always: false                          # 可选,绕过 requires
    install:
      kind: npm
      package: "@scope/pkg"
---

# Hook 文档(给人读的)
```

### 2.3 事件名清单(internal)

| 事件 | 触发 |
|---|---|
| `command:new` | 用户 `/new` 命令 |
| `command:reset` | `/reset` |
| `command:stop` | `/stop` |
| `message:received` | 新消息进入 |
| `message:sent` | 消息发出 |
| `gateway:startup` | Gateway 启动 |
| `compaction:start` / `compaction:end` | session compaction |
| `agent_end` | agent turn 结束 |
| `gateway_stop` | Gateway 关停 |

### 2.4 Handler 接口(handler.ts)

```typescript
export default async function (event, ctx) {
  // event = { type, payload, ts, ... }
  // ctx = { agentId?, sessionKey?, runId?, trace? }
  // 必须 throw 或返回 — 没有 exit code 概念
}
```

**重要**:
- 多个 handler **顺序执行**(family listeners first,然后 exact)
- 没有 priority 选项(目录 hook)
- 没有 timeout / 重试 / 持久化队列
- **throw 错误会被 log 但不会终止后续 handler**

### 2.5 启用配置

```json5
// ~/.openclaw/openclaw.json 或 workspace .openclaw.json
{
  "hooks": {
    "internal": {
      "entries": {
        "<hookKey>": {
          "enabled": true
        }
      }
    }
  }
}
```

**启用 ≠ 注册**:目录 hook 必须显式 enabled;bundled/managed hook 默认 enabled。

### 2.6 CLI 管理

```bash
openclaw hooks list
openclaw hooks info <name>
openclaw hooks enable <name>
openclaw hooks disable <name>
openclaw hooks check                  # 验证 hook 健康
openclaw gateway restart --reload-mode hybrid  # 应用变更
```

---

## 3. OpenClaw Plugin Hooks(工具拦截)

> **关键认知**:`before_tool_call` 是 OpenClaw 中"PreToolUse 的等价物",但只能在 Plugin 上下文里注册。

### 3.1 事件名(plugin lifecycle)

| 事件 | 用途 |
|---|---|
| **`before_tool_call`** | 工具调用前(拦截 / 重写 / 审批) |
| `after_tool_call` | 工具调用后(审计) |
| `message_sending` | 改写/取消 outgoing text |
| `reply_payload_sending` | 改写完整回复(含 media) |
| `model_call_started` / `model_call_ended` | 模型计时 |
| `agent_end` / `gateway_stop` | turn 结束 / shutdown |

### 3.2 before_tool_call Event payload

```typescript
type BeforeToolCallEvent = {
  toolName: string;                    // 例: "exec", "write", "edit"
  params: Record<string, unknown>;    // 工具参数(不是 tool_input wrapper)
  toolKind?: string;                   // host-authoritative discriminator
  toolInputKind?: string;              // 例: "javascript" for code_mode_exec
  derivedPaths?: string[];             // 推测的目标路径
  runId?: string;
  toolCallId?: string;
};

type BeforeToolCallCtx = {
  agentId?: string;
  sessionKey?: string;
  sessionId?: string;
  runId?: string;
  abortSignal?: AbortSignal;
  requester?: {
    channel?: string;
    senderId?: string;
    senderIsOwner?: boolean;
    roleIds?: string[];
  };
};
```

### 3.3 Handler 返回值(Block / Approve / Rewrite)

```typescript
type BeforeToolCallResult = {
  // 拦截
  block?: boolean;
  blockReason?: string;

  // 重写参数
  params?: Record<string, unknown>;

  // 请求审批
  requireApproval?: {
    title: string;
    description: string;
    scope?: ApprovalScope;
    severity?: "info" | "warning" | "critical";
    timeoutMs?: number;
    allowedDecisions?: Array<"allow-once" | "allow-always" | "deny">;
    pluginId?: string;
    onResolution?: (decision) => Promise<void> | void;
  };
};
```

**关键差异 vs Claude Code**:
- OpenClaw 是 **return object**,不是 **exit code + JSON stdout**
- Claude Code exit 2 = block;OpenClaw `{ block: true }` = block
- OpenClaw 支持 `requireApproval`(内置审批 UI),Claude Code 用 `permissionDecision: "ask"`
- OpenClaw 支持 `params` 重写且每 handler 隔离副本;Claude Code `hookSpecificOutput.permissionDecision` 仅 allow/deny/ask

### 3.4 注册语法(在 plugin 入口)

```typescript
api.on("before_tool_call", async (event, ctx) => {
  if (event.toolName === "exec") {
    const cmd = String(event.params.command ?? "");
    if (cmd.includes("rm -rf")) {
      return { block: true, blockReason: "Destructive command blocked" };
    }
  }
}, {
  matcher: ["exec", "write", "edit"],   // 可选,工具 ID 列表;省略 = 全部
  priority: 100,                          // 可选,数字越大越先跑
});
```

### 3.5 Plugin 配置启用

```json5
{
  "plugins": {
    "entries": {
      "<plugin-id>": {
        "enabled": true,
        "hooks": {
          "allowConversationAccess": true   // 非 bundled plugin 必需
        }
      }
    }
  }
}
```

---

## 4. OpenClaw Skills

### 4.1 格式(SKILL.md)

```markdown
---
name: my-skill
description: "Use when..."   # 必需
homepage: https://...
user-invocable: true           # 默认 true,作为 slash command 暴露
disable-model-invocation: false
command-dispatch: tool         # 可选,bypass model,直接派发到工具
command-tool: <tool-name>
command-arg-mode: raw          # raw | parsed
metadata:
  openclaw:
    emoji: "🚀"
    os: [darwin, linux]
    requires:
      bins: [python3]
      env: [API_KEY]
    install:
      kind: npm
      package: "@scope/pkg"
---

# Skill 文档
```

**与 Claude Code 兼容点**:SKILL.md frontmatter 几乎完全相同,OpenClaw 多 `metadata.openclaw.*` 段。

### 4.2 存储位置(优先级降序)

| 优先级 | 路径 |
|---|---|
| 1 | `<workspace>/skills` |
| 2 | `<workspace>/.agents/skills` |
| 3 | `~/.agents/skills` |
| 4 | `<state-dir>/skills` |
| 5 | `<state-dir>/agents/<agentId>/agent/workshop-skills` |
| 6 | bundled(随安装) |
| 7 | `skills.load.extraDirs` + plugin skills |

> **重要**:Claude Code 的 `~/.claude/skills` 和 `.claude/skills` **不**是 OpenClaw 的 skill root。

### 4.3 加载行为

- Snapshot 启动时建立,直到 refresh
- Refresh 触发:SKILL.md 改动(250ms debounce)、Gateway 重启、agent allowlist 改、新节点连接
- 每次消息最多 8 个 distinct skill
- Token 影响:~24 tokens/skill(base 97 chars + name/desc/location + XML escape)

---

## 5. OpenClaw 工具名全清单

| 类别 | 工具名 |
|---|---|
| **Runtime** | `exec`, `process`, `terminal`, `code_execution` |
| **Files** | `read`, `write`, `edit`, `apply_patch` |
| **Human input** | `ask_user`, `secrets` |
| **Web** | `web_search`, `x_search`, `web_fetch` |
| **Browser** | `browser` |
| **Sessions/agents** | `sessions_*`, `agents_wait`, `subagents`, `agents_list`, `session_status`, `get_goal`, `create_goal`, `update_goal` |
| **Automation** | `cron`, `heartbeat_respond` |
| **Gateway/nodes** | `gateway`, `nodes` |
| **Media** | `view_image`, `image_generate`, `music_generate`, `video_generate`, `tts` |

**关键差异 vs Claude Code**:
| Claude Code 工具 | OpenClaw 等价 |
|---|---|
| `Bash` | `exec` |
| `Read` | `read` |
| `Write` | `write` |
| `Edit` | `edit` 或 `apply_patch` |
| `MultiEdit` | 多次 `edit` |
| `Glob` | (无直接对应,需要 plugin) |
| `Grep` | (无直接对应,需要 `exec` 跑 grep) |
| `WebFetch` | `web_fetch` |
| `WebSearch` | `web_search` |
| `Task` (sub-agent) | `subagents` |
| `TodoWrite` | `progress_card` 或 `update_goal` |
| `NotebookEdit` | (无对应,需要 plugin) |
| `BashOutput` / `KillBash` | `process` |

---

## 6. 安全模型

### 6.1 OpenClaw 信任声明

> "Internal hooks are **trusted code**, not sandboxed scripts. They run with the Gateway process's filesystem, network, and environment access."

→ **plugin hook 必须在受信进程内运行**(Node.js 进程,与 Gateway 同权限)
→ 这与 Claude Code hook 不同(Claude Code hook 是子进程,可以沙箱)

### 6.2 Plugin 加载流程

```bash
# 1. 安装 plugin
openclaw plugins install <id>

# 2. 重载(代码或配置变更后)
openclaw plugins reload <id>

# 3. 验证运行时
openclaw plugins inspect <id> --runtime --json
```

**安全要求**:加载任何 plugin 前必须审查代码(native plugin 跑在 Gateway 进程内)。

---

## 7. 关键设计决策(待 spec 回答)

### 7.1 兼容策略选哪条?

| 策略 | 描述 | 工作量 | 维护成本 |
|---|---|---|---|
| **(A) Dual emit** | 同一段 hook 逻辑,同时输出 Claude Code settings.json 和 OpenClaw HOOK.md + handler.ts | 中 | 中(2 份资产要同步) |
| **(B) Adapter layer** | Claude Code hook 包装成 OpenClaw plugin,OpenClaw hook 包装成 Claude Code shell hook | 大 | 高(两套 runtime 抽象) |
| **(C) Manifest + auto-gen** | 写一份 hook 描述 manifest,CI 生成两份资产 | 中 | **低**(单源) |
| **(D) Runtime detect + dual read** | hook 脚本 runtime 检测自己在哪个平台,按格式输出 | 小 | 低(单脚本) |

**推荐**:先 (D) 给快速 win,再上 (C) 做长期单源维护。

### 7.2 工具名映射放在哪?

- 选项 1:hook 脚本内 if/elif(`TOOL_NAME=$(jq ...); if [ "$TOOL_NAME" = "Bash" ] || [ "$TOOL_NAME" = "exec" ]; then ...`)
- 选项 2:adapter 层转换,hook 内部只认规范化名

### 7.3 Skill 双发布?

- 选项 A:`install.sh --with-openclaw` 把 SKILL.md 复制到 `~/.agents/skills/<name>/`
- 选项 B:加 `metadata.openclaw.*` 段到现有 SKILL.md(单源)
- **推荐 B**:frontmatter 几乎一致,扩展 OpenClaw 段即可

### 7.4 测试矩阵

- **Claude Code**:本仓库现有 `guard-rails-test.sh` 229 行
- **OpenClaw**:需要新建 `templates/openclaw-hooks-test.sh`(插件版)
- 跨平台一致行为需 fixture-driven 测试

---

## 8. 引用

- OpenClaw 主页:https://openclaw.ai
- 文档根:https://docs.openclaw.ai
- Hooks 主页:https://docs.openclaw.ai/automation
- HOOK.md 写作:https://docs.openclaw.ai/automation/hooks/writing-hooks
- Plugin hook 主页:https://docs.openclaw.ai/plugins/hooks
- before_tool_call 详细:https://docs.openclaw.ai/plugins/hooks/tool-policy
- Skills 总览:https://docs.openclaw.ai/tools/skills
- 工具清单:https://docs.openclaw.ai/tools

---

*本文档由 Sub-project A research task 产出(2026-09-27),输入 spec 设计。*
