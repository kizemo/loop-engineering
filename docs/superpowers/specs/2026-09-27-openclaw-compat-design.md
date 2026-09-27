# Loop Engineering · OpenClaw 兼容层 Design Spec

> **状态**:DRAFT v2 · **创建日期**:2026-09-27 · **粒度**:中(架构 + 接口 + 任务大纲)
> **修订**:v2(2026-09-27)— 加 IPC 常驻进程 / Windows 全支持 / 单源 SKILL / 性能预算 < 50ms
> **范围**:Sub-project A · "loop-engineering 5 hook + 3 skill 在 OpenClaw 生态里也能跑"
> **作者**:research session · 接力关系:本 spec 经用户审核后,交给 writing-plans 制定实施计划
> **研究输入**:`.superpowers/research/openclaw-hooks.md` + `.superpowers/research/cc-vs-openclaw-hooks.md`
> **用户决策(2026-09-27)**:
> 1. ✅ 真做 core 重写(5 hook 改 thin wrapper,核心搬 TS,46-case 复测必须全 PASS)
> 2. ✅ Windows 全支持(Linux + Windows CI 矩阵必须双绿,OpenClaw Gateway + node IPC + bash/powershell hook)
> 3. ✅ 常驻 node 进程(Phase 1 上 IPC,延迟 < 50ms;不再等 Phase 2)
> 4. ✅ 单源 SKILL.md + 扩展 frontmatter(`metadata.openclaw.*` 段,CC 端忽略)

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
| 3 | 语言选型 | **TypeScript(core + OpenClaw plugin) + Bash/PowerShell(CC adapter)** | 全 TypeScript(CC 端需要 node,且失去 PowerShell) |
| 4 | 工具名映射 | **adapter 内 TOOL_ALIAS 表**(`Bash`/`exec` → `exec`) | 透明转换(失去可读性) |
| 5 | Skill 双发布 | **单源 + frontmatter 扩展**(`metadata.openclaw.events`) | install 脚本分发两份 |
| 6 | 测试矩阵 | **同一 fixture 跑两个 runtime**,输出对照 | 各自独立测试 |
| 7 | CI 范围 | **GitHub Actions 加 `openclaw-test` job**,**Linux + Windows 双矩阵** | 只 Linux(违反 v2 决策) |
| 8 | install flag | **`--with-openclaw`**,与 `--with-loopx-sync` 一致 | 默认开(增量风险) |
| 9 | 文档 | **新增 `docs/openclaw-compat.md`** 主文档 + hook README 加 OpenClaw 段 | 拆 6 个文档(过度设计) |
| 10 | Phase 2(manifest) | **留口子但本次不实施** | 现在就上(过度工程) |
| 11 | **Core 重写** | **必做** — 5 hook 改 thin wrapper,匹配逻辑搬 TS,**46-case 回归测试 gate** | 不重写(无法跨 runtime 复用) |
| 12 | **Windows 支持** | **必做** — OpenClaw Gateway(node) + CC PowerShell adapter + Node IPC(命名管道)+ Windows CI job | 只 Linux(违反 v2 决策) |
| 13 | **常驻 node 进程** | **必做,Phase 1** — IPC(Unix socket / Windows named pipe)+ 延迟 < 50ms | 等 Phase 2(违反 v2 决策;node 启动 ~100ms 不可接受) |
| 14 | **SKILL 单源** | **必做** — frontmatter 扩展 `metadata.openclaw.*`,CC 忽略无关段 | install 分发两份(违反 v2 决策) |

---

## 3. 架构设计

### 3.1 四层抽象(IPC 层新增)

