# Claude Code Hooks vs OpenClaw Hooks · 横向对比

> **抓取日期**:2026-09-27
> **目的**:为 Sub-project A 设计 compat 层提供决策依据
> **基线**:Claude Code 文档(2026-09) + OpenClaw docs(2026-09)

---

## 0. TL;DR(60 秒)

| 维度 | Claude Code | OpenClaw | 兼容难度 |
|---|---|---|---|
| **触发事件** | `PreToolUse` 等 30+ 个 | `before_tool_call` 等 6 个 | 🟢 中 |
| **工具名** | `Bash`, `Edit`, `Write` | `exec`, `write`, `edit` | 🟢 易 |
| **配置文件** | `.claude/settings.json` | `~/.openclaw/hooks/<n>/HOOK.md` + handler.ts | 🔴 难 |
| **Handler 类型** | Shell 命令(stdin/stdout) | TypeScript 同步函数 | 🔴 难 |
| **Block 协议** | `exit 2` 或 `JSON: deny` | `{ block: true, blockReason }` | 🟡 中 |
| **Skill 格式** | `SKILL.md` frontmatter | `SKILL.md` frontmatter(+ `metadata.openclaw.events`) | 🟢 易 |
| **Skill 存储** | `.claude/skills/`, `~/.claude/skills/` | `<workspace>/skills/`, `~/.agents/skills/` | 🟡 中 |
| **权限模型** | hook 子进程(可沙箱) | Plugin 跑在 Gateway 进程 | 🟢 易 |
| **生命周期** | 单次执行 | Snapshot + reload modes | 🟡 中 |

**核心结论**:
- **Skill 格式接近**,compat 成本低(加 `metadata.openclaw.*` 段即可)
- **Hook 协议差异大**,需要 adapter/dual-emit 层
- **最务实路径**:**(D) Runtime detect + dual output** — hook 脚本运行时检测平台,输出对应格式

---

## 1. 触发事件映射

### 1.1 Claude Code hook 事件(部分)

| 事件 | 触发时机 | 可 block? |
|---|---|---|
| `PreToolUse` | 工具调用前 | ✅ |
| `PostToolUse` | 工具调用后成功 | ❌ |
| `PostToolUseFailure` | 工具调用失败 | ❌ |
| `PermissionRequest` | 工具需要权限 | ❌(用 JSON decision) |
| `Stop` | Claude 完成回复 | ✅ |
| `SessionStart` / `SessionEnd` | session 开始/结束 | ❌ |
| `UserPromptSubmit` | 用户 prompt 后 | ✅ |
| `Notification` | 通知发送 | ❌ |
| `SubagentStart` / `SubagentStop` | sub-agent 启停 | ❌ |
| `PreCompact` / `PostCompact` | compaction | ❌ |
| `PreModelSwitch` | 模型切换 | ✅ |

### 1.2 OpenClaw hook 事件

| Internal hooks | 触发 |
|---|---|
| `command:new` / `command:reset` / `command:stop` | slash command |
| `message:received` / `message:sent` | 消息进出 |
| `gateway:startup` | Gateway 启动 |
| `compaction:start` / `compaction:end` | compaction |

| Plugin hooks | 触发 |
|---|---|
| **`before_tool_call`** | 工具调用前(PreToolUse 等价) |
| `after_tool_call` | 工具调用后 |
| `message_sending` | outgoing 文本改写 |
| `reply_payload_sending` | 完整回复改写 |
| `model_call_started` / `model_call_ended` | 模型计时 |
| `agent_end` / `gateway_stop` | turn/shutdown |

### 1.3 映射表

| Claude Code | OpenClaw | 备注 |
|---|---|---|
| `PreToolUse` | `before_tool_call` | ✅ 直接对应 |
| `PostToolUse` | `after_tool_call` | ✅ |
| `Stop` | `agent_end` | 🟡 时机略不同 |
| `SessionStart` | `gateway:startup` + `session_start` | 🟡 复合事件 |
| `SessionEnd` | `gateway_stop` | ✅ |
| `Notification` | `message:sent` | 🟡 |
| `SubagentStart` | `subagents`(工具调用) | 🔴 事件层无对应,需走工具拦截 |

