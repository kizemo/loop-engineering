# Loop Engineering · OpenClaw 兼容层 Implementation Plan

> **创建日期**:2026-09-27 · **接力**:docs/superpowers/specs/2026-09-27-openclaw-compat-design.md v2
> **范围**:Sub-project A · "loop-engineering 5 hook + 3 skill 在 OpenClaw 生态里也能跑"
> **执行模式**:Subagent-Driven(per spec §9 + Sub-project D 经验)
> **任务数**:9 + Final review · **工作量**:~20-27h

---

## 0. TL;DR(60 秒读完)

- **目标**:5 hook + 3 skill 在 OpenClaw(391k⭐)workspace 也能跑,行为一致,延迟 < 50ms(IPC)/ < 5ms(in-process)
- **架构**:4 层(Core logic TS / TOOL_ALIAS / IPC server / adapters),详见 spec §3
- **关键技术决策**:
  - 5 hook 改 thin wrapper,逻辑搬 TS(`templates/openclaw/core/`)
  - 常驻 IPC server(`templates/openclaw/ipc/server.ts`),CC hook 走 socket/pipe
  - OpenClaw adapter 走 in-process,无 IPC 开销
  - SKILL.md 单源 + frontmatter 扩展(`metadata.openclaw.*`)
  - Linux + Windows CI 矩阵双绿
- **风险**:`guard-rails-test.sh` 46/46 回归必须全 PASS(行为一致性 gate)
- **工作量**:~20-27h,9 task

---

## 1. Setup

### 1.1 仓库状态

- **基线**:`main` HEAD = `4b8fbe6`(SDD ledger scaffold)
- **分支**:`main`
- **前置 commit**:
  - `449f99e` docs(spec): add OpenClaw compat layer design spec (v1)
  - `5982774` docs(spec): revise OpenClaw compat spec to v2 (用户 4 决策)
  - `4b8fbe6` fix(sdd): scaffold Sub-project A ledger
- **Plan workspace**:`.superpowers/sdd/2026-09-27-openclaw-compat-plan/`
- **Spec 路径**:`docs/superpowers/specs/2026-09-27-openclaw-compat-design.md` v2(committed)

### 1.2 用户决策(spec v2 §0)

1. ✅ 真做 core 重写(5 hook 改 thin wrapper,核心搬 TS)
2. ✅ Windows 全支持(Linux + Windows CI 双矩阵)
3. ✅ 常驻 node 进程(IPC,延迟 < 50ms)
4. ✅ 单源 SKILL.md + frontmatter 扩展

### 1.3 全局约束(来自 spec)

- **范围**:只做 Sub-project A;**不做** Sub-project B/C/D 任何变更
- **目标用户**:OpenClaw 用户 + Claude Code 用户(双 runtime)
- **数据来源**:**只用本仓库 5 hook 现有逻辑**,不引入新匹配规则
- **测试证据**:每个 task 必须有可跑测试 + 跨 runtime 行为对照
- **CI 必双绿**:Linux + Windows

### 1.4 工具链要求

- Node.js 20+(LTS,本地 + CI)
- TypeScript 5.x(本地 + CI)
- ts-node(本地 + CI)
- PowerShell 7+(Windows 测试)
- bash 4.x+(Linux/Mac 测试)
- GitHub Actions(ubuntu-latest + windows-latest)

---

## 2. 任务依赖图

```
Task 1 (Core logic + 单测)              ──🔴 Gate: 46/46 PASS
  │
  ├──→ Task 2 (CC hook 改写 + IPC client) ──🔴 Gate: 46/46 PASS via IPC
  │       │
  ├──→ Task 3 (IPC server + transport)     ──🔴 Gate: < 50ms p99
  │       │
  │       ├──→ Task 4 (cc.sh + cc.ps1)
  │       │
  │       └──→ Task 5 (OpenClaw adapter + plugin)
  │
  └──→ Task 6 (跨 runtime 测试矩阵)
          │
          └──→ Task 7 (CI 集成)            ──🔴 Gate: Linux + Windows 双绿
                  │
                  └──→ Task 8 (Skill frontmatter + install 集成)
                          │
                          └──→ Task 9 (文档 + Final review)
```

---

## 3. 任务详情

### Task 1 · Core logic 提取 + 单测🔴 **Gate**

**目标**:把 5 hook 的匹配逻辑搬到 TypeScript,跑通 46-case 回归测试。

**Context**:用户决策 #1 — 必须做 core 重写。这是整个项目的基石,行为必须 100% 等价。

**改动文件**:

新增(6 文件):
- `templates/openclaw/core/types.ts` — `CheckContext`, `CheckResult`, `ToolName` 类型
- `templates/openclaw/core/normalize.ts` — TOOL_ALIAS 表 + normalize 函数
- `templates/openclaw/core/check-secret-path.ts` — secret files 匹配逻辑
- `templates/openclaw/core/check-main-branch-push.ts` — main branch 匹配
- `templates/openclaw/core/check-db-migration.ts` — DB migration 匹配
- `templates/openclaw/core/check-package-publish.ts` — package publish 匹配
- `templates/openclaw/core/check-installer-path.ts` — installer path 匹配
- `templates/openclaw/core/index.ts` — 统一入口 + `checks` map
- `templates/openclaw/core/*.test.ts` — node:test 单测(8 文件)

