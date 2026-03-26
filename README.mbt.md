# gitfilm

A CLI tool that emulates git operations and visualizes state transitions with prev/next snapshots.

By default, it simulates git operations without touching any real repository, displaying file states across the 3-area model: Working Tree / Staging Area / Repository. With `--execute`, it can replay operations against your actual repository after a sandbox dry-run.

## Installation

### via mise

```bash
mise use -g github:ushironoko/gitfilm
```

### via GitHub Releases

Download the binary for your platform from [Releases](https://github.com/ushironoko/gitfilm/releases).

Available platforms:
- `gitfilm-*-aarch64-macos.tar.gz` (macOS Apple Silicon)
- `gitfilm-*-x86_64-linux.tar.gz` (Linux x86_64)

### Build from source

Requires [MoonBit](https://www.moonbitlang.com/download) toolchain.

```bash
git clone https://github.com/ushironoko/gitfilm.git
cd gitfilm
moon build --target native --release
# Binary: target/native/release/build/cmd/main/main.exe
```

## Usage

```bash
moon run cmd/main --target native -- --files <file1>,<file2>,... '<op1>' '<op2>' ...
```

### `--execute` flag

By default, gitfilm simulates operations without touching any real repository. With `--execute`, it runs the git commands against your actual repository:

```bash
gitfilm --execute 'add main.rs' 'commit'
```

**Safety model:**

1. Operations are first simulated in an isolated git worktree (sandbox).
2. If simulation succeeds, the same operations are replayed against the real repository.
3. Resets past the root commit are rejected in `--execute` mode.

> **Warning**: `--execute` mutates your real repository. Always ensure your working tree is in a known state before using it.

### Basic example

```bash
moon run cmd/main --target native -- \
  --files main.rs,lib.rs \
  'add main.rs' \
  'commit' \
  'reset --soft HEAD~1'
```

Output:

```
=== prev ===
[Working Tree]  lib.rs: untracked
                main.rs: untracked
[Staging Area]  (empty)
[Repository]    (no commits)

=== next (after: Add("main.rs"), Commit, ResetSoft(1)) ===
[Working Tree]  lib.rs: untracked
                main.rs: clean
[Staging Area]  main.rs: staged    (+N -0)
[Repository]    (no commits)
```

### Supported operations

| Operation | Syntax |
|-----------|--------|
| git add | `'add <file>'` |
| git commit | `'commit'` |
| git reset --soft | `'reset --soft HEAD~N'` |
| git reset --mixed | `'reset --mixed HEAD~N'` or `'reset HEAD~N'` |
| git reset --hard | `'reset --hard HEAD~N'` |
| git restore | `'restore <file>'` |
| git checkout -- | `'checkout -- <file>'` |
| git rm | `'rm <file>'` |

### Scenario examples

#### Understanding the difference between reset modes

```bash
# --soft: only HEAD moves back. Changes remain staged.
moon run cmd/main --target native -- \
  --files main.rs \
  'add main.rs' 'commit' 'reset --soft HEAD~1'

# --mixed (default): HEAD moves back and staging is cleared. Working tree unchanged.
moon run cmd/main --target native -- \
  --files main.rs \
  'add main.rs' 'commit' 'reset --mixed HEAD~1'

# --hard: everything is discarded.
moon run cmd/main --target native -- \
  --files main.rs \
  'add main.rs' 'commit' 'reset --hard HEAD~1'
```

## 3-area model

gitfilm visualizes git's internal 3-area model:

```
[Working Tree]  ← actual files on disk
[Staging Area]  ← content staged via git add
[Repository]    ← content saved via git commit
```

File statuses:
- **untracked** — not yet tracked by git
- **modified (+N -M)** — changed (N lines added, M lines removed)
- **staged (+N -M)** — staged for commit
- **committed (cXXXXXX)** — stored in a commit
- **clean** — no changes
- **deleted** — removed

## License

Apache-2.0
