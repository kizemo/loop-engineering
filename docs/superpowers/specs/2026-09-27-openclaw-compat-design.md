# Loop Engineering · OpenClaw 兼容层 Design Spec

> **状态**:DRAFT · **创建日期**:2026-09-27 · **粒度**:中(架构 + 接口 + 任务大纲)
> **范围**:Sub-project A · "loop-engineering 5 hook + 3 skill 在 OpenClaw 生态里也能跑"
> **作者**:research session · 接力关系:本 spec 经用户审核后,交给 writing-plans 制定实施计划
> **研究输入**:`.superpowers/research/openclaw-hooks.md` + `.superpowers/research/cc-vs-openclaw-hooks.md`

---

## 0. TL;DR(1 分钟读完)

- **目标**:让本仓库的 5 hook + 3 skill + 3 Playbook 在 OpenClaw(391k⭐)workspace 也能跑
- **核心挑战**:Claude Code hook 协议(shell command + stdin JSON + exit 2)和 OpenClaw plugin hook(TS handler + return object + HOOK.md)完全不兼容
- **策略选择**:**Runtime detect + dual output**(Phase 1)+ **可选 manifest auto-gen**(Phase 2,留口子)
- **交付物**:`templates/openclaw/` 目录(~12 文件,800-1200 行)+ 适配 SKILL.md(~6 文件,300 行)+ 扩展 install.sh + 文档 + CI
- **工作量**:~16-24 小时(中粒度 spec,实施 8 task)
- **不交付**:OpenClaw 协议反向桥(把 OpenClaw hook 装到 Claude Code)— ROI 低,留 TODO

---

## 1. 背景与目标

### 1.1 项目原始目标(2026-09-26 校准后)

Sub-project A 服务于两条用户原始目标:

1. **针对 Agents 架构的 loop engineering 优化内容,打包成可复用项目**,任何 AI agent 软件可安装
2. **尽可能兼容 OpenClaw**(391k⭐ 本地 AI agent 框架)

本 spec 把这两条具体化为:**让本仓库的"loop-engineering guard rails"在 OpenClaw workspace 里也能跑起来,行为一致**。

### 1.2 范围分解(本 spec 覆盖)

| 维度 | 在范围? | 说明 |
|---|---|---|
| **5 hook(secret/main/db/package/installer)** | ✅ | 必须能在 OpenClaw `before_tool_call` 触发,等价 block |
| **3 skill(loopx-project 等)** | ✅ | SKILL.md frontmatter 扩展,让 OpenClaw 也能识别 |
| **Event writer(JSONL 日志)** | ✅ | 复用现有 `guard-event-writer.{sh,py}`,无需改动 |
| **Install 集成** | ✅ | `install.sh --with-openclaw` flag |
| **3 Playbook(A/B/C)** | ❌(文档级) | Playbook 是流程描述,不需要协议层适配;仅文档加一节 |
| **OpenClaw 反向适配(把 OpenClaw hook 装到 CC)** | ❌ | ROI 低,目标用户少;留 TODO |
| **重写 OpenClaw plugin SDK** | ❌ | 我们只是用户,不是贡献者 |

### 1.3 本 spec 解决的子问题

- ✅ 选定 compat 策略(runtime detect + dual output)
- ✅ 设计 core logic 与 adapter 分离架构
- ✅ 确定目录结构 + 文件清单
- ✅ 关键决策:工具名映射 / 事件映射 / 协议转换 / 测试矩阵
- ✅ Phase 1 vs Phase 2 边界(scope control)
- ✅ 验收标准
- ✅ 风险与回滚

---

## 2. 关键决策汇总

