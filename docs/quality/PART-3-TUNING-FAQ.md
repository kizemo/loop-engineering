# Part 3 · 调优与 FAQ(Tuning & FAQ)

> **数据截止**:2026-09-25 单日合成拦截日志(`_data-extract-notes.md` §1)+ 2026-09-26 hook/skill/playbook 元数据快照
> **文档性质**:FAQ 答案基于模板 hook + examples + Part 1-2.3 已交付内容;**真实部署后回填**会标注
> **承接文档**:[README.md](README.md) · [Part 1](PART-1-DECISION-FRAMEWORK.md) · [Part 2.1](PART-2-1-PRIMITIVES.md) · [Part 2.2](PART-2-2-SCENARIOS.md) · [Part 2.3](PART-2-3-ASSETS.md)

---

## §1 · 常见调优(4 子段)

### 1.1 放宽 hook(matchers 调宽 + allowlist 加项)

- **改 matcher 正则**:编辑 `templates/hooks/<hook>.{js|sh|py}` 的 `MATCHER` 常量,或 `<project>/.claude/settings.json` 挂载行的 `matcher` 字段。例:把 `Edit|Write|MultiEdit` 改成 `Edit|Write` 去掉 `MultiEdit` 拦截。
- **加 allowlist**:在 `<project>/.claude/guard-rails.yaml` 加项目特定允许规则(`secrets_extra_patterns` / `allowed_main_branches` / `installer_allow_paths` / `--allow-test` flag),完整字段见 `templates/hooks/README.md` §步骤 4。改完跑 `bash templates/hooks/guard-rails-test.sh` 验 happy + block 两路不破。

### 1.2 收紧 hook(更严正则 + 强制路径白名单)

- **加更严 matcher**:例 `templates/hooks/guard-installer-path.sh` 只允许 `target/release/bundle/`(默认是 `target/` / `release/` / `dist/` / `build/` / `output/` 全开),改 `INSTALLER_ALLOW_PATHS` 数组收紧。
- **强制必须某 hook**:从 `settings.json` 取消该 matcher 挂载会让对应工具调用无门禁。**永久开启**:把 hook 文件移到 `~/.claude/hooks/`(用户级)+ 加 `<always_on>` 注释,然后跑 `bash install.sh --reinstall`。
- **测试新规则**:`bash templates/hooks/guard-rails-test.sh --only guard-installer-path.sh` 只跑一个 hook,避免误拦其它。

### 1.3 调 Claude API 预算(`--max-budget-usd` + 事故升级)

- **默认值**:`--max-budget-usd 0.50`(单次会话花费上限),来自 `~/.claude/settings.json` 或 CLI flag。事故排查 / 大文件批处理时可显式调高:
  ```bash
  claude -p --max-budget-usd 5.00 "<prompt>"       # 单次提到 $5
  # 或编辑 settings.json 的 env.max_budget_usd = "5.00" 永久
  ```
- **搭配 quota**:见 [Part 2.1 §3.3](PART-2-1-PRIMITIVES.md) Quota 原语,budget 撞墙时 agent 会自动 truncate 而非烧钱继续。

### 1.4 定制 CLAUDE.md(项目专属规则注入)

- 在 `<project>/CLAUDE.md`(项目级,git 跟踪)或 `~/.claude/CLAUDE.md`(用户级)加**项目专属规则**,AI SessionStart 自动加载,无需 hook 拦截:
  - 例 1(团队规范):"本项目用 pnpm 而非 npm,所有 install 命令自动用 pnpm"
  - 例 2(代码风格):"PR 不接受 force-push squash,必须 rebase merge"
  - 例 3(禁词):"不要建议用 axios,统一用 fetch"
- **优先级**:用户级 `~/.claude/CLAUDE.md` < 项目级 `<project>/CLAUDE.md` < 当前目录级 `<cwd>/CLAUDE.md`,后者覆盖前者。完整优先级见用户级 CLAUDE.md § "新会话开局守则"。

---

## §2 · FAQ(14 条)