```
┌────────────────────────────────────────────────────────────────────────┐
│ Layer 4 · Runtime Detection & Output Adapters(跨平台)                │
│ ─────────────────────────────────────────────────                      │
│ Claude Code (Bash/PowerShell)              OpenClaw (TypeScript)       │
│   templates/openclaw/adapters/                templates/openclaw/     │
│     ├── cc.sh   (Linux/Mac Git-Bash)            adapters/openclaw.ts   │
│     └── cc.ps1  (Windows PowerShell)           (api.on, return obj)    │
│   IPC client: send JSON via socket → read response                    │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 3 · IPC Transport(常驻 node 进程)                              │
│ ─────────────────────────────────────────────────                      │
│   templates/openclaw/ipc-server.ts                                       │
│     ├── 启动:install.sh spawn,后台运行                                  │
│     ├── Unix socket (Linux/Mac):$XDG_RUNTIME_DIR/loopx-guard.sock     │
│     ├── Named pipe (Windows):\\.\pipe\loopx-guard                      │
│     ├── 协议:JSON request → JSON response                            │
│     ├── 心跳:30s ping,无响应自动重启                                   │
│     └── 进程模型:一个 server,N 个 CC adapter 客户端连                 │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2 · Tool Name & Event Mapping                                     │
│ ────────────────────────────────────                                    │
│   TOOL_ALIAS = { "Bash":"exec", "exec":"exec",                        │
│                   "Write":"write", "write":"write", ... }              │
│   EVENT_ALIAS = { "PreToolUse":"before_tool_call" }                   │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1 · Core Logic (100% shared, no IO)                             │
│ ────────────────────────────────────                                    │
│   checkSecretPath(toolName, params)                                    │
│   checkMainBranchPush(toolName, params)                                │
│   checkDbMigration(toolName, params)                                   │
│   checkPackagePublish(toolName, params)                                │
│   checkInstallerPath(toolName, params)                                 │
│   → returns { block: bool, reason?: string }                           │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Runtime detect 协议

```typescript
// OpenClaw runtime: api.on("before_tool_call", handler)
//   ↑ handler 收到的是 typed event,直接 in-process 调 core logic(无 IPC 开销)
//   ↑ return { block, blockReason } 给 OpenClaw

// Claude Code runtime: shell/powershell 脚本读 stdin JSON
//   ↑ 脚本通过 IPC socket 发送到常驻 ipc-server
//   ↑ 若 server 未启动:fallback 到 spawn sync 启动(冷启动,~100ms)
//   ↑ 若 server 已启动:IPC call ~5ms
```

**关键设计**:
- **OpenClaw adapter 是 in-process**(同 node 进程,无 IPC)— 性能最优
- **Claude Code adapter 走 IPC socket**(跨进程,跨平台)— 延迟 < 50ms
- **Server 进程**:`install.sh` 启动一次,后台 daemonize;每次 hook 复用

### 3.3 数据流

#### 3.3.1 OpenClaw(in-process)

```
OpenClaw agent 触发工具调用
        │
        ▼
plugin hook: before_tool_call
        │
        ▼
adapter/openclaw.ts (Layer 4, in-process)
   │
   ├── 解析 event.toolName → TOOL_ALIAS → exec/write/edit
   ├── 提取 event.params
   │
   ▼
core/check-*.ts (Layer 1, in-process)
   │
   ▼
{ block: bool, reason?: string }
   │
   ▼
adapter/openclaw.ts
   │
   ├── 若 block → return { block: true, blockReason }
   └── 若 allow → return undefined
```

延迟:< 5ms(in-process)

#### 3.3.2 Claude Code(IPC)

```
Claude Code 触发 hook
        │
        ▼
adapter/cc.sh 或 cc.ps1 (Layer 4)
   │
   ├── 读 stdin JSON
   ├── 尝试连接 IPC socket($XDG_RUNTIME_DIR/loopx-guard.sock 或 \\.\pipe\loopx-guard)
   │
   ├── 若连接成功:send JSON,read response
   └── 若未启动:fallback spawn sync 启动 server,等 2s,重连
   │
   ▼
ipc-server.ts (Layer 3, 常驻进程)
   │
   ├── 解析 JSON,normalize toolName
   ├── 跑 5 个 check
   │
   ▼
{ block: bool, reason: string } (JSON response)
   │
   ▼
adapter/cc.sh
   │
   ├── 若 block → 写 stderr reason,exit 2
   └── 若 allow → exit 0
