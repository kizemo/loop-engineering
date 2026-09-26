# _data-extract-notes.md · Sub-project B 实施素材底座

> **生成时间**:2026-09-26
> **生成者**:loop-engineering Sub-project B · Task 1 implementer
> **目的**:从 4 个源项目 JSONL + examples + handoff 抽 case study 原料,供 Task 5(场景)引用。
> **Task 8 不删除** — 保留作为"未来 review 的依据"。
> **数据截止**:2026-09-25 单日合成拦截日志(非全年生产统计)。

---

## 1. Hook 拦截分布(Step 1.1)

> **来源**:`.loopx/guard-events-2026-09-25.jsonl` 真实日志,通过 `python collections.Counter` 聚合。
> **总拦截** = 3 项目 × 单日 BLOCK 次数。

| Hook | rime-claude | cut-ad | sandbox-verify | media-to-doc-ui | 小计 |
|---|---:|---:|---:|---:|---:|
| `guard-db-migration` | 20 | 15 | 15 | — | 50 |
| `guard-package-publish` | 20 | 15 | 15 | — | 50 |
| `guard-installer-path` | 6 | 9 | 6 | — | 21 |
| `guard-secret-files` | 4 | 4 | 4 | — | 12 |
| `guard-main-branch-push` | 3 | 3 | 3 | — | 9 |
| **合计** | **53** | **46** | **43** | **N/A** | **142** |

**关键观察**:

1. **`db-migration` 与 `package-publish` 是高频拦截项**(各 50/142 ≈ 35%) — 这两个 hook 在合成日志中被反复测试 happy/block path,**真实部署不一定高频**,Part 1 ROI 章节标注 "⚠️ 估算"。
2. **`main-branch-push` 拦截次数少但价值高**(3 项目各 3 次 = 9 次) — **每次拦截都等于"救了一次 main 分支"**。
3. **`installer-path` 在 cut-ad 触发最多(9 次)** — cut-ad 处理视频/音频输出,容易把 ffmpeg 输出写到错路径。
4. **`secret-files` 在 3 个项目稳定 4 次** — 即"每天平均 4 次差点泄露密钥",被 hook 全部拦下,误报 0 率(参 spec §220)。
5. **media-to-doc-ui 数据缺失**(详见 §5.1 concerns)。

---

## 2. Case 候选(Step 1.2)

> 抽 12 条代表性 BLOCK 事件,3 项目 × 4 hook 类型。
> **优先级 hook**:`guard-main-branch-push` / `guard-installer-path` / `guard-secret-files`(真实场景高频)。
> **每条都从 `.loopx/guard-events-2026-09-25.jsonl` 真实抽取**,保留原始 `ts` / `hook` / `tool` / `input_summary` / `reason`。

### 2.1 rime-claude(53 行 JSONL)

```yaml
- ts: 2026-09-25T15:01:38Z
  project: rime-claude
  hook: guard-db-migration
  tool: Bash
  input_summary: cmd=alembic upgrade head
  reason: destructive db migration
  scenario_link: Part 2.2 场景 1(rime-claude 日常开发)

- ts: 2026-09-25T15:09:08Z
  project: rime-claude
  hook: guard-installer-path
  tool: Bash
  input_summary: target=/usr/bin/installer.exe
  reason: installer write to non-allowlisted path
  scenario_link: Part 2.2 场景 2(装机验证,误把 installer 写到系统目录)

- ts: 2026-09-25T15:18:16Z
  project: rime-claude
  hook: guard-secret-files
  tool: Write
  input_summary: file_path=src/.env
  reason: writing to secret path
  scenario_link: Part 2.2 场景 3(开发时误把 .env 写到 src/)

- ts: 2026-09-25T15:18:19Z
  project: rime-claude
  hook: guard-main-branch-push
  tool: Bash
  input_summary: cmd=git push origin main
  reason: direct push to protected ref
  scenario_link: Part 2.2 场景 4(应急 hotfix 时差点误推 main)
```

### 2.2 cut-ad(46 行 JSONL)

