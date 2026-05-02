#!/usr/bin/env bash
# =====================================================================
# Runtime Isolation & Persistence Boundary Lab (ram-lab)
# =====================================================================

set -euo pipefail
umask 077

COMMIT_OK=0
WORKDIR="/dev/shm/home_work"

cleanup() {
	if [ "$COMMIT_OK" -eq 1 ]; then
		rm -rf "$WORKDIR"
		unset PASSPHRASE
		PASSPHRASE=""
	else
		echo "[!] WARNING: Commit failed - workspace preserved at:"
		echo "    $WORKDIR"
	fi
}

trap cleanup EXIT INT TERM

# -------------------------
# Paths
# -------------------------
export DISK_HOME="$HOME"

SYNC_DIR="$DISK_HOME/.config"
SYNC="$SYNC_DIR/home.tar.age"

IGNORE="$DISK_HOME/.rwsignore"

TMP_TAR="/dev/shm/home_new.tar"
TMP_AGE="/dev/shm/home_new.tar.age"

# -------------------------
# Safety checks
# -------------------------
if [ ! -t 0 ]; then
	echo "[!] Must be run in an interactive terminal"
	exit 1
fi

mkdir -p "$SYNC_DIR"
chmod 700 "$SYNC_DIR"

# IMPORTANT: do NOT create or modify user config implicitly
if [ -f "$IGNORE" ]; then
	chmod 600 "$IGNORE"
fi

# -------------------------
# Input
# -------------------------
echo "[*] Enter RAM workspace passphrase:"
read -rs PASSPHRASE
echo

# -------------------------
# Workspace init
# -------------------------
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

# -------------------------
# Load archive
# -------------------------
if [ -f "$SYNC" ]; then
	echo "[*] Existing archive found - decrypting..."

	if ! printf '%s' "$PASSPHRASE" | age -d "$SYNC" | tar -xf - -C "$WORKDIR"; then
		echo "[!] ERROR: Invalid passphrase or corrupted archive."
		rm -rf "$WORKDIR"
		exit 1
	fi
else
	echo "[*] No archive found - fresh workspace."
fi

# -------------------------
# Environment isolation
# -------------------------
export HOME="$WORKDIR"
export XDG_CONFIG_HOME="$HOME/.config"
export PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

touch "$WORKDIR/.rws_active"

echo "[*] RAM workspace activated"
echo "[*] Exit shell to commit changes"

# -------------------------
# Execution boundary
# -------------------------
env \
	HOME="$HOME" \
	XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
	RAM_WS_ACTIVE=1 \
	HISTFILE=/dev/null \
	TERM="${TERM:-xterm-256color}" \
	LANG="${LANG:-C.UTF-8}" \
	USER="${USER:-$(id -un)}" \
	LOGNAME="${LOGNAME:-$(id -un)}" \
	SHELL=/usr/bin/zsh \
	/usr/bin/zsh -l

# -------------------------
# COMMIT pipeline
# -------------------------
echo "[*] Committing workspace..."

rm -f "$WORKDIR/.rws_active"

cd "$WORKDIR"

if [ -f "$IGNORE" ]; then
	if ! tar --exclude-from="$IGNORE" -cf "$TMP_TAR" .; then
		echo "[!] COMMIT FAILED: tar stage failed"
		exit 1
	fi
else
	if ! tar -cf "$TMP_TAR" .; then
		echo "[!] COMMIT FAILED: tar stage failed"
		exit 1
	fi
fi

if ! printf '%s\n%s\n' "$PASSPHRASE" "$PASSPHRASE" | age -p -o "$TMP_AGE" "$TMP_TAR"; then
	echo "[!] COMMIT FAILED: encryption stage failed"
	echo "[!] Recovery preserved at: $WORKDIR"
	exit 1
fi

if ! mv -f "$TMP_AGE" "$SYNC"; then
	echo "[!] COMMIT FAILED: write stage failed"
	echo "[!] Encrypted temp preserved: $TMP_AGE"
	exit 1
fi

chmod 600 "$SYNC"
rm -f "$TMP_TAR"

COMMIT_OK=1
echo "[*] Commit successful - RAM workspace session complete"
