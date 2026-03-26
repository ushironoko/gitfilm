# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
moon check                              # Type-check without building
moon test                               # Run all tests
moon test --update                      # Run tests and auto-update snapshots
moon test --package ushironoko/gitfilm/executor  # Run tests for a single package
moon build --target native              # Build native executable
moon run cmd/main --target native -- 'add main.rs' 'commit -m "init"'  # Run directly
moon fmt                                # Format code
moon info                               # Regenerate .mbti interface files
moon info && moon fmt                   # Pre-commit: update interfaces and format
```

## Architecture

gitfilm simulates git operations in an isolated worktree sandbox and visualizes state transitions using a 3-area model (Working Tree / Staging Area / Repository). With `--execute`, it can replay operations against the real repository.

**Data flow**: CLI args → `parser` → `executor` (sandbox simulation) → `renderer` (output)

- **model/** — Core data types shared by all packages. `Operation` enum represents parsed git commands. All structs are `pub(all)` for cross-package construction.
- **parser/** — Parses operation strings (e.g. `"reset --soft HEAD~1"`) and flags (`--execute`) into `ParsedInput`.
- **executor/** — Creates a git worktree sandbox, runs operations via `simulate()`, and optionally replays them on the real repo via `execute()`. Includes preflight safety checks for `--execute` mode.
- **process/** — FFI layer for spawning subprocesses (`git`, etc.) via `posix_spawn`. Native target only.
- **renderer/** — Parses porcelain status output and formats prev/next snapshots for display. Computes file status from git status entries and tracked file lists.
- **cmd/main/** — Entry point. Wires packages together.

## Testing Conventions

- **Snapshot tests with inline `inspect`**: Use `inspect(value, content="")` then `moon test --update` to populate. Do not use `@test.T::snapshot` (file-based).
- **Scenario-style**: Test operation chains as a whole, snapshotting the final `GitState` or rendered output.
- **`assert_eq`/`assert_true`**: Only in loops or where `inspect` is impractical.
- Blackbox tests in `*_test.mbt`, whitebox in `*_wbtest.mbt`.

## MoonBit Conventions

- Code blocks are separated by `///|` markers. Block order is irrelevant.
- Run `moon info && moon fmt` before committing. Check `.mbti` diffs to verify API changes are intentional.
- Deprecated code goes in `deprecated.mbt`.