```

延迟:< 50ms(IPC),< 100ms(cold start)

### 3.4 跨平台差异处理

| 维度 | Linux/macOS | Windows |
|---|---|---|
| IPC transport | Unix domain socket | Named pipe(`\\.\pipe\<name>`) |
| Socket 路径 | `$XDG_RUNTIME_DIR/loopx-guard.sock` 或 `$TMPDIR/loopx-guard.sock` | `\\.\pipe\loopx-guard` |
| Server 进程 | `node ipc-server.ts &`(nohup) | `Start-Process node -ArgumentList ...`(后台) |
| Server 状态查询 | `pgrep -f ipc-server` | `Get-Process node \| Where-Object ...` |
| Hook 脚本 | bash(本仓库已有,Git Bash 也行) | PowerShell 7+ |
| OpenClaw Gateway | node 启动 | node 启动(PowerShell 调 node)|
| 测试 | bash + node | PowerShell + node(用 `pwsh` 跑) |

**Node.js `net` 模块**原生支持两种 transport,server 代码 95% 共享,只有 `createServer.listen(path)` 路径字符串不同。

---

## 4. 目录结构(交付物)

```
loop-engineering/
├── templates/
│   ├── hooks/                      ← 现有(Claude Code 5 hook,**全改为 thin wrapper**)
│   │   ├── guard-secret-files.ts   ← 改:原 .js 逻辑搬 TS core,这里只 IPC call
│   │   ├── guard-main-branch-push.ts ← 改:同
│   │   ├── guard-db-migration.ts   ← 改:同
│   │   ├── guard-package-publish.ts ← 改:同
│   │   ├── guard-installer-path.ts ← 改:同
│   │   ├── guard-event-writer.sh   ← 不动(IPC server 内 spawn sync 调)
│   │   ├── guard-event-writer.py   ← 不动
│   │   └── guard-rails-test.sh     ← 不动(46 case 回归测试)
│   └── openclaw/                   ← 新增(Sub-project A 交付物)
│       ├── README.md               ← OpenClaw 集成指南
│       ├── adapters/
│       │   ├── cc.sh               ← Claude Code adapter(Bash,Linux/Mac)
│       │   ├── cc.ps1              ← Claude Code adapter(PowerShell,Windows)
│       │   └── openclaw.ts         ← OpenClaw plugin adapter(TS,跨平台 in-process)
│       ├── core/                   ← 共享 core logic(纯 TS,无 IO)
│       │   ├── index.ts            ← 统一入口 + TOOL_ALIAS + EVENT_ALIAS
│       │   ├── normalize.ts        ← input 规范化(Layer 2)
│       │   ├── types.ts            ← CheckContext / CheckResult / 等
│       │   ├── check-secret-path.ts
│       │   ├── check-main-branch-push.ts
│       │   ├── check-db-migration.ts
│       │   ├── check-package-publish.ts
│       │   └── check-installer-path.ts
│       ├── ipc/                    ← IPC 传输层(常驻 node 进程)
│       │   ├── server.ts           ← 常驻 server(跨平台 socket/pipe)
│       │   ├── client.ts           ← 客户端库(给 cc adapter 用)
│       │   ├── protocol.ts         ← 请求/响应 JSON schema
│       │   └── platform.ts         ← 平台差异(Linux/Mac socket vs Windows pipe)
│       ├── plugin/                 ← OpenClaw plugin 入口
│       │   ├── package.json
│       │   ├── openclaw.plugin.ts  ← plugin 主体(register hooks)
│       │   └── tsconfig.json
│       └── hooks/                  ← HOOK.md 元数据(给 openclaw hooks list)
│           ├── guard-secret-files/
│           │   ├── HOOK.md
│           │   └── handler.ts      ← thin wrapper(in-process 调 core)
│           ├── guard-main-branch-push/
│           ├── guard-db-migration/
│           ├── guard-package-publish/
│           └── guard-installer-path/
│
├── docs/
│   └── openclaw-compat.md          ← 主文档(~300 行)
│
├── .github/workflows/
│   └── openclaw-test.yml           ← 新增 CI,**Linux + Windows 矩阵**
│
├── install.sh / install.ps1        ← 加 --with-openclaw flag + server 启动逻辑
└── tests/openclaw/                 ← 跨 runtime 测试
    ├── fixtures/                   ← CC + OpenClaw 两套 input(同义不同格式)
    │   ├── secret-write.json
    │   ├── secret-write-allow.json
    │   ├── main-push.json
    │   └── ...
    ├── run-all.sh                  ← Linux/Mac runner
    ├── run-all.ps1                 ← Windows runner
    ├── ipc-server-test.sh          ← IPC server 单元测试
    └── README.md