| # | 决策 | 选择 | 替代方案(已否决) |
|---|---|---|---|
| 1 | compat 策略 | **Phase 1: runtime detect + dual output**;Phase 2: 可选 manifest auto-gen | Adapter 层(双 runtime 抽象);Dual emit 单脚本(耦合) |
| 2 | core 逻辑与 runtime 分离 | **必须分离** — core 是 TS,adapter 各 ~20 行 | 单脚本(难测试,难维护) |
| 3 | 语言选型 | **TypeScript(OpenClaw plugin) + Bash(Claude Code hook)** | 全 TypeScript(CC 端需要 node) |
| 4 | 工具名映射 | **adapter 内 TOOL_ALIAS 表**(`Bash`/`exec` → `exec`) | 透明转换(失去可读性) |
| 5 | Skill 双发布 | **单源 + frontmatter 扩展**(`metadata.openclaw.events`) | install 脚本分发两份 |
| 6 | 测试矩阵 | **同一 fixture 跑两个 runtime**,输出对照 | 各自独立测试 |
| 7 | CI 范围 | **GitHub Actions 加 `openclaw-test` job**,只在 Linux 跑 | 全平台跑 OpenClaw(Gateway 限制) |
| 8 | install flag | **`--with-openclaw`**,与 `--with-loopx-sync` 一致 | 默认开(增量风险) |
| 9 | 文档 | **新增 `docs/openclaw-compat.md`** 主文档 + hook README 加 OpenClaw 段 | 拆 6 个文档(过度设计) |
| 10 | Phase 2(manifest) | **留口子但本次不实施** | 现在就上(过度工程) |

---

## 3. 架构设计

### 3.1 三层抽象

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 3 · Runtime Detection & Output Adapters                │
│ ─────────────────────────────────────────────────             │
│ Claude Code (Bash/Node)              OpenClaw (TypeScript)    │
│   templates/openclaw/adapters/cc.sh    templates/openclaw/    │
│   (read stdin, exit 2 or JSON)         adapters/openclaw.ts   │
│                                          (api.on, return obj) │
├──────────────────────────────────────────────────────────────┤
│ Layer 2 · Tool Name & Event Mapping                          │
│ ────────────────────────────────────                         │
│   TOOL_ALIAS = { "Bash":"exec", "exec":"exec",              │
│                   "Write":"write", "write":"write", ... }    │
│   EVENT_ALIAS = { "PreToolUse":"before_tool_call" }          │
├──────────────────────────────────────────────────────────────┤
│ Layer 1 · Core Logic (100% shared, no IO)                    │
│ ────────────────────────────────────                         │
│   checkSecretPath(toolName, params)                          │
│   checkMainBranchPush(toolName, params)                      │
│   checkDbMigration(toolName, params)                         │
│   checkPackagePublish(toolName, params)                      │
│   checkInstallerPath(toolName, params)                       │
│   → returns { block: bool, reason?: string }                │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Runtime detect 协议

```typescript
// OpenClaw runtime: api.on("before_tool_call", handler)
//   ↑ handler 收到的是 typed event,直接走 core logic
//   ↑ return { block, blockReason } 给 OpenClaw

// Claude Code runtime: shell script 读 stdin JSON
//   ↑ shell 脚本 runtime 检测方式:
//     - 若 $CLAUDE_CODE=1 → Claude Code 模式
//     - 若 $OPENCLAW_ACTIVE=1 → OpenClaw 模式
//     - 都不存在 → 默认 Claude Code(backward compat)
```

**关键设计**:Claude Code hook 脚本不需要知道 OpenClaw;**OpenClaw adapter 包 Claude Code hook 脚本**(用 child_process spawn sync 跑 cc hook,parse exit code + stdout)。

### 3.3 数据流

```
OpenClaw agent 触发工具调用
        │
        ▼
plugin hook: before_tool_call
        │
        ▼
adapter/openclaw.ts (Layer 3)
   │
   ├── 解析 event.toolName → TOOL_ALIAS → exec/write/edit
   ├── 提取 event.params (tool input)
   │
   ▼
core-logic.ts (Layer 1)
   │
   ├── 跑同一个匹配逻辑
   │
   ▼
{ block: bool, reason?: string }
   │
   ▼
adapter/openclaw.ts
   │
   ├── 若 block → return { block: true, blockReason }
   └── 若 allow → return undefined(让 OpenClaw 继续)
```

