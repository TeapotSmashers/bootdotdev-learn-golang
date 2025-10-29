#!/usr/bin/env bash

# Simple checker for bootdotdev golang exercises
# Usage: check-answer --module 3 --lesson 4

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --module <n> --lesson <n>

Runs the user's code.go and the solution complete.go for the specified module and lesson
and compares their outputs.

Examples:
  $(basename "$0") --module 3 --lesson 4
EOF
}

MODULE=""
LESSON=""


CHECK_ONLY=0
NO_CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module|-m)
      MODULE="$2"; shift 2 ;;
    --lesson|-l)
      LESSON="$2"; shift 2 ;;
    --check|-c)
      CHECK_ONLY=1; shift ;;
    --no-clean|-n)
      NO_CLEAN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$MODULE" || -z "$LESSON" ]]; then
  echo "Both --module and --lesson are required" >&2
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find the module directory under course: try exact, then prefix (3-...), then substring
MODULE_DIR=""
if [[ -d "$ROOT_DIR/course/$MODULE" ]]; then
  MODULE_DIR="$ROOT_DIR/course/$MODULE"
fi
if [[ -z "$MODULE_DIR" ]]; then
  for d in "$ROOT_DIR"/course/${MODULE}-*; do
    if [[ -d "$d" ]]; then
      MODULE_DIR="$d"
      break
    fi
  done
