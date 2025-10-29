#!/usr/bin/env bash
# Install git hook from .githooks into .git/hooks (local only)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SRC="$ROOT_DIR/.githooks/pre-commit"
HOOK_DEST="$ROOT_DIR/.git/hooks/pre-commit"

if [[ ! -f "$HOOK_SRC" ]]; then
  echo "Hook source not found: $HOOK_SRC" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/.git/hooks"
if [[ -e "$HOOK_DEST" ]]; then
  echo "Existing hook at $HOOK_DEST detected. Backing up to ${HOOK_DEST}.bak"
  mv "$HOOK_DEST" "${HOOK_DEST}.bak"
fi

ln -s "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_SRC"
chmod +x "$HOOK_DEST"

echo "Installed pre-commit hook (symlinked .git/hooks/pre-commit -> .githooks/pre-commit)"
exit 0