不动:
- `templates/hooks/guard-rails-test.sh` — 46 case 保留
- 现有 5 hook(`.js`/`.sh`/`.py`)— Task 2 才改

**实现要点**:

```typescript
// templates/openclaw/core/types.ts
export type ToolName =
  | "exec" | "write" | "edit" | "read"
  | "apply_patch" | "web_fetch" | "web_search";

export interface CheckResult {
  block: boolean;
  reason?: string;
  severity?: "info" | "warning" | "critical";
}

export interface CheckContext {
  toolName: ToolName;
  params: Record<string, unknown>;
  cwd?: string;
  projectRoot?: string;
}

export type CheckFunction = (ctx: CheckContext) => CheckResult;
```

```typescript
// templates/openclaw/core/normalize.ts
export const TOOL_ALIAS: Record<string, ToolName> = {
  "Bash": "exec", "Execute": "exec",
  "Write": "write", "Read": "read",
  "Edit": "edit", "MultiEdit": "edit",
  "ApplyPatch": "apply_patch",
  "WebFetch": "web_fetch", "WebSearch": "web_search",
  "exec": "exec", "process": "exec", "terminal": "exec", "code_execution": "exec",
  "write": "write", "read": "read", "edit": "edit",
  "apply_patch": "apply_patch",
  "web_fetch": "web_fetch", "web_search": "web_search",
};

export function normalize(toolName: string, params: any): CheckContext {
  const canonical = TOOL_ALIAS[toolName] ?? toolName;
  // CC nested tool_input 拍平
  const flat = params?.tool_input ?? params ?? {};
  return { toolName: canonical, params: flat };
}
```