---

## 4. 目录结构(交付物)

```
loop-engineering/
├── templates/
│   ├── hooks/                      ← 现有(Claude Code 5 hook,不动)
│   ├── openclaw/                   ← 新增(Sub-project A 交付物)
│   │   ├── README.md               ← OpenClaw 集成指南
│   │   ├── adapters/
│   │   │   ├── cc.sh               ← Claude Code side adapter(Bash)
│   │   │   └── openclaw.ts         ← OpenClaw plugin side adapter(TS)
│   │   ├── core/
│   │   │   ├── index.ts            ← 统一入口 + TOOL_ALIAS + EVENT_ALIAS
│   │   │   ├── check-secret-path.ts
│   │   │   ├── check-main-branch-push.ts
│   │   │   ├── check-db-migration.ts
│   │   │   ├── check-package-publish.ts
│   │   │   └── check-installer-path.ts
│   │   ├── plugin/                 ← OpenClaw plugin 入口
│   │   │   ├── package.json
│   │   │   ├── openclaw.plugin.ts  ← plugin 主体(register hooks)
│   │   │   └── tsconfig.json
│   │   └── hooks/                  ← HOOK.md 元数据(给 openclaw hooks list)
│   │       ├── guard-secret-files/
│   │       │   ├── HOOK.md
│   │       │   └── handler.ts      ← thin wrapper 调 core
│   │       ├── guard-main-branch-push/
│   │       ├── guard-db-migration/
│   │       ├── guard-package-publish/
│   │       └── guard-installer-path/
│   └── skills/                     ← 现有 SKILL.md,frontmatter 扩展 metadata.openclaw.*
│
├── docs/
│   └── openclaw-compat.md          ← 主文档(~250 行)
│
├── .github/workflows/
│   └── openclaw-test.yml           ← 新增 CI,Linux-only
│
├── install.sh / install.ps1        ← 加 --with-openclaw flag
└── tests/openclaw/                 ← 跨 runtime 测试
    ├── fixtures/
    │   ├── secret-write.json
    │   ├── secret-write-allow.json
    │   ├── main-push.json
    │   └── ...
    ├── run-all.sh                  ← 跑两遍 runtime,assert 行为一致
    └── README.md
```

**文件总数**:~25 个(15 个新 + 10 个改)

---

## 5. 接口契约

### 5.1 Core Logic 接口(Layer 1)

```typescript
// templates/openclaw/core/index.ts

export type ToolName = "exec" | "write" | "edit" | "read" | "apply_patch" | "web_fetch" | "web_search" | ...;

export interface CheckResult {
  block: boolean;
  reason?: string;          // 给 user 看的
  severity?: "info" | "warning" | "critical";  // OpenClaw UI 用
  allowAlways?: boolean;    // 用户能否 "allow always"
}

export interface CheckContext {
  toolName: ToolName;
  params: Record<string, unknown>;
  cwd?: string;
  sessionId?: string;
  projectRoot?: string;
}

export type CheckFunction = (ctx: CheckContext) => CheckResult;

// 5 个 check 函数,签名一致
export const checks: Record<string, CheckFunction> = {
  "secret-files": checkSecretFiles,
  "main-branch-push": checkMainBranchPush,
  "db-migration": checkDbMigration,
  "package-publish": checkPackagePublish,
  "installer-path": checkInstallerPath,
};
```

### 5.2 TOOL_ALIAS 表(Layer 2)

