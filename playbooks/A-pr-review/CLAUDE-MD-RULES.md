# 项目级 CLAUDE.md 骨架 · Playbook A

> 这是 Playbook A 工头式 review 的"判断标准"。在目标项目根目录写 `CLAUDE.md`,AI reviewer 按此规范审 PR。

---

## 模板

```markdown
# 项目目标

<一句话写清楚这个项目做什么,谁用>

# 必读清单(按场景)

- 改 API:先读 docs/api-spec.md
- 加依赖:必须用 pnpm(不用 npm),加完跑 pnpm install
- 数据库 schema 变更:必走 alembic migration

# 代码风格

- TypeScript strict 模式,禁用 any
- Python:类型注解强制,函数 ≤ 30 行
- 提交信息:Conventional Commits(feat/fix/docs/...)

# 测试要求

- 新增/修改逻辑必须有对应测试
- 覆盖率不低于 80%
- 改完跑 `pnpm test` 全过

# 安全红线

- 绝不 commit `.env` / `*.pem` / `*.key`
- 绝不直推 main(走 PR + 至少 1 reviewer)
- 禁用 `git push --force`
- 禁用 `npm publish`(走 manual release 流程)

# AI reviewer 必查清单

- [ ] 有无新增密钥泄露
- [ ] 有无 SQL 注入风险
- [ ] 有无 hardcoded 凭证
- [ ] 有无删除迁移文件
- [ ] 有无跳过测试

# PR 模板

```markdown
## 改了啥
- <要点 1>
- <要点 2>

## 为什么改
<链接到 issue / 设计文档>

## 测试
- [ ] 单元测试加/改
- [ ] 集成测试通过
- [ ] 跑过 pnpm test 全过
```
```

---

## 说明

- **项目目标** 必填,AI reviewer 需要知道在审什么
- **必读清单** 是"强制入口",改了相关代码必须先看指定文件
- **代码风格** 写严格一点,AI reviewer 会按字面意思判断
- **测试要求** 量化(覆盖率数字),不然 AI 会放过边缘 case
- **安全红线** 是 hard block,任何违反直接 BLOCKING
- **AI reviewer 必查清单** 是"最小检查集",不够可以加,但别太多(LLM 注意力有限)
- **PR 模板** 让 PR 描述自带结构,reviewer 不用猜改了什么

---

## 实施

把上面的模板填好,放到目标仓库根目录的 `CLAUDE.md`。AI reviewer 在 PR review 时会读到这份规范作为判断基准。

---

## 参考

Playbook A 整体设计:`../README.md`
github action 模板:`./github-action.yml.template`
上层文档:本仓库根 `docs/ARCHITECTURE.md`