**结论**:核心 6 个事件可映射;其余需要 fallback("skip" 或 "log only")。

---

## 2. 工具名映射

| Claude Code | OpenClaw | 用途 |
|---|---|---|
| `Bash` | `exec` | 执行 shell 命令 |
| `Read` | `read` | 读文件 |
| `Write` | `write` | 写文件 |
| `Edit` | `edit` | 编辑文件 |
| `MultiEdit` | (多次 `edit`) | 批量编辑 |
| `Glob` | ❌ 无 | 文件 glob |
| `Grep` | ❌ 无 | 内容搜索(用 `exec` + grep) |
| `WebFetch` | `web_fetch` | 拉 URL |
| `WebSearch` | `web_search` | 搜索引擎 |
| `Task` | `subagents` | sub-agent 调度 |
| `TodoWrite` | `progress_card` / `update_goal` | 待办 |
| `NotebookEdit` | ❌ 无 | Jupyter notebook |
| `BashOutput` / `KillBash` | `process` | 后台进程 |
| `ListMcpResourcesTool` | (tool_search_code) | MCP |
| (插件工具 `mcp__*`) | 各种 plugin 工具 | 扩展 |

**关键差异**:
- OpenClaw **没有 `Glob` / `Grep`** 等内置文件搜索工具
- OpenClaw 把 **TodoWrite 当作"目标管理"工具**(`update_goal`),不是 transient todo
- `apply_patch` 是 OpenClaw 特有的 patch 工具,Claude Code 没有

**Compat 决策**:
- Hook 脚本需要内部维护一份 `TOOL_ALIAS` 表,把 Claude Code 的 `Bash` 和 OpenClaw 的 `exec` 都映射到同一逻辑路径"exec"
- 或在 adapter 层规范化

---

## 3. Hook 配置位置差异

### 3.1 Claude Code: 集中式 JSON

```json
// .claude/settings.json (项目级)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-secret-files.sh",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

**优势**:单一文件,易 diff,git 友好
**劣势**:语法严格(JSON 注释不行)

### 3.2 OpenClaw: 分布式 HOOK.md + handler

```
.openclaw/hooks/guard-secret-files/
├── HOOK.md          # frontmatter(YAML)+ 文档
└── handler.ts       # handler 函数
```

```yaml
---
name: guard-secret-files
description: "Block writes to secret paths"
metadata:
  openclaw:
    events: ["before_tool_call"]
    matcher: ["write", "edit"]
    export: default
    requires:
      bins: ["bash"]
---

# Hook 文档...
```

```typescript
// handler.ts
import type { HookAPI } from "@openclaw/plugin-sdk";

export default async function(event, ctx) {
  if (event.toolName === "write" || event.toolName === "edit") {
    // 同一段匹配逻辑
    const path = String(event.params.path ?? "");
    if (SECRET_RE.test(path)) {
      return { block: true, blockReason: "Writing to secret path blocked" };
    }
  }
}
```

**优势**:Hook 自包含(代码 + 文档 + 配置),可独立分发
**劣势**:每个 hook 一个目录,文件多;handler 必须是 TypeScript(本仓库 5 hook 全是 bash/python)

---

## 4. Block 协议对比

### 4.1 Claude Code 协议(三选一)

| 方式 | 适用 |
|---|---|
| `exit 2` | 简单场景(stderr 给 reason) |
| stdout JSON `{permissionDecision: "deny", permissionDecisionReason: "..."}` | 需要 structure |
| stdout JSON `{continue: false, stopReason: "..."}` | 非 PreToolUse 事件 |

### 4.2 OpenClaw 协议

```typescript
return {
  block: true,
  blockReason: "Writing to secret path blocked",
  // 可选: 重写参数
  params: { ...modifiedParams },
  // 可选: 请求审批
  requireApproval: { title, description, allowedDecisions: [...] }
};
```

### 4.3 抽象层(Compat layer)

```typescript
// compat/output.ts
type BlockResult = {
  cc: { exitCode: 2 | "0"; stdout?: string };
  openclaw: { block: boolean; blockReason?: string; params?: ...; requireApproval?: ... };
};

