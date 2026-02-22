# tmux 使用指南（简体中文）

## tmux 是什么？

tmux（terminal multiplexer）可以在一个终端里开多个会话。最强的地方是：**关掉终端或者断网，程序继续跑**。

## Kova 怎么用 tmux

tmux 是**可选的**，只有 `kova-monitor` 才需要。它开一个分屏 dashboard：

```
┌─────────────────────────────────┬──────────────────┐
│                                 │                  │
│  kova-loop 运行中               │  实时 dashboard  │
│  (implement → verify →          │  (进度、状态、    │
│   review → commit)              │   卡住的项目)    │
│                                 │                  │
└─────────────────────────────────┴──────────────────┘
```

没有 tmux 一样能用 Kova——直接跑 `/kova:loop` 或者 `bash .claude/hooks/kova-loop.sh prd.md` 就行。

---

## 安装

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

### 验证安装

```bash
tmux -V
# 应该看到: tmux 3.x
```

---

## 核心概念

tmux 有 3 层架构：

```
Session（会话）  ← 有名字的工作空间（关终端不会断）
  └── Window（窗口） ← 类似浏览器标签页
        └── Pane（面板） ← 窗口里的分割区域
```

---

## 基本命令

### Session 管理

| 命令 | 作用 |
|------|------|
| `tmux` | 新建无名 session |
| `tmux new -s work` | 新建名为 "work" 的 session |
| `tmux ls` | 列出所有 session |
| `tmux attach -t work` | 重新接入 "work" session |
| `tmux kill-session -t work` | 关闭 "work" session |

### 前缀键（Prefix Key）

tmux 所有快捷键都是先按 **`Ctrl+b`**，松手，再按下一个键。

### 导航

| 快捷键 | 作用 |
|--------|------|
| `Ctrl+b` 然后 `d` | **Detach** — 离开 session（session 继续跑） |
| `Ctrl+b` 然后 `%` | 左右分割面板 |
| `Ctrl+b` 然后 `"` | 上下分割面板 |
| `Ctrl+b` 然后 `方向键` | 切换面板 |
| `Ctrl+b` 然后 `z` | 放大/缩小当前面板 |
| `Ctrl+b` 然后 `x` | 关闭当前面板 |

### 窗口操作

| 快捷键 | 作用 |
|--------|------|
| `Ctrl+b` 然后 `c` | 新建窗口 |
| `Ctrl+b` 然后 `n` | 下一个窗口 |
| `Ctrl+b` 然后 `p` | 上一个窗口 |
| `Ctrl+b` 然后 `0-9` | 跳转到指定窗口 |
| `Ctrl+b` 然后 `,` | 重命名窗口 |

### 滚动模式

| 快捷键 | 作用 |
|--------|------|
| `Ctrl+b` 然后 `[` | 进入滚动模式 |
| `q` | 退出滚动模式 |
| `方向键` 或 `PgUp/PgDn` | 上下滚动 |

---

## 常见用法

### 1. 安全地跑长时间任务

```bash
tmux new -s deploy
./deploy.sh
# Ctrl+b d  → detach，deploy 继续跑
# 之后想看：
tmux attach -t deploy
```

### 2. 分屏：左边跑 server，右边写代码

```bash
tmux new -s dev
npm run dev
# Ctrl+b %  → 右边分割
# 右边面板：跑测试或者写代码
```

### 3. SSH 断线也不怕

```bash
ssh myserver
tmux new -s remote-work
# 干活...
# WiFi 断了？没关系！
# 重新连接：
ssh myserver
tmux attach -t remote-work
# 所有东西都还在
```

---

## 配合 Kova 使用

### 启动 monitor dashboard

```bash
kova-monitor start docs/prd.md
# 或者
.claude/kova monitor start docs/prd.md
```

会创建一个 tmux session：
- 左边面板：`kova-loop.sh` 跑你的 PRD
- 右边面板：实时进度 dashboard

### 接入正在运行的 monitor

```bash
kova-monitor attach
```

### 查看状态

```bash
kova-monitor status
```

### 停止 monitor

```bash
kova-monitor stop
```

### Detach 但不停止

按 `Ctrl+b` 然后 `d`。Loop 会继续在后台跑。

---

## 速查表

```
SESSION 管理                面板操作                  窗口操作
tmux new -s name            Ctrl+b %  左右分割        Ctrl+b c  新建窗口
tmux attach -t name         Ctrl+b "  上下分割        Ctrl+b n  下一个
tmux ls                     Ctrl+b →  去右边          Ctrl+b p  上一个
tmux kill-session -t name   Ctrl+b z  放大/缩小       Ctrl+b 0  跳到 #0
Ctrl+b d  detach            Ctrl+b x  关闭面板        Ctrl+b ,  重命名
```

---

## 常见问题

| 问题 | 解决方法 |
|------|----------|
| `tmux: command not found` | 安装 tmux（看上面安装部分） |
| `no server running` | 没有 active session，用 `tmux` 新建一个 |
| `sessions should be nested` | 你已经在 tmux 里面了，先 detach（`Ctrl+b d`） |
| 不会滚动 | 进入滚动模式：`Ctrl+b [`，再用方向键 |
| 面板太小 | 放大一个面板：`Ctrl+b z` |
