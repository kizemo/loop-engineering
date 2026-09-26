# Playbook A 部署指南 · loop-engineering

> **本指南的目的**:Playbook A 工头式 PR review 的**端到端实施手册**。本文是"不部署",只写怎么部署 — 真正的部署在本文档之外由实施者按步骤执行。
>
> **来源判断**(2026-09-26):Playbook A 对 loop-engineering 项目本身和"重装 Claude Code 后再次部署 loop-engineering"**无价值**(本文 §1.1)。其真正价值在用了 loop-engineering 的真实下游项目(见 §1.3 的 4 个 examples)。

---

## 1. 适用与不适用

### 1.1 不适用场景(明确不要做)

| 场景 | 为什么不适用 |
|---|---|
| **在 loop-engineering 项目本身启用 Playbook A** | loop-engineering 是模板库(README + 简短 hook 脚本 + Skill 文档),Claude reviewer 在 markdown 文档里找不到 security / common bug / style 问题 |
| **重装 Claude Code 后再次部署 loop-engineering 时启用 Playbook A** | `install.sh --target <项目>` 装的是 5 hook + 3 skill + 1 command,**不包含 Playbook A**。Playbook A 是 deploy 之后的可选项,跟"重装"无关 |
| **没有真实 PR 流的玩具项目** | Playbook A 跑一次要花 Claude API 费用 + GitHub Action minutes,没 PR 跑就是浪费 |

### 1.2 适用场景

满足以下**全部**条件才部署:

1. ✅ 目标项目**经常合并 PR**(平均每周 ≥1 个)
2. ✅ 目标项目有**真实代码**(不是纯文档/纯配置)
3. ✅ 实施者愿意配置 **ANTHROPIC_API_KEY** 到 GitHub Secret
4. ✅ 实施者接受 **$0.50/PR 的 Claude API 成本**(可调,见 §3.1)
5. ✅ 目标项目的 PR review 当前是**纯人工**(AI reviewer 是增量价值,不是替代)

### 1.3 候选目标项目(4 个 examples)

| 项目 | 类型 | 代码量 | 适用性 | 推荐度 |
|---|---|---|---|---|
| **rime-claude** | Rime 输入法 installer(Tauri) | 中 | ⭐⭐⭐⭐ 适合 — 有 PR 流、有真实代码、安全敏感(installer 路径) | 🥇 首选 |
| **media-to-doc-ui** | Tauri 桌面应用 | 大 | ⭐⭐⭐⭐ 适合 — 大量 src-tauri + 前端代码、并发/IPC 风险 | 🥇 备选 |
| **cut-ad** | 课程视频处理(FFmpeg + Python) | 中 | ⭐⭐⭐ 适合 — Python 代码 + FFmpeg 调用、错误处理多 | 🥈 |
| **sandbox-verify** | 装机验证公共工具(PowerShell + Bash) | 小 | ⭐⭐ 一般 — 代码量小、PR 频率低 | 🥉 |

---

## 2. 前置条件

### 2.1 必备

| 项 | 来源 | 说明 |
|---|---|---|
| `ANTHROPIC_API_KEY` | https://console.anthropic.com/ | 用户的 Claude API key |
| 目标仓库 admin 权限 | GitHub | 能进 Settings → Secrets and variables → Actions |
| GitHub Actions 已启用 | 目标仓库 Settings → Actions | 默认启用,确认即可 |
| `gh` CLI 已认证 | `gh auth status` | 部署者本机 |
| `claude` CLI(可选) | https://code.claude.com/docs/en/setup | 本地调试用,GitHub Action runner 自动装 |

### 2.2 可选

| 项 | 说明 |
|---|---|
| 预算上限 | 单 PR 默认 $0.50,改 `github-action.yml.template` 里 `--max-budget-usd` |
| 通知渠道 | Playbook A 默认 sticky-pull-request-comment,失败/超时不通知,需要可加 Slack/Discord webhook |

---

## 3. 实施步骤(端到端)

### 3.1 准备 GitHub Secret