```

**文件总数**:~35 个(25 个新 + 10 个改)

**关键变化**:
- 5 hook 现有 `.js`/`.sh`/`.py` → 全改 `.ts`(thin wrapper + IPC call)
- 新增 `ipc/` 目录 4 文件(server / client / protocol / platform)
- 新增 PowerShell adapter `cc.ps1`
- 测试加 `run-all.ps1` + `ipc-server-test.sh`

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
};

export function normalize(toolName: string, params: any): CheckContext {
  const canonical = TOOL_ALIAS[toolName] || toolName;
  // 把 Claude Code 的 nested tool_input 拍平
  const flatParams = params.tool_input ?? params;
  return { toolName: canonical, params: flatParams, ... };
}
```

### 5.3 IPC 协议(Layer 3)

#### 5.3.1 Transport

| Platform | Transport | 地址 |
|---|---|---|
| Linux/macOS | Unix domain socket | `$XDG_RUNTIME_DIR/loopx-guard.sock` 或 fallback `$TMPDIR/loopx-guard.sock` |
| Windows | Named pipe | `\\.\pipe\loopx-guard` |

**Node.js `net` 模块**:`net.createServer().listen(path)` 自动识别 socket 或 pipe(Windows)。

#### 5.3.2 协议(请求/响应,JSON 行分隔)

**请求**(client → server):
```json
{"id":"uuid-v4","action":"check","toolName":"Bash","params":{"command":"git push origin main"},"cwd":"/path/to/proj"}
```

**响应**(server → client):
```json
{"id":"uuid-v4","results":[{"check":"main-branch-push","block":true,"reason":"direct push to protected ref","severity":"critical"}]}
```

**错误响应**:
```json
{"id":"uuid-v4","error":"core-not-loaded","message":"checks not registered"}
```

#### 5.3.3 Server 进程管理

```typescript
// templates/openclaw/ipc/server.ts
import * as net from "net";
import { platform } from "process";
import { checks } from "../core";

const SOCKET_PATH = process.platform === "win32"
  ? "\\\\.\\pipe\\loopx-guard"
  : (process.env.XDG_RUNTIME_DIR || process.env.TMPDIR || "/tmp") + "/loopx-guard.sock";

const server = net.createServer((socket) => {
  let buf = "";
  socket.on("data", (chunk) => {
    buf += chunk.toString("utf8");
    let nl;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      handleRequest(socket, line);
    }
  });
});

function handleRequest(socket: net.Socket, line: string) {
  try {
    const req = JSON.parse(line);
    const ctx = normalize(req.toolName, req.params);
    const results = Object.entries(checks).map(([name, fn]) => ({
      check: name,
      ...fn(ctx),
    }));
    const blocker = results.find((r) => r.block);
    socket.write(JSON.stringify({ id: req.id, results }) + "\n");
  } catch (e: any) {
    socket.write(JSON.stringify({ id: "?", error: "parse-failed", message: e.message }) + "\n");
  }
}

server.listen(SOCKET_PATH, () => {
  // 输出 PID + socket path 给 install.sh 记录
  console.log(JSON.stringify({ ready: true, pid: process.pid, socket: SOCKET_PATH }));
});
```

#### 5.3.4 Client(给 cc adapter 用)

```typescript
// templates/openclaw/ipc/client.ts
import * as net from "net";
import { platform } from "process";
import { randomUUID } from "crypto";

export async function ipcCheck(req: Omit<IpcRequest, "id">): Promise<IpcResponse> {
  const path = process.platform === "win32"
    ? "\\\\.\\pipe\\loopx-guard"
    : (process.env.LOOPX_GUARD_SOCK || defaultPath());
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(path);
    const id = randomUUID();
    let buf = "";
    socket.on("connect", () => {
      socket.write(JSON.stringify({ id, ...req }) + "\n");
    });
    socket.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      const nl = buf.indexOf("\n");
      if (nl !== -1) {
        const resp = JSON.parse(buf.slice(0, nl));
        resolve(resp);
        socket.end();
      }
    });
    socket.on("error", (e) => reject(e));
    setTimeout(() => { socket.destroy(); reject(new Error("ipc-timeout")); }, 5000);
  });
}
```

### 5.4 Claude Code Adapter(Layer 4)

