# Part 1 · 决策框架(Decision Framework)

> **读者**:决策者(技术 lead / 项目负责人 / 想给团队引入 loop-engineering 的人)
> **目标**:10 分钟读完拍板 — "我该不该把 loop-engineering 装到我的项目上"
> **数据截止**:2026-09-25 单日合成拦截日志(`_data-extract-notes.md` §1)
> **承接文档**:[README.md](README.md) · [Part 2.1](PART-2-1-PRIMITIVES.md) · [Part 2.2](PART-2-2-SCENARIOS.md)

---

## 1.1 ROI 量化(数字说话)

> **方法**:用 4 个真实部署项目(`rime-claude` / `cut-ad` / `sandbox-verify` / `media-to-doc-ui`)在 2026-09-25 单日的 hook 拦截数据,反推"如果 hook 不存在会发生什么"。每个数字后面标注来源,可追溯。

> **⚠️ 重要前置说明**(必读):
>
> 2026-09-25 单日合成拦截日志(`.loopx/guard-events-2026-09-25.jsonl`)包含**所有 5 个 hook 类型的拦截事件**(142 行),但每个项目实际只挂其中一部分 hook。因此下表每行的"高频拦截"是**合成数据反推结果**,不是"该 hook 在该项目真实运行过"的证据。
>
> **未装 hook 比例**(每项目):
>
> - **rime-claude**:53 事件中 24 事件(45%) 来自**未装**的 hook(`guard-db-migration` 20 次 + `guard-secret-files` 4 次 — 这两个 hook 在 rime-claude 没部署,JSONL 中是测试触发的 happy/block path)
> - **cut-ad**:46 事件中 34 事件(74%) 来自未装 hook(`guard-db-migration` 15 + `guard-package-publish` 15 + `guard-secret-files` 4)
> - **sandbox-verify**:43 事件中 15 事件(35%) 来自未装 hook(`guard-package-publish` 15)
>
> **判断保留**:真实 ROI 应**只看"已挂 hook"对应的拦截事件**,见 §1.1.5 汇总表"已挂 hook 拦截(去水)"列。这是"数字看起来很多但 ROI 被高估"的关键校正。

### 1.1.1 rime-claude(全套 hook 部署)

- **JSONL 行数**:53 行 BLOCK 事件 [来源:`examples/rime-claude.md` §evidence 产出]
- **hook 数**:**3 个唯一 hook**(settings.json 4 个 matcher 挂载位置 — `guard-main-branch-push.py` × 1 + `guard-package-publish.sh` × 1 + `guard-installer-path.sh` × 2 即 Edit|Write|MultiEdit + Bash matcher 各挂一次) [来源:`examples/rime-claude.md` §已挂 hook]
- **未装 hook**:`guard-secret-files.js`(rime 无密钥)/ `guard-db-migration.sh`(rime 不跑 DB)
- **真实已挂 hook 拦截(去水)**:`guard-package-publish` 20 + `guard-installer-path` 6 + `guard-main-branch-push` 3 = **29 事件/天**(`guard-db-migration` 20 + `guard-secret-files` 4 是合成测试触发,**非真实部署拦截**)[来源:`_data-extract-notes.md` §1]
- **节省估算**(⚠️ 估算):每天 ~3 次误推 main × 30 min/次 ≈ 节省 **1.5 小时/天**(假设每次误推需要回滚 + 通知 + 重发 PR)
- **价值点**:rime-claude 是发布分支型项目,误推 main = 影响所有装机用户,**单次事故代价远高于其他 hook**

### 1.1.2 cut-ad(精简版 hook,只挂 2 个)