function emitBlock(reason: string, platform: "cc" | "openclaw" | "both"): BlockResult {
  if (platform === "cc") {
    return { cc: { exitCode: 2 }, openclaw: { block: false } };
  }
  if (platform === "openclaw") {
    return { cc: { exitCode: 0 }, openclaw: { block: true, blockReason: reason } };
  }
  return { cc: { exitCode: 2 }, openclaw: { block: true, blockReason: reason } };
}
```

**策略**:hook 脚本内调用 `emitBlock`,根据 `OPENCLAW_ACTIVE` / `CLAUDE_CODE` env var 决定输出哪边。

---

## 5. Input Schema 差异

### 5.1 Claude Code PreToolUse input

```json
{
  "session_id": "abc123",
  "transcript_path": "/home/user/.claude/...",
  "cwd": "/home/user/my-project",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /tmp/foo"
  },
  "tool_use_id": "toolu_01ABC..."
}
```

**特点**:
- `tool_input` 是 nested object(每个工具 schema 不同)
- `cwd`, `session_id`, `transcript_path` 是顶层

### 5.2 OpenClaw before_tool_call event

```typescript
{
  toolName: "exec",
  params: { command: "rm -rf /tmp/foo" },
  toolKind: "host-tool",
  runId: "...",
  toolCallId: "...",
}
```

**特点**:
- `params` 直接是工具参数,**没有 `tool_input` wrapper**
- 上下文在 `ctx`(第二个参数)

### 5.3 抽象

```typescript
function extractToolInput(event: any, platform: "cc" | "openclaw"): { toolName: string; params: any } {
  if (platform === "cc") {
    return { toolName: event.tool_name, params: event.tool_input || {} };
  }
  return { toolName: event.toolName, params: event.params || {} };
}
```

---

## 6. Skill 格式对比

### 6.1 Claude Code SKILL.md

```markdown
---
name: my-skill
description: "Use when..."   # 必需,含 "Use when" 触发描述
hooks:                          # 可选,skill-scoped hooks
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/check.sh"
---

# Skill 文档
```

### 6.2 OpenClaw SKILL.md

```markdown
---
name: my-skill
description: "Use when..."
metadata:
  openclaw:
    emoji: "🚀"
    events: ["before_tool_call"]    # 用于注册 hook
    requires:
      bins: ["node"]
---

# Skill 文档
```

### 6.3 兼容方案

**Option A: 单源 + 双 frontmatter**(推荐)

```markdown
---
name: loopx-project
description: "Use when..."
metadata:
  openclaw:
    emoji: "🔁"
    events: ["command:new"]
    requires:
      bins: ["loopx"]
---

# Skill 内容
```

Claude Code 会忽略 `metadata.openclaw.*` 段(它不识别),OpenClaw 会识别。
Claude Code 的 skill-scoped `hooks:` 段由 Claude Code 读;OpenClaw 走 `events: ["before_tool_call"]` 走 plugin hook。

**Option B: install 脚本分发两份**

```bash
# install.sh --with-openclaw
mkdir -p ~/.agents/skills/loopx-project/
cp templates/skills/loopx-project/SKILL.md ~/.agents/skills/loopx-project/

