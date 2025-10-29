#!/usr/bin/env bash

# Helper to (un)ignore local changes under the course/ directory.
# Usage:
#   ./scripts/course-ignore.sh ignore    # add /course/ to .git/info/exclude and assume-unchanged tracked files
#   ./scripts/course-ignore.sh unignore  # remove /course/ from .git/info/exclude and clear assume-unchanged
#   ./scripts/course-ignore.sh status    # show current state

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXCLUDE_FILE="$ROOT_DIR/.git/info/exclude"

usage() {
  cat <<EOF
Usage: $(basename "$0") <ignore|unignore|status>

ignore   - Add /course/ to local git exclude and mark tracked files under course/ as assume-unchanged
unignore - Remove /course/ from local git exclude and clear assume-unchanged flags on tracked files
status   - Show whether /course/ is excluded and list tracked files with assume-unchanged status
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

cmd="$1"
shift || true

# Helper: list tracked files under course
list_tracked_course() {
  git ls-files course || true
}

case "$cmd" in
  ignore)
    echo "Adding /course/ to $EXCLUDE_FILE (local only)"
    mkdir -p "$(dirname "$EXCLUDE_FILE")"
    if grep -Fxq "/course/" "$EXCLUDE_FILE" 2>/dev/null; then
      echo "/course/ already present in $EXCLUDE_FILE"
    else
      printf "\n# Ignore local lesson progress\n$(git -C "$ROOT_DIR" ls-files -v course | sed -n '1,200p' | cut -d " " -f 2 | sed 's/^/\//')" >> "$EXCLUDE_FILE"
      echo "Appended /course/ to $EXCLUDE_FILE"
    fi

    echo "Marking tracked files under course/ as assume-unchanged (so local edits are ignored by git)..."
    files=$(list_tracked_course)
    if [[ -z "$files" ]]; then
      echo "No tracked files under course/ found. Nothing to mark."
    else
      echo "$files" | xargs -r -n1 git update-index --assume-unchanged
      echo "Marked $(echo "$files" | wc -l) files as assume-unchanged."
    fi
    ;;

  unignore)
    echo "Removing /course/ from $EXCLUDE_FILE (local only)"
    if [[ -f "$EXCLUDE_FILE" ]]; then
      # remove exact line(s) containing /course/.*
      sed -i '/^# Ignore local lesson progress[[:space:]]*$/d' "$EXCLUDE_FILE" || true
      sed -i '/^[[:space:]]*$/d' "$EXCLUDE_FILE" || true
      sed -i.bak '/^\/course\/.*/d' "$EXCLUDE_FILE" || true
      echo "Updated $EXCLUDE_FILE (backup at $EXCLUDE_FILE.bak)"
    else
      echo "$EXCLUDE_FILE not found; nothing to remove"
    fi

    echo "Clearing assume-unchanged flags for tracked files under course/..."
    files=$(list_tracked_course)
    if [[ -z "$files" ]]; then
      echo "No tracked files under course/ found. Nothing to unmark."
    else
      echo "$files" | xargs -r -n1 git update-index --no-assume-unchanged
      echo "Cleared assume-unchanged on $(echo "$files" | wc -l) files."
    fi
    ;;

  status)
    echo "Checking $EXCLUDE_FILE for /course/..."
    if [[ -f "$EXCLUDE_FILE" && $(grep -c "/course/" "$EXCLUDE_FILE" || true) -ge 1 ]]; then
      echo "/course/ is present in $EXCLUDE_FILE"
    else
      echo "/course/ is NOT present in $EXCLUDE_FILE"
    fi

    echo
    echo "Tracked course files with assume-unchanged flag (git ls-files -v shows leading 'h')"
    git -C "$ROOT_DIR" ls-files -v course | sed -n '1,200p'

    echo
    echo "Git status (porcelain) — you should not see modified course/ files if they are ignored locally:"
    git -C "$ROOT_DIR" status --porcelain | sed -n '1,200p'
    ;;

  *)
    usage; exit 2
    ;;
esac

exit 0