```typescript
// 双向映射:CC ↔ OpenClaw
export const TOOL_ALIAS: Record<string, ToolName> = {
  // Claude Code → canonical
  "Bash": "exec",
  "Execute": "exec",
  "Read": "read",
  "Write": "write",
  "Edit": "edit",
  "MultiEdit": "edit",  // 拆多次
  "ApplyPatch": "apply_patch",
  "WebFetch": "web_fetch",
  "WebSearch": "web_search",
  // OpenClaw → canonical(同形)
  "exec": "exec",
  "process": "exec",
  "terminal": "exec",
  "code_execution": "exec",
  "read": "read",
  "write": "write",
  "edit": "edit",
  "apply_patch": "apply_patch",
  "web_fetch": "web_fetch",
  "web_search": "web_search",
  // Bash 提取(参数语义)
  // exec.params.command → exec(语义保持)
};

export function normalize(toolName: string, params: any): CheckContext {
  const canonical = TOOL_ALIAS[toolName] || toolName;
  // 把 Claude Code 的 nested tool_input 拍平
  const flatParams = params.tool_input ?? params;
  return { toolName: canonical, params: flatParams, ... };
}
```

### 5.3 Claude Code Adapter(Layer 3, Bash)

```bash
#!/usr/bin/env bash
# templates/openclaw/adapters/cc.sh
# Claude Code 端的 compat 入口(就是现有 hook 脚本,无需新文件)
# 行为:读 stdin JSON → 提取 tool_name + tool_input → 调 node core logic
# 输出:exit 0 (allow) 或 exit 2 (block,stderr 给 reason)

input=$(cat)
node -e "
  const { normalize, checks } = require('./templates/openclaw/core');
  const ev = JSON.parse(process.argv[1]);
  const ctx = normalize(ev.tool_name, ev);
  for (const [name, fn] of Object.entries(checks)) {
    const r = fn(ctx);
    if (r.block) {
      console.error('[' + name + '] BLOCKED: ' + r.reason);
      process.exit(2);
    }
  }
" "$input"
```

**关键洞察**:**这个 cc.sh 不是新文件,而是改写现有 5 hook 的内部实现** — 现有 hook 的匹配逻辑搬到 TS core,hook 脚本变成 thin wrapper。

### 5.4 OpenClaw Adapter(Layer 3, TypeScript)

```typescript
// templates/openclaw/adapters/openclaw.ts
import type { HookAPI } from "@openclaw/plugin-sdk";
import { normalize, checks } from "../core";

export function register(api: HookAPI): void {
  api.on("before_tool_call", async (event, ctx) => {
    const c = normalize(event.toolName, event.params);
    for (const [name, fn] of Object.entries(checks)) {
      const r = fn({ ...c, sessionId: ctx.sessionKey });
      if (r.block) {
        return {
          block: true,
          blockReason: r.reason || "Blocked by guard rail",
          requireApproval: r.severity === "critical" ? {
            title: name,
            description: r.reason,
            severity: "critical",
            allowedDecisions: ["allow-once", "allow-always", "deny"],
          } : undefined,
        };
      }
    }
    // allow
    return undefined;
  }, {
    matcher: ["exec", "write", "edit", "apply_patch", "web_fetch", "web_search"],
    priority: 100,
  });
}
```

### 5.5 OpenClaw Plugin 入口

```typescript
// templates/openclaw/plugin/openclaw.plugin.ts
import { register as registerGuardRails } from "../adapters/openclaw";

export default {
  id: "loopx-guard-rails",
  name: "LoopX Guard Rails",
  version: "1.0.0",
  register(api: any) {
    registerGuardRails(api);
  },
};
```

```json
// templates/openclaw/plugin/package.json
{
  "name": "@loopx/guard-rails-openclaw",
  "version": "1.0.0",
  "main": "openclaw.plugin.ts",
  "openclaw": {
    "minRuntime": "0.5.0"
  },
  "dependencies": {
    "@openclaw/plugin-sdk": "^1.0.0"
  }
}
```

---

## 6. SKILL.md frontmatter 扩展(对现有 3 skill 改动)

