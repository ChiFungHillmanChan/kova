# Kova 协议 — 完整指南

<p align="center">
  <img src="../../assets/kova-hero.png" alt="Kova — 自主工程协议" width="100%" />
</p>

> 安装到**任何项目**中，将 Claude Code 从"你问它答的 AI"变成"自动开发、自动测试、自动修复的工程团队"。

---

## 目录

- [Kova 是什么？](#kova-是什么)
- [安装](#安装)
- [四个 Hooks（自动触发）](#四个-hooks自动触发)
  - [Hook 1：自动格式化](#hook-1formatsh--自动格式化)
  - [Hook 2：快速停止闸门](#hook-2verify-on-stopsh--快速停止闸门)
  - [Hook 3：拦截危险指令](#hook-3block-dangeroussh--拦截危险指令)
  - [Hook 4：保护敏感文件](#hook-4protect-filessh--保护敏感文件)
- [CLAUDE.md — 文化文件](#claudemd--文化文件)
- [斜杠命令](#斜杠命令slash-commands)
- [Team Loop — 王牌功能](#team-loop--王牌功能)
  - [PRD 格式](#prd-格式)
  - [Phase 0：Clarify（澄清）](#phase-0clarify澄清)
  - [Phase 1：Plan（规划）](#phase-1plan规划)
  - [Phase 2：Implement（实现）](#phase-2implement实现)
  - [Phase 3：Verify（验证）](#phase-3verify验证)
  - [Phase 4：Review（多模型审查）](#phase-4review多模型审查)
  - [Phase 5：Commit（提交）](#phase-5commit提交)
  - [Loop 控制机制](#loop-控制机制)
- [安装 Codex（可选）](#安装-codex可选)
- [日常工作流程](#日常工作流程)
- [支持的语言](#支持的语言)
- [总结](#总结)

---

## Kova 是什么？

Kova 是一套"规则 + 脚本 + 命令"的组合包。你安装到任何一个项目里，Claude Code 就会从一个"你问它答"的 AI 助手，变成一个"自动开发、自动测试、自动修复"的工程团队。

**简单说：安装了 Kova 之后，Claude 不再问你"我该不该这样做？"，它直接做，做完自己检查，检查不过自己再改。**

---

## 安装

### 方法 A：Claude Code 插件（推荐）

```bash
claude /install kova          # 轻量版：命令 + 技能
claude /install kova-full     # 完整版：命令 + 技能 + hooks + 执行保障
```

不需要 clone，不需要运行脚本，安装后立即可用。

| 插件 | 包含内容 |
|------|----------|
| **kova** | 斜杠命令 + 工程协议技能 |
| **kova-full** | kova 全部内容 + 安全 hooks、验证闸门、自动格式化、commit 闸门、Team Loop |

### 方法 B：传统安装（clone + install.sh）

```bash
# Clone Kova
git clone https://github.com/ChiFungHillmanChan/kova.git ~/kova

# 进入你的项目
cd /path/to/your/project

# 先预览将会安装什么
bash ~/kova/install.sh --dry-run

# 把 Kova 安装到这个项目
bash ~/kova/install.sh

# 可选：安装全局 CLI
bash ~/kova/install.sh --global

# 为这个项目启用 hooks
kova activate

# 检查安装状态
kova status
```

安装器会做以下事情：
1. 在你的项目中创建 `.claude/` 目录结构
2. 复制所有 hooks（自动触发的脚本）
3. 复制所有 slash commands（你输入 `/plan`、`/verify-app` 这些命令）
4. 复制 `CLAUDE.md`（规矩文件，教 Claude 怎么做事）
5. 将所有 `.sh` 文件设置为可执行

**需要安装的东西：**
- `jq`（必需）— `brew install jq`（macOS）/ `apt install jq`（Linux）
- `gh`（可选）— 用来开 Pull Request
- `codex`（可选）— 用来做跨模型审查，下面会详细讲

---

## 四个 Hooks（自动触发）

<p align="center">
  <img src="../../assets/kova-safety.png" alt="Kova 7 层验证架构" width="100%" />
</p>

Hooks 是"自动运行的脚本"。你不需要输入任何命令，它们会在特定时刻自动执行。

### Hook 1：`format.sh` — 自动格式化

**什么时候运行？** 每次 Claude 写完或改完任何一个文件之后。

**做什么？** 自动帮你格式化代码。

它会自动检测你用什么语言：
- JavaScript / TypeScript → 用 Prettier
- Python → 用 Ruff 或者 Black
- Go → 用 gofmt
- Rust → 用 rustfmt
- Ruby → 用 RuboCop
- Java → 用 google-java-format
- .NET → 用 dotnet format

**也就是说：** Claude 写完 code，代码自动变得漂亮，不需要你手动 format。

---

### Hook 2：`verify-on-stop.sh` — 快速停止闸门

**什么时候运行？** 每次 Claude 说"我做完了"想停下来的时候。

**做什么？** 运行快速检查：**只跑 lint + typecheck**（第 5-6 层）。如果任何一个失败，Claude **会被拦住不让停**，得继续修。这样保持停止时的速度，同时捕捉到最常见的问题。

**第 5 层：Lint（代码规范检查）**
- 检查你的代码有没有违反规范。
- ESLint、ruff、flake8、golangci-lint、clippy、rubocop……自动检测。
- 有 lint 错误 → **阻止**

**第 6 层：Type Check（类型检查）**
- TypeScript → `tsc --noEmit`
- Python → `mypy` 或者 `pyright`
- Go → `go vet`
- Rust → `cargo check`
- 有类型错误 → **阻止**

**也就是说：** Claude 做完了，想停下来，但它得过 lint 和 typecheck 才能停。如果任何一个失败，它得自己修到通过为止。

**如果 3 次都修不好：** 自动写一个 `DEBUG_LOG.md` 记录问题，然后自动开一个全新的 Claude session 去尝试修复（self-healing）。如果新 session 也修不好，才真正停下来等人类处理。

#### 完整 7 层验证（Team Loop）

完整的 7 层验证是在 **Team Loop**（`/kova:loop`）里通过 `verify-gate.sh` 运行的，不是每次停都跑。包括：

1. **Build** — 编译你的项目（npm run build、go build、cargo build 等）
2. **Unit Tests** — 运行所有 unit test，失败会 retry 一次
3. **Integration Tests** — 只有配置了 `test:integration` 才会运行
4. **E2E Tests** — 只有安装了 Playwright 才会运行
5. **Lint** — 和停止闸门一样
6. **Type Check** — 和停止闸门一样
7. **Security Audit** — 仅警告，不会阻止

---

### Hook 3：`block-dangerous.sh` — 拦截危险指令

**什么时候运行？** 每次 Claude 想执行 bash 命令之前。

**做什么？** 检查它想执行的命令是不是危险的。如果是，直接阻止。

会拦截的命令包括：
- `rm -rf /` — 删除整个系统
- `rm -rf ~` — 删除整个 home 目录
- `git push --force` — 强制推送（会覆盖别人的代码）
- `DROP TABLE` / `DROP DATABASE` — 删除数据库表
- Fork bomb — 会让电脑死机的命令
- 直接操作 `/dev/` 设备

**也就是说：** Claude 就算"发疯"也不会搞坏你的系统。

---

### Hook 4：`protect-files.sh` — 保护敏感文件

**什么时候运行？** 每次 Claude 想写入或修改文件之前。

**做什么？** 拦截对敏感文件的修改。

会保护的文件包括：

**Env 文件**（basename 精确匹配 — `some.environment.ts` 不会被拦截）：
- `.env`、`.env.local`、`.env.development`、`.env.test`、`.env.staging`、`.env.production`、`.env.prod`

**敏感路径**（路径子字符串匹配）：
- `.pem`、`.key` — 加密密钥
- `id_rsa` — SSH 私钥
- `secrets/` 目录
- `credentials/` 目录
- `serviceAccountKey.json`、`firebase-adminsdk` — 云服务凭证

**也就是说：** Claude 不会不小心改到你的密码和 API key。

---

## CLAUDE.md — 文化文件

这个文件是教 Claude"怎么做事"的规矩。安装后 Claude 会自动读它。

### 核心规则

**Claude 不需要问你就可以自己做的事情：**
- 选哪个实现方式更好 → 直接选，写个 comment 解释为什么
- 写 test → 永远都写，不需要问
- 文件/文件夹命名 → 跟着项目现有的惯例
- 修 bug 时顺手做小型重构 → 直接做，最后提一句就行
- 给没有 type 的代码加 type → 直接加
- 修 lint / format 错误 → 直接修
- 跑 test / build / type check → 永远都跑，不需要问

**Claude 必须问你才能做的事情：**
- 删除 production 数据或者数据库表
- 改 `.env` / secrets / credentials
- 影响超过 3 个主要系统的架构改动
- 部署到 production
- 同一个任务失败了 3 次以上

### Assumption Protocol（假设协议）

当需求不清楚的时候，Claude **不会停下来问你**。它会：
1. 做一个最合理的假设
2. 写一个 comment：`// ASSUMPTION: [假设内容]`
3. 继续做
4. 最后告诉你它做了什么假设

**也就是说：** Claude 不会不停地问你"你想怎样？""我该不该这样做？"它会自己判断，做完再说。

---

## 斜杠命令（Slash Commands）

### `/plan [feature]` — 先规划，再做事

你说：`/plan 加一个登录功能`

Claude 会：
1. 探索你整个 codebase，看有什么相关文件
2. 写一个计划出来
3. **等你批准**才开始写代码

你看完计划，输入 `go`，它就开始自动实现。

### `/verify-app` — 完整 QA 检查（10 层）

比自动的 7 层更严格。额外多 3 层：

- 第 1-4 层：Build + Unit + Integration + E2E（和自动的一样）
- **第 5 层：浏览器检查** — 用 Chrome 打开你的 app，看有没有 console 错误、页面坏了没有
- **第 6 层：无障碍检查** — alt text、label、heading 层级、键盘导航
- **第 7 层：性能检查** — 加载时间、bundle 大小
- 第 8-10 层：Lint + Type check + Security / Code review

**这是你开 PR 或者部署之前跑的"终极验收"。**

### `/commit-push-pr` — 自动 commit + push + 开 PR

Claude 会自动：
1. `git add` 相关文件
2. 写一个 Conventional Commit 格式的 message（`feat:`、`fix:`、`refactor:` 等）
3. `git push`
4. 用 `gh` 开一个 Draft PR

你什么都不需要做。

### `/fix-and-verify` — 自动修 bug

Claude 会：
1. 分析错误
2. 尝试修复
3. 跑测试
4. 如果测试还失败 → 再分析、再修、再跑
5. 循环直到全部通过
6. 如果修了 3 次都修不好 → 才停下来问你

**你说"有 bug"，它自己搞到没 bug 为止。**

### `/code-review` — 多 Agent 代码审查

Claude 会同时开 4 个独立的 reviewer：

1. **Code Quality Reviewer** — 检查代码质量、架构、DRY、命名、文件长度（300 行限制）
2. **Security Reviewer** — 检查 OWASP Top 10 安全问题：注入攻击、XSS、认证绕过……
3. **Test Coverage Reviewer** — 检查测试覆盖率，哪些 case 没有 test，然后直接写
4. **UX Reviewer**（只限 UI 相关改动）— 检查无障碍、响应式、交互、加载/错误/空状态

这 4 个 reviewer 是**并行运行**的（同一时间开），不是一个一个等。

### `/simplify` — 简化代码

不改变行为，只是清理：
- 删除死代码
- 改善命名
- 简化结构

### `/daily-standup` — 每日报告

显示：今天做了什么、有什么阻塞、下一步做什么、速度如何。

---

## Team Loop — 王牌功能

<p align="center">
  <img src="../../assets/kova-workflow.png" alt="Kova Team Loop — 6 阶段工作流程" width="100%" />
</p>

这是 Kova 最强大的功能。你写一个 PRD（Product Requirements Document，就是一个待办清单），然后输入：

```
/kova:loop docs/my-prd.md
```

Claude 就会**自动逐项实现**你的 PRD，每一项都经过 6 个阶段。

### PRD 格式

就是一个 Markdown 文件，里面有 checkbox：

```markdown
# My Feature PRD
- [ ] 加一个登录页面
- [ ] 加密码重置功能
- [ ] 加 Google OAuth 登录
- [x] 设计数据库 schema（已完成）
```

`- [ ]` 是未做的，`- [x]` 是已完成的。

---

### Phase 0：Clarify（澄清）

Claude 读你写的项目，比如"加一个登录页面"。

它会问自己：
- 这个需求清不清楚？
- 有没有模糊的地方？

**但它不会问你。** 它会自己做假设，然后写到 `.kova-loop/plans/item-N-clarify.md`。

比如它可能写：
```
ASSUMPTION: 登录页面用 email + password，不需要 username。
ASSUMPTION: 失败时显示 toast notification。
```

---

### Phase 1：Plan（规划）

如果项目不是很简单（比如"改个 typo"就不需要规划），Claude 会：

1. 用 `superpowers:brainstorming` skill 想 2-3 个方案
2. 选最好的一个
3. 开一个 Explore agent 扫描整个 codebase，找出相关的文件和 pattern
4. 写一个详细计划到 `.kova-loop/plans/item-N-plan.md`

计划会写到 `file:function` 级别的具体步骤：
```
1. 创建 src/pages/Login.tsx — 登录表单组件
2. 创建 src/api/auth.ts — login() 函数，调用 POST /api/auth/login
3. 修改 src/routes.tsx — 添加 /login 路由
4. 创建 src/pages/__tests__/Login.test.tsx — 测试
```

---

### Phase 2：Implement（实现）

Claude 按照计划一步一步写代码。

它会：
1. 加载 `production-code-standards` skill（确保写出 production 级别的代码）
2. 如果是 UI 相关的项目，额外加载 `ui-ux-pro-max` skill
3. 逐步执行计划
4. 写测试：happy path（正常情况）、edge case（边界情况）、error case（错误情况）
5. 记录改了哪些文件

**这个阶段有 3 种模式：**
- `implement` — 正常的全新实现
- `fix-verify` — 上一次 verify（第 3 阶段）失败了，只针对那些具体错误去修
- `fix-review` — 上一次 review（第 4 阶段）找到 HIGH 级别问题，只针对那些问题去修

---

### Phase 3：Verify（验证）

通过 `verify-gate.sh` 运行完整 7 层验证：

1. Build
2. Unit tests（失败会 retry 一次）
3. Integration tests（有才跑）
4. E2E tests（有 Playwright 才跑）
5. Lint
6. Type check
7. Security audit（仅警告）

**如果 1-6 全部通过：** 进入 Phase 4（review）。

**如果任何一层失败：**
- 将所有错误写入 `.kova-loop/current-failures.md`，包含 file:line 的具体位置
- 设置 mode 为 `fix-verify`
- 返回 Phase 2，只修那些具体错误
- 再跑一次 Phase 3

这个 fix → verify → fix → verify 的循环会一直跑，直到通过或者试了 5 次（max_fix_attempts）。

如果 5 次都搞不定 → 标记为 STUCK，写入 `STUCK_ITEMS.md`，跳过这个项目，继续下一个。

---

### Phase 4：Review（多模型审查）

这个阶段有两部分：**Claude 多 agent 审查** 和 **Codex 跨模型审查**。

#### 第一部分：Claude 多 Agent 审查

Claude 会同时开最多 4 个独立的 reviewer agent：

**Reviewer 1 — Code Quality：**
- 检查代码质量
- 有没有违反 DRY（Don't Repeat Yourself）
- Pattern 一不一致
- Error handling 好不好
- Edge case 有没有处理
- 命名好不好
- 文件有没有超过 300 行

**Reviewer 2 — Security：**
- 检查 OWASP Top 10 安全问题
- SQL injection、XSS、CSRF
- 有没有 hardcode secret
- 认证/授权有没有漏洞
- Input validation、output encoding

**Reviewer 3 — Test Coverage：**
- 检查哪些代码路径没有测试
- 测试质量好不好（有没有真正 assert 有意义的东西）
- **这个 reviewer 会直接写测试**（其他 reviewer 不能改文件）

**Reviewer 4 — UX（只限 UI 项目）：**
- 无障碍（accessibility）
- 响应式设计（responsive）
- 交互 pattern
- Loading state、error state、empty state

这 4 个 agent 是**并行运行**的。Claude 会在一个 message 里面开完 4 个 Task，同时跑，不需要等。

#### 第二部分：Codex 跨模型审查（可选）

这是新加的功能。

Claude 会先检查你有没有安装 OpenAI 的 Codex CLI：

```bash
command -v codex &>/dev/null
```

**如果没有安装：** 静默跳过，什么都不说。一切照常。

**如果安装了：** Claude 会：

1. 用 `git diff` 获取所有改动
2. 准备一个 prompt，里面包括：
   - 这个 PRD 项目是什么（"加一个登录页面"）
   - 做了什么改动（summary）
   - 预期结果是什么
   - 改了哪些文件
   - 完整的 diff
3. 将这个 prompt 发送给 Codex（也就是 OpenAI 的模型）
4. Codex 会用它自己的"大脑"去审查你的代码
5. Claude 收到 Codex 的回复，解析出 findings

**为什么要这样做？**

因为 Claude 的 4 个 reviewer agent 全部都是 Claude 模型。它们有**相同的盲点**。

用一个完全不同的模型（Codex / GPT）去看同一份代码，可以找到 Claude 看不到的问题。反过来也一样 — Claude 可以找到 Codex 看不到的问题。

这就是"多模型审查"的优势。就像你找两家不同的会计师事务所去审计同一本账一样。

**如果 Codex 出错、超时、或者没有输出：** 写一个 warning，继续。Codex 审查是 non-blocking 的，不会因为 Codex 有问题而让整个 loop 停下来。

#### 合并结果

所有 findings（4 个 Claude agent + Codex）会合并成一个列表，按严重程度分类：

- **HIGH**（严重）— **阻止！** 要回去修复
- **MEDIUM**（中等）— 记录下来，不阻止
- **LOW**（轻微）— 记录下来，不阻止

写入 `.kova-loop/current-review.md`，格式：
```
- [src/api/auth.ts:42] [security] — SQL injection: user input directly in query
- [src/pages/Login.tsx:15] [codex] — Missing error boundary for async state
```

**如果有任何 HIGH finding：** 进入 `fix-review` 模式，返回 Phase 2 修复。
**如果没有 HIGH finding：** 通过！去 Phase 5。

---

### Phase 5：Commit（提交）

Claude 会：
1. `git add` 所有改动的文件
2. 写一个 Conventional Commit message，比如：
   ```
   feat(auth): add login page with email/password

   Kova Team Loop — Item 1/3
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
3. `git commit`
4. 记录 commit hash

然后设置下一个项目，重新开始 Phase 0。

---

### Loop 控制机制

**进度追踪：**
每次 iteration 之后，Claude 会更新：
- `.kova-loop/LOOP_PROGRESS.md` — 哪些项目完成了、哪个正在做
- `.kova-loop/ITERATION_LOG.md` — 每次 iteration 的详细记录

**STUCK 检测：**
如果同一个项目修了 5 次（默认）都修不好，Claude 会：
- 标记为 STUCK
- 写入 `.kova-loop/STUCK_ITEMS.md`
- 跳过，继续下一个

**可恢复：**
如果你中途停了（断线、手动取消等），`.kova-loop/` 里面保存了所有进度。下次再运行 `/kova:loop docs/my-prd.md`，它会问你：`resume`（继续）/ `restart`（重新开始）/ `cancel`（取消）。

**预览模式：**
```
/kova:loop docs/my-prd.md --dry-run
```
只显示计划，不会真正开始执行。

**其他参数：**
- `--no-commit` — 做完不 commit
- `--max-iterations 40` — 最多跑 40 次 iteration（默认 20）
- `--max-fix-attempts 10` — 每个项目最多试 10 次修复（默认 5）

---

## 安装 Codex（可选）

```bash
npm install -g @openai/codex
codex login
```

如果没有安装、没有登录、或者没有 OpenAI 账号，跨模型审查会自动跳过。其他所有功能正常运行。

---

## 日常工作流程

```
早上：
  /daily-standup              <- 30 秒看完项目状态

做新功能：
  /plan 加一个登录页面        <- 先规划，你批准后才做
  -> "go"                     <- Claude 自动实现
  /verify-app                 <- QA 检查（或者 Claude 停的时候自动跑）
  /commit-push-pr             <- 自动 commit + push + 开 PR

发现 bug：
  /fix-and-verify             <- Claude 自己修到没 bug 为止

合并之前：
  /code-review                <- 多 agent 审查（+ Codex 跨模型审查）
  /simplify                   <- 清理代码

做大型功能（多个项目）：
  /kova:loop docs/prd.md      <- 自动逐项实现，每项过 6 个阶段

下班：
  /daily-standup              <- 看今天做了什么
```

---

## 支持的语言

| 语言 | 构建 | 测试 | Lint | 类型检查 | 格式化 | 安全审计 |
|------|------|------|------|----------|--------|----------|
| JS/TS | 是 | vitest, jest | eslint | tsc | prettier | npm/pnpm/yarn audit |
| Python | - | pytest | ruff, flake8 | mypy, pyright | ruff, black | pip-audit |
| Go | go build | go test | golangci-lint | go vet | gofmt | govulncheck |
| Rust | cargo build | cargo test | cargo clippy | cargo check | rustfmt | cargo audit |
| Ruby | - | rspec | rubocop | - | rubocop -a | bundle-audit |
| Java | mvn/gradle | mvn/gradle test | - | - | google-java-format | - |
| .NET | dotnet build | dotnet test | dotnet format | dotnet build | dotnet format | - |

自动检测基于锁文件和配置文件（package.json、go.mod、Cargo.toml 等）。

---

## 总结

<p align="center">
  <img src="../../assets/kova-comparison.png" alt="没有 Kova vs 有 Kova" width="100%" />
</p>

| 方面 | 没有 Kova | 有 Kova |
|------|-----------|---------|
| 格式化 | 你自己 format | 自动 format |
| 测试 | Claude 可能跳过 | 自动跑，失败了自动修 |
| 安全 | Claude 可能 `rm -rf` | 危险指令全部拦截 |
| 密码保护 | Claude 可能改到 .env | 敏感文件全部保护 |
| 审查 | 你自己看代码 | 4 个 Claude agent + Codex 并行审查 |
| 工作模式 | 你问它答 | 它自己做，做完再说 |
| 失败处理 | 报个错误就停 | 自动修，修不好才停 |

**Kova 的哲学："你不是信任它会做对的事，你是建立一个系统让做错的事变得困难。"**

---

## 当前的保证和限制

**Hooks 启用时保证的事情：**
- 每次停都会跑 lint + typecheck（快速停止闸门）
- 每次写文件都会检查保护名单
- 每次执行 bash 都会检查危险指令
- Team Loop 通过 bash 运行完整 7 层验证 — Claude 不能跳过

**Hooks 不保证的事情：**
- 用户可以停用 hooks（`kova deactivate` 或者改 settings.json）
- 停止闸门只跑 lint + typecheck — build、test、security 只在 Team Loop 里运行
- 文件保护用 pattern matching，不是 OS 层面的权限
- Hooks 需要安装 `jq`；没有安装的话它们会静默退出
