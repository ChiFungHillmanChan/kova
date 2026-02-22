# tmux 使用指南（繁體中文）

## tmux 係咩？

tmux（terminal multiplexer）可以喺一個 terminal 入面開多個 session。最強嘅地方係：**關咗 terminal 或者斷線，程式繼續跑**。

## Kova 點用 tmux

tmux 係 **可選嘅**，只有 `kova-monitor` 先要用。佢開一個分割畫面嘅 dashboard：

```
┌─────────────────────────────────┬──────────────────┐
│                                 │                  │
│  kova-loop 運行中               │  即時 dashboard  │
│  (implement → verify →          │  (進度、狀態、    │
│   review → commit)              │   卡住嘅項目)    │
│                                 │                  │
└─────────────────────────────────┴──────────────────┘
```

冇 tmux 一樣可以用 Kova——直接跑 `/kova:loop` 或者 `bash .claude/hooks/kova-loop.sh prd.md` 就得。

---

## 安裝

### macOS

```bash
brew install tmux
```

### Ubuntu / Debian

```bash
sudo apt update && sudo apt install tmux
```

### Fedora / RHEL

```bash
sudo dnf install tmux
```

### Arch Linux

```bash
sudo pacman -S tmux
```

### 驗證安裝

```bash
tmux -V
# 應該見到: tmux 3.x
```

---

## 核心概念

tmux 有 3 層架構：

```
Session（會話）  ← 有名嘅工作空間（關 terminal 唔會死）
  └── Window（窗口） ← 好似 browser 分頁
        └── Pane（面板） ← 窗口入面嘅分割區
```

---

## 基本命令

### Session 管理

| 命令 | 作用 |
|------|------|
| `tmux` | 開新 session（冇名） |
| `tmux new -s work` | 開一個叫 "work" 嘅 session |
| `tmux ls` | 列出所有 session |
| `tmux attach -t work` | 接返 "work" session |
| `tmux kill-session -t work` | 關閉 "work" session |

### Prefix Key（前綴鍵）

tmux 所有快捷鍵都係先撳 **`Ctrl+b`**，放手，再撳下一個鍵。

### 導航

| 快捷鍵 | 作用 |
|--------|------|
| `Ctrl+b` 然後 `d` | **Detach** — 離開 session（session 繼續跑） |
| `Ctrl+b` 然後 `%` | 左右分割面板 |
| `Ctrl+b` 然後 `"` | 上下分割面板 |
| `Ctrl+b` 然後 `方向鍵` | 切換面板 |
| `Ctrl+b` 然後 `z` | 放大/縮小當前面板 |
| `Ctrl+b` 然後 `x` | 關閉當前面板 |

### 窗口操作

| 快捷鍵 | 作用 |
|--------|------|
| `Ctrl+b` 然後 `c` | 開新窗口 |
| `Ctrl+b` 然後 `n` | 下一個窗口 |
| `Ctrl+b` 然後 `p` | 上一個窗口 |
| `Ctrl+b` 然後 `0-9` | 跳去指定窗口 |
| `Ctrl+b` 然後 `,` | 改窗口名 |

### 捲動模式

| 快捷鍵 | 作用 |
|--------|------|
| `Ctrl+b` 然後 `[` | 進入捲動模式 |
| `q` | 退出捲動模式 |
| `方向鍵` 或 `PgUp/PgDn` | 上下捲動 |

---

## 常見用法

### 1. 安全咁跑長時間任務

```bash
tmux new -s deploy
./deploy.sh
# Ctrl+b d  → detach，deploy 繼續跑
# 之後想睇返：
tmux attach -t deploy
```

### 2. 分割畫面：左邊跑 server，右邊寫 code

```bash
tmux new -s dev
npm run dev
# Ctrl+b %  → 右邊分割
# 右邊面板：跑測試或者寫 code
```

### 3. SSH 斷線都唔驚

```bash
ssh myserver
tmux new -s remote-work
# 做嘢...
# WiFi 斷咗？唔緊要！
# 重新連線：
ssh myserver
tmux attach -t remote-work
# 所有嘢都仲喺度
```

---

## 配合 Kova 使用

### 啟動 monitor dashboard

```bash
kova-monitor start docs/prd.md
# 或者
.claude/kova monitor start docs/prd.md
```

會建立一個 tmux session：
- 左邊面板：`kova-loop.sh` 跑緊你嘅 PRD
- 右邊面板：即時進度 dashboard

### 接入跑緊嘅 monitor

```bash
kova-monitor attach
```

### 睇狀態

```bash
kova-monitor status
```

### 停止 monitor

```bash
kova-monitor stop
```

### Detach 但唔停止

撳 `Ctrl+b` 然後 `d`。Loop 會繼續喺背景跑。

---

## 速查表

```
SESSION 管理                面板操作                  窗口操作
tmux new -s name            Ctrl+b %  左右分割        Ctrl+b c  開新窗口
tmux attach -t name         Ctrl+b "  上下分割        Ctrl+b n  下一個
tmux ls                     Ctrl+b →  去右邊          Ctrl+b p  上一個
tmux kill-session -t name   Ctrl+b z  放大/縮小       Ctrl+b 0  跳去 #0
Ctrl+b d  detach            Ctrl+b x  關閉面板        Ctrl+b ,  改名
```

---

## 常見問題

| 問題 | 解決方法 |
|------|----------|
| `tmux: command not found` | 裝 tmux（睇上面安裝部分） |
| `no server running` | 冇 active session，用 `tmux` 開一個 |
| `sessions should be nested` | 你已經喺 tmux 入面，先 detach（`Ctrl+b d`） |
| 唔識捲動 | 進入捲動模式：`Ctrl+b [`，再用方向鍵 |
| 面板太細 | 放大一個面板：`Ctrl+b z` |