### 6.1 示例:`templates/skills/loopx-project/SKILL.md`

```markdown
---
name: loopx-project
description: "Use when managing a project with LoopX 5 primitives..."
metadata:
  openclaw:
    emoji: "🔁"
    events: ["command:new", "message:received"]
    requires:
      bins: ["loopx"]
---

# Skill 内容(主体不动)
```

### 6.2 install.sh 集成

```bash
# install.sh 新增 --with-openclaw flag
if [[ "${WITH_OPENCLAW:-0}" == "1" ]]; then
  # 把 templates/openclaw/plugin/ 复制到目标 workspace 的 .openclaw/plugins/loopx-guard-rails/
  mkdir -p "$TARGET/.openclaw/plugins/loopx-guard-rails/"
  cp -r templates/openclaw/plugin/* "$TARGET/.openclaw/plugins/loopx-guard-rails/"
  # HOOK.md metadata 复制到 .openclaw/hooks/<name>/
  for hook_dir in templates/openclaw/hooks/*/; do
    name=$(basename "$hook_dir")
    mkdir -p "$TARGET/.openclaw/hooks/$name/"
    cp "$hook_dir/HOOK.md" "$TARGET/.openclaw/hooks/$name/"
    # handler.ts 由 core-logic 动态生成(不复制)
  done
  # SKILL.md metadata 注入(可选:自动 merge)
  echo "[install] OpenClaw compat installed to $TARGET/.openclaw/"
fi
```

**核心 install 行为**:
- Claude Code 路径:**完全不动**(现有 `--with-loopx-sync` 兼容)
- OpenClaw 路径:**新插件** + HOOK.md metadata
- 二者并行不冲突(用户可只装一个)

---

## 7. 测试矩阵

### 7.1 现有测试 → 复用

`templates/hooks/guard-rails-test.sh` 已覆盖 Claude Code 路径 46 个 case。Phase 1 改造后,这些测试**继续通过**(因为 Claude Code 端行为不变)。

### 7.2 新增 OpenClaw 测试

`tests/openclaw/run-all.sh`:

```bash
#!/usr/bin/env bash
# 跑两遍,行为必须一致
set -u

PASS=0
FAIL=0

run_check() {
  local name="$1" fixture="$2" expected_block="$3"
  
  # 1. 跑 Claude Code adapter
  cc_exit=0
  cat "fixtures/$fixture" | bash templates/openclaw/adapters/cc.sh >/dev/null 2>&1 || cc_exit=$?
  
  # 2. 跑 OpenClaw adapter(用 ts-node)
  oc_block=$(cat "fixtures/$fixture" | ts-node -e "
    const { normalize, checks } = require('./templates/openclaw/core');
    let ev = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    // 模拟 OpenClaw event format
    ev = { toolName: ev.tool_name, params: ev.tool_input };
    const ctx = normalize(ev.toolName, ev.params);
    for (const [n, fn] of Object.entries(checks)) {
      const r = fn(ctx);
      if (r.block) { console.log('BLOCK'); process.exit(0); }
    }
    console.log('ALLOW');
  ")
  
  # 3. 比较
  if [ "$cc_exit" -eq 2 ] && [ "$oc_block" = "BLOCK" ]; then
    echo "PASS $name (both block)"
    PASS=$((PASS+1))
  elif [ "$cc_exit" -eq 0 ] && [ "$oc_block" = "ALLOW" ]; then
    echo "PASS $name (both allow)"
    PASS=$((PASS+1))
  else
    echo "FAIL $name: cc_exit=$cc_exit, oc_block=$oc_block (expected_block=$expected_block)"
    FAIL=$((FAIL+1))
  fi
}

run_check "secret-block" "secret-write.json" "BLOCK"
run_check "secret-allow" "secret-write-allow.json" "ALLOW"
run_check "main-push-block" "main-push.json" "BLOCK"
run_check "main-push-allow" "main-push-feature.json" "ALLOW"
# ... 5 hook × 2-3 case = 12-15 case

echo "$PASS pass, $FAIL fail"
exit $FAIL
```

