# Example · sandbox-verify

> 已部署 hook 的项目示例之四 — **独有 secret-files + db-migration** 两个 hook。

---

## 项目背景

**sandbox-verify** 是用户的跨项目真机验证工具集合,在 Windows Sandbox 里跑各种 installer 验证脚本。包含 rime-claude / weavepage / media-to-doc-ui 三个子项目(每个有独立 verify.ps1)。

**这个项目的特性**:经常处理各种凭证(Windows Sandbox 共享 token、GitHub PAT)和数据库迁移(dbt 项目),所以**必须挂 secret-files 和 db-migration 两个 hook**,其他项目用不到。

## 部署状态

| 项 | 状态 |
|---|---|
| `.claude/hooks/` 部署 | ✅ 10 文件 |
| `.claude/settings.json` 挂载 | ✅ 4 hook(**含 secret-files 和 db-migration**) |
| `.loopx/guard-events-2026-09-25.jsonl` | ✅ 43 行 |
| 子项目 | rime-claude / weavepage / media-to-doc-ui |

## 已挂 hook(独有配置)

`.claude/settings.json` 实际内容:

| matcher | hook | 原因(独有) |
|---|---|---|
| `Edit\|Write\|MultiEdit` | `guard-secret-files.js` | **独有** — sandbox-verify 处理 Windows Sandbox 配置含 GitHub PAT / Gist token |
| `Bash` | `guard-main-branch-push.py` | 防止 main 分支被误推(沙箱验证脚本影响下游用户) |
| `Bash` | `guard-db-migration.sh` | **独有** — sandbox-verify 跑 dbt 项目验证,dbt migration 不可逆 |
| `Bash` | `guard-installer-path.sh` | sandbox-verify 处理多个 installer(rime / weavepage / mtd) |

**未挂**:`guard-package-publish.sh`(本项目不发布包)

## 关键决策点(独有)

1. **挂 `guard-secret-files.js`**。**Why**:sandbox-verify 配置文件里经常出现 GitHub PAT(`ghp_*`)、AWS key、Gist token,Claude 误把它们写到普通文件是高频踩坑。
2. **挂 `guard-db-migration.sh` 而不是 `guard-package-publish.sh`**。**Why**:sandbox-verify 跑 dbt 项目的 `dbt run tag:prod`(生产环境 dbt migration),不跑 npm publish。
3. **`guard-db-migration.sh` 的 timeout 设 3 秒**(其他 hook 都是 2 秒)。**Why**:dbt 项目的 hook 内部要做 path 解析(检查当前目录是否有 dbt_project.yml),略慢。
4. **子项目各自有独立 `verify.ps1`**,不混在同一个 hook 里。**Why**:不同子项目的 sandbox 隔离需求不同,hook 只管"通用危险操作拦截",不卷入子项目逻辑。

## evidence 产出

`F:/soft/00selfmade/sandbox-verify/.loopx/guard-events-2026-09-25.jsonl`(43 行)

注意 sandbox-verify 的 evidence 行数最少(43),但**每个 hook 至少触发过一次**。说明 hook 选配精准,无 false positive 浪费。

## 复用本仓库怎么装

```bash
./loop-engineering/install.sh --target /path/to/sandbox-verify
# 然后写带 secret-files + db-migration 的 settings.json
```

## 教训

> **根据"项目实际会出什么问题"选 hook,而不是"装最全显得安全"**。

| 项目类型 | 必装 hook |
|---|---|
| **任何项目** | `guard-main-branch-push.py`(基础) |
| **处理凭证的项目** | + `guard-secret-files.js` |
| **跑 DB migration 的项目** | + `guard-db-migration.sh` |
| **发布包的项目** | + `guard-package-publish.sh` |
| **写 installer 的项目** | + `guard-installer-path.sh` |

## 参考

- 仓库根:`F:/soft/00selfmade/sandbox-verify/`
- 子项目:`rime-claude/`、`weavepage/`、`media-to-doc-ui/`
- 用户 CLAUDE.md:`~/.claude/CLAUDE.md` §"跨项目真机验证 (sandbox-verify)"