5 个 check 函数,把现有 bash/python hook 的正则逐字搬到 TS,确保:
- 大小写处理一致
- Windows 路径(`\` → `/`)一致
- allowlist/denylist 行为一致

**测试计划**:

```bash
# 1. 单测(node:test)
node --test templates/openclaw/core/*.test.ts
# 期望:全 PASS,~30 case

# 2. 回归(关键 gate):跑现有 bash hook test,但通过 stdin 喂相同 fixture 给 core
# 写 helper:cc-fixture.json → node normalize+checks → 对比预期 block/allow
bash tests/openclaw/run-core-regression.sh
# 期望:46/46 PASS(与原 bash hook 行为一致)
```

**Gate 条件**:
- [ ] node:test 单测 100% PASS
- [ ] **46/46 回归 PASS**(行为一致)
- [ ] 不通过 = 整个项目失败,需修订 spec

**风险**:
- **行为漂移**:正则从 bash 搬到 TS,边界 case 可能不一致(大小写 / 全角字符 / Windows 路径)
  - 缓解:逐 case 对照;不通过就改 spec 或在 core 里加特例
- **normalize 边界**:TOOL_ALIAS 表不全,新工具名 fallback 行为
  - 缓解:fallback 到 unknown,不 block

**估算**:3-4h

---

### Task 2 · Claude Code hook 改写 + IPC client🔴 **Gate**

**目标**:现有 5 hook 改 thin wrapper,通过 IPC client 调用常驻 server。

**Context**:用户决策 #1 + #3 — hook 改写 + IPC。延迟 < 50ms。

**改动文件**:

替换(5 文件):
- `templates/hooks/guard-secret-files.ts`(原 `.js`)— thin wrapper
- `templates/hooks/guard-main-branch-push.ts`(原 `.py`)— thin wrapper
- `templates/hooks/guard-db-migration.ts`(原 `.sh`)— thin wrapper
- `templates/hooks/guard-package-publish.ts`(原 `.sh`)— thin wrapper
- `templates/hooks/guard-installer-path.ts`(原 `.sh`)— thin wrapper

保留:
- 原 `.js`/`.py`/`.sh` 文件备份为 `.legacy`(不删,加注释说明已弃用)
- `guard-rails-test.sh` 不动

新增:
- `templates/openclaw/ipc/client.ts`(5 个 hook 共用)

**实现要点**:

```typescript
// templates/openclaw/ipc/client.ts
import * as net from "net";
import { platform } from "process";
import { randomUUID } from "crypto";
import { platformPath } from "./platform";

export interface IpcRequest {
  id: string;
  action: "check";
  toolName: string;
  params: any;
  cwd?: string;
}

export interface IpcCheckResult {
  check: string;
  block: boolean;
  reason?: string;
  severity?: string;
}

export interface IpcResponse {
  id: string;
  results: IpcCheckResult[];
  error?: string;
  message?: string;
}

export async function ipcCheck(req: Omit<IpcRequest, "id">, timeoutMs = 5000): Promise<IpcResponse> {
  const id = randomUUID();
  const path = platformPath();
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(path);
    let buf = "";
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(`ipc-timeout after ${timeoutMs}ms`));
    }, timeoutMs);
    socket.on("connect", () => {
      socket.write(JSON.stringify({ id, ...req }) + "\n");
    });
    socket.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      const nl = buf.indexOf("\n");
      if (nl !== -1) {
        clearTimeout(timeout);
        const resp = JSON.parse(buf.slice(0, nl));
        resolve(resp);
        socket.end();
      }
    });
    socket.on("error", (e) => {
      clearTimeout(timeout);
      reject(e);
    });
  });
}
```

```typescript
// templates/hooks/guard-secret-files.ts
#!/usr/bin/env node
import { ipcCheck } from "../openclaw/ipc/client";

(async () => {
  let raw = "";
  try { raw = require("fs").readFileSync(0, "utf8") || ""; } catch {}
  const ev = raw ? JSON.parse(raw) : { tool_name: "unknown", tool_input: {} };
  try {
    const r = await ipcCheck({
      action: "check",
      toolName: ev.tool_name || ev.toolName || "unknown",
      params: ev.tool_input || ev.params || {},
      cwd: ev.cwd,
    });
    const blocker = r.results.find((x) => x.block);
    if (blocker) {
      process.stderr.write(`[${blocker.check}] BLOCKED: ${blocker.reason}\n`);
      process.exit(2);
    }
    process.exit(0);
  } catch (e: any) {
    // IPC 失败 → fail-soft(默认 allow,记录日志)
    process.stderr.write(`[guard-secret-files] ipc-failed: ${e.message}\n`);
    process.exit(0);
  }
})();
```

**测试计划**:

```bash
# 1. 单元:IPC client 单独跑(node:test)
node --test templates/openclaw/ipc/client.test.ts

# 2. 集成:用 mock server 跑 5 hook
bash tests/openclaw/mock-ipc-test.sh
# 期望:5 hook 全部能 connect → send → read → exit

# 3. 回归(关键 gate):原 46 case 跑新 TS hook
bash templates/hooks/guard-rails-test.sh
# 期望:46/46 PASS
```

**Gate 条件**:
- [ ] IPC client 单测全 PASS
- [ ] **46/46 回归 PASS**(经过 IPC path)
- [ ] 5 hook 启动延迟 < 50ms(IPC 路径)

**风险**:
- **IPC 失败策略**:server 没启动 / 崩溃 → 5 hook 怎么处理?
  - 决策:**fail-soft**(allow + log warning)— 不阻挡用户,但 install.sh 末尾检测并启动 server
  - 备选:fail-closed(拒绝 + 提示)— 太严格,用户首次安装时所有 hook 都不通
- **Windows 兼容性**:IPC client 在 Windows 走 named pipe,可能阻塞
  - 缓解:timeout 5s + clearTimeout
- **原 hook 文件处理**:`.legacy` 后缀还是直接替换?
  - 决策:替换 + git 历史保留(原文件已在 git 里)

**估算**:3-4h

---

### Task 3 · IPC server + 跨平台 transport🔴 **Gate**

**目标**:常驻 node server,跨平台支持 socket (Unix) / pipe (Windows),< 50ms 延迟。

**Context**:用户决策 #3 — IPC 必做,延迟 < 50ms。这是性能关键路径。

**改动文件**(全部新增):

- `templates/openclaw/ipc/server.ts`(~150 行)— 常驻 server
- `templates/openclaw/ipc/protocol.ts`(~80 行)— JSON schema
- `templates/openclaw/ipc/platform.ts`(~50 行)— 跨平台路径
- `templates/openclaw/ipc/server.test.ts`(~100 行)— server 单测
- `tests/openclaw/ipc-server-test.sh`(~80 行)— 集成测试

**实现要点**:

```typescript
// templates/openclaw/ipc/platform.ts
import { platform } from "process";
import * as os from "os";
import * as path from "path";

export function defaultSocketPath(): string {
  if (platform === "win32") return "\\\\.\\pipe\\loopx-guard";
  // Unix: XDG_RUNTIME_DIR > TMPDIR > /tmp
  const xdg = process.env.XDG_RUNTIME_DIR;
  if (xdg) return path.join(xdg, "loopx-guard.sock");
  const tmp = process.env.TMPDIR || os.tmpdir();
  return path.join(tmp, "loopx-guard.sock");
}

export function defaultPidFilePath(): string {
  return defaultSocketPath() + ".pid";
}

export function platformSupportsIPC(): boolean {
  return ["linux", "darwin", "win32"].includes(platform);
}
```

```typescript
// templates/openclaw/ipc/server.ts
import * as net from "net";
import * as fs from "fs";
import { checks } from "../core";
import { normalize } from "../core/normalize";
import { defaultSocketPath, defaultPidFilePath } from "./platform";

const SOCKET = process.env.LOOPX_GUARD_SOCK || defaultSocketPath();
const PID_FILE = defaultPidFilePath();

interface PendingRequest {
  resolve: (resp: any) => void;
  reject: (err: Error) => void;
}

const server = net.createServer((socket) => {
  let buf = "";
  socket.on("data", (chunk) => {
    buf += chunk.toString("utf8");
    let nl: number;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      handleLine(socket, line);
    }
  });
  socket.on("error", () => {});  // swallow
});

function handleLine(socket: net.Socket, line: string) {
  let req: any;
  try {
    req = JSON.parse(line);
  } catch {
    socket.write(JSON.stringify({ error: "parse-failed", message: "invalid JSON" }) + "\n");
    return;
  }
  try {
    const ctx = normalize(req.toolName, req.params);
    const results = Object.entries(checks).map(([name, fn]) => ({
      check: name,
      ...fn({ ...ctx, cwd: req.cwd }),
    }));
    socket.write(JSON.stringify({ id: req.id, results }) + "\n");
  } catch (e: any) {
    socket.write(JSON.stringify({ id: req.id, error: "core-failed", message: e.message }) + "\n");
  }
}

// 启动 + 注册 PID
try { fs.unlinkSync(SOCKET); } catch {}  // Unix:清 stale socket
server.listen(SOCKET, () => {
  fs.writeFileSync(PID_FILE, String(process.pid));
  // 输出 ready 信号给 install.sh 捕获
  console.log(JSON.stringify({
    ready: true,
    pid: process.pid,
    socket: SOCKET,
    pid_file: PID_FILE,
  }));
});

// 优雅退出
process.on("SIGTERM", () => { server.close(); try { fs.unlinkSync(SOCKET); } catch {}; process.exit(0); });
process.on("SIGINT", () => { server.close(); try { fs.unlinkSync(SOCKET); } catch {}; process.exit(0); });
process.on("exit", () => { try { fs.unlinkSync(PID_FILE); } catch {} });
```

**测试计划**:

```bash
# 1. Server 单测(node:test)
node --test templates/openclaw/ipc/server.test.ts
# 期望:启动 / 处理 / 关闭全 OK

# 2. 集成测试:start → 100 并发 call → stop
bash tests/openclaw/ipc-server-test.sh
# 期望:
#   - Server 启动 < 500ms
#   - 100 并发 call p99 < 50ms
#   - kill 后 socket 清理

# 3. Soak test(内存)
for i in {1..1000}; do
  echo '{"id":"t","action":"check","toolName":"Bash","params":{"command":"echo"}}' | nc -U "$SOCKET"
done
# 期望:内存增长 < 10MB
```

**Gate 条件**:
- [ ] Server 单测全 PASS
- [ ] **延迟 p99 < 50ms**(本地 + CI)
- [ ] **内存 1000 round < 10MB 增长**
- [ ] Linux + Windows 都跑通(CI 测试)

**风险**:
- **Unix socket 权限**:在共享系统上,其他用户能 connect
  - 缓解:server 启动时 `chmod 600`(Unix only)
- **Named pipe Windows 安全**:默认 everyone 可访问
  - 缓解:server 启动时设 DACL(需要 win32 API)— Phase 1 可接受风险
- **Server 崩溃后残留 socket/pipe 文件**:connect 失败
  - 缓解:启动时 unlink(Unix);Windows pipe 在 server exit 自动清理
- **PID file 竞态**:两个 install 同时启动
  - 缓解:检测 PID file,如有则先 kill 旧进程

**估算**:3-4h

---

### Task 4 · cc.sh + cc.ps1 adapter

**目标**:Claude Code 端两个平台的 adapter,Fallback 启动 server。

**改动文件**(新增):

- `templates/openclaw/adapters/cc.sh`(~40 行)— Linux/macOS Git Bash
- `templates/openclaw/adapters/cc.ps1`(~50 行)— Windows PowerShell 7+

**实现要点**:

```bash
#!/usr/bin/env bash
# templates/openclaw/adapters/cc.sh
# Claude Code hook adapter (Linux/macOS)
# 行为:读 stdin → IPC call to server → exit code

set -u
input=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SERVER="$PROJECT_ROOT/templates/openclaw/ipc/server.ts"

# 1. 尝试 IPC
result=$(node -e "
  const { ipcCheck } = require('$SCRIPT_DIR/../ipc/client');
  const req = JSON.parse(process.argv[1]);
  ipcCheck({ ...req, action: 'check' })
    .then((r) => {
      const blocker = r.results.find(x => x.block);
      if (blocker) {
        process.stderr.write('[' + blocker.check + '] BLOCKED: ' + (blocker.reason || '') + '\n');
        process.exit(2);
      }
      process.exit(0);
    })
    .catch((e) => {
      process.stderr.write('ipc-failed: ' + e.message + '\n');
      process.exit(1);
    });
" "$input" 2>&1)
exit_code=$?

# 2. Fallback:server 未启动 → spawn sync 启动 + 重试
if [ $exit_code -eq 1 ] && [[ "$result" == *"ipc-failed"* || "$result" == *"ENOENT"* ]]; then
  PID_FILE="${LOOPX_GUARD_PID:-/tmp/loopx-guard.pid}"
  if [ ! -f "$PID_FILE" ] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    nohup node "$SERVER" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
  fi
  # 重试 IPC(同上 node -e 代码,DRY 可优化)
  ...
fi

exit $exit_code
```

```powershell
# templates/openclaw/adapters/cc.ps1
# Claude Code hook adapter (Windows PowerShell 7+)

$ErrorActionPreference = 'Stop'
$input = [Console]::In.ReadToEnd()
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$serverScript = Join-Path $scriptDir '..\ipc\server.ts'

# 1. 尝试 IPC
try {
    $result = & node -e "
      const { ipcCheck } = require('$($scriptDir.Replace('\','/'))/../ipc/client');
      const req = JSON.parse(process.argv[1]);
      ipcCheck({ ...req, action: 'check' })
        .then((r) => {
          const blocker = r.results.find(x => x.block);
          if (blocker) {
            console.error('[' + blocker.check + '] BLOCKED: ' + (blocker.reason || ''));
            process.exit(2);
          }
          process.exit(0);
        })
        .catch((e) => {
          console.error('ipc-failed: ' + e.message);
          process.exit(1);
        });
    " $input

    if ($LASTEXITCODE -eq 2) { exit 2 }
    if ($LASTEXITCODE -eq 0) { exit 0 }
} catch {}

# 2. Fallback:启动 server + 重试
$pidFile = Join-Path $env:TEMP 'loopx-guard.pid'
$needStart = $true
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile
    $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    if ($proc) { $needStart = $false }
}
if ($needStart) {
    Start-Process node -ArgumentList $serverScript -NoNewWindow
    $newPid = (Get-Process node | Sort-Object StartTime -Descending | Select-Object -First 1).Id
    $newPid | Out-File -FilePath $pidFile -Encoding ASCII
    Start-Sleep -Seconds 2
}

# 重试 IPC(同上代码)
...

exit $LASTEXITCODE
```

**测试计划**:

```bash
# Linux/Mac
bash tests/openclaw/adapter-cc-test.sh
# 期望:cc.sh 能 IPC call + fallback 启动 server

# Windows(本地或 CI)
pwsh tests/openclaw/adapter-cc-test.ps1
# 期望:cc.ps1 同上
```

**估算**:2-3h

---

### Task 5 · OpenClaw adapter + plugin 入口

**目标**:OpenClaw 端 in-process adapter,无 IPC 开销(< 5ms)。

**改动文件**(新增):

- `templates/openclaw/adapters/openclaw.ts`(~80 行)
- `templates/openclaw/plugin/openclaw.plugin.ts`(~30 行)
- `templates/openclaw/plugin/package.json`(~20 行)
- `templates/openclaw/plugin/tsconfig.json`(~15 行)
- `templates/openclaw/hooks/guard-secret-files/HOOK.md`
- `templates/openclaw/hooks/guard-secret-files/handler.ts`(~15 行)
- `templates/openclaw/hooks/guard-main-branch-push/HOOK.md`
- `templates/openclaw/hooks/guard-main-branch-push/handler.ts`
- `templates/openclaw/hooks/guard-db-migration/HOOK.md`
- `templates/openclaw/hooks/guard-db-migration/handler.ts`
- `templates/openclaw/hooks/guard-package-publish/HOOK.md`
- `templates/openclaw/hooks/guard-package-publish/handler.ts`
- `templates/openclaw/hooks/guard-installer-path/HOOK.md`
- `templates/openclaw/hooks/guard-installer-path/handler.ts`

**实现要点**:

```typescript
// templates/openclaw/adapters/openclaw.ts
import type { HookAPI } from "@openclaw/plugin-sdk";
import { normalize, checks } from "../core";
import type { CheckContext } from "../core/types";

export function register(api: HookAPI): void {
  api.on("before_tool_call", async (event, ctx) => {
    const c = normalize(event.toolName, event.params);
    const enriched: CheckContext = {
      ...c,
      cwd: ctx?.sessionKey ? process.cwd() : undefined,
      sessionId: ctx?.sessionKey,
    };
    for (const [name, fn] of Object.entries(checks)) {
      const r = fn(enriched);
      if (r.block) {
        return {
          block: true,
          blockReason: r.reason || `Blocked by ${name}`,
          requireApproval: r.severity === "critical" ? {
            title: name,
            description: r.reason || "Blocked by guard rail",
            severity: "critical",
            allowedDecisions: ["allow-once", "allow-always", "deny"],
          } : undefined,
        };
      }
    }
    return undefined;  // allow
  }, {
    matcher: ["exec", "write", "edit", "apply_patch", "web_fetch", "web_search"],
    priority: 100,
  });
}
```

```typescript
// templates/openclaw/hooks/guard-secret-files/handler.ts
import { checkSecretFiles } from "../../core/check-secret-path";
import { normalize } from "../../core/normalize";

export default async function(event: any, ctx: any) {
  const c = normalize(event.toolName, event.params);
  const r = checkSecretFiles(c);
  if (r.block) return { block: true, blockReason: r.reason };
  return undefined;
}
```

```markdown
<!-- templates/openclaw/hooks/guard-secret-files/HOOK.md -->
---
name: guard-secret-files
description: "Block writes to secret paths (.env, *.pem, *.key, credentials.*, etc.)"
metadata:
  openclaw:
    emoji: "🔒"
    events: ["before_tool_call"]
    matcher: ["write", "edit", "apply_patch"]
    requires:
      bins: ["node"]
---

# guard-secret-files

Block Edit/Write/MultiEdit operations to secret paths. Same logic as Claude Code
guard-secret-files hook, ported to TypeScript for OpenClaw plugin context.
```

**测试计划**:

```bash
# 单元:模拟 OpenClaw event,跑 adapter
node --test templates/openclaw/adapters/openclaw.test.ts
# 期望:5 hook 都能在 mock event 下 block/allow

# 集成:用 ts-node 跑 handler.ts(模拟 OpenClaw loader)
ts-node templates/openclaw/hooks/guard-secret-files/handler.ts < secret-write.json
# 期望:{ block: true, blockReason: "..." }
```

**估算**:2-3h

---

### Task 6 · 跨 runtime 测试矩阵

**目标**:12-15 fixture,跨 runtime 行为对照测试。

**改动文件**(新增):

- `tests/openclaw/fixtures/secret-write-block.json`
- `tests/openclaw/fixtures/secret-write-allow.json`
- `tests/openclaw/fixtures/main-push-block.json`
- `tests/openclaw/fixtures/main-push-allow.json`
- `tests/openclaw/fixtures/db-migration-block.json`
- `tests/openclaw/fixtures/db-migration-allow.json`
- `tests/openclaw/fixtures/package-publish-block.json`
- `tests/openclaw/fixtures/package-publish-allow.json`
- `tests/openclaw/fixtures/installer-path-block.json`
- `tests/openclaw/fixtures/installer-path-allow.json`
- `tests/openclaw/run-all.sh`(~80 行)
- `tests/openclaw/run-all.ps1`(~80 行)
- `tests/openclaw/README.md`(~50 行)

**实现要点**:

```bash
#!/usr/bin/env bash
# tests/openclaw/run-all.sh
# Cross-runtime behavior parity test
# 跑两遍:cc adapter + openclaw adapter,assert 一致

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

run_case() {
  local name="$1" fixture="$2" expected="$3"
  
  # 1. CC adapter(走 IPC,模拟 hook 输入)
  cc_out=$(echo "{\"tool_name\":\"$(jq -r '.tool_name' $fixture)\",\"tool_input\":$(jq -c '.tool_input' $fixture)}" \
    | bash templates/openclaw/adapters/cc.sh 2>&1)
  cc_exit=$?
  
  # 2. OpenClaw adapter(in-process via ts-node)
  oc_out=$(echo "{\"id\":\"t\",\"action\":\"check\",\"toolName\":\"$(jq -r '.oc.toolName' $fixture)\",\"params\":$(jq -c '.oc.params' $fixture)}" \
    | ts-node templates/openclaw/adapters/openclaw.ts 2>&1)
  
  # 3. 对照 expected
  if [ "$expected" = "block" ]; then
    [ $cc_exit -eq 2 ] && [[ "$oc_out" == *'"block":true'* ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
  else
    [ $cc_exit -eq 0 ] && [[ "$oc_out" != *'"block":true'* ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
  fi
  echo "  $name: $([ $cc_exit -eq 2 ] && echo BLOCK || echo ALLOW) (cc) / $oc_out (oc) [$expected]"
}

run_case "secret-block" "secret-write-block.json" "block"
run_case "secret-allow" "secret-write-allow.json" "allow"
# ... 12-15 case

echo "$PASS pass, $FAIL fail"
exit $FAIL
```

**测试计划**:本 task 即测试本身,跑通即完成。

**估算**:2-3h

---

### Task 7 · CI 集成🔴 **Gate**

**目标**:GitHub Actions 加 `openclaw-test.yml`,Linux + Windows 双矩阵必双绿。

**改动文件**(新增):

- `.github/workflows/openclaw-test.yml`(~60 行)
- README 加 CI badge

**实现要点**:

```yaml
# .github/workflows/openclaw-test.yml
name: openclaw-compat-test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: ${{ matrix.os }} openclaw compat
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - name: Install TypeScript + ts-node
        run: npm install -g typescript ts-node
      - name: Start IPC server (background)
        run: |
          if [ "$RUNNER_OS" = "Windows" ]; then
            Start-Process node -ArgumentList "templates/openclaw/ipc/server.ts" -NoNewWindow
            Start-Sleep -Seconds 3
          else
            nohup node templates/openclaw/ipc/server.ts &
            sleep 2
          fi
      - name: Run core unit tests
        run: node --test templates/openclaw/core/*.test.ts
      - name: Run IPC server tests
        run: bash tests/openclaw/ipc-server-test.sh
      - name: Run cross-runtime parity tests
        shell: bash
        run: |
          if [ "$RUNNER_OS" = "Windows" ]; then
            pwsh tests/openclaw/run-all.ps1
          else
            bash tests/openclaw/run-all.sh
          fi
      - name: Regression: existing 46-case guard-rails test
        shell: bash
        run: bash templates/hooks/guard-rails-test.sh
      - name: Upload test report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: openclaw-test-${{ matrix.os }}
          path: tests/openclaw/output/
```

**测试计划**:push 触发,看 GitHub Actions 跑通。

**Gate 条件**:
- [ ] Linux job 全绿
- [ ] Windows job 全绿
- [ ] 失败需立即修复(不能 defer)

**风险**:
- **Windows runner 慢**:测试 5-8min,可能超时
  - 缓解:`timeout-minutes: 15`
- **Server 后台启动失败**:Start-Process 后立即 sleep 不够
  - 缓解:sleep 3s,或轮询 server PID 文件

**估算**:1-2h

---

### Task 8 · Skill frontmatter 扩展 + install 集成

**目标**:3 SKILL.md 单源扩展 + `install.{sh,ps1} --with-openclaw` 集成。

**改动文件**:

修改(3 文件):
- `templates/skills/loopx-project/SKILL.md` — 加 `metadata.openclaw.*` 段
- `templates/skills/loopx-guard-summary/SKILL.md` — 同
- `templates/skills/loopx-doctor/SKILL.md` — 同

修改(2 文件):
- `install.sh` — 加 `--with-openclaw` flag + 启动 server 逻辑
- `install.ps1` — 同(PowerShell 版)

新增:
- `templates/openclaw/install-helpers/start-server.sh`(~30 行)
- `templates/openclaw/install-helpers/start-server.ps1`(~40 行)
- `tests/openclaw/install-openclaw-test.sh`(~80 行)— dry-run 测试

**实现要点**:

```markdown
<!-- templates/skills/loopx-project/SKILL.md 增量 -->
---
name: loopx-project
description: "Use when managing a project with LoopX 5 primitives..."
metadata:
  openclaw:
    emoji: "🔁"
    events: ["command:new", "message:received"]
    requires:
      bins: ["loopx"]
    install:
      kind: bundled
---

# 现有内容不动
```

```bash
# install.sh 增量
if [[ "${WITH_OPENCLAW:-0}" == "1" ]]; then
  echo "[install] Setting up OpenClaw compat..."
  
  # 1. 复制 plugin 到目标 workspace
  mkdir -p "$TARGET/.openclaw/plugins/loopx-guard-rails/"
  cp -r "$SCRIPT_DIR/templates/openclaw/plugin/"* "$TARGET/.openclaw/plugins/loopx-guard-rails/"
  
  # 2. 复制 hooks metadata
  for hook_dir in "$SCRIPT_DIR/templates/openclaw/hooks/"*/; do
    name=$(basename "$hook_dir")
    mkdir -p "$TARGET/.openclaw/hooks/$name/"
    cp "$hook_dir/HOOK.md" "$TARGET/.openclaw/hooks/$name/"
    cp "$hook_dir/handler.ts" "$TARGET/.openclaw/hooks/$name/"
  done
  
  # 3. 启动 IPC server(后台)
  bash "$SCRIPT_DIR/templates/openclaw/install-helpers/start-server.sh" "$TARGET"
  
  # 4. 提示
  echo "[install] OpenClaw compat installed. Run: openclaw plugins reload loopx-guard-rails"
fi
```

```bash
# templates/openclaw/install-helpers/start-server.sh
#!/usr/bin/env bash
# Start IPC server as daemon for given target project
set -u
TARGET="${1:?usage: start-server.sh <target-project-path>}"
LOOPX_DIR="$TARGET/.loopx"
PID_FILE="$LOOPX_DIR/guard-server.pid"

mkdir -p "$LOOPX_DIR"

# 已有 server?
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Server already running (PID $(cat "$PID_FILE"))"
  exit 0
fi

# 启动
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nohup node "$SCRIPT_DIR/../ipc/server.ts" >"$LOOPX_DIR/guard-server.log" 2>&1 &
echo $! > "$PID_FILE"
sleep 1

# 验证
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Server started (PID $(cat "$PID_FILE"))"
else
  echo "Server start FAILED — see $LOOPX_DIR/guard-server.log"
  exit 1
fi
```

**测试计划**:

```bash
# Dry-run:在临时目录跑 install,验证产物
bash tests/openclaw/install-openclaw-test.sh /tmp/test-target
# 期望:
#   /tmp/test-target/.openclaw/plugins/loopx-guard-rails/ 存在
#   /tmp/test-target/.openclaw/hooks/guard-*/HOOK.md 存在
#   /tmp/test-target/.loopx/guard-server.pid 存在
#   Server 进程能用 ps 看到
```

**估算**:2-3h

---

### Task 9 · 文档 + Final review

**目标**:主文档、README 更新、example、Final review。

**改动文件**:

新增:
- `docs/openclaw-compat.md`(~300 行,主文档)
- `examples/openclaw-workspace.md`(~100 行)

修改:
- `README.md` — 加 OpenClaw 段 + CI badge
- `templates/hooks/README.md` — 加 OpenClaw 兼容段
- `docs/quality/PART-2-3-ASSETS.md` — 加 OpenClaw 列(如有)— 可选

**实现要点**:

```markdown
# docs/openclaw-compat.md

> LoopX guard rails 在 OpenClaw workspace 也能跑,行为与 Claude Code 一致。

## 这是什么

[简要说明 Sub-project A 的目标]

## 安装

\`\`\`bash
# 在目标项目里
cd /path/to/your-project
/path/to/loop-engineering/install.sh --with-openclaw

# 或 PowerShell(Windows)
pwsh /path/to/loop-engineering/install.ps1 -WithOpenclaw
\`\`\`

## 5 hook 在 OpenClaw 怎么跑

| Hook | CC 端触发 | OpenClaw 端触发 | 行为 |
|---|---|---|---|
| guard-secret-files | Edit/Write | write/edit/apply_patch | 一致 |
| guard-main-branch-push | Bash | exec | 一致 |
| ... |

## 3 skill metadata 扩展

[说明单源 frontmatter]

## 自定义 hook(用 core logic 写新 check)

[给 power user 的指南]

## 故障排查

| 症状 | 原因 | 解决 |
|---|---|---|
| OpenClaw plugin 没加载 | `openclaw plugins reload` 没跑 | `openclaw plugins reload loopx-guard-rails` |
| hook 不触发 | matcher 不匹配 | 检查 `tools.allow` / `matcher` |
| IPC server 没启动 | install 失败 | `bash install-helpers/start-server.sh /path/to/proj` |
| Windows 性能慢 | named pipe + PowerShell 启动 | 检查 `pwsh` 版本(7+)|

## 跨平台差异

| 维度 | Linux/macOS | Windows |
|---|---|---|
| IPC | Unix socket | Named pipe |
| Adapter | bash | PowerShell 7+ |
| Server 启动 | nohup & | Start-Process |

## 引用

- Spec: docs/superpowers/specs/2026-09-27-openclaw-compat-design.md
- Plan: docs/superpowers/plans/2026-09-27-openclaw-compat-plan.md
- OpenClaw docs: https://docs.openclaw.ai
```

**Final review 检查清单**:

- [ ] spec self-check(所有验收条目)
- [ ] 跨 runtime 端到端手测
- [ ] Windows 手测(本地或 CI artifact)
- [ ] 性能 benchmark(IPC p99 < 50ms)
- [ ] 内存 soak(1000 round < 10MB 增长)
- [ ] 文档内部链接通顺
- [ ] push + 写 handoff

**估算**:2-3h

---

### Final · push + handoff

- 写 `handoff-loop-engineering-openclaw-compat-done-2026-09-27.md`
- 写 `prompt-loop-engineering-openclaw-compat-done-next.md`
- `git push origin main`
- 更新 progress.md 把 Final 标 complete

---

## 4. 风险与回滚

| 风险 | 严重度 | 缓解 |
|---|---|---|
| **Core 重写行为漂移** | 🔴 高 | Task 1 gate:46/46 PASS |
| **Windows 平台 bug** | 🔴 高 | Task 7 gate:CI 双绿;本地手测 |
| **IPC 性能不达标** | 🔴 高 | Task 3 gate:p99 < 50ms;超了用 Unix socket + 持久连接 |
| Server 内存泄漏 | 中 | Task 6 soak test |
| OpenClaw SDK breaking change | 中 | Adapter 层隔离 |
| PowerShell 5.1 不支持 | 中 | spec 强制 7+,文档明示 |
| 用户装完没启动 server | 中 | install.sh 末尾 health-check |

**回滚策略**:本 plan 不实施 → 仓库无 compat 目录,git 历史干净。原 5 hook `.js`/`.sh`/`.py` 保留为 `.legacy`,需要可回滚。

---

## 5. 验收标准(汇总自 spec §11)

### 5.1 必达(用户决策)

- [ ] **(用户 #1)** 5 core check 函数 + 单元测试全 PASS,`guard-rails-test.sh` **46/46 PASS**
- [ ] **(用户 #2)** **GitHub Actions Linux + Windows 双绿**
- [ ] **(用户 #3)** IPC 延迟 **< 50ms p99**,OpenClaw adapter < 5ms
- [ ] **(用户 #4)** 3 SKILL.md frontmatter 单源扩展,CC 不报错

### 5.2 功能性

- [ ] 5 hook 改 thin wrapper,行为等价
- [ ] 12-15 fixture 跨 runtime 全 PASS
- [ ] 5 HOOK.md + handler.ts 完整
- [ ] `install.sh/ps1 --with-openclaw` 跑通
- [ ] uninstall kill server + 清 socket/pipe

### 5.3 工程性

- [ ] CI Linux + Windows 双绿
- [ ] IPC 1000-round soak,内存增长 < 10MB
- [ ] `docs/openclaw-compat.md`(~300 行)+ 内部链接通
- [ ] README + hook README 加 OpenClaw 段
- [ ] 至少 1 个 example

---

## 6. 不在本 plan 范围

- ❌ OpenClaw → Claude Code 反向桥(ROI 低,留 TODO)
- ❌ Sub-project B/C/D 任何变更
- ❌ 现有 5 hook 的匹配规则变更(只搬运,不修改)
- ❌ OpenClaw Gateway / plugin SDK 自身的修改
- ❌ Phase 2 manifest auto-gen(留口子)

---

## 7. 时间线(估时)

| Task | 估时 | 累计 |
|---|---|---|
| 1 · Core logic + 单测 | 3-4h | 3-4h |
| 2 · CC hook 改写 + IPC client | 3-4h | 6-8h |
| 3 · IPC server + transport | 3-4h | 9-12h |
| 4 · cc.sh + cc.ps1 adapter | 2-3h | 11-15h |
| 5 · OpenClaw adapter + plugin | 2-3h | 13-18h |
| 6 · 测试矩阵 | 2-3h | 15-21h |
| 7 · CI 集成 | 1-2h | 16-23h |
| 8 · Skill + install | 2-3h | 18-26h |
| 9 · 文档 + Final | 2-3h | 20-29h |
| **总计** | | **~20-29h** |

---

## 8. Next step(本 plan 完成后)

- 用户审 plan → 批准
- 逐 task 实施(每个 task 1+ commit)
- Task 1/2/3/7 不通过 = 整个 plan 失败,需修订
- 9 task + Final 全部完成 → push → 写 handoff

---

## 附录 A · 修订历史

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-27 | v1 | 初版,基于 spec v2(DRAFT),9 task,~20-29h |

---

*本 plan 由 writing-plans 流程产出,基于 spec v2 + 用户 4 决策。提交用户审核后,逐 task 实施。*