### 7.3 CI

`.github/workflows/openclaw-test.yml`:

```yaml
name: openclaw-compat-test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: npm install -g ts-node typescript
      - run: bash tests/openclaw/run-all.sh
```

**Linux-only**:OpenClaw Gateway 在 macOS/Windows 上行为略不同(macOS sandbox 限制),Phase 1 只在 Linux 跑通,跨平台留给后续。

---

## 8. 文档交付物

### 8.1 `docs/openclaw-compat.md`(主文档,~250 行)

| 节 | 内容 |
|---|---|
| 1 | 这是什么 + 适用人群 |
| 2 | 安装(配 install.sh --with-openclaw) |
| 3 | 5 hook 在 OpenClaw 怎么跑(对照表) |
| 4 | 3 skill metadata 扩展 |
| 5 | 自定义 hook(用 core logic 写新 check) |
| 6 | 故障排查(OpenClaw plugin 没加载?hook 不触发?) |
| 7 | 与 Claude Code 的差异(runtime detect 行为) |
| 8 | 引用 |

### 8.2 `templates/openclaw/README.md`(集成指南,~150 行)

- 文件清单
- 一行命令装好
- hook README 更新(在 `templates/hooks/README.md` 加 "OpenClaw 兼容" 段)

---

## 9. 任务大纲(交给 writing-plans)

### Task 1:Core logic 提取(2-3h)

- 把 5 hook 的匹配逻辑搬到 TypeScript(`core/*.ts`)
- 写 unit test(Jest 或 node:test)
- 与 Claude Code 现有 fixture 跑一遍,确保 100% 一致

### Task 2:Claude Code adapter 改写(1-2h)

- 现有 5 hook 改写为 thin wrapper(调 node core)
- 跑现有 `guard-rails-test.sh`,46 case 全 PASS
- 性能:确保 hook 延迟 < 100ms(node 启动可能慢,可考虑持久化进程)

### Task 3:OpenClaw adapter + plugin 入口(3-4h)

- 写 `adapters/openclaw.ts`
- 写 `plugin/openclaw.plugin.ts` + `package.json`
- 写 5 个 `hooks/<name>/HOOK.md` + `handler.ts` thin wrapper
- 本地用 ts-node 手动跑一次 5 hook

### Task 4:测试矩阵(2-3h)

- 写 `tests/openclaw/run-all.sh`
- 12-15 fixture 覆盖 5 hook × block/allow
- 跨 runtime 行为对照测试

### Task 5:CI 集成(1h)

- 新增 `.github/workflows/openclaw-test.yml`
- push 触发,Linux-only
- README 加 CI badge

### Task 6:Skill frontmatter 扩展(1h)

- 现有 3 skill 的 SKILL.md 加 `metadata.openclaw.*` 段
- 验证 Claude Code 不受影响(metadata 段被忽略)

### Task 7:install.sh 集成(1-2h)

- 加 `--with-openclaw` flag
- 复制 plugin + hooks metadata 到目标 workspace
- 加 unit test(目标项目 dry-run)

### Task 8:文档 + Final review(2-3h)

- 写 `docs/openclaw-compat.md`
- 更新 `templates/hooks/README.md` + 顶层 `README.md`
- 加 1 个 example `examples/openclaw-workspace.md`
- Final review(spec self-check + cross-runtime 端到端)

**总工作量**:~13-19 小时(8 task)

---

## 10. 关键决策细节(供 writing-plans 参考)

### 10.1 Core logic 与现有 hook 行为一致性

**关键风险**:Core logic 用 TypeScript 重写,可能与现有 bash/python hook 行为有微妙差异(字符处理 / 大小写 / Windows 路径)。

