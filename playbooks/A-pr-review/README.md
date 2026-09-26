# Playbook A · 工头式(代码审查 + 自动修复)

> **循环长度**:短(单 PR,分钟到小时)
> **状态**:🟡 框架已就绪,接入需用户补 secrets + 启用 workflow

---

## 一、目标

CI 上每个 PR 自动 review + 修小问题(可选)。危险的(risk + 安全 + 架构)留给人工。

**最小启动版**(本次提供):**只 review + 提评论,不改任何代码**。

---

## 二、叠法

```
GitHub Action 触发(PR open / synchronize)
    ↓
claude -p "review this PR diff for security issues and common bugs"
    ↓
输出:review 评论 + 是否需要改
    ↓
若需改:claude -p "fix the issues you found, run tests"(本次默认禁用)
    ↓
Hook (PreToolUse) 拦截"危险命令"
Hook (Stop, exit 2) 阻止它在测试没全过前停
```

---

## 三、文件清单(本目录)

| 文件 | 用途 |
|---|---|
| `README.md`(本文件) | Playbook A 总览 |
| `github-action.yml.template` | `.github/workflows/pr-review.yml` 模板 |
| `CLAUDE-MD-RULES.md` | 项目级 CLAUDE.md 风格规范骨架 |

---

## 四、实施步骤

### 4.1 准备 GitHub Actions secrets

1. 进入 GitHub repo → Settings → Secrets and variables → Actions
2. 添加 secret:`ANTHROPIC_API_KEY` = 你的 Claude API key

### 4.2 复制 workflow 文件

```bash
# 在目标仓库根目录:
mkdir -p .github/workflows
cp <loop-engineering-repo>/playbooks/A-pr-review/github-action.yml.template \
   .github/workflows/pr-review.yml

# 改里面的占位符:
#   <YOUR_REPO> → 你的仓库名
#   <YOUR_BOT_NAME> → AI reviewer bot 名字(如 "loop-engineering-bot")
```

### 4.3 写项目级 CLAUDE.md

按 `CLAUDE-MD-RULES.md` 的骨架,在目标项目根目录写 `CLAUDE.md`,把代码风格 + 安全规范 + 禁区写清楚。这是 AI reviewer 的"判断标准"。

### 4.4 启用

首次合并 PR 时,GitHub Actions 会自动触发,review 报告贴在 PR 评论里。

---

## 五、安全网(本 Playbook 必装)

无论怎么实施,以下 4 个项目级 guard rails hook **必须装上**(在 `install.sh` 阶段已经部署):

- `guard-main-branch-push.py`:防止 AI 误推到 main
- `guard-package-publish.sh`:防止 AI 误 `npm publish`
- `guard-installer-path.sh`:防止 AI 写 installer 到错路径
- `guard-secret-files.js`:防止 AI 写密钥(本次默认不挂此 hook,需用户在 settings.json 启用)

---

## 六、风险与避坑

1. **AI reviewer 误报率高** — 把"严重问题"标准写严,宁可漏报不要误报(用户更烦"假警报")
2. **Claude API 费用** — 加 `--max-budget-usd 0.50` 单 PR 限 0.5 美元
3. **token 泄漏** — Anthropic API key 放 GitHub Secrets,绝不 commit 进 repo
4. **AI 改了不该改的** — 本次默认禁用"自动修",只 review + 评论

---

## 七、为什么 Playbook A 暂不直接启用?

用户决策(2026-09-26):**Playbook A 暂缓**,原因是用户希望把 loop engineering 优化打包成**复用项目**(本仓库),届时单独建一个仓库,再从仓库里实施 Playbook A。

本目录提供的 `github-action.yml.template` + `CLAUDE-MD-RULES.md` 是**模板**,等用户准备好 GitHub 仓库 + API key 时即可使用。