#### 5.4.1 cc.sh(Linux/macOS)

```bash
#!/usr/bin/env bash
# templates/openclaw/adapters/cc.sh
# Claude Code 端的 compat 入口(Linux/macOS)
# 行为:读 stdin JSON → IPC call to server → 解析 response → exit code
# Fallback:server 未启动 → spawn sync 启动 → 等 2s → 重试

set -u
input=$(cat)
SOCK="${LOOPX_GUARD_SOCK:-${XDG_RUNTIME_DIR:-/tmp}/loopx-guard.sock}"

# 尝试 IPC
result=$(node -e "
  const { ipcCheck } = require('./templates/openclaw/ipc/client');
  const req = JSON.parse(process.argv[1]);
  ipcCheck(req).then((r) => {
    const blocker = r.results.find(x => x.block);
    if (blocker) {
      console.error('[' + blocker.check + '] BLOCKED: ' + blocker.reason);
      process.exit(2);
    }
    process.exit(0);
  }).catch((e) => {
    console.error('ipc-failed: ' + e.message);
    process.exit(1);
  });
" "$input" 2>&1) || {
  # IPC 失败 → fallback cold start
  if [ ! -f "${SOCK}.pid" ]; then
    node templates/openclaw/ipc/server.ts &
    SERVER_PID=$!
    echo $SERVER_PID > "${SOCK}.pid"
    sleep 2
  fi
  # 重试(同上代码,略)
}

exit $?
```

#### 5.4.2 cc.ps1(Windows)

```powershell
# templates/openclaw/adapters/cc.ps1
# Claude Code 端的 compat 入口(Windows)
# 行为同 cc.sh,只是 PowerShell 语法

$input = [Console]::In.ReadToEnd()
$pipeName = "loopx-guard"

# 转 JSON 给 node IPC client
$result = node -e "
  const { ipcCheck } = require('./templates/openclaw/ipc/client');
  const req = JSON.parse(process.argv[1]);
  ipcCheck(req).then((r) => {
    const blocker = r.results.find(x => x.block);
    if (blocker) {
      console.error('[' + blocker.check + '] BLOCKED: ' + blocker.reason);
      process.exit(2);
    }
    process.exit(0);
  });
" $input

if ($LASTEXITCODE -eq 2) { exit 2 }
exit 0
```

### 5.5 OpenClaw Adapter(Layer 4, TypeScript, in-process)

```typescript
// templates/openclaw/adapters/openclaw.ts
import type { HookAPI } from "@openclaw/plugin-sdk";
import { normalize, checks } from "../core";

export function register(api: HookAPI): void {
  api.on("before_tool_call", async (event, ctx) => {
    // in-process:无 IPC,直接调 core
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
    return undefined;
  }, {
    matcher: ["exec", "write", "edit", "apply_patch", "web_fetch", "web_search"],
    priority: 100,
  });
}
```

### 5.6 OpenClaw Plugin 入口

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

> **用户决策更新**:core 重写 / Windows / IPC / 单源 SKILL 全部必做,Phase 1 就要全部交付。

### Task 1:Core logic 提取 + 单测(3-4h)🔴 **Gate**

- 把 5 hook 的匹配逻辑搬到 TypeScript(`core/check-*.ts`)
- 写 unit test(node:test,12-15 fixture)
- **关键 gate**:跑现有 `guard-rails-test.sh`,**46/46 case 必须 PASS**(行为一致性)
- 不通过 = 整个项目失败,spec 需修订
- 输出:`core/` 目录 6 文件,单测全绿

### Task 2:Claude Code hook 改写 + IPC 客户端(3-4h)🔴 **Gate**

- 现有 5 hook 改写为 thin wrapper(`guard-*.ts`)
- 每个 wrapper 通过 IPC client 调用常驻 server
- 跑现有 `guard-rails-test.sh`,46/46 PASS(IPC call 比原 80ms 还快)
- 输出:5 个 `.ts` 替换原 `.js`/`.sh`/`.py`

### Task 3:IPC server + 跨平台 transport(3-4h)🔴 **Gate**