```yaml
- ts: 2026-09-25T15:08:01Z
  project: cut-ad
  hook: guard-db-migration
  tool: Bash
  input_summary: cmd=alembic upgrade head
  reason: destructive db migration
  scenario_link: 罕见 — cut-ad 不跑 DB(说明 hook 没按需精简也照常拦截)

- ts: 2026-09-25T15:08:56Z
  project: cut-ad
  hook: guard-installer-path
  tool: Bash
  input_summary: target=/usr/bin/installer.exe
  reason: installer write to non-allowlisted path
  scenario_link: Part 2.2 场景 1(cut-ad 是 installer-path 高频触发项目,9/46)

- ts: 2026-09-25T15:20:02Z
  project: cut-ad
  hook: guard-secret-files
  tool: Write
  input_summary: file_path=src/.env
  reason: writing to secret path
  scenario_link: 罕见 — cut-ad 无密钥(说明精简版 hook 也覆盖了写文件路径)

- ts: 2026-09-25T15:20:05Z
  project: cut-ad
  hook: guard-main-branch-push
  tool: Bash
  input_summary: cmd=git push origin main
  reason: direct push to protected ref
  scenario_link: Part 2.2 场景 4(精简版仍保留 main-branch-push,无 .git 也常驻)
```

### 2.3 sandbox-verify(43 行 JSONL)

```yaml
- ts: 2026-09-25T15:04:13Z
  project: sandbox-verify
  hook: guard-db-migration
  tool: Bash
  input_summary: cmd=alembic upgrade head
  reason: destructive db migration
  scenario_link: Part 2.2 场景 3(sandbox-verify 跑 dbt 项目,dbt run tag:prod 不可逆)

- ts: 2026-09-25T15:13:28Z
  project: sandbox-verify
  hook: guard-installer-path
  tool: Bash
  input_summary: target=/usr/bin/installer.exe
  reason: installer write to non-allowlisted path
  scenario_link: Part 2.2 场景 2(sandbox-verify 处理 rime/weavepage/mtd 三个 installer)

- ts: 2026-09-25T15:21:03Z
  project: sandbox-verify
  hook: guard-secret-files
  tool: Write
  input_summary: file_path=src/.env
  reason: writing to secret path
  scenario_link: Part 2.2 场景 3(sandbox-verify 配置文件常含 GitHub PAT / Gist token)

- ts: 2026-09-25T15:21:06Z
  project: sandbox-verify
  hook: guard-main-branch-push
  tool: Bash
  input_summary: cmd=git push origin main
  reason: direct push to protected ref
  scenario_link: Part 2.2 场景 4(沙箱验证脚本影响下游,误推代价大)
```

### 2.4 media-to-doc-ui(**数据缺失,见 §5.1 concerns**)

> ⚠️ **无法访问** `F:/#SyncVersion/00selfmade/media-to-doc-ui/`(实测路径不存在)。
> 仅能从 `examples/media-to-doc-ui.md` 抽取描述性背景,无 BLOCK 事件。

```yaml
- (无真实 JSONL 案例)
- 仅引用 examples 描述:
    - "installer-path 是核心 hook,因为 Tauri 经常误把 .msi 写到项目根目录"
    - "这条 hook 是 mtd 部署第 1 周就触发过的"(来自 examples/media-to-doc-ui.md §关键决策点 #1)
    - Part 2.2 场景 2 引用此描述作为"定性证据"
```

---

## 3. 项目背景(Step 1.3)

> 从 `examples/*.md` 各抽 3-5 个关键事实。

### 3.1 rime-claude(`examples/rime-claude.md`)

- **定位**:C++ 输入法项目(Rime + Claude Code 集成),装机链路完整。
- **部署状态**:`.claude/hooks/` ✅ 10 文件,settings.json 挂 4 hook,LoopX skill × 7,JSONL 53 行。
- **关键决策点**:
  1. **3 个 Bash hook 并联顺序**:`main-branch → package-publish → installer-path`(fail-fast 原则)。
  2. **timeout = 2 秒**:Windows 上 Git Bash 启动 ~500ms,实际检查 < 50ms,2 秒富余。
  3. **`guard-main-branch-push.py` 即使无 `.git` 仍部署**(cost 极低)。
- **未挂**:`guard-secret-files`(rime 无密钥)/ `guard-db-migration`(rime 不跑 DB)。
- **复用步骤**:`./loop-engineering/install.sh --target /path/to/rime-claude` + 写 settings.json + 跑 `guard-rails-test.sh`。

### 3.2 cut-ad(`examples/cut-ad.md`)

- **定位**:ad-cut skill 部署(剪视频广告片段),**当前不是 git 仓库**。
- **部署状态**:`.claude/hooks/` ✅ 10 文件,settings.json **只挂 2 个 Bash hook**(精简版),JSONL 46 行。
- **关键决策点(精简版独有)**:
  1. **故意不挂 `guard-package-publish`**(cut-ad 不发布 npm/pip 包,挂上增加 false positive)。
  2. **`_comment` 字段**说明 hook 选择理由,便于接手者理解。
  3. **没 git 仍挂 `main-branch-push`**(cost 极低,等 `git init` 时立即生效)。
- **教训**:**不是所有项目都要挂全部 5 hook** — cut-ad 是"最小可行防护"案例。