**缓解**:
1. Task 1 完成后,跑现有 `guard-rails-test.sh`,确保所有 46 case 通过
2. 不通过的 case 调 spec,直到一致
3. Task 1 不通过 = 项目失败,需 spec 修订

### 10.2 性能预算

| 阶段 | 预算 |
|---|---|
| node 启动 | < 200ms(实测,~80-120ms) |
| core logic 跑 5 check | < 5ms |
| stdin parse + JSON | < 10ms |
| 总 hook 延迟 | < 250ms |

**对比 Claude Code 现有**:`guard-secret-files.js` 是 node,实测 < 80ms。

**风险**:每次 hook 启动 node,Windows 上慢(WSL/路径解析)。**Phase 2 优化**:常驻 node 进程(走 IPC),但 Phase 1 不做。

### 10.3 Windows 兼容性

- OpenClaw Gateway 在 Windows 上有限制(进程模型不同)
- Phase 1 **只测 Linux**;macOS/Windows 标"unsupported,Phase 2 评估"
- Claude Code hook 在 Windows 仍工作(现有 bash hook 不变)

### 10.4 Permission 语义差异

| Claude Code | OpenClaw |
|---|---|
| exit 2 = block(stop) | `block: true` = block |
| stdout `{permissionDecision: "ask"}` = 请求审批 | `requireApproval: {...}` = 内置审批 UI |
| stdout `{permissionDecision: "allow"}` = 显式 allow(影响 tool) | 默认行为(无 return) |

**决策**:`severity: "critical"` 的 hook(如 main-branch-push)→ 走 `requireApproval`,让用户拍板
`severity: "warning"` → 直接 block,不问

---

## 11. 验收标准

- [ ] 5 core check 函数 + 单元测试,Jest/node:test 全 PASS
- [ ] 现有 5 Claude Code hook 改写为 thin wrapper,`guard-rails-test.sh` 46/46 PASS
- [ ] OpenClaw plugin 在 mock 环境(ts-node 跑 adapter)行为一致,12-15 fixture 跨 runtime 全 PASS
- [ ] 5 HOOK.md + handler.ts 写完,frontmatter 完整
- [ ] `install.sh --with-openclaw` 跑通,目标 workspace 出现 `.openclaw/plugins/loopx-guard-rails/`
- [ ] 3 SKILL.md frontmatter 扩展后,Claude Code 不报错(metadata 段忽略)
- [ ] CI 加 `openclaw-test.yml`,push 触发跑通
- [ ] `docs/openclaw-compat.md` 写完,内部链接全通
- [ ] 顶层 README + `templates/hooks/README.md` 加 OpenClaw 段
- [ ] 至少 1 个 example:`examples/openclaw-workspace.md`

---

## 12. 实施阶段元信息

### 12.1 工作量

~13-19 小时(8 task):
- 编码:8-10h
- 测试:2-3h
- 文档:2-3h
- review + 修订:1-3h

### 12.2 数据依赖

- OpenClaw plugin SDK 文档与版本(已抓 v0.5+)
- 现有 5 hook 源码(已读完)
- TypeScript toolchain(node 20+,ts-node,可选 Jest)

### 12.3 外部依赖

- OpenClaw Gateway 稳定(plugin SDK 0.5.x)
- Node.js 20+(现有项目已支持)
- `loopx` CLI 可选(用于 skill 测试)

### 12.4 风险与回滚

| 风险 | 严重度 | 缓解 |
|---|---|---|
| Core logic 重写行为不一致 | **高** | Task 1 gate:46 case 全 PASS 才进 Task 2 |
| OpenClaw SDK breaking change | 中 | Adapter 层隔离,只换 wrapper |
| node hook 启动慢 | 中 | 性能预算 < 250ms;超了再优化(常驻进程) |
| Windows 不支持 | 低 | Phase 1 文档明示"Linux/macOS only",Windows 用户走 Claude Code |
| 用户装完发现 OpenClaw plugin 没启用 | 中 | install.sh 末尾打印"openclaw plugins reload loopx-guard-rails"提示 |

