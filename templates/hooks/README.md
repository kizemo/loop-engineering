# Project-Level Guard Rails · Hook 模板

> 5 个项目级 guard rails hook,部署到具体项目根目录使用。
> 与用户级 `~/.claude/hooks/` 下的全局 hook **互补不重叠**:
> - 用户级 = 全局生效,所有项目用同一套基线规则
> - 项目级 = 按项目特性细化(允许覆盖路径 / 允许的 main 分支 / 等等)

---

## 5 个 Hook 速览

| # | 文件 | 触发事件 | 拦截目标 | 默认规则来源 |
|---|---|---|---|---|
| 1 | `guard-secret-files.js` | PreToolUse: `Edit\|Write\|MultiEdit` | 写 `.env` / `*.pem` / `*.key` / `secrets/` / `credentials.*` / `*.sqlite3` 等 | 用户级 le-gatekeeper.js 只挡 Bash,这个补 Edit/Write 缺口 |
| 2 | `guard-main-branch-push.py` | PreToolUse: `Bash` | `git push origin main\|master` / `git push -f` | 用户级无,本 hook 全局补 |
| 3 | `guard-db-migration.sh` | PreToolUse: `Bash` | `alembic upgrade` / `manage.py migrate` / `prisma migrate deploy` / `dbt run tag:prod` | 销售 BI 平台用 |
| 4 | `guard-package-publish.sh` | PreToolUse: `Bash` | `npm publish` / `twine upload` / `cargo publish` / `vsce publish` / `gh release create` | 装机项目发 release 用 |
| 5 | `guard-installer-path.sh` | PreToolUse: `Bash\|Edit\|Write` | 把 `.exe`/`.msi`/`.dmg`/`.deb` 写到 `target/`/`release/`/`dist/`/`build/`/`output/` 之外 | rime / media-to-doc / cut-ad 装机项目用 |

---

## 部署流程

### 步骤 1 · 复制模板到项目

```bash
# 把需要的 hook 复制到目标项目
cp ~/.claude/hooks/templates/guard-secret-files.js \
   <project>/.claude/hooks/

# Windows 注意:用 Git Bash 或 PowerShell
cp ~/.claude/hooks/templates/guard-main-branch-push.py \
   <project>/.claude/hooks/

# 等等
```

### 步骤 2 · 添加执行权限

```bash
chmod +x <project>/.claude/hooks/guard-*.{js,py,sh}
```

### 步骤 3 · 在项目 `settings.json` 挂 matcher

每个项目根目录的 `.claude/settings.json` 加:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command",
            "command": "node .claude/hooks/guard-secret-files.js",
            "timeout": 2 }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command",
            "command": "python .claude/hooks/guard-main-branch-push.py",
            "timeout": 2 },
          { "type": "command",
            "command": "bash .claude/hooks/guard-db-migration.sh",
            "timeout": 3 },
          { "type": "command",
            "command": "bash .claude/hooks/guard-package-publish.sh",
            "timeout": 2 },
          { "type": "command",
            "command": "bash .claude/hooks/guard-installer-path.sh",
            "timeout": 2 }
        ]
      }
    ]
  }
}
```

> **注意**:`guard-installer-path.sh` 需要挂两个 matcher(Edit|Write|MultiEdit **和** Bash),
> 因为二进制可能通过 `bash -c "curl ... > installer.exe"` 写入。

### 步骤 4 · (可选) 项目级配置覆盖

在 `<project>/.claude/guard-rails.yaml` 添加项目特定规则:

```yaml
# 销售 BI 平台项目示例
secrets_extra_patterns:
  - "infra/grafana-secrets/"
  - "deploy/prod-keys/\\.pem$"

allowed_main_branches:
  - main
  - release/*

installer_allow_paths:
  - target/release/bundle/
  - release/
```

---

## 单元测试

`guard-rails-test.sh` 在本目录,可独立测试 5 个 hook:

```bash
bash ~/.claude/hooks/templates/guard-rails-test.sh
```

每个 hook 测试:
- **Happy path**(合法命令/路径) → exit 0
- **Block path**(危险命令/路径) → exit 2 + stderr 含 hook 名

---

## 与用户级 hook 的协作

| 场景 | 用户级 hook | 项目级 hook | 谁先执行? |
|---|---|---|---|
| `rm -rf /tmp/foo` | le-gatekeeper.js 拦 | — | 用户级 |
| `Edit .env` 写文件 | 无 | guard-secret-files.js 拦 | 项目级 |
| `git push origin main` | 无 | guard-main-branch-push.py 拦 | 项目级 |
| `Bash: echo "" > installer.exe` | 无 | guard-installer-path.sh 拦 | 项目级 |
| `Bash: alembic upgrade head` | 无 | guard-db-migration.sh 拦 | 项目级 |

PreToolUse 多 hook 链:**任一 exit 2 即阻止工具调用**,Claude Code 会显示 stderr 给用户,
用户可显式批准后重试。

---

## 维护说明

- 修改默认规则:**直接修改本目录的模板文件**(因为 5 个项目都从这里复制)
- 升级流程:模板改了 → 4 个项目重新 `cp` 覆盖 → `chmod +x` 即可
- 紧急豁免:临时编辑 `<project>/.claude/settings.json` 注释对应 matcher
- 不再需要某 hook:删除 `<project>/.claude/hooks/guard-xxx` + `settings.json` 对应条目
