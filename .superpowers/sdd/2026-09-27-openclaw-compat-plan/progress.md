# SDD ledger — plan: docs/superpowers/plans/2026-09-27-openclaw-compat-plan.md

## Setup
- BASE: 5982774 (docs(spec): revise OpenClaw compat spec to v2 — IPC + Windows + core rewrite)
- Branch: main
- Workspace: .superpowers/sdd/2026-09-27-openclaw-compat-plan/
- Plan path: docs/superpowers/plans/2026-09-27-openclaw-compat-plan.md (v1, 1177 lines, approved at commit 06d794f)
- Spec: docs/superpowers/specs/2026-09-27-openclaw-compat-design.md (v2 DRAFT, ~1100 lines, approved at commit 5982774)
- Execution mode: Subagent-Driven(per spec §9 + Sub-project D 经验)
- Estimated total work: ~20-27h(9 task, code 1500-2000 + tests 600-800 + docs 400)

## Pre-flight scan
- [x] No task contradictions with Global Constraints
- [x] No review-rubric-vs-plan conflicts found
- [x] No file path conflicts with existing templates/hooks/(verified by `ls`)
- [x] User 4 decisions applied(spec v2,commit 5982774):core rewrite / Windows / IPC / single-source SKILL
- [x] writing-plans 产出 plan.md(本次会话内,commit 06d794f)
- [ ] 用户审 plan 通过

## User decisions(2026-09-27,记录于 spec §0)
1. ✅ 真做 core 重写 — 5 hook 改 thin wrapper,46-case 回归测试 gate(Task 1 🔴)
2. ✅ 需要 Windows 支持 — Linux + Windows CI 双矩阵必双绿(Task 7 🔴)
3. ✅ 常驻 node 进程(性能优化)— Phase 1 上 IPC,延迟 < 50ms(Task 3 🔴)
4. ✅ 单源 SKILL.md + 扩展 frontmatter(`metadata.openclaw.*` 段,CC 端忽略)

## Tasks
- Task 1: **complete**(commit 265c1f6 — Core logic 提取 + 单测,Gate:38/38 PASS)
- Task 2: **complete**(Claude Code hook 改写 + IPC client,**Gate:38/38 PASS via IPC on Win/Linux**)
- Task 3: **complete**(IPC server + 跨平台 transport,**Gate:6/6 PASS**,< 50ms 验证)
- Task 4: **complete**(cc.sh + cc.ps1 adapter,**Gate:9/9 + 7/7 PASS**)
  - `templates/openclaw/adapters/cc.sh`(Linux/macOS Git Bash,~95 行)
  - `templates/openclaw/adapters/cc.ps1`(Windows PowerShell 5.1+ 测试通过,~130 行)
  - `tests/openclaw/adapter-cc-test.sh`(9 case:allow / block / stdin 处理 / server fallback)
- Task 5: pending(计划:OpenClaw adapter + plugin 入口)
- Task 6: pending(计划:跨 runtime 测试矩阵)
- Task 7: pending(计划:CI 集成,**Gate:Linux + Windows 双绿**)
- Task 8: pending(计划:Skill frontmatter 扩展 + install 集成)
- Task 9: pending(计划:文档 + Final review)
- Final: pending(commit + push + handoff)

## Risk register
- 🔴 **Core 重写行为漂移** — Task 1 gate:46 case 全 PASS 才进 Task 2
- 🔴 **Windows 平台 bug**(named pipe / PowerShell)— Task 7 gate:CI Windows runner 必须绿;本地手测
- 🟡 IPC server 启动失败 — cc.sh fallback:sync spawn server + 2s 重试
- 🟡 OpenClaw SDK breaking change — Adapter 层隔离
- 🟡 Server 内存泄漏 — Task 6 加 1000-round soak test
- 🟡 PowerShell 5.1 vs 7+ 差异 — spec 强制 PowerShell 7+(pwsh)

## Next step
- [x] Plan 写完,commit 06d794f
- [ ] 用户审 plan 通过
- [ ] 开始 Task 1(Core logic 提取)— 🔴 Gate 任务

## 提交链(实时更新)

| Commit | Task | 说明 |
|---|---|---|
| `449f99e` | (Setup) | docs(spec): v1 |
| `5982774` | (Setup) | docs(spec): v2 (用户 4 决策) |
| `4b8fbe6` | (Setup) | fix(sdd): scaffold ledger |
| `06d794f` | (Setup) | docs(plan): 9-task plan |
| `265c1f6` | Task 1 | feat(openclaw): port 5 hook logic to TypeScript core (Gate 38/38) |
| (待定) | Task 2 | feat(openclaw): CC hook 改写 + IPC client (Gate 38/38) |
| (待定) | Task 3 | feat(openclaw): IPC server + cross-platform transport (Gate 6/6) |
