#!/usr/bin/env bash
# =====================================================================
# Runtime Isolation & Persistence Boundary Lab (ram-ws)
# =====================================================================

set -euo pipefail

cleanup() {
	rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

export DISK_HOME="$HOME"
SYNC_DIR="$DISK_HOME/.config"
mkdir -p "$SYNC_DIR"
chmod 700 "$SYNC_DIR"
SYNC="$SYNC_DIR/home.tar.age"
if [ -e "$SYNC" ]; then
	chmod 600 "$SYNC"
fi
IGNORE="$DISK_HOME/.rwsignore"
touch "$IGNORE"
chmod 600 "$IGNORE"
WORKDIR="/dev/shm/home_work"
TMP_TAR="/dev/shm/home_new.tar"
TMP_AGE="/dev/shm/home_new.tar.age"

if [ ! -t 0 ]; then
	echo "[!] Must be run in an interactive terminal"
	exit 1
fi

echo "[*] Enter RAM workspace passphrase:"
read -rs PASSPHRASE
echo

echo "[*] Preparing RAM workspace..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

if [ -s "$SYNC" ]; then
	if ! printf '%s' "$PASSPHRASE" | age -d "$SYNC" | tar -xf - -C "$WORKDIR"; then
		echo "[!] ERROR: Incorrect passphrase or corrupted archive."
		rm -rf "$WORKDIR"
		unset PASSPHRASE
		exit 1
	fi
else
	echo "[*] No existing archive found - starting fresh workspace."
fi

export HOME="$WORKDIR"
export XDG_CONFIG_HOME="$HOME/.config"
touch "$WORKDIR/.rws_active"

echo "[*] RAM workspace activated!"
echo "[*] Starting safe shell - exit to save."

HOME="$HOME" \
XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
RAM_WS_ACTIVE=1 \
HISTFILE=/dev/null \
SAVEHIST=0 \
SHELL=/usr/bin/zsh \
/usr/bin/zsh -l

echo "[*] Exited RAM workspace - beginning save process..."
rm -f "$WORKDIR/.rws_active"

echo "[*] Repacking RAM workspace..."
cd "$WORKDIR"
tar --exclude-from="$IGNORE" -cf "$TMP_TAR" .

echo "[*] Encrypting RAM workspace..."
if ! printf '%s\n%s\n' "$PASSPHRASE" "$PASSPHRASE" | age -p -o "$TMP_AGE" "$TMP_TAR"; then
    echo "[!] ERROR: Encryption failed - RAM workspace preserved."
    echo "[!] Data safe at: $WORKDIR"
    echo "[!] Tar backup at: $TMP_TAR"
    trap - EXIT INT TERM
    unset PASSPHRASE
    exit 1
fi

mv "$TMP_AGE" "$SYNC"
rm -f "$TMP_TAR"

echo "[*] Wiping RAM workspace..."
trap - EXIT INT TERM
rm -rf "$WORKDIR"

PASSPHRASE=""
unset PASSPHRASE

echo "[*] RAM workspace session complete - data saved."