mkdir -p .openclaw/hooks/loopx-project/
cp templates/openclaw-plugin/* .openclaw/hooks/loopx-project/
```

**推荐 Option A**(零分发成本,单源)。

---

## 7. 决策矩阵:哪种 compat 策略?

| 策略 | 描述 | 工作量 | 维护成本 | 推荐度 |
|---|---|---|---|---|
| **(A) Dual emit** | hook 写一份,但同时输出 Claude Code exit code + OpenClaw JSON | 中 | 中 | ⭐⭐⭐ |
| **(B) Adapter layer** | Claude Code 写 adapter 包成 OpenClaw plugin;反之亦然 | 大 | 高 | ⭐ |
| **(C) Manifest + auto-gen** | 写 YAML manifest,CI 生成 Claude Code settings.json + OpenClaw HOOK.md | 中 | 低(单源) | ⭐⭐⭐⭐ |
| **(D) Runtime detect + dual read** | hook 脚本 runtime 检测平台,按格式输出 | 小 | 低 | ⭐⭐⭐⭐⭐ |

### 推荐:**(D) 起步 + (C) 长期**

1. **Phase 1(D 立即做)**:写 `templates/openclaw/compat.sh` 库,提供:
   - `compat_get_tool_input`(读 stdin / env,normalize 到 `{ tool_name, params }`)
   - `compat_emit_block(reason)`(根据 `OPENCLAW_ACTIVE` env 输出)
   - `compat_emit_allow`(同上)
2. **Phase 2(后续,选 C 或保持 D)**:
   - 如果 hook 数量 > 10,上 manifest 方案
   - 否则 D 方案够用

---

## 8. 实操对比:同一个 hook 在两个 runtime

### 8.1 Claude Code 路径

```bash
# 1. hook 脚本: templates/hooks/guard-secret-files.js
node guard-secret-files.js < input.json
# 2. exit 2 if secret path
# 3. 用户级 .claude/settings.json 加 matcher
```

### 8.2 OpenClaw 路径

```bash
# 1. hook 目录: templates/openclaw/hooks/guard-secret-files/
# 2. handler.ts
cat > handler.ts <<'EOF'
export default async function(event, ctx) {
  // 适配 input: event.toolName, event.params
  // 适配 output: return { block: true, blockReason: "..." }
};
EOF
# 3. HOOK.md frontmatter
# 4. plugin 注册 + reload
openclaw plugins reload loopx-guard-rails
```

### 8.3 抽象后:同一段匹配逻辑 + 两个 wrapper

```typescript
// core-logic.ts(共享,无 IO)
export function checkSecretPath(toolName: string, params: any): { block: boolean; reason?: string } {
  const path = params.file_path || params.path || params.command || "";
  if (SECRET_RE.test(path)) {
    return { block: true, reason: `Writing to secret path: ${path}` };
  }
  return { block: false };
}
```

```bash
# cc-adapter.sh
input=$(cat)
result=$(echo "$input" | node -e "
  const core = require('./core-logic');
  const ev = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  const r = core.checkSecretPath(ev.tool_name, ev.tool_input || {});
  if (r.block) { console.log(JSON.stringify({permissionDecision:'deny',permissionDecisionReason:r.reason})); process.exit(0); }
")
if [ -n "$result" ]; then echo "$result"; exit 0; fi
exit 0
```

```typescript
// openclaw-adapter.ts
import { checkSecretPath } from "../core-logic";
export default async function(event, ctx) {
  const r = checkSecretPath(event.toolName, event.params);
  if (r.block) return { block: true, blockReason: r.reason };
}
```

**优势**:
- core logic 100% 复用,只测一次
- 两个 wrapper 各 ~20 行
- 加新 hook = 加 core + 2 wrappers

---

## 9. 测试对比

| 维度 | Claude Code | OpenClaw |
|---|---|---|
| **测试方式** | stdin JSON + assert exit code | mock event + assert return value |
| **现有测试** | `guard-rails-test.sh` 229 行,46 cases | (无,需新建) |
| **CI** | GitHub Actions(本仓库已配) | 需新建 |

**测试复用**:同一份 fixture(JSON input)可两边用,只需在不同 runtime 跑。

---

## 10. 风险与回滚

| 风险 | 缓解 |
|---|---|
| OpenClaw plugin SDK breaking change | adapter 层隔离,只换 wrapper |
| OpenClaw 平台用户少,投入产出比不确定 | Phase 1 极小投入验证;不行就只做文档说明"用户可自行实现" |
| skill metadata 段被 Claude Code 拒绝 | 测试覆盖;fallback 到 Option B install 脚本分发 |
| 用户装了 compat 但没用 OpenClaw | runtime detect 自动 fallback,零副作用 |

---

## 11. 下一步(spec 输入)

基于本对比,spec 需要回答:

1. **范围**:做哪些 compat 维度?(hook / skill / settings / install)
2. **策略**:Phase 1 = runtime detect adapter;Phase 2 = manifest auto-gen?
3. **结构**:`templates/openclaw/` 目录结构怎么定?
4. **测试**:CI 矩阵(Claude Code + OpenClaw 两套?)
5. **验收**:装到 OpenClaw workspace 后,5 hook 行为一致?

详见 `docs/superpowers/specs/2026-09-27-openclaw-compat-design.md`(待写)。

---

*本文档由 Sub-project A research task 产出(2026-09-27),输入 spec 设计阶段。*