**回滚策略**:本 spec 不实施 → 仓库无 compat 目录,git 历史干净。所有现有 hook 行为不变。

---

## 13. 验收清单(本 spec 完成的标志)

- [ ] 用户审核 spec 通过
- [ ] writing-plans 产出 `docs/superpowers/plans/2026-09-27-openclaw-compat-plan.md`
- [ ] plan 含 8 task,每个 task 有:数据依赖 / 改动文件 / 验收 / 风险
- [ ] 8 task 全部执行 + commit
- [ ] Final review 通过(行为一致 + 文档完整 + CI 跑通)

---

## 14. spec self-boundary(本 spec 不写什么)

**不写**:
- ❌ 5 hook 的具体匹配逻辑(那是 `core/*.ts` 实施细节)
- ❌ OpenClaw plugin SDK API 完整描述(那是 OpenClaw 文档)
- ❌ 完整 TS 类型定义(那是代码生成)
- ❌ 跨 runtime 性能 benchmark 详细数据(那是 Task 1 实测)

**只写**:
- ✅ 架构 + 接口契约
- ✅ 任务大纲(谁做什么 / 顺序 / 验收)
- ✅ 关键决策(runtime detect / core 分离 / skill 扩展)
- ✅ 风险与回滚

---

## 15. 下一步(交给 writing-plans)

**本 spec 经用户审核后,交给 writing-plans 制定详细实施计划**,包括:

1. 8 个 task 的拆解 + 顺序 + 依赖图
2. 每个 task 的改动文件清单(具体路径)
3. 实施时间线(估时 vs 实际)
4. 中间检查点(每完成 1-2 task,跑相关测试)

**关键交接信息**:
- 8 task 列表(本 spec §9)
- 架构 + 接口(本 spec §3 + §5)
- 验收标准(本 spec §11)
- 容错 + 测试策略(本 spec §7 + §12.4)

---

## 附录 A · 与已有资产的关系

| 现有资产 | 在 Sub-project A 的复用 |
|---|---|
| `templates/hooks/guard-*.{js,sh,py}` | **重写**为 thin wrapper,核心逻辑搬到 TS core |
| `templates/skills/*/SKILL.md` | **扩展 frontmatter**,加 `metadata.openclaw.*` 段 |
| `templates/hooks/guard-event-writer.{sh,py}` | **不动**,OpenClaw adapter 通过 spawn sync 调用 |
| `install.sh` | **新增** `--with-openclaw` flag |
| `tests/guard-rails-test.sh` | **跑同一个 fixture**,验证 cc adapter 行为 |
| `.github/workflows/loopx-sync-test.yml` | **参考** 加 `.github/workflows/openclaw-test.yml` |

**复用原则**:尽量不动现有 hook 行为(用户已装的项目不受影响)。

---

## 附录 B · Phase 2 路线图(本次不做)

如果 Phase 1 成功,可以扩展:

| 维度 | 描述 |
|---|---|
| **Manifest auto-gen** | 写一份 hook 描述 YAML,CI 生成 5 份 adapter + HOOK.md |
| **常驻 node 进程** | Claude Code hook 走 IPC,延迟降到 < 50ms |
| **Windows 兼容** | 适配 OpenClaw Windows 行为(可能需要 WSL) |
| **Plugin SDK 升级跟踪** | 自动检测 OpenClaw 新事件,提示 spec 升级 |
| **Cross-runtime 行为 diff** | CI 自动比较 cc exit code vs openclaw block |

---

## 附录 C · 修订历史

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-27 | DRAFT | 初版,基于 research/openclaw-hooks.md + cc-vs-openclaw-hooks.md |

---

*本 spec 由 research + 对比分析产出,8 task,~13-19h 工作量。提交用户审核后,交 writing-plans 出实施计划。*
