# Example · cut-ad

> 已部署 hook 的项目示例之三 — **精简版** settings.json(只挂 2 个 Bash hook)。

---

## 项目背景

**cut-ad** 是用户的 ad-cut skill 部署(剪掉视频里的广告片段)。当前还不是 git 仓库(没 `.git`),但已部署 hook — 因为即使没 git,**写 installer 到错路径也会触发问题**。

## 部署状态

| 项 | 状态 |
|---|---|
| `.claude/hooks/` 部署 | ✅ 10 文件 |
| `.claude/settings.json` 挂载 | ✅ 2 hook(精简版) |
| `.loopx/guard-events-2026-09-25.jsonl` | ✅ 46 行 |
| `.git/` | ❌ 未初始化 |

## 已挂 hook(精简版)

`.claude/settings.json` 实际只有 2 个 Bash hook:

```json
{
  "_comment": "cut-ad is the ad-cut skill deployment. installer-path guards against ffmpeg outputs going to wrong paths; main-branch guards against accidental main pushes (no .git yet, harmless to have).",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/guard-installer-path.sh", "timeout": 2}
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "python .claude/hooks/guard-main-branch-push.py", "timeout": 2},
          {"type": "command", "command": "bash .claude/hooks/guard-installer-path.sh", "timeout": 2}
        ]
      }
    ]
  }
}
```

**未挂**:`guard-secret-files.js` / `guard-db-migration.sh` / `guard-package-publish.sh`

## 关键决策点(精简版独有)

1. **故意不挂 `guard-package-publish.sh`**。**Why**:cut-ad 不发布 npm / pip 包,只有 ad-cut skill 本地部署,挂了反而增加 false positive。
2. **故意不挂 `guard-secret-files.js`**。**Why**:cut-ad 处理的是用户输入的视频文件路径,无密钥风险。
3. **`_comment` 字段** 说明 hook 选择理由。**Why**:其他开发者接手 cut-ad 时,能立刻看出"为什么没装 secret-files"。
4. **没 git 仍然挂 `main-branch-push`**。**Why**:cost 极低,等将来 `git init` 时立即生效。

## evidence 产出

`F:/soft/00selfmade/cut-ad/.loopx/guard-events-2026-09-25.jsonl`(46 行)

注意 cut-ad 的 evidence 行数比 rime-claude 少 7 行,说明 cut-ad 触发危险操作的次数更少(主要是 installer-path hook 在拦截 ffmpeg 输出路径)。

## 复用本仓库怎么装

```bash
./loop-engineering/install.sh --target /path/to/cut-ad
# 然后写精简版 settings.json(只要 2 个 Bash hook)
```

## 教训

> **不是所有项目都要挂全部 5 hook**。cut-ad 是"最小可行防护"案例 — 装最少、影响最大、false positive 最低。

参考本目录 rime-claude 和 media-to-doc-ui 是"全套防护"案例。**根据项目特性选 hook,别照搬**。

## 参考

- 仓库根:`F:/soft/00selfmade/cut-ad/`(非 git)
- 项目主页:本仓库 `../handoff-ad-cut-skill-2026-08-15.md`