### Q1: hook 误拦截了合法命令,怎么撤?
A: 三种方式 — ① 永久卸:`bash install.sh --uninstall`(取消对应 matcher 挂载);② 临时允许:在 `<project>/.claude/guard-rails.yaml` 加 allowlist 例 `allowed_main_branches: ["main", "develop"]`;③ 一次性批准:hook 退出 2 时 stderr 会给提示,用户在 Claude Code 里显式批准后重试即可。详见 [Part 1 §1.4](PART-1-DECISION-FRAMEWORK.md)。

### Q2: hook 退出码 2 但 `.loopx/guard-events-*.jsonl` 无新行,怎么调试?
A: 99% 是 `.loopx/` 目录不存在或不可写 — 先 `mkdir -p .loopx && touch .loopx/.write-test`,再跑一次被拦命令。10% 是 hook 启动失败(Python 启动慢、Windows Git Bash msys timeout):在 `settings.json` 把 `timeout` 从 2s 调到 3s。详见 `templates/hooks/README.md` §故障排查。

### Q3: `loopx doctor --deep` 跑不过,怎么修?
A: 跑 `loopx update --execute --ref main` 拉到最新,然后再跑 `loopx doctor --deep`。常见 fail:`objective` / `goal_id` 字段为空 → 跑 `loopx start-goal --guided --project . --goal-text "<GOAL_TEXT>"` 重建。Schema 字段映射见 [Part 2.1 §2.1](PART-2-1-PRIMITIVES.md)。

### Q4: sub-agent 重复任务怎么避免(同 goal_id 重复 start)?
A: 用 `loopx sync-global --goal-id GOAL-001` 拉最新状态,而不是 `--refresh-state`(后者会重新 spawn agent)。判断标准:同 goal_id + 同 objective + <24h = 续做;否则新 goal_id。详见 [Part 2.1 §3.4](PART-2-1-PRIMITIVES.md) Evidence 原语。

### Q5: 为什么没有真实事故日志?(*handoff review 强化必加*)
A: 数据合成 + handoff 缺事故 — ① JSONL 是 2026-09-25 **单日合成测试数据**(`_data-extract-notes.md` §5.3),不是全年生产拦截,所有数字都已标 `[来源:.loopx/guard-events-2026-09-25.jsonl(单日合成)]`;② 2 份历史 handoff 都只把"差点发生的事故"当**方法**引用,没具体故事(`_data-extract-notes.md` §5.2),所以 Part 2.2 场景只能描述 hook 行为,无法写真实事故时间线。**真实生产后需重抽 JSONL 回填**。

