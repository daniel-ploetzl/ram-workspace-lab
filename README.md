# ram-workspace-lab
Runtime Isolation & Persistence Boundary Lab

## Overview

`ram-ws.sh` runs a user workspace entirely from RAM (`/dev/shm`) and persists it as an encrypted archive on disk.

It enforces a strict separation between **runtime state** and **persistent state**, where persistence is an explicit, controlled operation.

---

## What it does

1. Prompts for a passphrase
2. State transition:
   - EMPTY: if `~/.config/home.tar.age` is missing, a fresh RAM workspace is created
   - LOAD: if archive exists, it is decrypted and extracted into `/dev/shm/home_work` (failure aborts before shell startup)
3. Launches `/usr/bin/zsh -l` with a controlled environment that preserves essential host context (e.g. PATH, TERM, LANG) while overriding execution-critical variables (HOME, XDG_CONFIG_HOME)
4. EXEC phase: interactive session runs fully in RAM
5. COMMIT phase on exit:
   - workspace is repacked using `tar`
   - optional exclusions applied from `~/.rwsignore`
   - archive is encrypted using `age`
   - stored as `~/.config/home.tar.age` with permission `600`
6. RAM workspace is removed only after successful commit

---

## Analysis focus

This project examines how execution context affects system visibility:

- runtime activity exists only in memory (`/dev/shm`)
- no persistent filesystem artifacts are required during execution
- persistence is explicit and occurs only at commit time

Focus areas:

- separation of runtime vs persistent state
- observability differences between process and filesystem layers
- effect of execution location on monitoring and forensics

---

## Configuration: `.rwsignore`

`.rwsignore` is an optional user-defined exclusion file used during COMMIT.

If present, it is passed directly to:

```bash
tar --exclude-from="$HOME/.rwsignore"
```

### Purpose

Exclude noisy or non-essential data such as:

- caches (`.cache/`)
- build artifacts (`node_modules/`, `dist/`)
- temporary files (`*.log`, `tmp/`)

### Format

One pattern per line:

```text
.cache/
node_modules/
*.log
```

### Behavior

- If present: used as-is, never modified
- If absent: full workspace is archived
- Script never creates or modifies this file

---

## Requirements

- Linux with `/dev/shm`
- `bash`
- `age`
- `tar`
- `zsh`

---

## Usage

```bash
chmod +x ram-ws.sh
./ram-ws.sh
```

Exit shell to trigger commit.

---

## Environment

```text
HOME=/dev/shm/home_work
XDG_CONFIG_HOME=$HOME/.config
RAM_WS_ACTIVE=1
HISTFILE=/dev/null
PATH=<host PATH preserved; fallback applied if unset>
SHELL=/usr/bin/zsh
```

---

## Failure behaviour

### LOAD failure
- incorrect passphrase
- corrupted archive
→ abort before shell execution

### COMMIT failure
- workspace preserved in `/dev/shm/home_work`
- intermediate artifacts may remain:
  - `/dev/shm/home_new.tar`
  - `/dev/shm/home_new.tar.age`
- no automatic deletion occurs
