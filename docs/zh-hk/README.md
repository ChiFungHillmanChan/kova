# Kova 協議 — 完整指南

<p align="center">
  <img src="../../assets/kova-hero.png" alt="Kova — 自主工程協議" width="100%" />
</p>

> 裝落去**任何 project**，將 Claude Code 由「你問佢答嘅 AI」變成「自動做嘢、自動測試、自動改錯嘅工程團隊」。

---

## 目錄

- [Kova 係乜嘢？](#kova-係乜嘢)
- [安裝](#安裝)
- [四個 Hooks（自動觸發）](#四個-hooks自動觸發)
  - [Hook 1：自動格式化](#hook-1formatsh--自動格式化)
  - [Hook 2：快速停止閘門](#hook-2verify-on-stopsh--快速停止閘門)
  - [Hook 3：攔截危險指令](#hook-3block-dangeroussh--攔截危險指令)
  - [Hook 4：保護敏感檔案](#hook-4protect-filessh--保護敏感檔案)
- [CLAUDE.md — 文化文件](#claudemd--文化文件)
- [斜線指令](#斜線指令slash-commands)
- [Team Loop — 皇牌功能](#team-loop--皇牌功能)
  - [PRD 格式](#prd-格式)
  - [Phase 0：Clarify（澄清）](#phase-0clarify澄清)
  - [Phase 1：Plan（計劃）](#phase-1plan計劃)
  - [Phase 2：Implement（實現）](#phase-2implement實現)
  - [Phase 3：Verify（驗證）](#phase-3verify驗證)
  - [Phase 4：Review（多模型審查）](#phase-4review多模型審查)
  - [Phase 5：Commit（提交）](#phase-5commit提交)
  - [Loop 控制機制](#loop-控制機制)
- [安裝 Codex（可選）](#安裝-codex可選)
- [日常工作流程](#日常工作流程)
- [支援嘅語言](#支援嘅語言)
- [總結](#總結)

---

## Kova 係乜嘢？

Kova 係一套「規則 + 腳本 + 指令」嘅組合包。你裝落去任何一個 project 入面，Claude Code 就會由一個「你問佢答」嘅 AI 助手，變成一個「自動做嘢、自動測試、自動改錯」嘅工程團隊。

**簡單講：裝咗 Kova 之後，Claude 唔再問你「我應唔應該咁做？」，佢直接做，做完自己檢查，檢查唔過自己再改。**

---

## 安裝

### 方法 A：Claude Code Plugin（推薦）

```bash
claude /install kova          # 輕量版：指令 + 技能
claude /install kova-full     # 完整版：指令 + 技能 + hooks + 執行保障
```

唔使 clone，唔使跑腳本，裝完即刻用得。

| Plugin | 包含咩 |
|--------|--------|
| **kova** | 斜線指令 + 工程協議技能 |
| **kova-full** | kova 所有嘢 + 安全 hooks、驗證閘門、自動格式化、commit 閘門、Team Loop |

### 方法 B：傳統安裝（clone + install.sh）

```bash
# Clone Kova
git clone https://github.com/ChiFungHillmanChan/kova.git ~/kova

# 入去你個 project
cd /path/to/your/project

# 先睇下會安裝啲乜
bash ~/kova/install.sh --dry-run

# 安裝 Kova 入呢個 project
bash ~/kova/install.sh

# 可選：安裝 global CLI
bash ~/kova/install.sh --global

# 為呢個 project 啟用 hooks
kova activate

# 檢查安裝狀態
kova status
```

安裝器會做以下嘢：
1. 喺你個 project 入面建立 `.claude/` 資料夾結構
2. 複製所有 hooks（自動觸發嘅腳本）
3. 複製所有 slash commands（你打 `/plan`、`/verify-app` 呢啲指令）
4. 複製 `CLAUDE.md`（規矩文件，教 Claude 點做人）
5. 將所有 `.sh` 檔案設定為可執行

**需要裝嘅嘢：**
- `jq`（必須）— `brew install jq`（macOS）/ `apt install jq`（Linux）
- `gh`（可選）— 用嚟開 Pull Request
- `codex`（可選）— 用嚟做跨模型審查，下面會詳細講

---

## 四個 Hooks（自動觸發）

<p align="center">
  <img src="../../assets/kova-safety.png" alt="Kova 7 層驗證架構" width="100%" />
</p>

Hooks 係「自動跑嘅腳本」。你唔使打任何指令，佢哋會喺特定時刻自動執行。

### Hook 1：`format.sh` — 自動格式化

**幾時跑？** 每次 Claude 寫完或改完任何一個檔案之後。

**做咩？** 自動幫你 format 個代碼。

佢會自動偵測你用咩語言：
- JavaScript / TypeScript → 用 Prettier
- Python → 用 Ruff 或者 Black
- Go → 用 gofmt
- Rust → 用 rustfmt
- Ruby → 用 RuboCop
- Java → 用 google-java-format
- .NET → 用 dotnet format

**即係話：** Claude 寫完 code，個 code 自動靚仔，唔使你手動 format。

---

### Hook 2：`verify-on-stop.sh` — 快速停止閘門

**幾時跑？** 每次 Claude 話「我做完啦」想停低嘅時候。

**做咩？** 跑快速檢查：**只跑 lint + typecheck**（第 5-6 層）。如果任何一個 fail，Claude **會被閘住唔畀停**，要繼續修。咁樣保持停止時嘅速度，同時捕捉到最常見嘅問題。

**第 5 層：Lint（代碼規範檢查）**
- 檢查你嘅 code 有冇違反規範。
- ESLint、ruff、flake8、golangci-lint、clippy、rubocop……自動偵測。
- 有 lint error → **阻截**

**第 6 層：Type Check（型別檢查）**
- TypeScript → `tsc --noEmit`
- Python → `mypy` 或者 `pyright`
- Go → `go vet`
- Rust → `cargo check`
- 有 type error → **阻截**

**即係話：** Claude 做完嘢，佢想停，但佢要過 lint 同 typecheck 先至停得。如果任何一個 fail，佢要自己修到過為止。

**如果 3 次都修唔到：** 自動寫一個 `DEBUG_LOG.md` 記錄問題，然後自動開一個全新嘅 Claude session 去嘗試修理（self-healing）。如果新 session 都修唔到，先至真正停低等你人類去搞。

#### 完整 7 層驗證（Team Loop）

完整嘅 7 層驗證係喺 **Team Loop**（`/kova:loop`）入面透過 `verify-gate.sh` 跑嘅，唔係每次停都跑。包括：

1. **Build** — 編譯你個 project（npm run build、go build、cargo build 等）
2. **Unit Tests** — 跑所有 unit test，fail 會 retry 一次
3. **Integration Tests** — 只有設定咗 `test:integration` 先至會跑
4. **E2E Tests** — 只有裝咗 Playwright 先至會跑
5. **Lint** — 同停止閘門一樣
6. **Type Check** — 同停止閘門一樣
7. **Security Audit** — 只係警告，唔會阻截

---

### Hook 3：`block-dangerous.sh` — 攔截危險指令

**幾時跑？** 每次 Claude 想行 bash command 之前。

**做咩？** 檢查佢想行嘅指令係咪危險嘅。如果係，直接阻截。

會攔截嘅指令包括：
- `rm -rf /` — 刪除成個系統
- `rm -rf ~` — 刪除成個 home directory
- `git push --force` — 強制推送（會覆蓋其他人嘅代碼）
- `DROP TABLE` / `DROP DATABASE` — 刪除資料庫
- Fork bomb — 會令電腦死機嘅指令
- 直接操作 `/dev/` 設備

**即係話：** Claude 就算「發癲」都唔會搞壞你嘅系統。

---

### Hook 4：`protect-files.sh` — 保護敏感檔案

**幾時跑？** 每次 Claude 想寫入或修改檔案之前。

**做咩？** 攔截對敏感檔案嘅修改。

會保護嘅檔案包括：

**Env 檔案**（basename 精確匹配 — `some.environment.ts` 唔會被攔截）：
- `.env`、`.env.local`、`.env.development`、`.env.test`、`.env.staging`、`.env.production`、`.env.prod`

**敏感路徑**（路徑子字串匹配）：
- `.pem`、`.key` — 加密金鑰
- `id_rsa` — SSH 私鑰
- `secrets/` 資料夾
- `credentials/` 資料夾
- `serviceAccountKey.json`、`firebase-adminsdk` — 雲端服務憑證

**即係話：** Claude 唔會唔小心改到你嘅密碼同 API key。

---

## CLAUDE.md — 文化文件

呢個檔案係教 Claude 「點做人」嘅規矩。裝咗之後 Claude 會自動讀佢。

### 核心規則

**Claude 唔使問你就可以自己做嘅嘢：**
- 揀邊個實現方式比較好 → 直接揀，寫個 comment 解釋點解
- 寫 test → 永遠都寫，唔使問
- 檔案/資料夾命名 → 跟住 project 現有嘅慣例
- 修 bug 時順手做小型重構 → 直接做，最後講一句就得
- 幫冇 type 嘅 code 加 type → 直接加
- 修 lint / format error → 直接修
- 跑 test / build / type check → 永遠都跑，唔使問

**Claude 一定要問你先至可以做嘅嘢：**
- 刪除 production 數據或者資料庫 table
- 改 `.env` / secrets / credentials
- 影響超過 3 個主要系統嘅架構改動
- Deploy 去 production
- 同一個 task fail 咗 3 次以上

### Assumption Protocol（假設協議）

當要求唔清楚嘅時候，Claude **唔會停低問你**。佢會：
1. 做一個最合理嘅假設
2. 寫一個 comment：`// ASSUMPTION: [假設內容]`
3. 繼續做
4. 最後同你講佢做咗咩假設

**即係話：** Claude 唔會不停問你「你想點呀？」「我應唔應該咁做呀？」佢會自己判斷，做完先講。

---

## 斜線指令（Slash Commands）

### `/plan [feature]` — 先計劃，再做嘢

你話：`/plan 加一個登入功能`

Claude 會：
1. 探索你成個 codebase，睇吓有乜嘢相關檔案
2. 寫一個計劃出嚟
3. **等你批准**先至開始寫 code

你睇完個計劃，打 `go`，佢就開始自動實現。

### `/verify-app` — 完整 QA 檢查（10 層）

比自動嘅 7 層更加嚴格。額外多 3 層：

- 第 1-4 層：Build + Unit + Integration + E2E（同自動嗰個一樣）
- **第 5 層：瀏覽器檢查** — 用 Chrome 開你個 app，睇有冇 console error、頁面壞咗冇
- **第 6 層：無障礙檢查** — alt text、label、heading 層級、keyboard navigation
- **第 7 層：效能檢查** — 載入時間、bundle 大小
- 第 8-10 層：Lint + Type check + Security / Code review

**呢個係你開 PR 或者 deploy 之前跑嘅「終極驗收」。**

### `/commit-push-pr` — 自動 commit + push + 開 PR

Claude 會自動：
1. `git add` 相關檔案
2. 寫一個 Conventional Commit 格式嘅 message（`feat:`、`fix:`、`refactor:` 等等）
3. `git push`
4. 用 `gh` 開一個 Draft PR

你乜都唔使做。

### `/fix-and-verify` — 自動修 bug

Claude 會：
1. 分析 error
2. 嘗試修理
3. 跑 test
4. 如果 test 仲 fail → 再分析、再修、再跑 test
5. 循環直到全部 pass
6. 如果修咗 3 次都修唔到 → 先至停低問你

**即係話：** 你話「有 bug」，佢自己搞到冇 bug 為止。

### `/code-review` — 多 Agent 代碼審查

Claude 會同時開 4 個獨立嘅 reviewer：

1. **Code Quality Reviewer** — 檢查代碼質素、架構、DRY、命名、檔案長度（300 行限制）
2. **Security Reviewer** — 檢查 OWASP Top 10 安全問題：注入攻擊、XSS、認證繞過……
3. **Test Coverage Reviewer** — 檢查測試覆蓋率，邊啲 case 冇 test，然後直接寫
4. **UX Reviewer**（只限 UI 相關改動）— 檢查無障礙、響應式、互動、載入/錯誤/空狀態

呢 4 個 reviewer 係**平行跑**嘅（同一時間開），唔係一個一個等。

### `/simplify` — 簡化代碼

唔改變行為，只係清理：
- 刪死 code
- 改善命名
- 簡化結構

### `/daily-standup` — 每日報告

顯示：今日做咗乜、有咩 blocker、下一步做乜、速度如何。

---

## Team Loop — 皇牌功能

<p align="center">
  <img src="../../assets/kova-workflow.png" alt="Kova Team Loop — 6 階段工作流程" width="100%" />
</p>

呢個係 Kova 最強嘅嘢。你寫一個 PRD（Product Requirements Document，即係一個 to-do list），然後打：

```
/kova:loop docs/my-prd.md
```

Claude 就會**自動逐項實現**你嘅 PRD，每一項都經過 6 個 phase。

### PRD 格式

就係一個 Markdown 檔案，入面有 checkbox：

```markdown
# My Feature PRD
- [ ] 加一個登入頁面
- [ ] 加密碼重設功能
- [ ] 加 Google OAuth 登入
- [x] 設計資料庫 schema（已完成）
```

`- [ ]` 係未做嘅，`- [x]` 係已完成嘅。

---

### Phase 0：Clarify（澄清）

Claude 讀你寫嘅 item，例如「加一個登入頁面」。

佢會問自己：
- 呢個需求清唔清楚？
- 有冇模糊嘅地方？

**但佢唔會問你。** 佢會自己做假設，然後寫落去 `.kova-loop/plans/item-N-clarify.md`。

例如佢可能寫：
```
ASSUMPTION: 登入頁面用 email + password，唔需要 username。
ASSUMPTION: 失敗時顯示 toast notification。
```

---

### Phase 1：Plan（計劃）

如果個 item 唔係好簡單（例如「改個 typo」就唔使計劃），Claude 會：

1. 用 `superpowers:brainstorming` skill 去諗 2-3 個方案
2. 揀最好嗰個
3. 開一個 Explore agent 去掃描成個 codebase，搵出相關嘅檔案同 pattern
4. 寫一個詳細計劃去 `.kova-loop/plans/item-N-plan.md`

計劃會寫到 `file:function` 級別嘅具體步驟，例如：
```
1. 建立 src/pages/Login.tsx — 登入表單元件
2. 建立 src/api/auth.ts — login() function，call POST /api/auth/login
3. 修改 src/routes.tsx — 加 /login route
4. 建立 src/pages/__tests__/Login.test.tsx — 測試
```

---

### Phase 2：Implement（實現）

Claude 按住計劃一步一步寫 code。

佢會：
1. 載入 `production-code-standards` skill（確保寫出 production 級別嘅 code）
2. 如果係 UI 相關嘅 item，額外載入 `ui-ux-pro-max` skill
3. 逐步執行計劃
4. 寫 test：happy path（正常情況）、edge case（邊界情況）、error case（錯誤情況）
5. 記錄改咗邊啲檔案

**呢個 phase 有 3 種模式：**
- `implement` — 正常嘅全新實現
- `fix-verify` — 上一次 verify（第 3 個 phase）fail 咗，只針對嗰啲具體錯誤去修
- `fix-review` — 上一次 review（第 4 個 phase）搵到 HIGH 級別問題，只針對嗰啲問題去修

---

### Phase 3：Verify（驗證）

透過 `verify-gate.sh` 跑完整 7 層驗證：

1. Build
2. Unit tests（fail 會 retry 一次）
3. Integration tests（有先跑）
4. E2E tests（有 Playwright 先跑）
5. Lint
6. Type check
7. Security audit（只係警告）

**如果 1-6 全部 pass：** 進入 Phase 4（review）。

**如果任何一層 fail：**
- 將所有錯誤寫入 `.kova-loop/current-failures.md`，包含 file:line 嘅具體位置
- 設定 mode 為 `fix-verify`
- 返回去 Phase 2，只修嗰啲具體錯誤
- 再跑一次 Phase 3

呢個 fix → verify → fix → verify 嘅循環會一直跑，直到 pass 或者試咗 5 次（max_fix_attempts）。

如果 5 次都搞唔掂 → 標記為 STUCK，寫入 `STUCK_ITEMS.md`，跳過呢個 item，繼續下一個。

---

### Phase 4：Review（多模型審查）

呢個 phase 有兩部分：**Claude 多 agent 審查** 同 **Codex 跨模型審查**。

#### 第一部分：Claude 多 Agent 審查

Claude 會同時開最多 4 個獨立嘅 reviewer agent：

**Reviewer 1 — Code Quality：**
- 檢查代碼質素
- 有冇違反 DRY（Don't Repeat Yourself）
- Pattern 一唔一致
- Error handling 好唔好
- Edge case 有冇處理
- 命名好唔好
- 檔案有冇超過 300 行

**Reviewer 2 — Security：**
- 檢查 OWASP Top 10 安全問題
- SQL injection、XSS、CSRF
- 有冇 hardcode secret
- 認證/授權有冇漏洞
- Input validation、output encoding

**Reviewer 3 — Test Coverage：**
- 檢查邊啲 code path 冇 test
- Test 質素好唔好（有冇真正 assert 啲有意義嘅嘢）
- **呢個 reviewer 會直接寫 test**（其他 reviewer 唔可以改檔案）

**Reviewer 4 — UX（只限 UI item）：**
- 無障礙（accessibility）
- 響應式設計（responsive）
- 互動 pattern
- Loading state、error state、empty state

呢 4 個 agent 係**平行跑**嘅。Claude 會喺一個 message 入面開晒 4 個 Task，同時跑，唔使等。

#### 第二部分：Codex 跨模型審查（可選）

呢個係新加嘅功能。

Claude 會先檢查你有冇裝 OpenAI 嘅 Codex CLI：

```bash
command -v codex &>/dev/null
```

**如果冇裝：** 靜靜哋跳過，乜都唔講。一切照常。

**如果有裝：** Claude 會：

1. 用 `git diff` 攞到所有改動
2. 準備一個 prompt，入面包括：
   - 呢個 PRD item 係咩（「加一個登入頁面」）
   - 做咗咩改動（summary）
   - 預期結果係咩
   - 改咗邊啲檔案
   - 完整嘅 diff
3. 將呢個 prompt 送去 Codex（即係 OpenAI 嘅模型）
4. Codex 會用佢自己嘅「腦」去審查你嘅 code
5. Claude 收到 Codex 嘅回覆，parse 出 findings

**點解要咁做？**

因為 Claude 嘅 4 個 reviewer agent 全部都係 Claude 模型。佢哋有**相同嘅盲點**。

用一個完全唔同嘅模型（Codex / GPT）去睇同一份 code，可以搵到 Claude 睇唔到嘅問題。反過嚟都一樣 — Claude 可以搵到 Codex 睇唔到嘅問題。

呢個就係「多模型審查」嘅優勢。好似你搵兩間唔同嘅會計師事務所去 audit 同一盤數咁。

**如果 Codex 出錯、timeout、或者冇 output：** 寫一個 warning，繼續。Codex 審查係 non-blocking 嘅，唔會因為 Codex 有問題而令成個 loop 停咗。

#### 合併結果

所有 findings（4 個 Claude agent + Codex）會合埋做一個 list，分為：

- **HIGH**（嚴重）— **阻截！** 要返去修理
- **MEDIUM**（中等）— 記錄落嚟，唔阻截
- **LOW**（輕微）— 記錄落嚟，唔阻截

寫入 `.kova-loop/current-review.md`，格式：
```
- [src/api/auth.ts:42] [security] — SQL injection: user input directly in query
- [src/pages/Login.tsx:15] [codex] — Missing error boundary for async state
```

**如果有任何 HIGH finding：** 進入 `fix-review` 模式，返去 Phase 2 修理。
**如果冇 HIGH finding：** Pass！去 Phase 5。

---

### Phase 5：Commit（提交）

Claude 會：
1. `git add` 所有改動嘅檔案
2. 寫一個 Conventional Commit message，例如：
   ```
   feat(auth): add login page with email/password

   Kova Team Loop — Item 1/3
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
3. `git commit`
4. 記錄 commit hash

然後設定下一個 item，重新開始 Phase 0。

---

### Loop 控制機制

**進度追蹤：**
每次 iteration 之後，Claude 會更新：
- `.kova-loop/LOOP_PROGRESS.md` — 邊啲 item 完成咗、邊個正在做
- `.kova-loop/ITERATION_LOG.md` — 每次 iteration 嘅詳細記錄

**STUCK 偵測：**
如果同一個 item 修咗 5 次（預設）都修唔到，Claude 會：
- 標記為 STUCK
- 寫入 `.kova-loop/STUCK_ITEMS.md`
- 跳過，繼續下一個 item

**可以恢復：**
如果你中途停咗（斷線、手動取消等等），`.kova-loop/` 入面有晒進度。下次再跑 `/kova:loop docs/my-prd.md`，佢會問你：`resume`（繼續）/ `restart`（重新開始）/ `cancel`（取消）。

**預覽模式：**
```
/kova:loop docs/my-prd.md --dry-run
```
只係顯示個計劃，唔會真正開始做。

**其他 flags：**
- `--no-commit` — 做完唔 commit
- `--max-iterations 40` — 最多跑 40 次 iteration（預設 20）
- `--max-fix-attempts 10` — 每個 item 最多試 10 次修理（預設 5）

---

## 安裝 Codex（可選）

```bash
npm install -g @openai/codex
codex login
```

如果冇裝、冇 login、或者冇 OpenAI account，跨模型審查會自動跳過。其他所有功能正常運作。

---

## 日常工作流程

```
朝早：
  /daily-standup              <- 30 秒睇完 project 狀態

做新功能：
  /plan 加一個登入頁面        <- 先計劃，你批准先做
  -> "go"                     <- Claude 自動實現
  /verify-app                 <- QA 檢查（或者 Claude 停嘅時候自動跑）
  /commit-push-pr             <- 自動 commit + push + 開 PR

發現 bug：
  /fix-and-verify             <- Claude 自己修到冇 bug 為止

合併之前：
  /code-review                <- 多 agent 審查（+ Codex 跨模型審查）
  /simplify                   <- 清理代碼

做大型功能（多個 item）：
  /kova:loop docs/prd.md      <- 自動逐項實現，每項過 6 個 phase

收工：
  /daily-standup              <- 睇今日做咗咩
```

---

## 支援嘅語言

| 語言 | Build | Test | Lint | Type Check | Format | 安全審計 |
|------|-------|------|------|------------|--------|----------|
| JS/TS | 有 | vitest, jest | eslint | tsc | prettier | npm/pnpm/yarn audit |
| Python | - | pytest | ruff, flake8 | mypy, pyright | ruff, black | pip-audit |
| Go | go build | go test | golangci-lint | go vet | gofmt | govulncheck |
| Rust | cargo build | cargo test | cargo clippy | cargo check | rustfmt | cargo audit |
| Ruby | - | rspec | rubocop | - | rubocop -a | bundle-audit |
| Java | mvn/gradle | mvn/gradle test | - | - | google-java-format | - |
| .NET | dotnet build | dotnet test | dotnet format | dotnet build | dotnet format | - |

自動偵測係根據 lockfile 同設定檔（package.json、go.mod、Cargo.toml 等）。

---

## 總結

<p align="center">
  <img src="../../assets/kova-comparison.png" alt="冇 Kova vs 有 Kova" width="100%" />
</p>

| 層面 | 冇 Kova | 有 Kova |
|------|---------|---------|
| 格式化 | 你自己 format | 自動 format |
| 測試 | Claude 可能跳過 | 自動跑，fail 咗自動修 |
| 安全 | Claude 可能 `rm -rf` | 危險指令全部攔截 |
| 密碼保護 | Claude 可能改到 .env | 敏感檔案全部保護 |
| 審查 | 你自己睇 code | 4 個 Claude agent + Codex 平行審查 |
| 工作模式 | 你問佢答 | 佢自己做，做完先講 |
| 失敗處理 | 報個 error 就停 | 自動修，修唔到先至停 |

**Kova 嘅哲學：「你唔係信任佢會做啱嘢，你係建立一個系統令做錯嘢變得困難。」**

---

## 現時嘅保證同限制

**Hooks 啟用時保證嘅嘢：**
- 每次停都會跑 lint + typecheck（快速停止閘門）
- 每次寫檔案都會檢查保護名單
- 每次行 bash 都會檢查危險指令
- Team Loop 透過 bash 跑完整 7 層驗證 — Claude 唔可以跳過

**Hooks 唔保證嘅嘢：**
- 用戶可以停用 hooks（`kova deactivate` 或者改 settings.json）
- 停止閘門只跑 lint + typecheck — build、test、security 只喺 Team Loop 入面跑
- 檔案保護用 pattern matching，唔係 OS 層面嘅權限
- Hooks 需要裝 `jq`；冇裝嘅話佢哋會靜靜哋退出