- 写 `ipc/server.ts`(Unix socket on Linux/Mac,named pipe on Windows)
- 写 `ipc/client.ts`(跨平台自动选 transport)
- 写 `ipc/protocol.ts`(JSON 行分隔 schema)
- 写 `ipc/platform.ts`(路径解析 + 启动检测)
- `ipc-server-test.sh`:`sleep 0` + 100 个并发 IPC call + 断言
- 输出:`ipc/` 4 文件,本地手测 < 50ms

### Task 4:cc.sh + cc.ps1 adapter(2-3h)

- `adapters/cc.sh`(Linux/Mac Git-Bash):IPC client 调用 + fallback cold-start
- `adapters/cc.ps1`(Windows PowerShell 7+):同上
- 跨平台手测:Linux dev box + Windows VM(或 GitHub Actions Windows runner)
- 输出:`adapters/cc.{sh,ps1}` 各 ~30 行

### Task 5:OpenClaw adapter + plugin 入口(2-3h)

- 写 `adapters/openclaw.ts`(in-process,无 IPC)
- 写 `plugin/openclaw.plugin.ts` + `package.json` + `tsconfig.json`
- 写 5 个 `hooks/<name>/HOOK.md` + `handler.ts` thin wrapper
- 本地用 ts-node 手动跑一次 5 hook
- 输出:`plugin/` 3 文件 + `hooks/<name>/` 5 目录

### Task 6:跨 runtime 测试矩阵(2-3h)

- `tests/openclaw/fixtures/`:12-15 fixture(CC + OpenClaw 两套格式)
- `tests/openclaw/run-all.sh`(Linux/Mac):跑 cc.sh + oc adapter,断言一致
- `tests/openclaw/run-all.ps1`(Windows):同上
- `tests/openclaw/ipc-server-test.sh`:100 并发 call + 启动/重启测试
- 输出:`tests/openclaw/` 4 文件 + fixtures

### Task 7:CI 集成(1-2h)🔴 **Gate**

