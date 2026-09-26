# Example · rime-claude

> 已部署 5 道项目级 guard rails hook 的项目示例之一。

---

## 项目背景

**rime-claude** 是用户的 C++ 输入法项目(Rime 输入法框架 + Claude Code 集成)。装机链路完整,有 Windows Sandbox 验证流程(参见 sandbox-verify/rime-claude/)。

## 部署状态

| 项 | 状态 |
|---|---|
| `.claude/hooks/` 部署 | ✅ 10 文件(5 hook + 3 helper + 1 test + 1 README) |
| `.claude/settings.json` 挂载 | ✅ 4 hook(见下) |
| `.loopx/guard-events-2026-09-25.jsonl` | ✅ 53 行 |
| LoopX skill | ✅ 7 个(`~/.codex/skills/loopx*`) |
| `/deploy-verify` slash command | ✅ 支持(`rime-claude` 参数) |

## 已挂 hook

`.claude/settings.json` 实际内容:

| matcher | hook | 原因 |
|---|---|---|
| `Edit\|Write\|MultiEdit` | `guard-installer-path.sh` | installer 写错路径会破坏 Rime 部署目录 |
| `Bash` | `guard-main-branch-push.py` | 防止误推 main(Rime 项目 main 是发布分支) |
| `Bash` | `guard-package-publish.sh` | 防止误 `gh release create`(CI 自动管) |
| `Bash` | `guard-installer-path.sh` | 同 Edit/Write 拦截 |

**未挂**:`guard-secret-files.js`(rime 无密钥)、`guard-db-migration.sh`(rime 不跑 DB)

## 关键决策点

1. **3 个 Bash hook 并联,顺序** `main-branch → package-publish → installer-path`。**Why**:早 fail-fast,前两个是"完全不能做",第三个是"位置不对"。从最严的开始匹配。
2. **timeout: 2** 秒每个 hook。**Why**:rime-claude 项目在 Windows 上,Git Bash 启动 hook 本身 ~500ms,实际检查 < 50ms,2 秒富余。
3. **`guard-main-branch-push.py` 即使无 `.git` 仍部署**。**Why**:cost 极低(纯字符串匹配),等初始化 .git 时不用再装。

## evidence 产出

`F:/soft/00selfmade/rime_claude/.loopx/guard-events-2026-09-25.jsonl`(53 行)记录了 2026-09-25 当天 5 个 hook 的所有 BLOCK 事件。

例(单行):

```json
{
  "ts": "2026-09-25T15:01:38Z",
  "hook": "guard-main-branch-push",
  "tool": "Bash",
  "input_summary": "cmd=git push origin main",
  "reason": "destructive main push blocked",
  "exit_code": 2,
  "cwd": "F:/soft/00selfmade/rime_claude",
  "project": "rime-claude"
}
```

## 复用本仓库怎么装

```bash
# 1. clone 本仓库
git clone https://github.com/<your-org>/loop-engineering.git

# 2. 在 rime-claude 项目跑 install.sh
./loop-engineering/install.sh --target /path/to/rime-claude

# 3. 把上面的 settings.json 内容写进 rime-claude/.claude/settings.json

# 4. 验证
bash /path/to/rime-claude/.claude/hooks/guard-rails-test.sh
```

## 参考

- 仓库根:`F:/soft/00selfmade/rime_claude/`
- 装机脚本:`F:/soft/00selfmade/sandbox-verify/rime-claude/rime-verify.ps1`
- 用户全局铁律方案:`~/.claude/loop-engineering-claude-铁律方案.md`