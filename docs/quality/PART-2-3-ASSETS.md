# Part 2.3 · 资产速查手册(Cheat-Sheet)

> **数据截止**:2026-09-25 单日合成拦截日志 + 2026-09-26 skill/command/playbook 元数据快照
> **文档性质**:示例数据合成 + 部分 skill 字段待 Sub-project D 补
> **承接文档**:[README.md](README.md) · [Part 1](PART-1-DECISION-FRAMEWORK.md) · [Part 2.1](PART-2-1-PRIMITIVES.md) · [Part 2.2](PART-2-2-SCENARIOS.md) · [Part 3](PART-3-TUNING-FAQ.md)

---

## 0. 字典式查询说明

本文档是**资产速查**,不是叙事。每资产**一表,字段固定**,按"我在查什么"跳读,不要从头读到尾。

**4 节资产结构**:

| 节 | 资产类型 | 字段数 | 表格数 |
|---|---|---|---|
| §1 | 5 hook | 6 | 1(全表) |
| §2 | 3 skill | 5 | 1(全表) |
| §3 | 1 command | 4 | 1(全表) |
| §4 | 3 Playbook | 6 | 1(全表) |

**字段约定**:
- `触发词` = 用户/Agent 怎么唤起它(slash 命令 / 自然语言关键词 / 隐式)
- `拦截目标` / `副作用` = 该资产**拒绝什么** / **改什么文件**
- `故障排查` = exit 2 / 无日志 / 误拦 时第一步看哪
- `🟡` / `🔴` = 模板状态(已就绪 / 框架就绪 / TODO)

**自动生成说明**:本节由本任务实施阶段**手动撰写**,未来 `scripts/gen-hook-docs.sh` 从源码提取 matcher / 拦截目标 / 输出 schema,避免文档漂移(见 spec §5.5)。

---

## §1 · 5 hook 速查表

**字段**:`Hook / 文件 / 触发事件 / 拦截目标 / matcher / 故障排查`(6 列)。所有 hook 部署在 `<project>/.claude/hooks/`,通过 `<project>/.claude/settings.json` 的 `PreToolUse` 挂载。完整字段说明见 `templates/hooks/README.md`。

| Hook | 文件 | 触发事件 | 拦截目标 | matcher | 故障排查 |
|---|---|---|---|---|---|
| guard-secret-files.js | `templates/hooks/guard-secret-files.js` | PreToolUse | 写 `.env` / `*.pem` / `*.key` / `secrets/` / `credentials.*` / `*.sqlite3` | `Edit\|Write\|MultiEdit` | exit 2 但 `.loopx/guard-events-*.jsonl` 无新行 → 检查 `.loopx/` 目录是否存在且可写 |
| guard-main-branch-push.py | `templates/hooks/guard-main-branch-push.py` | PreToolUse | `git push origin main\|master` / `git push -f` | `Bash` | timeout?Python 启动慢,`settings.json` 里把 `timeout` 从 2s 调到 3s |
| guard-db-migration.sh | `templates/hooks/guard-db-migration.sh` | PreToolUse | `alembic upgrade` / `manage.py migrate` / `prisma migrate deploy` / `dbt run --tag prod` | `Bash` | 误拦测试用 migrate?在命令前加 `--allow-test` flag,或编辑 `<project>/.claude/guard-rails.yaml` 加 allowlist |
| guard-package-publish.sh | `templates/hooks/guard-package-publish.sh` | PreToolUse | `npm publish` / `twine upload` / `cargo publish` / `vsce publish` / `gh release create` | `Bash` | `gh release create` 误拦?看 stderr 含 hook 名;若确实要 release,把命令挪到 CI 而非本地 |
| guard-installer-path.sh | `templates/hooks/guard-installer-path.sh` | PreToolUse | 把 `.exe` / `.msi` / `.dmg` / `.deb` 写到 `target/` / `release/` / `dist/` / `build/` / `output/` **之外** | `Bash` + `Edit\|Write\|MultiEdit` | 写自定义路径?改 `<project>/.claude/guard-rails.yaml` 的 `installer_allow_paths` 列表(见 `templates/hooks/README.md` §步骤 4) |

