# LoopX connect 命令模板 · Playbook B

> 在调研项目根目录跑 `loopx connect` 把这次调研注册为 LoopX goal。

---

## 命令模板

```bash
loopx connect \
    --goal-id <GOAL-ID> \
    --objective "<调研目标,一句话>" \
    --domain "<调研领域,中文英文都行>" \
    --goal-doc "<本地调研文档路径>" \
    --adapter-kind claude-goal-mode \
    --harden
```

---

## 参数说明

| 参数 | 含义 | 示例 |
|---|---|---|
| `--goal-id` | 唯一 goal 标识,全大写短横线 | `GOAL-001`、`LOOPX-ECOSYSTEM-2026Q4` |
| `--objective` | 一句话调研目标(AI 永远记住) | "调研 LoopX 跟 claude-mem 的边界,产出对比表" |
| `--domain` | 领域标签(用于 grouping) | "AI Agent 控制面" |
| `--goal-doc` | 本地调研计划文档,绝对路径 | `/c/Users/<you>/research/loopx-ecosystem/goal.md` |
| `--adapter-kind` | 适配器类型 | `claude-goal-mode`(LoopX 官方 cc-haha 适配器) |
| `--harden` | 启用 PreToolUse 网关,自动拒绝超配额动作 | flag,无需参数 |

---

## goal-doc.md 模板

在 `--goal-doc` 指向的文件里写清调研计划:

```markdown
# 调研目标

<一段话讲清楚这次调研要回答什么问题、产出什么>

# 范围(Scope)

## 调研对象
- <项目 1>:<定位>
- <项目 2>:<定位>

## 不调研(Out of Scope)
- <明确排除的方向>

# 读者画像

- <谁会读这篇调研>
- <他们的痛点>

# 产出形式

- [ ] 调研笔记(每日 review-packet 累积)
- [ ] 对比表(横向 4-6 个项目)
- [ ] 选型建议(给读者)
- [ ] 风险提示(踩坑清单)

# 进度判据

- 一周内完成对比表初稿
- 两周内产出博文初稿
- 每周 5 篇 review-packet

# 禁区

- 不调研:与目标无关的项目(避免 scope creep)
- 不产出:超过 8000 字的报告(精简为主)
- 不接受:未经官方核实的 star / commit 数
```

---

## 实施示例(假设调研"AI Agent 控制面对比")

```bash
# 1. 准备目录
mkdir -p ~/research/agent-control-plane/{notes,evidence,review-packets}
cd ~/research/agent-control-plane

# 2. 写 goal-doc
cat > goal.md <<'EOF'
# 调研目标

横向对比 LoopX / claude-mem / auto-research / beads 四个 AI Agent 控制面项目,
回答"我应该选哪个?"的核心问题。

# 范围

## 调研对象
- LoopX(GitHub 6k⭐,Apache-2.0)
- claude-mem
- auto-research
- beads

## 不调研
- 大模型本身的对比
- 控制面之外的 Agent 工具

# 读者画像

- 想给项目接 AI Agent 控制面的开发者
- 想知道哪个项目 star 多、谁维护、社区活跃度

# 产出形式

- [ ] 4 项目对比表(功能 / 活跃度 / 学习成本)
- [ ] 选型决策树
- [ ] 风险提示
- [ ] 8000 字内博文初稿

# 禁区

- 不引用未经核实的 star 数
- 不写超过 8000 字
EOF

# 3. 跑 connect
loopx connect \
    --goal-id GOAL-001-AGENT-CONTROL-PLANE \
    --objective "对比 LoopX / claude-mem / auto-research / beads 四个 AI Agent 控制面项目,产出 8000 字选型博文" \
    --domain "AI Agent 控制面" \
    --goal-doc "$PWD/goal.md" \
    --adapter-kind claude-goal-mode \
    --harden

# 4. 验证
loopx status --goal-id GOAL-001-AGENT-CONTROL-PLANE
loopx doctor --deep  # 期望 9/9 required check 全 True
```

---

## 跑通后的日常

```bash
# 看今日 review-packet
cat .loopx/review-packets/$(date +%Y-%m-%d).md

# 看 quota
loopx quota should-run --goal-id GOAL-001-AGENT-CONTROL-PLANE

# 手动拍板
echo "decision: 继续对比 beads 的最新动态" > .loopx/decisions/$(date +%Y-%m-%d).md

# 终止
loopx disconnect --goal-id GOAL-001-AGENT-CONTROL-PLANE
```

---

## 参考

- LoopX 完整文档:`../../templates/skills/loopx-project/SKILL.md`
- Playbook B 总览:`./README.md`
- Sub-agent 配置:`./SUB-AGENT-CONFIG.yaml`