# ram-ws — Runtime Isolation & Persistence Boundary Lab

## Overview

`ram-ws.sh` runs a user workspace entirely from RAM (`/dev/shm`) and persists it as an encrypted archive on disk.

It is designed to separate **runtime state** from **persistent state** and make persistence an explicit operation.

---

## What it does

1. Prompts for a passphrase
2. If `~/.config/home.tar.age` exists and is non-empty, decrypts it into `/dev/shm/home_work`; otherwise starts with an empty workspace
3. Launches a login shell with `HOME` redirected to RAM
4. On successful exit:
   - repacks workspace (excluding `~/.rwsignore`)
   - encrypts archive using `age`
   - writes back to disk
5. Wipes the RAM workspace

---

## Analysis focus

This project examines how execution context affects system visibility:

- runtime activity occurs entirely in memory (`/dev/shm`)
- file-based artefacts are absent during execution
- persistence is delayed and explicitly triggered on exit

Focus areas:

- separation of runtime vs persistent state
- observability differences (process vs filesystem level)
- impact of execution location on monitoring

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

Exit the shell to trigger save and encryption.

---

## Environment

- HOME=/dev/shm/home_work
- XDG_CONFIG_HOME=$HOME/.config
- RAM_WS_ACTIVE=1
- HISTFILE=/dev/null

---

## Failure behaviour

- Decryption failure (existing archive with wrong passphrase or corruption): abort and wipe RAM workspace
- Encryption failure: preserve
  - /dev/shm/home_work
  - /dev/shm/home_new.tar

---

## Notes

- Ignore rules use standard `tar --exclude-from` format (`~/.rwsignore`, auto-created if missing)

---