1. 进入目标仓库:`https://github.com/<owner>/<repo>/settings/secrets/actions`
2. 点击 **New repository secret**
3. 填:
   - **Name**:`ANTHROPIC_API_KEY`
   - **Secret**:你的 Claude API key(`sk-ant-...`)
4. 点击 **Add secret**

> ⚠️ 不要把 API key 写在 workflow 文件里,会被 GitHub 自动 mask 但仍有泄漏风险。

### 3.2 复制 workflow 文件

```bash
# 在目标仓库根目录:
mkdir -p .github/workflows
cp <loop-engineering-repo>/playbooks/A-pr-review/github-action.yml.template \
   .github/workflows/pr-review.yml
```

### 3.3 替换占位符

打开 `.github/workflows/pr-review.yml`,替换:

| 占位符 | 替换为 | 例 |
|---|---|---|
| `<YOUR_ORG>` | 目标仓库的组织/用户名 | `kizemo` |
| `<YOUR_REPO>` | 目标仓库名 | `rime-claude` |
| `<YOUR_BOT_NAME>` | AI reviewer bot 名字(评论里显示) | `loop-engineering-reviewer` |

### 3.4 写目标项目 CLAUDE.md

按 `playbooks/A-pr-review/CLAUDE-MD-RULES.md` 的骨架,在目标仓库根目录写 `CLAUDE.md`。**这是 AI reviewer 的"判断标准"**,必须写实。

关键 6 段(参考骨架,必须填实):
1. **项目目标** — 一句话写清楚做什么、谁用
2. **必读清单** — 按场景(改 API / 加依赖 / 数据库 schema)列出必读文件
3. **代码风格** — TypeScript/Python 等具体规则,写严格
4. **测试要求** — 量化覆盖率数字,AI 按字面意思判断
5. **安全红线** — hard block,任何违反直接 BLOCKING
6. **AI reviewer 必查清单** — 最小检查集(5-7 条)

完整模板见 `../playbooks/A-pr-review/CLAUDE-MD-RULES.md`。

### 3.5 启用 + 测试

1. **commit + push** workflow 文件和 CLAUDE.md 到 main
2. **建一个测试 PR**(故意写一个有安全问题的 diff,例如:
   - 加一个 `console.log(process.env.API_KEY)`
   - 加一个 `// TODO: fix SQL injection later` 在 SQL 查询里
   - 加一个被禁的 `git push --force` 注释)
3. 观察 GitHub Actions:应该看到 "PR Review (Loop Engineering Playbook A)" workflow 触发
4. 等 1-3 分钟,PR 评论应该出现带 `loop-engineering-review` header 的 sticky 评论
5. 检查评论内容是否包含:
   - 识别了故意放的安全问题(✓)
   - 没误报正常代码(✓)
   - 给了具体行号引用(✓)

---

## 4. 4 个候选目标适用性深度分析

### 4.1 rime-claude(🥇 首选)

- **为什么最适合**:
  - installer 路径敏感 — AI reviewer 能找到 `target/release/dist/build/output` 之外的路径错误
  - 有真实 PR 流(用户 2026 年起每周合并 2-3 个)
  - 安全要求高(installer 一旦发布,撤回难)
- **CLAUDE.md 重点段**:
  - 必读清单:`docs/api-spec.md`(改 API)+ `installer/inno-setup.iss`(改安装包)
  - 安全红线:`target/release/dist/build/output` 之外路径硬 block
- **风险**:
  - installer 编译时间长,GitHub Action 需要 `timeout-minutes: 15`(模板默认 10,需调整)

### 4.2 media-to-doc-ui(🥇 备选)

- **为什么适合**:
  - 大量 src-tauri Rust 代码 + 前端 TS 代码
  - IPC 边界是常见漏洞点,AI reviewer 能找到 unsafe 代码
  - PR 频繁
- **CLAUDE.md 重点段**:
  - 必读清单:`src-tauri/src/lib.rs`(改 IPC)、`src/types/*.ts`(改前端类型)
  - 代码风格:Rust clippy 严格 + TS strict
- **风险**:
  - 编译时间长,timeout 需要拉到 20 分钟