**挂载示例**(从 `templates/hooks/README.md` §步骤 3 摘录,完整 JSON 见源文件):

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command",
                    "command": "node .claude/hooks/guard-secret-files.js",
                    "timeout": 2 }] },
      { "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/guard-main-branch-push.py", "timeout": 2 },
          { "type": "command", "command": "bash .claude/hooks/guard-db-migration.sh",         "timeout": 3 },
          { "type": "command", "command": "bash .claude/hooks/guard-package-publish.sh",      "timeout": 2 },
          { "type": "command", "command": "bash .claude/hooks/guard-installer-path.sh",       "timeout": 2 }
        ] }
    ]
  }
}
```

**单元测试**:`bash templates/hooks/guard-rails-test.sh`(每个 hook 跑 happy + block 两路,block 路径期望 `exit 2 + stderr 含 hook 名`)。

**与用户级 hook 协作**:用户级 `~/.claude/hooks/le-gatekeeper.js` 只挡 `rm -rf` / `DROP` / `format` 这类**全 Bash 域**危险命令,项目级 5 hook 补 `Edit/Write` 缺口和**特定命令白名单**(push-to-main / publish / db-migrate / installer-path)。**任一 exit 2 即阻止工具调用**,Claude Code 会把 stderr 显示给用户,用户可显式批准后重试。

**项目级覆盖**:在 `<project>/.claude/guard-rails.yaml` 写项目特定规则,见 `templates/hooks/README.md` §步骤 4(`secrets_extra_patterns` / `allowed_main_branches` / `installer_allow_paths`)。

**5 hook 一行总览**(从 `templates/hooks/README.md` line 12-18 复制,便于翻牌):

| # | hook | 兜底用户级 hook 之外的什么缺口 |
|---|---|---|
| 1 | guard-secret-files.js | 用户级 `le-gatekeeper.js` 只挡 Bash,这个补 Edit/Write 缺口 |
| 2 | guard-main-branch-push.py | 用户级无,本 hook 全局补 |
| 3 | guard-db-migration.sh | 销售 BI 平台用 |
| 4 | guard-package-publish.sh | 装机项目发 release 用 |
| 5 | guard-installer-path.sh | rime / media-to-doc / cut-ad 装机项目用 |

**典型 happy / block 路径示例**(每个 hook 一对,摘自 `templates/hooks/guard-rails-test.sh`):

| Hook | happy(应 exit 0) | block(应 exit 2) |
|---|---|---|
| guard-secret-files.js | `Edit config.json`(非 secret) | `Edit .env.production` |
| guard-main-branch-push.py | `git push origin feature/foo` | `git push origin main` |
| guard-db-migration.sh | `alembic upgrade --sql true` | `alembic upgrade head`(默认 prod) |
| guard-package-publish.sh | `npm pack`(只打包,不发) | `npm publish --access public` |
| guard-installer-path.sh | `Edit target/release/foo.exe` | `Edit ~/Desktop/foo.exe` |

---

## §2 · 3 skill 速查表

**字段**:`Skill / 触发词 / 输入 / 输出 / 示例`(5 列)。所有 skill 在 `templates/skills/<name>/SKILL.md`,通过 Claude Code 的 skill 机制自动加载。

| Skill | 触发词 | 输入 | 输出 | 示例 |
|---|---|---|---|---|
| loopx-project | 自然语言:"LoopX" / "loopx" / "goal" / "refresh-state" / "sync-global" / `loopx start-goal --guided --project . --goal-text "<GOAL_TEXT>"` | 目标文本(自然语言)或 LoopX CLI 命令 | structured project state(写入 `.loopx/registry.json` + `.codex/goals/<goal-id>/ACTIVE_GOAL_STATE.md`) | `/loopx 调研 auto-research 工具演化` → 编译为 goal-id + objective 文本 |
| loopx-self-repair | (隐式,LoopX 内部触发;或显式:"自检" / "诊断" / "为什么 agent 行为异常") | agent 失败信息 / drift 现象 / 用户根因分析请求 | repair packet + 修复命令(`loopx --format json diagnose --goal-id <goal-id>` 等) | 任务进度意外变小 / recommended_action 与 stale todo 不一致 → 自动触发,无需手动调用 |
| guard-rails-summary | 自然语言:"今天 hook 拦了什么" / "本周拦截" / "guard-rails summary" / 或 bash 触发 | 日期范围(可选 `--project-root <path>`,默认 cwd) | markdown summary(按 hook / tool / reason / project 分组,读 `.loopx/guard-events-YYYY-MM-DD.jsonl`) | `bash .claude/hooks/loopx-guard-summary.sh` 跑一次出当日拦截分类表 |

**注意**:`loopx-self-repair` 在 `templates/skills/loopx-self-repair/SKILL.md` 已注册(`name: loopx-self-repair` frontmatter,2-3 行),其余字段(触发词 / 输入 / 输出)从 SKILL.md § Repair Loop 抽取;`guard-rails-summary` 同上(`templates/skills/guard-rails-summary/SKILL.md` 已注册)。两者均为 🟡 字段子集已确认,完整示例调用待 Sub-project D 实际跑通后补。

**加载顺序**:skill 在 SessionStart 时按目录顺序加载(`loopx-project` → `loopx-self-repair` → `guard-rails-summary`)。如果同一触发词命中多个 skill,以**目录字母序在前**的胜出。

**3 skill 触发词 → 调用方式对照**:

| Skill | 用户怎么用 | Agent 怎么用 |
|---|---|---|
| loopx-project | 直接说"用 LoopX 调研 X" | `/loopx <goal text>` slash 命令 |
| loopx-self-repair | 说"为什么 agent 行为异常" / "自检" | 自动(LoopX 失败信号触发) |
| guard-rails-summary | "今天 hook 拦了什么" | `bash .claude/hooks/loopx-guard-summary.sh` |

**skill vs command vs hook 三者区别**:
- **skill** = 多步骤行为模式(读 SKILL.md 决定怎么干)
- **command** = 单步 slash 命令(读 templates/commands/*.md 决定参数解析)
- **hook** = 工具调用前/后**强制拦截**(不读 md,纯脚本 exit 0/2)

---

## §3 · 1 command 速查表

**字段**:`Command / 触发词 / 参数 / 副作用`(4 列)。所有 command 在 `templates/commands/<name>.md`,通过 Claude Code 的 slash 机制注册(frontmatter `description:` 必填)。

| Command | 触发词 | 参数 | 副作用 |
|---|---|---|---|
| `/deploy-verify` | `/deploy-verify [project]`(`/deploy-verify rime-claude` 或 `/deploy-verify weavepage`) | `[project]` ∈ {`rime-claude`, `weavepage`};`-InstallerPath <abs-path>`;`-SandboxOnly`(rime only);`-OldInstaller` / `-NewInstaller`(weavepage upgrade);`-Wait`(默认 `NoWait`);`-NoWait` | 1. 把 installer 暂存到 `C:\Users\Duanyi\sandbox-artifacts\{project}\installers\`;2. 启动 Windows Sandbox 跑 `install → snapshot → uninstall → screenshot`;3. 写 `C:\Users\Duanyi\sandbox-artifacts\{project}\logs\verify.log`(rime: 10 min 超时;weavepage: 15 min 超时);4. 改 `C:\Users\Duanyi\sandbox-artifacts\{project}\screenshots\`;5. 失败时阻塞并要求显式批准 |

**自动推断**(没带参数时):project 从 cwd 路径匹配(`*rime_claude*` → rime-claude;`*weavepage*` 或 `*tiptap_app*` → weavepage);InstallerPath 从项目 build 输出目录 glob 取 mtime 最新,见 `templates/commands/deploy-verify.md` § What it does step 2。

**实现位置**:分发器 `C:\Users\Duanyi\.local\bin\deploy-verify.ps1`(PowerShell, BOM UTF-8),转发到 `F:\soft\00selfmade\sandbox-verify\{rime-claude\|weavepage}\{rime\|weavepage}-verify.ps1`。

**何时不要用**(摘自 `templates/commands/deploy-verify.md` § When NOT to use this):

- ❌ 测试 dev build + debug log → 用项目自己的 dev/test 工作流
- ❌ 跨平台打包测试 → Windows Sandbox 仅 Windows
- ❌ 长时 soak test → Sandbox 关掉就 reset(最多 ~1h)
- ❌ 需要持久状态 → Sandbox 是 ephemeral

**已知问题**:`media-to-doc-ui` 项目**没有** verify script,要先按 `rime-claude/` 模板镜像一份(详见 `F:\soft\00selfmade\sandbox-verify\README.md`)。Win11 24H2 `vmcompute` 偶发 flake → 见用户记忆 `feedback_win11_sandbox_vmcompute_restart.md`。

**项目键 → verify 脚本 → build 输出根**(摘自 `templates/commands/deploy-verify.md` § Project map):

| project key | subdir under sandbox-verify | verify script | build output root |
|---|---|---|---|
| `rime-claude` | `rime-claude/` | `rime-verify.ps1` | `F:\soft\00selfmade\rime_claude` |
| `weavepage` | `weavepage/` | `weavepage-verify.ps1` | `F:\soft\00selfmade\tiptap_app` |

**日志路径**(失败时第一处翻):
- rime: `C:\Users\Duanyi\sandbox-artifacts\rime\logs\verify.log`
- weavepage: `C:\Users\Duanyi\sandbox-artifacts\weavepage\logs\verify.log`
- 截图: `<same root>\screenshots\screenshot.png`

---

## §4 · 3 Playbook 速查表

**字段**:`Playbook / 类型 / 适用场景 / 循环长度 / 模板状态 / 触发命令`(6 列)。3 种 Playbook 对应不同"循环长度"和"适用场景",完整对照见 `playbooks/README.md`。

| Playbook | 类型 | 适用场景 | 循环长度 | 模板状态 | 触发命令 |
|---|---|---|---|---|---|
| A · 工头式 | 短(单 PR) | CI PR review / 提评论 / 不改代码 | 分钟到小时 | 🟡 框架已就绪(`.github/workflows/pr-review.yml.template` 已写,接入 `settings.json` 待用户实施,需 GitHub repo + Actions secrets) | GitHub Action 自动触发(PR 创建) |
| B · 研究员式 | 长(跨天调研) | 跨天调研 / 写系列博文 / 跟进开源项目 | 跨天(2-3 天) | 🟡 通用框架就绪(`SUB-AGENT-CONFIG.yaml` + `LOOPX-CONNECT-CMD.md` 已写,具体调研主题由用户后补到 `TODO-TOPIC.md`) | `loopx connect --goal-id GOAL-001 ...` + `/loop` |
| C · On-call 式 | 应急(告警 hotfix) | 半夜告警 / SRE hotfix / 误拦 | 分钟级 | 🔴 TODO(前置条件高:需生产环境 + SRE 同事 + PagerDuty MCP,小团队不推荐) | (待实施,设计稿见 `playbooks/README.md` §三) |

**选哪个?** 摘自 `playbooks/README.md` §二:

| 你的情况 | 推荐 |
|---|---|
| 有 GitHub 项目,想让 PR 自动 review | **Playbook A** |
| 有长期调研任务(写系列博文、跟进开源项目) | **Playbook B** |
| 有持续运行的业务系统,半夜不想被叫醒 | **Playbook C** |
| 个人开发者,只想把 guard rails 装上 | **不需要 Playbook**,只跑 `install.sh` 就够 |

**5 原语对照**(每个 Playbook 怎么落地 5 原语,完整见 `playbooks/README.md` §三):

- **Playbook A**:Objective = CLAUDE.md 写"代码风格 + 安全规范";Todo = TaskList(review → fix → test → commit);Gate = PreToolUse Hook 拦 rm / push-to-main / publish;Evidence = PostToolUse Hook 记每条 git commit 到 Slack;Quota = `--max-budget-usd 0.50` 限单 PR
- **Playbook B**:Objective = LoopX `goal_id` + CLAUDE.md;Todo = LoopX `todo claim/update` + TaskList;Gate = LoopX `gate` + PreToolUse Hook;Evidence = LoopX `evidence` + review-packet + auto memory;Quota = LoopX `should_run` + `--max-budget-usd`
- **Playbook C**:Objective = CLAUDE.md 写"SRE 黄金信号 + 事故分级";Todo = TaskList(诊断 / 修 / 测 / 报告);Gate = PreToolUse Hook(直推 main / 删库 / 改 DNS) + SRE Slack 确认;Evidence = PostToolUse Hook 记所有 commit + diff;Quota = Routines 设"半夜模式每天最多烧 $5"

**实施风险**(由低到高):A 低(只 review 不改) → B 中(AI 可能跑偏) → C 高(误拦/误修代价大)。

**Playbook × 资产组合矩阵**(每种 Playbook 用哪些 hook / skill / command):

| Playbook | 用的 hook | 用的 skill | 用的 command |
|---|---|---|---|
| A · 工头式 | 5 hook 全开(项目级 guard rails) | loopx-project(可选,只在 goal 不一致时用) | `/deploy-verify`(若项目发 installer) |
| B · 研究员式 | guard-secret-files.js + guard-main-branch-push.py(其他可关) | loopx-project + loopx-self-repair(失败时) | (一般不用) |
| C · On-call 式 | 5 hook 全开 + SRE Slack 二次确认 | guard-rails-summary(事故后总结) | `/deploy-verify`(hotfix 后回滚验证) |

---

## 5. 跳读索引(按"我在查什么"快速定位)

| 我想... | 跳到 |
|---|---|
| 看 hook 拦什么 / 怎么挂 | §1 hook 表 + `templates/hooks/README.md` |
| 解决 hook exit 2 / 误拦 | §1 故障排查列 + [Part 3 FAQ](PART-3-TUNING-FAQ.md) |
| 调出 LoopX goal | §2 `loopx-project` 行 + `templates/skills/loopx-project/SKILL.md` |
| 看今天 hook 拦了什么 | §2 `guard-rails-summary` 行 + `templates/hooks/loopx-guard-summary.sh` |
| agent 行为异常,想自检 | §2 `loopx-self-repair` 行 + `templates/skills/loopx-self-repair/SKILL.md` |
| 跑装机 verify | §3 `/deploy-verify` 行 + `templates/commands/deploy-verify.md` |
| 选 Playbook A/B/C | §4 选哪个表 + `playbooks/README.md` §二 |
| 调 hook 阈值 / 加白名单 | §1 故障排查列 + `<project>/.claude/guard-rails.yaml` |

**资产计数**:

| 类别 | 数量 | 状态分布 |
|---|---|---|
| hook | 5 | 5× 🟢(全 OK,模板 + 测试就绪) |
| skill | 3 | 1× 🟢(`loopx-project` 完整) / 2× 🟡(`loopx-self-repair` + `guard-rails-summary` 字段子集待 D 补) |
| command | 1 | 1× 🟢 |
| Playbook | 3 | 2× 🟡(A 框架就绪 / B 框架就绪) / 1× 🔴(C TODO) |

---

## 6. 下一步

- **想了解 5 原语怎么落地这些资产**:[Part 2.1](PART-2-1-PRIMITIVES.md)
- **想看 4 场景怎么用**:[Part 2.2](PART-2-2-SCENARIOS.md)(主菜)
- **遇到误拦截 / 想调 hook**:[Part 3](PART-3-TUNING-FAQ.md)
- **理论 + 元数据来源**:`templates/hooks/README.md` · `templates/skills/*/SKILL.md` · `templates/commands/deploy-verify.md` · `playbooks/README.md`