- 新增 `.github/workflows/openclaw-test.yml`
- **Linux + Windows 双矩阵**(用户决策 #2)
- push 触发,跑 unit + ipc + cross-runtime 测试
- README 加 CI badge
- 输出:`openclaw-test.yml` ~40 行

### Task 8:Skill frontmatter 扩展 + install 集成(2-3h)

- 现有 3 SKILL.md 加 `metadata.openclaw.events` + `requires.bins` 段(单源)
- `install.sh --with-openclaw`:复制 plugin + 启动 ipc-server 注册为 daemon
- `install.ps1 --with-openclaw`:Windows 版(Start-Process 后台)
- 加 unit test:`tests/install-openclaw-test.sh` dry-run
- 输出:`install.{sh,ps1}` 各加 30 行

### Task 9:文档 + Final review(2-3h)

- 写 `docs/openclaw-compat.md`(~300 行,主文档)
- 更新 `templates/hooks/README.md` + 顶层 `README.md` 加 OpenClaw 段
- 加 1 个 example:`examples/openclaw-workspace.md`
- Final review:spec self-check + cross-runtime 端到端 + Windows 手测
- 输出:3 文档 + 1 example + Final report

**总工作量**:~20-27 小时(9 task)

**🔴 Gate 任务**(任何不通过 = 项目失败):1、2、3、7

---

## 10. 关键决策细节(供 writing-plans 参考)

### 10.1 Core logic 与现有 hook 行为一致性(用户决策 #1)

**关键风险**:Core logic 用 TypeScript 重写,可能与现有 bash/python hook 行为有微妙差异(字符处理 / 大小写 / Windows 路径)。

**缓解**:
1. Task 1 完成后,跑现有 `guard-rails-test.sh`,确保所有 46 case 通过
2. 不通过的 case 调 spec,直到一致
3. Task 1 不通过 = 项目失败,需 spec 修订

**Gate 路径**:`Task 1 → 46/46 PASS → Task 2 开工`

### 10.2 性能预算(用户决策 #3:IPC 常驻进程)

| 阶段 | 预算 |
|---|---|
| IPC client connect (Unix socket / named pipe) | < 5ms |
| IPC request/response round-trip | < 10ms |
| Server 处理 5 check | < 5ms |
| Total Claude Code hook latency | **< 50ms** |
| Cold start(server 未启动时) | < 150ms(可接受,后续 hook 复用) |
| OpenClaw in-process adapter | **< 5ms**(无 IPC) |

**对比现状**:
- 现状(`guard-secret-files.js` 每次 node 启动):~80-120ms
- 优化后(IPC server 常驻):< 50ms
- 优化幅度:**~2-3x**

### 10.3 Windows 兼容性(用户决策 #2)

**支持矩阵**(Phase 1 必须全绿):

| 维度 | Linux | macOS | Windows |
|---|---|---|---|
| OpenClaw Gateway | ✅ node | ✅ node | ✅ node |
| OpenClaw plugin | ✅ in-process | ✅ in-process | ✅ in-process |
| Claude Code hook | ✅ cc.sh | ✅ cc.sh(Git Bash)| ✅ cc.ps1(PowerShell 7+) |
| IPC transport | ✅ Unix socket | ✅ Unix socket | ✅ Named pipe |
| CI 跑通 | ✅ ubuntu-latest | ✅ macos-latest(可选) | ✅ windows-latest |
| `guard-rails-test.sh` 跑通 | ✅ | ✅(Git Bash) | ⚠️ 需 power shell 等价(不在本 spec 范围)|

**Windows 特定考虑**:
- Named pipe 路径: `\\.\pipe\loopx-guard`
- PowerShell 7+(pwsh)而非 Windows PowerShell 5.1(`powershell`)
- Node.js `net.createServer().listen('\\\\.\\pipe\\loopx-guard')` — 注意 path 转义
- `Start-Process node -ArgumentList ...` 后台启动,`Get-Process node` 查询 PID
- Server 进程崩溃自动重启(install.sh 末尾加 health-check 守护)

**测试要求**:
- GitHub Actions Windows runner 跑 `pwsh tests/openclaw/run-all.ps1`
- 本地开发:Windows 10/11 + WSL2 或 PowerShell 7+ 都行

### 10.4 Permission 语义差异

| Claude Code | OpenClaw |
|---|---|
| exit 2 = block(stop) | `block: true` = block |
| stdout `{permissionDecision: "ask"}` = 请求审批 | `requireApproval: {...}` = 内置审批 UI |
| stdout `{permissionDecision: "allow"}` = 显式 allow(影响 tool) | 默认行为(无 return) |

**决策**:`severity: "critical"` 的 hook(如 main-branch-push)→ 走 `requireApproval`,让用户拍板
`severity: "warning"` → 直接 block,不问

### 10.5 IPC server 进程管理

**启动时机**:
- `install.sh --with-openclaw`:启动一次,后台 daemonize,写入 PID file
- `install.sh --uninstall`:kill PID,清 socket/pipe

**进程隔离**:
- 每个 workspace 一个 server(`<workspace>/.loopx/guard-server.pid` + socket)
- 多 workspace 不冲突(各自 PID file + socket 路径)

**生命周期**:
- install 启动 → hook 调用 → install 卸载 kill
- crash 检测:`cc.sh` 连不上 server → 自动 spawn sync 重启 → 等 2s → 重试

**资源占用**:
- 常驻内存:~30MB(node 基础 + core)
- 0 个 hook 时 CPU 0%(idle on socket)
- 100 并发 call 测试必须 < 50ms p99

### 10.6 现有 bash hook 兼容性

**问题**:`templates/hooks/guard-*.{js,sh,py}` 现状是 node/bash/python 混用。
**方案**:全改 `.ts`(thin wrapper + IPC client)。原 `.sh`/`.py` 保留作为 fallback,但主路径走 TS。

**Windows fallback**:`guard-db-migration.sh` / `guard-installer-path.sh` / `guard-package-publish.sh` 是 bash 脚本,在 Windows 上需要 Git Bash 或 WSL。`cc.ps1` 不直接调这些 bash 文件,而是调 `node guard-*.ts`(IPC 路径),所以 Windows 上无需 Git Bash。

---

## 11. 验收标准(v2,反映用户 4 决策)

### 11.1 必达(用户决策对应)

- [ ] **(用户 #1)** 5 core check 函数 + 单元测试,node:test 全 PASS,**`guard-rails-test.sh` 46/46 PASS**(回归测试)
- [ ] **(用户 #2)** **GitHub Actions Linux + Windows 双绿**,Windows runner 跑 `run-all.ps1` 通过
- [ ] **(用户 #3)** IPC 常驻 server 跑通,Claude Code hook 延迟 **< 50ms**(p99 < 100ms),OpenClaw adapter < 5ms(in-process)
- [ ] **(用户 #4)** 3 SKILL.md frontmatter 单源扩展 `metadata.openclaw.*`,Claude Code 不报错

### 11.2 功能性

- [ ] 现有 5 Claude Code hook 改写为 thin wrapper,行为完全等价
- [ ] OpenClaw plugin 在 mock 环境(ts-node 跑 adapter)行为一致,12-15 fixture 跨 runtime 全 PASS
- [ ] 5 HOOK.md + handler.ts 写完,frontmatter 完整
- [ ] `install.sh --with-openclaw` 跑通,目标 workspace 出现 `.openclaw/plugins/loopx-guard-rails/` + `.loopx/guard-server.pid`
- [ ] `install.sh --uninstall` kill server,清 socket/pipe,删 plugin 目录

### 11.3 工程性

- [ ] CI 加 `openclaw-test.yml`,push 触发跑通(Linux + Windows)
- [ ] IPC server 100 并发测试通过,无 memory leak(跑 1000 round 后内存增长 < 10MB)
- [ ] `docs/openclaw-compat.md` 写完(~300 行),内部链接全通
- [ ] 顶层 README + `templates/hooks/README.md` 加 OpenClaw 段
- [ ] 至少 1 个 example:`examples/openclaw-workspace.md`
- [ ] README 加 CI badge

---

## 12. 实施阶段元信息(v2)

### 12.1 工作量(反映用户决策)

~20-27 小时(9 task):
- Core 重写 + 单测 + IPC 实现:10-12h(vs v1 估时 +60%)
- 测试矩阵(跨平台):3-4h
- 文档 + Final review:3-4h
- 跨平台调试(Windows 首次跑):2-3h
- review + 修订:2-4h

### 12.2 数据依赖

- OpenClaw plugin SDK 文档与版本(已抓 v0.5+)
- 现有 5 hook 源码(已读完)
- TypeScript toolchain(node 20+,ts-node,**必需**)
- PowerShell 7+(Windows 测试用)
- GitHub Actions Windows runner

### 12.3 外部依赖

- OpenClaw Gateway 稳定(plugin SDK 0.5.x)
- Node.js 20+(现有项目已支持)
- `loopx` CLI 可选(用于 skill 测试)
- Windows 10/11 测试机 或 CI runner

### 12.4 风险与回滚

| 风险 | 严重度 | 缓解 |
|---|---|---|
| **Core 重写行为漂移** | 🔴 **高** | Task 1 gate:`guard-rails-test.sh` 46/46 PASS 才进 Task 2 |
| **Windows 平台 bug**(named pipe / PowerShell) | 🔴 **高** | Task 7 gate:CI Windows runner 必须绿;本地 Windows 10/11 手测 |
| **IPC server 启动失败** | 中 | cc.sh fallback:sync spawn server + 2s 重试 |
| **OpenClaw SDK breaking change** | 中 | Adapter 层隔离,只换 wrapper |
| **Server 内存泄漏** | 中 | Task 6 加 1000-round soak test |
| **用户装完发现 OpenClaw plugin 没启用** | 中 | install.sh 末尾打印"openclaw plugins reload loopx-guard-rails"提示 |
| **PowerShell 5.1 vs 7+ 差异** | 中 | spec 强制 PowerShell 7+(pwsh),旧版报错提示升级 |

**回滚策略**:本 spec 不实施 → 仓库无 compat 目录,git 历史干净。所有现有 hook 行为不变(原 `.js`/`.sh`/`.py` 保留,新 `.ts` 是新增不替换)。

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
| 2026-09-27 | v1 DRAFT | 初版,基于 research/openclaw-hooks.md + cc-vs-openclaw-hooks.md |
| 2026-09-27 | v2 DRAFT | 用户 4 决策:core 重写 / Windows / IPC / 单源 SKILL — 架构加 IPC 层,9 task,~20-27h |

---

*本 spec v2 由用户 4 决策驱动:core 重写必做 + Windows 全支持 + IPC 常驻进程 + 单源 SKILL frontmatter。9 task,~20-27h 工作量,4 个 🔴 gate。提交用户审核后,交 writing-plans 出实施计划。*