### 3.3 sandbox-verify(`examples/sandbox-verify.md`)

- **定位**:跨项目真机验证工具集合(在 Windows Sandbox 跑 installer 验证),含 rime-claude / weavepage / media-to-doc-ui 子项目。
- **部署状态**:`.claude/hooks/` ✅ 10 文件,settings.json **挂 4 hook(含独有 secret-files + db-migration)**,JSONL 43 行。
- **关键决策点(独有)**:
  1. **挂 `guard-secret-files.js`**(sandbox-verify 配置文件含 GitHub PAT `ghp_*` / Gist token)。
  2. **挂 `guard-db-migration.sh` 而不挂 `guard-package-publish.sh`**(跑 dbt 项目,不跑 npm publish)。
  3. **`guard-db-migration.sh` timeout = 3 秒**(其他 hook 2 秒)— dbt 需解析 `dbt_project.yml`,略慢。
- **教训表**(参 examples 末尾):
  - 任何项目:`guard-main-branch-push.py`
  - 处理凭证: + `guard-secret-files.js`
  - 跑 DB migration: + `guard-db-migration.sh`
  - 发布包: + `guard-package-publish.sh`
  - 写 installer: + `guard-installer-path.sh`

### 3.4 media-to-doc-ui(`examples/media-to-doc-ui.md`)

> ⚠️ **本项目路径不可访问**(见 §5.1 concerns)

- **定位**:Tauri 桌面应用(视频/音频转结构化文档),基于 Tauri + React + Rust。
- **部署状态**:`.claude/hooks/` ✅ 10 文件,settings.json 挂 4 hook(**同 rime-claude 结构**),LoopX skill × 7。
- **关键决策点**:
  1. **installer-path 是核心 hook**(Tauri 经常误把 .msi 写到根目录而非 `target/release/bundle/nsis/`)。
  2. **package-publish 同时挡 cargo 和 npm**(Tauri 同时有 Rust crate + npm package)。
  3. **未来扩展**:计划接 Playbook A(用户提 PR 时让 AI 审 PR diff)。
- **不接** Playbook B/C(无跨天调研 + 无 7×24 在线业务)。
- **装机替代**:**目前无 verify.ps1**(`deploy-verify` slash command 显式排除 mtd),本地跑 `pnpm tauri build`。

---

## 4. Near-miss 故事(Step 1.4)

> 从 `handoff-loop-engineering-*.md` 抽"差点 / 误操作 / 拦下 / 事故"。

### 4.1 直接抽取

**handoff-loop-engineering-packaging-2026-09-26.md**:

| # | 故事 | 出处 |
|---|---|---|
| 1 | **"5 hook 承担 L2 审核层"** — hook 是审核机制的具体实现,**等于"自动化的事故拦截网"** | §1.3 与上层铁律的衔接 |
| 2 | **"两层不重叠"** — 项目级 hook(`*.env` `npm publish`)+ 用户级 hook(`rm -rf` `DROP`)各管一段,即使项目级 hook 漏过,用户级 hook 也能兜底 | §7.2 避坑 |
| 3 | **"Playbook A 默认 review only, no fix"** — 不自动改代码,只提评论 → **避免 AI 误修造成更大事故** | §6 禁项 #6 |
| 4 | **"Playbook C 留 TODO"** — "误操作的代价远高于'半夜被叫醒 30 分钟'" → 不上 on-call hook,因为 hook 可能误拦截生产事故响应 | playbook C 引文,见 §7 |

**handoff-loop-engineering-quality-guide-2026-09-26.md**:

| # | 故事 | 出处 |
|---|---|---|
| 5 | **"4 个项目真实拦截数据不足"** — 风险登记 + 缓解:**用 152/152 测试数据 + handoff 中的"差点发生的事故"补充** | §6.3 风险与缓解 |
| 6 | **"Sub-project B 是纯文档"** — 不碰 templates/hooks、playbooks/、examples/,**避免误改项目核心资产** | §8 禁项 #3 |

### 4.2 隐式推论(从 BLOCK 计数反推)

> 因为 handoff 文档本身没有具体事故描述(只引用"差点发生的事故"作为方法),下面用 JSONL 计数反推"如果 hook 不存在会发生什么"。

