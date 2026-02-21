# Changelog

## [0.2.0] - 2026-02-21

### Added

- **Rate Limiting** — Prevents API cost overruns during long loop sessions
  - Configurable via `MAX_INVOCATIONS_PER_HOUR` env var (default: 100)
  - Auto-detects API rate limit errors in Claude output (429, "too many requests")
  - Countdown display on stderr during wait periods
  - State tracked in `.kova-loop/.rate_limit_state`

- **Circuit Breaker** — Stops loops that are clearly stuck
  - Trips after 3 consecutive stuck items (`CIRCUIT_BREAKER_THRESHOLD`)
  - Trips after 5 iterations with no file changes (`CIRCUIT_BREAKER_NO_PROGRESS`)
  - Writes detailed `CIRCUIT_BREAKER.md` report with next steps
  - Exit code 2 distinguishes circuit breaker from normal stuck (exit 1)

- **tmux Dashboard** (`kova-monitor`) — Real-time loop monitoring
  - `kova-monitor start <prd>` — split-pane tmux session (loop left, dashboard right)
  - `kova-monitor attach/stop/status` — session management
  - Dashboard refreshes every 2s showing: progress, rate limit, circuit breaker, recent activity, verify results
  - Graceful fallback when tmux not installed

- **Global Install** — System-wide CLI availability
  - `install.sh --global` copies `kova` + `kova-monitor` to `~/.local/bin` (fallback `/usr/local/bin`)
  - PATH detection with actionable warnings
  - `--global --dry-run` preview mode
  - Per-project hooks still require `kova install`

- **Setup Wizard** (`kova setup`) — One-command project onboarding
  - Detects project stack
  - Runs install + activate
  - Shows final status summary

- `kova monitor` command delegates to `kova-monitor`

### Changed

- `kova-loop.sh` now sources `rate-limiter.sh` and `circuit-breaker.sh`
- `kova help` lists `setup` and `monitor` commands
- `install.sh` copies new lib files (`rate-limiter.sh`, `circuit-breaker.sh`) and `kova-monitor`
- Loop summary now shows API call count

### Tests

- 65 new tests (177 total, up from 112)
  - `tests/unit/rate-limiter.bats` — 19 tests
  - `tests/unit/circuit-breaker.bats` — 18 tests
  - `tests/unit/kova-monitor.bats` — 10 tests
  - `tests/integration/monitor.bats` — 10 tests
  - `tests/integration/global-install.bats` — 8 tests

## [0.1.0] - 2025-06-01

### Added

- Initial release
- 5 hooks: format, block-dangerous, protect-files, verify-on-stop, kova-loop
- 7-layer verification gate
- 6-phase Team Loop with PRD parsing
- Stack detection for 7 ecosystems
- CLI with help, status, activate, deactivate, install
- 112 tests