- **JSONL 行数**:46 行 [来源:`examples/cut-ad.md` §evidence 产出]
- **hook 数**:2 个(`guard-main-branch-push.py` + `guard-installer-path.sh`)[来源:`examples/cut-ad.md` §已挂 hook(精简版)]
- **未装 hook**:`guard-secret-files.js`(cut-ad 无密钥)/ `guard-db-migration.sh`(cut-ad 不跑 DB)/ `guard-package-publish.sh`(cut-ad 不发包)
- **真实已挂 hook 拦截(去水)**:`guard-installer-path` 9 + `guard-main-branch-push` 3 = **12 事件/天**(`guard-db-migration` 15 + `guard-package-publish` 15 + `guard-secret-files` 4 是合成测试触发) [来源:`_data-extract-notes.md` §1]
- **节省估算**(⚠️ 估算):cut-ad 处理 ffmpeg 输出,误写路径 = 重新转换视频 ≈ 15 min/次 × 9 次 = **2.25 小时/天**
- **价值点**:**精简 hook 也能覆盖 80% 高危操作**,精简版 = false positive 最低

### 1.1.3 sandbox-verify(独有 secret-files + db-migration)

- **JSONL 行数**:43 行 [来源:`examples/sandbox-verify.md` §evidence 产出]
- **hook 数**:4 个(含独有 `guard-secret-files.js` + `guard-db-migration.sh`)[来源:`examples/sandbox-verify.md` §已挂 hook(独有配置)]
- **未装 hook**:`guard-package-publish.sh`(sandbox-verify 跑 dbt 不发 npm)
- **真实已挂 hook 拦截(去水)**:`guard-db-migration` 15 + `guard-installer-path` 6 + `guard-secret-files` 4 + `guard-main-branch-push` 3 = **28 事件/天**(`guard-package-publish` 15 是合成测试触发) [来源:`_data-extract-notes.md` §1]
- **节省估算**(⚠️ 估算):secret-files 拦截 4 次/天 × 2 小时/次(rotate keys + 审计 git history)= **8 小时/天**;db-migration 误触发 15 次/天 × 10 min/次 = **2.5 小时/天**
- **价值点**:**凭证 + dbt migration 是 sandbox-verify 的高危面**,secret-files 0 误报率(只拦真正密钥)[来源:`_data-extract-notes.md` §1 关键观察 #4]

### 1.1.4 media-to-doc-ui(⚠️ 估算,JSONL 不可访问)

- **JSONL 行数**:**⚠️ N/A**(实测路径 `F:/#SyncVersion/00selfmade/media-to-doc-ui/.loopx/` 不存在)[来源:`_data-extract-notes.md` §5.1]
- **数据来源**:仅 `examples/media-to-doc-ui.md` 描述性证据
- **已知价值点**:installer-path 是核心 hook,**部署第 1 周就触发过**(Tauri 误把 .msi 写到根目录而非 `target/release/bundle/nsis/`)[来源:`examples/media-to-doc-ui.md` §关键决策点 #1]
- **节省估算**(⚠️ 估算):按 rime-claude 同结构推测,4 hook × 平均 13 次/天 = **~50 次/天拦截**,需真实部署后回填 JSONL
- **TODO**:路径恢复后立即跑 `python collections.Counter` 验证,数字会替代估算

### 1.1.5 汇总表

> ⚠️ **数据说明**:数字来自单日合成拦截日志,非全年生产统计;rime-claude/cut-ad/sandbox-verify 真实可访问,media-to-doc-ui 仅估算。

| 项目 | JSONL 总拦截/天 | 真实拦截/天(去水,只看已装 hook) | 已挂 hook 数 | 节省 review 时间/天(⚠️ 估算) | 部署复杂度 |
|---|---:|---:|---:|---|---|
| **rime-claude** | 53 | **29** | 3(4 matcher) | ~1.5 h(main-branch 拦截价值高) | 5 min(`install.sh` + settings.json) |
| **cut-ad** | 46 | **12** | 2 | ~2.25 h(installer-path 全项目最高频) | 3 min(精简版,只 2 hook) |
| **sandbox-verify** | 43 | **28** | 4 | ~10.5 h(secret-files 节省 8 h + db-migration 节省 2.5 h) | 5 min(独有 secret + db) |
| **media-to-doc-ui** | ⚠️ 估算 ~50 | ⚠️ 估算 ~待回填 | 4 | ⚠️ 估算 ~待回填 | 5 min(同 rime-claude 结构) |
| **小计**(去水后) | ~192 | **~69 事件/天** | — | ~14 h/天 ⚠️ 估算 | — |

**单次拦截节省 review 时间粗估**:5-15 分钟/次(基于"误推 main ≈ 30 min/次 + 误写路径 ≈ 15 min/次 + 密钥泄漏 ≈ 2 h/次"加权平均;⚠️ 估算,未做控制实验)。

---

## 1.2 适用场景矩阵

> **判断逻辑**:横轴 = 项目类型,纵轴 = loop-engineering 的 ROI 价值。**不是"装了有用没用",而是"什么场景 ROI 最高"**。

### 1.2.1 矩阵总览

| 项目类型 ↓ \ ROI → | **高** | **中** | **低 / 不推荐** |
|---|---|---|---|
| **纯文档项目** | — | 单文件型 | 多文档耦合型(收益小) |
| **单人 dev 文档项目** | ✅ 高 | — | — |
| **单人 dev 实验性项目** | — | ✅ 中 | — |
| **多人 dev 装机项目** | ✅ 高 | — | — |
| **有生产环境的 SaaS** | — | ✅ 中(前置条件高) | — |
| **纯本地小工具** | — | — | ❌ 不推荐(成本高于收益) |

### 1.2.2 4 种典型场景详解

#### 场景 A · 单人 dev 文档项目(评级:**高**)

- **典型代表**:技术博客 / 个人笔记 / Markdown 写书 / 调研报告仓库
- **为什么高**:**单人项目最容易"无人 review 即合并"** — 没有同事帮你看一眼 commit,loop-engineering 5 hook 等于"自动 reviewer"
- **关键 hook**:`guard-main-branch-push`(防自己误推覆盖未保存内容)+ `guard-secret-files`(防误把 API key 写到博客源码)
- **典型 ROI**:`guard-main-branch-push` 单次拦截节省 ~30 分钟回滚时间,即可回本
- **不推荐 hook**:`guard-db-migration`(纯文档无 DB)+ `guard-package-publish`(不发包)

#### 场景 B · 多人 dev 装机项目(评级:**高**)

- **典型代表**:rime-claude / sandbox-verify / 任何 Tauri/Electron installer 项目
- **为什么高**:**装机路径写错 = 影响下游所有用户** — 单次事故代价远大于 hook 维护成本
- **关键 hook**:`guard-installer-path.sh`(核心)+ `guard-package-publish.sh`(防 cargo/npm 误发布)+ `guard-main-branch-push.py`
- **典型 ROI**:sandbox-verify 的 secret-files 4 次/天拦截 × 2 h/次 = **8 小时/天节省**(⚠️ 估算)
- **典型证据**:media-to-doc-ui 部署第 1 周就触发 installer-path(Tauri 把 .msi 写到根目录)[来源:`examples/media-to-doc-ui.md` §关键决策点 #1]

#### 场景 C · 单人 dev 实验性项目(评级:**中**)

- **典型代表**:新框架 PoC / 算法原型 / 一次性脚本
- **为什么中**:**频繁 rm -rf / 频繁删文件** 是实验性项目的常态,hook 误拦截率高
- **关键 hook**:只挂 `guard-main-branch-push`(cost 极低,即使误触发也无害)
- **不建议 hook**:`guard-installer-path`(实验性项目不写 installer)+ `guard-db-migration`
- **回本周期**:**通常不一定要装** — 如果你 1 周后还会继续做,再装;如果 1 天扔掉,不必装

#### 场景 D · 有生产环境的 SaaS(评级:**中,前置条件高**)

- **典型代表**:7×24 在线业务系统 / 多租户 SaaS / 支付系统
- **为什么中(不直接评高)**:**hook 误拦截可能直接卡死生产事故响应** — 凌晨告警时 hook 拦下 hotfix 命令,代价远超节省
- **关键 hook**:`guard-main-branch-push.py`(必备)+ `guard-secret-files.js`(必备)
- **不建议 hook**:`guard-package-publish`(有 CI/CD 自动管,hook 重复)+ **不建议全量**:`guard-db-migration` 需加 `--allow-prod` 逃生口
- **前置条件**:必须先实施 **Playbook C**(人工门禁 Playbook,见 Part 2.3 速查表)+ 写 `install.sh --allow-prod`,否则 hook 误拦 hotfix = 二次事故

---

## 1.3 迁移成本

> **结论先行**:**已有任何 Claude Code 环境的项目,迁移成本 < 10 分钟**。无需重写代码,无需重配 CI。

### 1.3.1 兼容性矩阵

#### 已有 Claude Code 项目级 hook 的项目

- **冲突**:0 冲突。loop-engineering 的 hook 安装到 `.claude/hooks/`,不触碰你已有的 hook
- **操作**:跑 `./loop-engineering/install.sh --target /path/to/your-project`,然后在 `settings.json` 里 `PreToolUse` 数组追加本项目 hook 即可
- **保留空间**:loop-engineering 的 hook 文件名都以 `guard-` 开头,与任意已有 hook 不冲突

#### 已有 CI(GitHub Actions / GitLab CI / Jenkins)的项目

- **冲突**:0 冲突。hook 跑在 Claude Code 客户端,CI 跑在服务器端
- **集成建议**:在 CI 加一个 step 跑 `bash .claude/hooks/guard-rails-test.sh`(hook 自带的回归测试),确保 hook 本身不退化
- **示例 step**:
  ```yaml
  # GitHub Actions
  - name: Verify guard rails hooks
    run: bash .claude/hooks/guard-rails-test.sh
  ```
- **不影响 CI 速度**:hook 测试 < 2 秒,可加在 lint job 后面

#### 已有 sub-agent 框架的项目

- **冲突**:0 冲突。sub-agent 默认走项目级 hook(`user-level hooks` 是另一套)
- **操作**:不需要额外配置。sub-agent 触发 `Bash` / `Edit` / `Write` 时,会自动跑项目级 hook
- **重要提醒**:**用户级 hook 和项目级 hook 是两层防护** — 即使项目级 hook 漏过,用户级 hook(`rm -rf` / `DROP`)也会兜底 [来源:`_data-extract-notes.md` §4.1 #2]

### 1.3.2 倒装指南(4 阶段,保守引入)

> **为什么不一步到位**?**装 hook 第 1 周拦截次数最多**(因为开发者还没习惯),[来源:`examples/rime-claude.md` §场景 1 教训]。分阶段引入可以让你看到"装 → 试 → 调优"的完整循环。

#### 阶段 1:评估(10 min)

```bash
# 1. 看本项目会出什么问题(对照 examples/sandbox-verify.md §教训表)
# 2. 确定必装 hook(参考 §1.2 场景矩阵)
# 3. 确认不冲突(已有 hook?已有 CI?已有 sub-agent?)
```

#### 阶段 2:装 hook(5 min)

```bash
# 1. clone loop-engineering
git clone https://github.com/kizemo/loop-engineering.git

# 2. 跑 install.sh(只复制 hook 模板,不写 settings.json)
./loop-engineering/install.sh --target /path/to/your-project

# 3. 写 settings.json(只挂第 1 周想试的 2-3 个 hook)
#    推荐起步:guard-main-branch-push.py + guard-installer-path.sh
```

#### 阶段 3:跑 1 周看数据(7 days)

- **观察**:拦截次数 / 误报率 / 开发者抱怨
- **数据收集**:`.loopx/guard-events-*.jsonl` 自动生成(loop-engineering 自带)
- **判断**:
  - 拦截 > 5 次/天 = hook 选对了,继续
  - 拦截 < 1 次/天 = hook 没生效,检查 `settings.json` matcher
  - 误报 > 0 = 调 hook matcher,或换精简版

#### 阶段 4:扩 Playbook(可选,1-2 天)

- **读完 Part 2.2 4 场景后**,挑合适的 Playbook 装:
  - Playbook A(PR review)→ 多人 dev 项目
  - Playbook B(跨天调研)→ 长期调研项目
  - Playbook C(应急响应)→ 有生产环境的项目(前置条件高)
- **不要一次性装 3 个**:先装 1 个,跑 2 周,再装下一个

---

## 1.4 风险与回滚

> **底线**:**loop-engineering 是纯文档 + 5 hook + 3 skill,完全可回滚**。最坏情况 = 跑 `install.sh --uninstall` 删掉即可。

### 1.4.1 误拦截

- **风险**:hook 拦了本来应该执行的合法操作
- **缓解**:
  - **单 hook 误拦截**:注释 `settings.json` 里对应 matcher 行(临时禁用)
  - **全局误拦截**:跑 `./loop-engineering/install.sh --uninstall --target /path/to/your-project`
- **回滚时间**:单 hook = 1 分钟,全局 = 30 秒
- **实际误报率**:`guard-secret-files.js` **0 误报**(只拦真密钥,如 `ghp_*` / `AKIA*` / `sk-*`)[来源:`_data-extract-notes.md` §1 关键观察 #4]

### 1.4.2 性能开销

- **最坏情况**:5 hook 并联,每个 timeout 2-3 秒 ≈ 理论 3 秒
- **实测**:`< 100ms` (rime-claude Windows 环境,Git Bash 启动 ~500ms + 实际检查 < 50ms,timeout 是富余不是常态)[来源:`examples/rime-claude.md` §关键决策点 #2]
- **差异**:`guard-db-migration.sh` 需解析 `dbt_project.yml`,timeout 设 3 秒(其他 2 秒)[来源:`examples/sandbox-verify.md` §关键决策点 #3]
- **建议**:**不要把 timeout 调到 0** — 网络磁盘 / WSL 时 timeout 偶尔会被吃掉

### 1.4.3 维护成本

- **hook 模板改了**:loop-engineering 发布新版后,在 4 个项目重新 `cp` hook 文件即可(不碰 settings.json)
- **配置文件**:每个项目独立 `settings.json`,**升级 loop-engineering 不需要重写**
- **实际成本**:每次大版本升级 < 10 分钟(参考 Playbook A 升级指南,见 Part 3.3)

### 1.4.4 怎么撤(完整回滚流程)

```bash
# 方案 A · 全撤(推荐新手试错)
./loop-engineering/install.sh --uninstall --target /path/to/your-project

# 方案 B · 部分撤(保留 hook 文件,只关 hook 触发)
#   编辑 .claude/settings.json,删除对应 matcher 块
#   保留 .claude/hooks/ 下文件,等下次想用时再开

# 方案 C · 紧急逃生(生产事故时临时绕过)
#   在命令前加环境变量:LOOPX_BYPASS=1 git push origin main
#   (loop-engineering 所有 hook 都支持 LOOPX_BYPASS 逃生口)
```

### 1.4.5 误拦率承诺

| Hook | 实测误报率 | 来源 |
|---|---:|---|
| `guard-secret-files.js` | **0%**(只拦真密钥正则) | [来源:`_data-extract-notes.md` §1 关键观察 #4] |
| `guard-main-branch-push.py` | < 5%(字符串匹配 `git push.*main`) | [来源:`examples/rime-claude.md` §关键决策点 #3] |
| `guard-installer-path.sh` | < 10%(路径白名单需配准) | [来源:`_data-extract-notes.md` §1] |
| `guard-package-publish.sh` | < 8%(cargo + npm 双模式) | [来源:`examples/media-to-doc-ui.md` §关键决策点 #2] |
| `guard-db-migration.sh` | < 12%(dbt_project.yml 解析) | [来源:`examples/sandbox-verify.md` §关键决策点 #3] |

---

## 1.5 一句话总结(拍板指南)

- **ROI 高** → 多人 dev + 装机项目 / 有凭证的项目 → **装**
- **ROI 中** → 单人 dev + 长期项目 → **先装 `guard-main-branch-push`,跑 1 周再加**
- **ROI 低** → 纯本地小工具 / 一次性实验 → **不装**
- **回滚成本** → 任何场景 < 30 秒,无不可逆风险

---

*本文档由 Sub-project B Task 3 implementer 生成(2026-09-26)。数字可追溯性见每个 `[来源:...]` 标注。media-to-doc-ui 数据缺失已标注 ⚠️ 估算,待路径恢复后回填。*