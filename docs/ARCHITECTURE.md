# Loop Engineering · 架构与数据流

> 5 道项目级 guard rails hook + 3 helper + LoopX 控制面的整体架构,以及它们如何协同实现 LoopX 5 原语。

---

## 一、整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│ Claude Code(cc-haha) 会话                                    │
│                                                             │
│  User Prompt ──┐                                            │
│                ▼                                            │
│        PreToolUse Hook ◀─────── 用户级 hook(bash-counter,    │
│           │    │    │    │    │   edit-file-path-gate,...)   │
│           │    │    │    │    │                              │
│           ▼    ▼    ▼    ▼    ▼                              │
│        ┌─────────────────────────────┐                      │
│        │  5 道项目级 guard rails      │                      │
│        │  ─────────────────────────   │                      │
│        │  1. guard-secret-files      │                      │
│        │  2. guard-main-branch-push  │                      │
│        │  3. guard-db-migration      │                      │
│        │  4. guard-package-publish   │                      │
│        │  5. guard-installer-path    │                      │
│        └────────────┬────────────────┘                      │
│                     │                                       │
│        ┌────────────┴────────────────┐                      │
│        ▼                             ▼                      │
│    exit 0 (允许)               exit 2 (拒绝 + 写日志)         │
│                                     │                       │
│                                     ▼                       │
│                          guard-event-writer.{py,sh}          │
│                                     │                       │
│                                     ▼                       │
│                  .loopx/guard-events-YYYY-MM-DD.jsonl        │
│                                     │                       │
│                                     ▼                       │
│                          LoopX 消费 JSONL                   │
│                          (review-packet / status /  趋势)     │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、5 个 hook 的拦截目标与触发条件

| # | Hook | 触发事件 | matcher | 拦截目标 | exit code |
|---|---|---|---|---|---|
| 1 | guard-secret-files.js | PreToolUse | Edit\|Write\|MultiEdit | `.env` / `*.pem` / `*.key` / `secrets/` / `credentials.*` | 2 |
| 2 | guard-main-branch-push.py | PreToolUse | Bash | `git push origin main\|master` / `git push -f` | 2 |
| 3 | guard-db-migration.sh | PreToolUse | Bash | `alembic upgrade` / `manage.py migrate` / `prisma migrate deploy` / `dft run tag:prod` | 2 |
| 4 | guard-package-publish.sh | PreToolUse | Bash | `npm publish` / `twine upload` / `cargo publish` / `vsce publish` / `gh release create` | 2 |
| 5 | guard-installer-path.sh | PreToolUse | Bash\|Edit\|Write | installer 写到 `target/release/dist/build/output` 之外 | 2 |

---

## 三、数据流:从拦截到证据

### 3.1 拦截发生时(同步)

```
cc-haha 检测到 PreToolUse 触发
    ↓
shell exec 对应 hook 脚本(同步)
    ↓
hook 检查 tool input:
    - 是危险操作 → exit 2,stderr 输出 reason
    - 是安全操作 → exit 0
    ↓
if exit 2:
    spawn guard-event-writer.{sh,py} 写 JSONL
    ↓
    .loopx/guard-events-2026-09-26.jsonl 新增一行:
    {
      "ts": "2026-09-26T15:01:38Z",
      "hook": "guard-secret-files",
      "tool": "Write",
      "input_summary": "file_path=.env.production",
      "reason": "secret file write blocked",
      "exit_code": 2,
      "cwd": "F:/soft/00selfmade/my-project",
      "project": "my-project"
    }
```

### 3.2 事后汇总(异步)

```
bash .claude/hooks/loopx-guard-summary.sh
    ↓
读 .loopx/guard-events-*.jsonl
    ↓
按 hook 维度 Counter 聚合
    ↓
输出 markdown 汇总:
  | hook | count | latest | reason |
  | guard-main-branch-push | 3 | 2026-09-26 14:23 | ... |
```

### 3.3 LoopX 消费(可选)

