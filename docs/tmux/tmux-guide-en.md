# tmux Guide for Kova

## What is tmux?

tmux (terminal multiplexer) lets you run multiple terminal sessions inside one window. Sessions survive disconnects — close your terminal or lose SSH, and everything keeps running.

## Why Kova Uses tmux

tmux is **optional**. It powers `kova-monitor`, a split-pane dashboard:

```
┌─────────────────────────────────┬──────────────────┐
│                                 │                  │
│  kova-loop running              │  Live dashboard  │
│  (implement → verify →          │  (progress,      │
│   review → commit)              │   stuck items)   │
│                                 │                  │
└─────────────────────────────────┴──────────────────┘
```

Without tmux, Kova still works — just run `/kova:loop` or `bash .claude/hooks/kova-loop.sh prd.md` directly.

---

## Installation

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

### Verify

```bash
tmux -V
# Expected: tmux 3.x
```

---

## Core Concepts

tmux has 3 layers:

```
Session          ← a named workspace (survives terminal close)
  └── Window     ← like a browser tab
        └── Pane ← a split within a window
```

---

## Essential Commands

### Sessions

| Command | What it does |
|---------|-------------|
| `tmux` | Start a new unnamed session |
| `tmux new -s work` | Start a session named "work" |
| `tmux ls` | List all sessions |
| `tmux attach -t work` | Re-attach to "work" |
| `tmux kill-session -t work` | Kill "work" session |

### Prefix Key

All tmux shortcuts start with **`Ctrl+b`** (the prefix key). Press `Ctrl+b`, release, then press the next key.

### Navigation

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+b` then `d` | **Detach** — leave session (it keeps running) |
| `Ctrl+b` then `%` | Split pane left/right |
| `Ctrl+b` then `"` | Split pane top/bottom |
| `Ctrl+b` then `arrow keys` | Move between panes |
| `Ctrl+b` then `z` | Zoom/unzoom current pane |
| `Ctrl+b` then `x` | Close current pane |

### Windows

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+b` then `c` | Create new window |
| `Ctrl+b` then `n` | Next window |
| `Ctrl+b` then `p` | Previous window |
| `Ctrl+b` then `0-9` | Jump to window by number |
| `Ctrl+b` then `,` | Rename current window |

### Copy Mode (scrolling)

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+b` then `[` | Enter copy/scroll mode |
| `q` | Exit copy mode |
| `arrow keys` or `PgUp/PgDn` | Scroll |

---

## Common Workflows

### 1. Run a long process safely

```bash
tmux new -s deploy
./deploy.sh
# Ctrl+b d  → detach, deploy keeps running
# Later:
tmux attach -t deploy
```

### 2. Split screen: server + code

```bash
tmux new -s dev
npm run dev
# Ctrl+b %  → split right
# Right pane: run tests or edit code
```

### 3. Survive SSH disconnects

```bash
ssh myserver
tmux new -s remote-work
# Do your work...
# WiFi dies? No problem.
# Reconnect:
ssh myserver
tmux attach -t remote-work
# Everything is still there
```

---

## Using tmux with Kova

### Start the monitor dashboard

```bash
kova-monitor start docs/prd.md
# or
.claude/kova monitor start docs/prd.md
```

This creates a tmux session with:
- Left pane: `kova-loop.sh` running your PRD
- Right pane: live progress dashboard

### Attach to a running monitor

```bash
kova-monitor attach
```

### Check status

```bash
kova-monitor status
```

### Stop the monitor

```bash
kova-monitor stop
```

### Detach without stopping

Press `Ctrl+b` then `d`. The loop keeps running in the background.

---

## Quick Reference Card

```
SESSION MANAGEMENT          PANES                    WINDOWS
tmux new -s name            Ctrl+b %  split right    Ctrl+b c  new
tmux attach -t name         Ctrl+b "  split down     Ctrl+b n  next
tmux ls                     Ctrl+b →  move right     Ctrl+b p  prev
tmux kill-session -t name   Ctrl+b z  zoom toggle    Ctrl+b 0  jump to #0
Ctrl+b d  detach            Ctrl+b x  close pane     Ctrl+b ,  rename
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `tmux: command not found` | Install tmux (see Installation above) |
| `no server running` | No active sessions. Start one with `tmux` |
| `sessions should be nested` | You're already inside tmux. Detach first (`Ctrl+b d`) |
| Can't scroll | Enter copy mode: `Ctrl+b [`, then use arrow keys |
| Panes too small | Zoom one pane: `Ctrl+b z` |
