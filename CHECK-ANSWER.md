check-answer
============

Small helper script to compare student `code.go` with the solution `complete.go` for exercises.

Usage
-----

From repository root:

`./check-answer --module 3 --lesson 4`

Short flags are available:

`./check-answer -m 3 -l 4`

Options
-------

`--module`, `-m`:      Module number or substring (e.g. `3`, `3-functions`)

`--lesson`, `-l`:      Lesson number, suffix, or folder name (e.g. `4`, `4-pass_by_value`, `pass_by_value`)

`--check`, `-c`:       Run static checks on the student file (`gofmt -l` and `go vet`)

`--no-clean`, `-n`:    Keep temporary output files when the run completes (default is to clean)

What it does
------------
- Locates the module under `course/` using exact, prefix (`<n>-...`) or substring match.
- Locates the exercise under `exercises/` or `challenges/` using exact name, prefix or substring.
- Runs `go run` on `code.go` (student) and `complete.go` (solution).
- Captures stdout, stderr and exit codes for each run.
- Normalizes outputs (trims trailing spaces and leading/trailing blank lines) and compares them with `diff -u`.
- Prints a short summary and exits with non-zero on mismatch.

Notes
-----
- By default temporary files are removed. Use `--no-clean` to keep them for inspection.
- If you want additional comparisons (e.g., compare only numbers or ignore ordering), I can add modes for that.
