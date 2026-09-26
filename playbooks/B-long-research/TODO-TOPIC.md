<!-- TODO: 用户后补具体调研主题 -->

# Playbook B · 调研主题占位

**当前状态**:空文件,等用户提调研方向后填入。

## 用户需要决定的事

请在下方填一段(2-3 句话),讲清楚这次调研要回答什么问题:

```markdown
# 调研主题

<一段话讲清楚这次调研要回答什么问题 + 产出形式 + 读者>

# 调研对象

- <项目 1>:<一句话定位>
- <项目 2>:<一句话定位>
- <项目 3>:<一句话定位>(可选)

# 不调研(避免 scope creep)

- <明确排除>

# 期望产出

- <产出 1>:800 字内对比表
- <产出 2>:选型决策树
- <产出 3>:博文初稿 ≤ 8000 字
```

填好后,按 `LOOPX-CONNECT-CMD.md` 跑 `loopx connect` 启动调研。

---

## 示例主题(供参考,任选其一或自己提)

### 选项 1:LoopX 生态深度跟进
> 调研 LoopX 1.x 后期的 canary 部署模式 + 与 claude-mem 的边界划分,
> 给"已经在用 LoopX 的用户"一份升级指南。
> 读者:已在 LoopX 上跑项目的开发者

### 选项 2:auto-research 类工具 2026 演化
> 调研 auto-research / Dobby / Karpathy 提到的"auto research = objective + metric + boundaries + go"工具生态,
> 产出对比表。
> 读者:对"让 AI 自动做研究"感兴趣的产品经理 + 研究员

### 选项 3:Claude Code 控制面生态
> 横向对比 LoopX / claude-mem / beads / auto-research 四个 AI Agent 控制面项目,
> 给"想给项目接控制面"的开发者一份选型决策树。
> 读者:开发者、技术 lead

### 选项 4:用户自提
> 在下方填你自己的方向。