fi
if [[ -z "$MODULE_DIR" ]]; then
  for d in "$ROOT_DIR"/course/*; do
    if [[ -d "$d" && "$(basename "$d")" == *"$MODULE"* ]]; then
      MODULE_DIR="$d"
      break
    fi
  done
fi

if [[ -z "$MODULE_DIR" ]]; then
  echo "Module directory containing '$MODULE' not found under $ROOT_DIR/course" >&2
  exit 3
fi

# Search in exercises and challenges for a folder whose basename contains LESSON substring
EXER_DIR=""
for parent in exercises challenges; do
  PARENT_DIR="$MODULE_DIR/$parent"
  if [[ -d "$PARENT_DIR" ]]; then
    # exact match
    if [[ -d "$PARENT_DIR/$LESSON" ]]; then
      EXER_DIR="$PARENT_DIR/$LESSON"
      break
    fi
    # try prefix match first (e.g., 4-... or 6a-...)
    for d in "$PARENT_DIR"/${LESSON}-*; do
      if [[ -d "$d" ]]; then
        EXER_DIR="$d"
        break 2
      fi
    done
    # fallback to substring match
    for d in "$PARENT_DIR"/*; do
      if [[ -d "$d" && "$(basename "$d")" == *"$LESSON"* ]]; then
        EXER_DIR="$d"
        break 2
      fi
    done
  fi
done

if [[ -z "$EXER_DIR" ]]; then
  echo "Exercise directory containing '$LESSON' not found under $MODULE_DIR" >&2
  exit 4
fi

echo "Found exercise: $EXER_DIR"

STUDENT="$EXER_DIR/code.go"
SOLUTION="$EXER_DIR/complete.go"

if [[ ! -f "$STUDENT" ]]; then
  echo "Student file not found: $STUDENT" >&2
  exit 5
fi
if [[ ! -f "$SOLUTION" ]]; then
  echo "Solution file not found: $SOLUTION" >&2
  exit 6
fi

TMPDIR=$(mktemp -d)
student_out="$TMPDIR/student.out"
student_err="$TMPDIR/student.err"
student_exit="$TMPDIR/student.exit"
solution_out="$TMPDIR/solution.out"
solution_err="$TMPDIR/solution.err"
solution_exit="$TMPDIR/solution.exit"

# helper: normalize output (trim leading/trailing blank lines and trailing spaces)
normalize() {
  # read from stdin, trim trailing spaces, remove leading/trailing blank lines
  sed 's/[ \t]*$//' | awk 'BEGIN{p=0} {lines[++n]=$0} END{i=1; while(i<=n && lines[i]=="") i++; j=n; while(j>=i && lines[j]=="") j--; for(k=i;k<=j;k++) print lines[k]}'
}

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo "Running static checks on student file..."
  (cd "$EXER_DIR" && gofmt -l "$STUDENT" ) > "$TMPDIR/gofmt.out" || true
  (cd "$EXER_DIR" && go vet "$STUDENT" ) > "$TMPDIR/govet.out" 2>&1 || true
  if [[ -s "$TMPDIR/gofmt.out" ]]; then
    echo "gofmt suggests changes in:" >&2
    sed -n '1,200p' "$TMPDIR/gofmt.out" >&2
  else
    echo "gofmt: OK"
  fi
  if [[ -s "$TMPDIR/govet.out" ]]; then
    echo "go vet warnings:" >&2
    sed -n '1,200p' "$TMPDIR/govet.out" >&2
  else
    echo "go vet: OK"
  fi
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Running student code..."
set +e
go run "$STUDENT" >"$student_out" 2>"$student_err"
SEX=$?
echo $SEX > "$student_exit"
set -e
if [[ $SEX -ne 0 ]]; then
  echo "Student program exited with non-zero status ($SEX). Stderr:" >&2
  sed -n '1,200p' "$student_err" >&2
  echo "--- Full stdout ---"
  sed -n '1,200p' "$student_out"
fi

echo "Running solution code..."
set +e
go run "$SOLUTION" >"$solution_out" 2>"$solution_err"
SOX=$?
echo $SOX > "$solution_exit"
set -e
if [[ $SOX -ne 0 ]]; then
  echo "Solution program exited with non-zero status ($SOX). Stderr:" >&2
  sed -n '1,200p' "$solution_err" >&2
  echo "--- Full stdout ---"
  sed -n '1,200p' "$solution_out"
fi

echo
echo "--- Student stdout (raw) ---"
sed -n '1,200p' "$student_out"
echo ""
echo "--- Solution stdout (raw) ---"
sed -n '1,200p' "$solution_out"
echo ""
echo "--- Diff (solution vs student) ---"

# normalize both outputs before diffing
norm_student="$TMPDIR/student.norm"
norm_solution="$TMPDIR/solution.norm"
cat "$student_out" | normalize > "$norm_student"
cat "$solution_out" | normalize > "$norm_solution"

DIFF_OK=0
if diff -u "$norm_solution" "$norm_student" >/dev/stdout 2>/dev/null; then
  DIFF_OK=1
fi

# Compare stderr normalized
norm_student_err="$TMPDIR/student.err.norm"
norm_solution_err="$TMPDIR/solution.err.norm"
cat "$student_err" | normalize > "$norm_student_err"
cat "$solution_err" | normalize > "$norm_solution_err"
ERR_DIFF_OK=0
if diff -u "$norm_solution_err" "$norm_student_err" >/dev/stdout 2>/dev/null; then
  ERR_DIFF_OK=1
fi

# Read exit codes
SEX=$(cat "$student_exit")
SOX=$(cat "$solution_exit")

OK=true
if [[ $DIFF_OK -eq 1 && $ERR_DIFF_OK -eq 1 && $SEX -eq $SOX ]]; then
  echo
  echo "Outputs and stderr and exit codes match — well done!"
else
  OK=false
  echo
  echo "Difference summary:" >&2
  if [[ $DIFF_OK -ne 1 ]]; then
    echo "  - stdout differs (see above)" >&2
  else
    echo "  - stdout: match" >&2
  fi
  if [[ $ERR_DIFF_OK -ne 1 ]]; then
    echo "  - stderr differs (shown below):" >&2
    sed -n '1,200p' "$student_err" >&2
    sed -n '1,200p' "$solution_err" >&2
  else
    echo "  - stderr: match" >&2
  fi
  if [[ $SEX -ne $SOX ]]; then
    echo "  - exit codes differ: student=$SEX solution=$SOX" >&2
  else
    echo "  - exit codes: match ($SEX)" >&2
  fi
fi

# Clean up unless NO_CLEAN is set
if [[ "$OK" == true && $NO_CLEAN -eq 0 ]]; then
  rm -rf "$TMPDIR"
elif [[ "$OK" == false && $NO_CLEAN -eq 0 ]]; then
  # on failure, default to cleaning too (user requested autoclean). If user wants to keep outputs, use --no-clean
  rm -rf "$TMPDIR"
fi

if [[ "$OK" == true ]]; then
  exit 0
else
  if [[ $NO_CLEAN -eq 1 ]]; then
    echo "Temporary files left in: $TMPDIR" >&2
  fi
  exit 7
fi
