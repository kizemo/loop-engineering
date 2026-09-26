# Example · media-to-doc-ui

> 已部署 5 道项目级 guard rails hook 的项目示例之二。

---

## 项目背景

**media-to-doc-ui**(简称 mtd)是用户的 Tauri 桌面应用 — 把视频/音频转成结构化文档。基于 Tauri + React + Rust。装机链路见 sandbox-verify 项目,但 mtd 当前**不在 sandbox-verify 的 verify 范围内**(见 `~/.claude/commands/deploy-verify.md` "When NOT to use")。

## 部署状态

| 项 | 状态 |
|---|---|
| `.claude/hooks/` 部署 | ✅ 10 文件 |
| `.claude/settings.json` 挂载 | ✅ 4 hook(同 rime-claude) |
| `.loopx/guard-events-2026-09-25.jsonl` | ✅ 有 |
| LoopX skill | ✅ 7 个 |

## 已挂 hook

`.claude/settings.json` 跟 rime-claude **结构完全相同**:

| matcher | hook | 原因 |
|---|---|---|
| `Edit\|Write\|MultiEdit` | `guard-installer-path.sh` | Tauri 产出 .msi / .exe 必须写到 `target/release/bundle/` |
| `Bash` | `guard-main-branch-push.py` | main 是发布分支 |
| `Bash` | `guard-package-publish.sh` | 防止误 `cargo publish` / `npm publish` |
| `Bash` | `guard-installer-path.sh` | 同 Edit/Write 拦截 |

**未挂**:`guard-secret-files.js`(无密钥)、`guard-db-migration.sh`(mtd 用 SQLite 本地文件,不走 migration 工具)

## 关键决策点

1. **installer-path 是核心 hook**,因为 Tauri 经常误把 `.msi` 写到项目根目录(而不是 `target/release/bundle/nsis/`)。**这条 hook 是 mtd 部署第 1 周就触发过的**。
2. **package-publish 同时挡 cargo 和 npm**(hook 内已包含 `cargo publish` 检测)。**Why**:Tauri 项目同时有 Rust crate 和 npm package 两类发布目标。
3. **未挂 secret-files 是有意为之**。**Why**:mtd 无云端密钥,挂上只会增加 false positive。

## evidence 产出

`F:/soft/#SyncVersion/00selfmade/media-to-doc-ui/.loopx/guard-events-2026-09-25.jsonl`(同模式,具体行数随使用情况)

## 复用本仓库怎么装

```bash
./loop-engineering/install.sh --target /path/to/media-to-doc-ui
# 然后按上面 settings.json 写挂载
```

## 未来扩展

- mtd 计划接 **Playbook A**:用户提 PR 时让 AI 审 PR diff(rime-claude 已经有此 hook,效果验证过)
- mtd 不接 **Playbook B**(无需跨天调研任务)
- mtd 不接 **Playbook C**(无 7×24 在线业务系统)

## 参考

- 仓库根:`F:/soft/#SyncVersion/00selfmade/media-to-doc-ui/`
- 装机脚本:**目前不存在**(`deploy-verify` slash command 显式排除 mtd)
- 装机替代:本地跑 `pnpm tauri build`