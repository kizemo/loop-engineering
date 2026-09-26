# 全局 CLAUDE.md · Loop Engineering 部分抽离

> 本文件是**项目级精简版**,从全局 `~/.claude/CLAUDE.md` 抽出"loop engineering 铁律(单一源引用)"一节。
> 完整版本请看用户全局 CLAUDE.md(由 Claude Code 自动加载)。

---

## Loop Engineering 铁律(单一源引用)

完整 L1-L5 闭环规则、12 条铁律、Skill 模板、hooks 骨架见:

[`LOOP-ENGINEERING-RULES.md`](LOOP-ENGINEERING-RULES.md)

**单一源原则**: 通用规则(任务编排 / 执行 / 审核 / 沉淀 / 进化 五层闭环)全部走该文档,本文件只保留与具体行为耦合的红线(沟通语言 / 代码风格 / 安全红线 / 会话健康 / 接力纪律)。**避免规则双向维护漂移**。

**何时读铁律方案**:
- 接复杂任务(≥3 步)前,先读该文档建立 L1-L5 心智模型
- 建新 Skill 时,套用其 § 3.2 含「已知陷阱」章节的模板
- 配新项目 hooks 时,套用其 § 3.3 的 hooks 骨架(L2 Stop 检查 task.md、L3 PostToolUse 检查 task.md 进度)

**与本文件的衔接**:
- § "新会话开局守则"(会话级纪律)= 铁律 L5 编排层在本文件的具体化
- § "会话健康"(jsonl / bash / API 错误红线)= 铁律 L1 执行层的健康监测
- § "防丢失工程实践" + § "开新会话交接"= 铁律 L3 沉淀层在本文件的具体化
- 安全红线 + sandbox-verify = 铁律 L2 审核层在本文件的具体化

---

## 注

本文件**只用于提示铁律方案的存在**,不复制任何具体规则。具体规则版本同步以 `LOOP-ENGINEERING-RULES.md` 为准。

如果本文件与 `LOOP-ENGINEERING-RULES.md` 出现不一致,**以铁律方案为准**(它是单一源)。