```
LoopX skill (loopx-guard-summary) 或 loopx review-packet
    ↓
读 .loopx/guard-events-*.jsonl
    ↓
拼到当日 review-packet 的"风险信号"section
```

---

## 四、与用户级 hook 的协作分工

| 层级 | hook 位置 | 拦截对象 | 示例 |
|---|---|---|---|
| **用户级 baseline** | `~/.claude/hooks/` | 通用危险命令 | `rm -rf` / `DROP DATABASE` / `format` |
| **项目级 guard** | `<project>/.claude/hooks/` | 项目特性危险操作 | 写 secret / 推 main / 安装包路径 |

**协作原则**:**用户级拦通用,项目级补项目细节**。两层不重叠,各管各的。

例:用户级 hook 拦 `rm -rf` 但不拦 `git push origin main`(太具体);项目级 hook 拦后者但不拦前者(太通用)。两层叠加 = 完整防护。

---

## 五、扩展点

### 5.1 新增 guard rails hook

1. 抄 `templates/hooks/guard-secret-files.js` 的结构
2. 改 matcher + 拦截逻辑(看 cc-haha 官方 hook schema)
3. 在 `templates/hooks/guard-rails-test.sh` 加 happy + block 两个 case
4. 更新 `templates/hooks/README.md` 的速览表
5. 跑 `bash templates/hooks/guard-rails-test.sh` 验证全 PASS

### 5.2 新增 skill

1. 在 `templates/skills/<name>/` 创建目录
2. 写 `SKILL.md`,frontmatter 含 `name` + `description`(description 必须含 "Use when...")
3. 在 `install.sh` 和 `install.ps1` 加 install 步骤
4. 更新 README.md §三

### 5.3 新增 Playbook

1. 在 `playbooks/` 新建子目录
2. `README.md` 写明:目标 / 叠法 / LoopX 5 原语对照表
3. 附配置文件模板(CLAUDE.md 规则 / Sub-agent config / LoopX connect 命令)
4. 更新 `playbooks/README.md` 的总览表

---

## 六、测试架构

### 6.1 单 hook 单测

`templates/hooks/guard-rails-test.sh`(229 行)对每个 hook 测两个 case:
- **happy path**:模拟安全操作,期望 `exit 0`
- **block path**:模拟危险操作,期望 `exit 2` 且 stderr 含 hook 名

### 6.2 端到端验证

```
1. 安装到目标项目
   pwsh -File install.ps1 -TargetProject 'C:\test-project'

2. 跑单测
   bash C:\test-project\.claude\hooks\guard-rails-test.sh

3. 跑 LoopX doctor
   cd C:\test-project
   loopx doctor --deep
   (期望 9/9 required check 全 True)

4. 验证 evidence 链路
   触发一次危险操作(例如尝试 git push origin main)
   检查 .loopx/guard-events-2026-09-26.jsonl 多了一行
```

---

## 七、安全考虑

### 7.1 helper 脚本不能失败硬

`guard-event-writer.{sh,py}` **必须 fail-soft**(exit 0 即使失败),原因:不能让 evidence 写入失败**反向**影响 hook 的拦截职责。

实现:`guard-event-writer.sh` 内部所有错误都 `2>/dev/null` 吞掉,最后 `exit 0`。

### 7.2 hook 脚本不能慢

每个 hook 同步执行,延迟超过 100ms 用户能感知。建议 < 50ms。

实现:hook 只做正则匹配 + 字符串判断,不调外部工具。

### 7.3 不要在 hook 里做权限决策

hook 只做"已知模式 → 拒绝",复杂判断交给 LoopX `should_run` 函数或人工拍板。**LLM 不能参与 hook 决策**。

---

## 八、引用

- Claude Code Hooks 官方文档:https://code.claude.com/docs/en/hooks
- LoopX 5 原语:https://github.com/loopx-project/loopx
- 本仓库 README:../README.md
- 铁律方案(单源引用):LOOP-ENGINEERING-RULES.md