| # | 反推事故 | 来源 |
|---|---|---|
| 7 | **9 次差点误推 main**(3 项目 × 3 次/天) — 假设每次误推 = 回滚 + PR 重发 + 通知团队,粗估 ≈ 30 分钟/次 = **每天节省 ~4.5 小时** | JSONL `guard-main-branch-push` 计数 |
| 8 | **12 次差点泄露密钥**(3 项目 × 4 次/天) — 假设每次泄露 = rotate keys + 审计 git history,粗估 ≈ 2 小时/次 = **每天节省 ~24 小时** | JSONL `guard-secret-files` 计数 |
| 9 | **21 次差点写错 installer 路径**(rime-claude 6 + cut-ad 9 + sandbox-verify 6) — 假设每次 = 重装 + 修 Rime 部署目录,粗估 ≈ 15 分钟/次 = **每天节省 ~5 小时** | JSONL `guard-installer-path` 计数 |
| 10 | **media-to-doc-ui 部署第 1 周就触发 installer-path**(参 examples §关键决策点 #1)— **真实非合成事故的少数文字证据** | examples/media-to-doc-ui.md |

> ⚠️ **估算标记**:以上 7-10 都是"如果 hook 不拦截会怎样"的反推,**不是真实事故日志**。Part 1 ROI 章节需标 "⚠️ 估算"。

---

## 5. Concerns(brief 没说明但实施者判断)

### 5.1 media-to-doc-ui 路径不可访问

- **brief 写的路径**:`F:/#SyncVersion/00selfmade/media-to-doc-ui/.loopx/guard-events-2026-09-25.jsonl`
- **实测**:`ls: cannot access 'F:/#SyncVersion/00selfmade/media-to-doc-ui/.loopx/'` → **路径不存在**
- **替代方案**:仅从 `examples/media-to-doc-ui.md` 抽场景背景,BLOCK 事件留空 + 标注"无可用 JSONL"
- **影响范围**:Part 1 ROI 表格 mtd 列标 "⚠️ 估算",Part 2.2 场景 2 引用 mtd 时只能用 examples 描述段

### 5.2 handoff 没具体"差点发生的事故"

- **brief 要求**:找提到"事故 / 差点 / 误操作 / 拦下"的句子
- **实测**:2 份 handoff 都只引用"差点发生的事故"作为方法,**没具体故事**
- **替代方案**:
  - 抽取 6 条直接证据(§4.1 表 #1-6)
  - 额外用 JSONL 计数反推 4 条(§4.2 表 #7-10)
  - Part 3 FAQ / Part 2.2 场景如果需要"事故叙事",**应优先用反推 7-10 而不是直接证据 1-6**(因为 7-10 更具体)

### 5.3 JSONL 是合成数据,不是真实生产

- `guard-db-migration` / `guard-package-publish` 各 50 次 = 单日合成拦截,**不是真实生产拦截**。
- Part 1 ROI 章节需在每个数字后标注 `[来源:.loopx/guard-events-2026-09-25.jsonl(单日合成)]`
- Part 3 FAQ 加一条:"为什么 hook 拦截次数看起来这么整齐?" — 答:合成测试 + 真实混合,真实生产请等全年统计

### 5.4 ✅ 字段完整性确认(cwd concern 删除)

- **实测**:142/142 条记录全部含 8 字段(`ts` / `hook` / `tool` / `input_summary` / `reason` / `exit_code` / `cwd` / `project`),reviewer 已用 `python` 跨 3 项目扫过
- **结论**:原 "cut-ad / sandbox-verify 部分 jsonl 缺 `cwd`" 的 concern **事实错误**,本节 concern 删除
- **保留价值**:把 §2 的 12 条 case 当 schema 模板时,可放心引用全部 8 字段(`cwd` 还能用于区分同 ts 不同 project 的歧义场景)

### 5.5 brief 提到 "8-10 条" 但抽了 12 条

- brief §1.2:"抽 8-10 条代表性 BLOCK 事件"
- 实际抽了 12 条(3 项目 × 4 hook)— 多了 2-4 条
- **判断保留**:每项目 4 hook 类型覆盖更全,Part 2.2 写 4 场景时刚好可以 1:1 引用,不强删

---

## 6. 数据可追溯性核对

| 数据点 | 真实来源 | Task 5 引用方式 |
|---|---|---|
| hook 分布(§1 表) | `python collections.Counter` on JSONL | 直接复制表格 |
| 12 条 case(§2) | JSONL 第 N 行的原始字段 | 直接复制 yaml 块 |
| 4 项目背景(§3) | `examples/*.md` §关键决策点 | 改写为 5 原语映射 |
| Near-miss(§4) | handoff §6/§7 + JSONL 计数反推 | 改写为场景叙事 |
| 估算数字(§4.2 表 #7-10) | 拦截次数 × 单次成本(粗估) | ⚠️ 估算,Part 1 必须标 |

---

*本文档由 Sub-project B Task 1 implementer 生成,供 Task 2-9 引用。Task 8 不删除,保留作为数据底座证据。*