### Q6: 怎么升级 loop-engineering 到 v1.1?
A: 看 [GitHub release notes](https://github.com/kizemo/loop-engineering/releases),跑 `bash install.sh --upgrade`(脚本自动备份旧 hook + diff 升级),然后 `bash templates/hooks/guard-rails-test.sh` 跑全 hook 回归。**升级前先 git commit 当前 settings.json**,升级失败可手动 revert。

### Q7: `.loopx/guard-events-*.jsonl` 日志保留多久?
A: 默认**永久**(Git tracked 或本地累积,无自动清理)。大项目 1 年可累积 50MB+,建议加 `.gitignore` `*.jsonl` 但本地保留。归档策略:`bash .claude/hooks/loopx-guard-summary.sh --since 2026-01-01 --limit 10000` 抽统计 + 删旧文件。

### Q8: 能不能只装部分 hook?
A: 可以,选挂 matcher 即可。`settings.json` 的 `PreToolUse` 数组里**只放需要的 matcher**,不写就等于没装。精简方案如 `cut-ad` 只挂 `guard-main-branch-push.py` + `guard-installer-path.sh` 2 个,见 [Part 1 §1.1.2](PART-1-DECISION-FRAMEWORK.md)。

### Q9: Playbook C(On-call 式)何时能实施?
A: **等 Sub-project D 实施**,前置条件高(需生产环境 + SRE 同事 + PagerDuty MCP)。小团队不推荐 — 见 `playbooks/README.md` §三 Playbook C 段。当前只能装 Playbook A(PR review)+ B(跨天调研)。

### Q10: Part 1 数字来源可信吗?
A: **可信度分层** — ① 直接证据:JSONL 字段(142/142 条 8 字段全,见 `_data-extract-notes.md` §5.4);② 反推估算:`拦截次数 × 单次成本`粗算,每个数字已标 `⚠️ 估算`;③ 真实生产回填:hook 部署 ≥30 天后才有意义,**当前文档明示合成数据**。

### Q11: 与用户级 hook(如 `~/.claude/hooks/le-gatekeeper.js`)冲突怎么办?
A: PreToolUse 多 hook 链是**叠加而非互斥** — 任一 hook exit 2 即阻止工具调用,用户级 + 项目级 hook 互补(用户级挡 `rm -rf`/`DROP`/`format` 全 Bash 域,项目级补 Edit/Write 缺口)。详见 [Part 2.3 §1](PART-2-3-ASSETS.md)。

### Q12: LoopX doctor --deep 跑不过但 `loopx update` 也救不了?
A: 重新装 LoopX:`curl -fsSL https://loopx.dev/install.sh | bash` + `loopx update --execute --ref main`,再跑 `loopx doctor --deep`。若仍 fail,跑 `loopx --format json diagnose --goal-id <goal-id>` 拿诊断 JSON 看具体 fail 字段。

### Q13: Windows Git Bash 启动 hook 慢怎么办?
A: msys 环境 Python/Node 启动开销大 — `settings.json` 把对应 matcher 的 `timeout` 从默认 2s 调到 **3-5s**(`guard-main-branch-push.py` 经常需要)。若仍超时,把 `python .claude/hooks/xxx.py` 改成 `pythonw` 或预编译成 `.exe`(`pyinstaller --onefile`)。

### Q14: 为什么 hook 拦截次数看起来这么整齐(20/15/15 那种)?
A: JSONL 中 `guard-db-migration` / `guard-package-publish` 各 50 次 = **单日合成拦截**,不是真实生产累计。`guard-db-migration` 在 rime-claude 拦 20 次只是因为 rime 不跑 DB、JSONL 拿 happy+block 测试用例填位。**真实生产请等 ≥30 天统计**,不要拿当前数字外推年度 ROI。

---

## §3 · 升级指南

### 3.1 LoopX 上游变更同步

- **日常**:LoopX release → 跑 `loopx update --execute --ref main`,重新跑 `loopx doctor --deep` 验 schema 字段未变。
- **大版本**(LoopX 2.x):先看 migration guide,跑 `bash install.sh --upgrade-loopx`,再用 `loopx --format json diagnose --goal-id <goal-id>` 验历史 goal 是否兼容。
- **失败回滚**:`loopx update --ref main --rollback`(loop-engineering 自动备份上一版到 `~/.loopx/backups/`).

### 3.2 loop-engineering 大版本迁移

- **步骤**:① `git pull` 拉 loop-engineering 最新;② 看 `templates/hooks/CHANGELOG.md`(待补) + GitHub release notes;③ 跑 `bash install.sh --upgrade`(自动备份旧 hook + diff 升级);④ `bash templates/hooks/guard-rails-test.sh` 跑全 hook 回归;⑤ 跑 `loopx doctor --deep` 验集成。
- **升级失败**:settings.json 已 git commit,`git checkout HEAD -- .claude/settings.json` 一键回滚;hook 文件 `bash install.sh --rollback` 还原。

### 3.3 Sub-project D 待定事项

- **Playbook C 实施**:前置条件高(生产 + SRE + PagerDuty MCP),小团队不推荐。当前文档明示"待 Sub-project D 实施"。
- **LoopX 上游同步策略**:目前是手动 `loopx update`,Sub-project D 会做自动 weekly sync + 冲突检测(独立文档待写)。
- **真实生产数据回填**:hook 部署 ≥30 天后用 `loopx-guard-summary.sh --since <30d-ago>` 抽统计,回填 Part 1 ROI 表的 `[来源:...]` 标签。

---

**报告**:见 `.superpowers/sdd/2026-09-26-agent-quality-guide-plan/task-7-report.md` · **未 push**(留 Task 10)
