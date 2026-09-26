# GitHub 推送指南 · loop-engineering

> **移植来源**:参考 `F:\soft\00selfmade\filemanager\docs\FORK-WORKFLOW.md`(双 remote fork 模式) + `F:\soft\00selfmade\tiptap_app`(weavepage 仓库)的单 remote + HTTPS 推送模式,移植到本仓库的轻量版。

---

## 1. 仓库位置

| 项 | 值 |
|---|---|
| **托管平台** | GitHub |
| **组织/账户** | `kizemo`(个人账户,与 sigma-file-manager / weavepage 同账户) |
| **仓库名** | `loop-engineering` |
| **完整 URL** | `https://github.com/kizemo/loop-engineering.git` |
| **协议** | HTTPS(与 sigma-file-manager / weavepage 一致,gh CLI 可直接认证) |
| **可见性** | public(开源 Apache-2.0) |

---

## 2. 本地 git 配置

### 2.1 Remote

```bash
git remote add origin https://github.com/kizemo/loop-engineering.git
```

### 2.2 身份(local 覆盖)

loop-engineering 用 bot 身份提交(不影响其他项目),参考 `FORK-WORKFLOW.md` §"Git 身份"原则。

```ini
# .git/config (本仓库 local 段)
[user]
    name = loop-engineering-bot
    email = loop-engineering@users.noreply.github.com
```

> 与全局配置(`kizemo` / `kizemo@users.noreply.github.com`)隔离,**不会影响其他仓库**(与 sigma-file-manager 模式一致)。

---

## 3. 推送方法

### 3.1 首次推送

```bash
# 1. 推 main 分支
git push -u origin main

# 2. 打 v1.0.0 tag
git tag -a v1.0.0 -m "v1.0.0: initial packaging of loop-engineering (37 files, install.sh 38/38 PASS)"

# 3. 推 tag
git push origin v1.0.0

# 4. 创建 GitHub Release(用 gh CLI,已认证 kizemo 账户)
gh release create v1.0.0 \
  --title "Loop Engineering v1.0.0" \
  --notes "## Loop Engineering v1.0.0

### 初始发布

把 4 个已部署项目(rime-claude / media-to-doc-ui / cut-ad / sandbox-verify)的 152/152 通过测试沉淀成可复用工具集。

### 核心资产

- 5 道项目级 guard rails hook(secret / main branch / db migration / package publish / installer path)
- 3 种 Playbook 框架(A:工头式 / B:研究员式 / C:On-call 式)
- 4 个已部署项目示例(examples/)
- 一键安装脚本(install.sh + install.ps1)

### 验证

- install.sh 单测:**38/38 PASS**
- 文件数:37
- 协议:Apache-2.0

### 文档

- [README](../README.md)
- [架构](../docs/ARCHITECTURE.md)
- [Playbook 总览](../playbooks/README.md)" \
  --target main
```

### 3.2 一键脚本

抄 sigma 的 `scripts/sync-upstream.sh` 风格,本仓库提供 `scripts/push-to-github.sh`:

```bash
#!/usr/bin/env bash
# scripts/push-to-github.sh
# 用法:bash scripts/push-to-github.sh [tag]
# 默认 tag = v1.0.0
set -euo pipefail
TAG="${1:-v1.0.0}"

echo "→ 推送 main 分支..."
git push -u origin main

echo "→ 打 tag $TAG..."
git tag -a "$TAG" -m "$TAG: see CHANGELOG.md for details"

echo "→ 推送 tag..."
git push origin "$TAG"

echo "→ 创建 GitHub Release(gh CLI)..."
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG 已存在,跳过 create。"
else
  gh release create "$TAG" \
    --title "Loop Engineering $TAG" \
    --generate-notes \
    --target main
fi

echo "✓ 完成 — https://github.com/kizemo/loop-engineering/releases/tag/$TAG"
```

> 注:本仓库当前未提供该脚本,如需可从上方复制到 `scripts/push-to-github.sh` 并加执行权限。

---

## 4. 移植来源对照

| 本仓库做法 | 移植自 | 关键差异 |
|---|---|---|
| **单 remote(origin)** | `tiptap_app`(weavepage)的单 remote | sigma-file-manager 用双 remote(origin + upstream),因为它是 fork;loop-engineering 不是 fork,单 remote 即可 |
| **HTTPS 协议** | 两个项目都用 HTTPS | 不需要 SSH key,gh CLI 直接认证 |
| **bot 身份(local 覆盖)** | `FORK-WORKFLOW.md` §"Git 身份"原则 | 全局是 kizemo,local 覆盖 loop-engineering-bot,与 sigma 模式一致 |
| **main 分支** | sigma-file-manager(`main`) | weavepage 用 `master`,本仓库从 commit 7d5fee7 起就用 `main`,与 sigma 一致 |
| **tag v1.0.0** | sigma-file-manager(`v2.2.0` / `ms-store-v2.2.0`) | loop-engineering 是初始发布,用 `v1.0.0` |
| **gh CLI + 自动 release notes** | sigma release.yml | 本仓库无 release 产物,只需 `--generate-notes`,不编译 |

---

## 5. 推送后验证清单

- [ ] `git remote -v` 显示 `https://github.com/kizemo/loop-engineering.git`
- [ ] GitHub 仓库页面 https://github.com/kizemo/loop-engineering 显示 37 文件
- [ ] Tag v1.0.0 在 https://github.com/kizemo/loop-engineering/releases
- [ ] Release 标题 "Loop Engineering v1.0.0",自动 notes
- [ ] `git clone https://github.com/kizemo/loop-engineering.git` 在新目录能完整 clone

---

## 6. 故障排查

| 现象 | 原因 | 解法 |
|---|---|---|
| `git push` 报 403 | gh CLI 未认证 / token 缺 `repo` scope | `gh auth refresh -h github.com -s repo` |
| `gh release create` 报 404 | 远程仓库还不存在 | 确认 GitHub 上已建空仓库 |
| Tag 已存在 | 之前推送过 | `git tag -d v1.0.0 && git push origin :refs/tags/v1.0.0` 然后重打 |
| Push 后文件数不对 | `.gitignore` 漏文件 / 多文件 | `git ls-files | wc -l` 应为 37 |

---

*本文档为 loop-engineering v1.0 推送的"移植 + 落地"指南,与 `handoff-loop-engineering-packaging-2026-09-26.md` §5.1 配套使用。*
