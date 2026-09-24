#!/usr/bin/env bash
# Seed a deterministic dirty working tree for the lab's workflow phase.
#
# Drops three unrelated edits into sample-app/:
#   1. sample-app/app.py        — add a docstring to greet()
#   2. sample-app/README.md     — add a "Run me" section
#   3. sample-app/tests/test_app.py — add a second test
#
# Idempotent on a clean working tree. Refuses to run on an already-dirty tree
# so it can't double-apply the changes.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# prefer python3, fall back to plain python where python3 is missing
PY_BIN="$(command -v python3 || command -v python || true)"
if [ -z "$PY_BIN" ]; then
  echo "ERROR: python3 (or python) is required to seed the working tree."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree or index is not clean."
  echo "Stash or commit your changes first:"
  echo "  git stash --include-untracked"
  exit 1
fi

# --- 1. Docstring on greet() -------------------------------------------------
"$PY_BIN" - <<'PY'
from pathlib import Path

p = Path("sample-app/app.py")
text = p.read_text()
needle = "def greet(name: str, shout: bool = False) -> str:\n    message ="
replacement = (
    "def greet(name: str, shout: bool = False) -> str:\n"
    "    \"\"\"Return a friendly greeting for `name`.\"\"\"\n"
    "    message ="
)
if needle not in text:
    raise SystemExit("seed: could not find greet() signature in app.py")
if replacement in text:
    raise SystemExit("seed: docstring already present — refusing to double-apply")
p.write_text(text.replace(needle, replacement))
PY

# --- 2. Run-me section in sample-app/README.md -------------------------------
cat >> sample-app/README.md <<'EOF'

## Run me

```bash
python sample-app/app.py Ada
# → Hello, Ada!
```
EOF

# --- 3. Second test ----------------------------------------------------------
cat >> sample-app/tests/test_app.py <<'EOF'


def test_greet_handles_empty_string():
    assert greet("") == "Hello, !"
EOF

echo "seed-messy-state.sh: dropped three changes into sample-app/"
git status --short