### 4.3 cut-ad(🥈 备选)

- **为什么适合**:
  - Python + FFmpeg,错误处理多,AI 能找到未捕获的异常
  - 安全要求中等(本地工具,不暴露网络)
- **CLAUDE.md 重点段**:
  - 必读清单:`docs/ffmpeg-cmd.md`(改 FFmpeg 调用)
  - 代码风格:Python 类型注解强制
- **风险**:
  - 没强类型,AI reviewer 误报率可能高

### 4.4 sandbox-verify(🥉 一般)

- **为什么不优先**:
  - 代码量小,PR 频率低(每月 1-2 个)
  - PowerShell + Bash 混合,AI reviewer 对 PowerShell 不熟悉
- **什么时候用**:
  - 用户想先在小项目验证 Playbook A 流程,避免在 rime-claude 上首次踩坑

---

## 5. 验证清单

### 5.1 端到端 PR 测试 checklist

- [ ] 故意放的安全问题被识别
- [ ] 故意放的代码风格问题被识别
- [ ] 没误报正常代码
- [ ] 评论带 `loop-engineering-review` header
- [ ] 评论有具体行号引用
- [ ] GitHub Action 耗时 < 5 分钟(超过说明 prompt 太长)
- [ ] 单 PR 成本 < $0.50(超过说明 diff 太大或 review 范围太广)

### 5.2 长期监控指标

| 指标 | 健康范围 | 异常处理 |
|---|---|---|
| 单 PR 平均成本 | < $0.30 | > $0.50 调小 prompt 或限 diff 行数 |
| AI reviewer 误报率 | < 20% | > 30% 收紧 CLAUDE.md 规则,或加白名单 |
| Action 成功率 | > 95% | < 90% 检查 ANTHROPIC_API_KEY 余额 + runner 资源 |
| 评论被采纳率 | > 50% | < 30% 调严 reviewer prompt(让 AI 更挑剔) |

---

## 6. 故障排查

| 现象 | 原因 | 解法 |
|---|---|---|
| Action 一直 pending | runner 排队 | 检查 GitHub Actions 配额 |
| Action 报 `claude: command not found` | runner 没装 Claude CLI | 模板注释里有 setup 链接,加 install 步骤 |
| API key 报 401 | ANTHROPIC_API_KEY 失效或余额不足 | `gh secret list` 检查 secret 是否还在,console.anthropic.com 查余额 |
| 评论没出现 | sticky-pull-request-comment 没权限 | workflow `permissions` 加 `pull-requests: write`(模板已有) |
| 评论出现但内容是空 | Claude CLI 报 timeout 或 budget 超 | 调大 `--max-budget-usd`,或缩小 diff 范围 |
| 评论全是误报 | CLAUDE.md 写得太宽泛 | 收紧 reviewer 必查清单,加否定式规则(不要 ...)|

---

## 7. 回滚(怎么撤掉 Playbook A)

```bash
# 在目标仓库:
rm .github/workflows/pr-review.yml
git commit -am "chore: disable Playbook A PR review"
git push origin main
# GitHub Secret 不需要删(留着以后再用),但要删的话:
# Settings → Secrets → ANTHROPIC_API_KEY → Remove
```

回滚后:
- 已合并的 PR 评论保留在历史里
- 后续 PR 不再触发 review workflow
- loop-engineering 的 5 hook 仍然在跑(不受 Playbook A 影响)

---

## 8. 相关文档

- [Playbook A 总览](../playbooks/A-pr-review/README.md)
- [workflow 模板](../playbooks/A-pr-review/github-action.yml.template)
- [CLAUDE.md 骨架](../playbooks/A-pr-review/CLAUDE-MD-RULES.md)
- [Playbook 总览](../playbooks/README.md)
- [架构文档](ARCHITECTURE.md) — Playbook A 与 5 hook 的协作关系

---

*本文档由 packaging 阶段会话补充生成,响应用户"Playbook A 是否有价值"的判断后,记录"判断依据 + 部署步骤 + 不适用场景"三件事,作为下次实施 Playbook A 的唯一参考入口。*
