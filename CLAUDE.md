# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
moon check                              # Type-check without building
moon test                               # Run all tests
moon test --update                      # Run tests and auto-update snapshots
moon test --package ushironoko/gitfilm/emulator  # Run tests for a single package
moon build --target native              # Build native executable
moon run cmd/main --target native -- --files f1.rs 'add f1.rs' 'commit'  # Run directly
moon fmt                                # Format code
moon info                               # Regenerate .mbti interface files
moon info && moon fmt                   # Pre-commit: update interfaces and format
```

## Architecture

gitfilm emulates git operations and visualizes state transitions using a 3-area model (Working Tree / Staging Area / Repository). It never touches real git repositories.

**Data flow**: CLI args → `parser` → `emulator` (state transitions) → `renderer` (output)

- **model/** — Core data types shared by all packages. `GitState` holds the complete snapshot (WorkingTree, StagingArea, Repository). `Operation` enum represents parsed git commands. All structs are `pub(all)` for cross-package construction.
- **parser/** — Parses `--files` flag and operation strings (e.g. `"reset --soft HEAD~1"`) into `ParsedInput`.
- **emulator/** — Pure function `apply(state, op) -> Result[GitState, String]` for each git operation. `execute_all` chains operations sequentially with early error return. Maps are copied before mutation to preserve immutability.
- **renderer/** — Derives `FileStatus` by comparing content across the 3 areas (not stored, computed each time). Formats prev/next snapshots for display.
- **cmd/main/** — Entry point. Reads actual files from disk, wires packages together.

## Testing Conventions

- **Snapshot tests with inline `inspect`**: Use `inspect(value, content="")` then `moon test --update` to populate. Do not use `@test.T::snapshot` (file-based).
- **Scenario-style**: Test operation chains as a whole, snapshotting the final `GitState` or rendered output.
- **`assert_eq`/`assert_true`**: Only in loops or where `inspect` is impractical.
- Blackbox tests in `*_test.mbt`, whitebox in `*_wbtest.mbt`.

## MoonBit Conventions

- Code blocks are separated by `///|` markers. Block order is irrelevant.
- Run `moon info && moon fmt` before committing. Check `.mbti` diffs to verify API changes are intentional.
- Deprecated code goes in `deprecated.mbt`.
