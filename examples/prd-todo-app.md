# PRD: Todo App CLI

> Example PRD for new Kova users.
> Run with: `/kova:loop examples/prd-todo-app.md`

## Overview

Build a minimal CLI todo app in Bash. This PRD is designed to demonstrate the
full Kova loop — implement, verify, review, commit — across 5 small items.

## Items

- [ ] Create `examples/todo-app/todo.sh` — a Bash script that stores todos in a plain-text file (`~/.kova-todo.txt`) and supports `add <text>`, `list`, `done <number>`, and `clear` subcommands
- [ ] Add input validation to `todo.sh` — print usage help when no subcommand is given, reject empty `add` text, and exit with code 1 on any invalid input
- [ ] Add a `count` subcommand to `todo.sh` that prints the number of pending (uncompleted) todos
- [ ] Write Bats tests in `examples/todo-app/tests/todo.bats` covering: add + list round-trip, done marks completion, count accuracy, and error cases (no args, empty add)
- [ ] Add a one-line description comment at the top of `todo.sh` and a `README.md` in `examples/todo-app/` explaining how to run and test the app

## Notes

- Tech stack: Bash, Bats (testing)
- No external dependencies beyond coreutils
- The todo file path should be overridable via `TODO_FILE` env var for testing
