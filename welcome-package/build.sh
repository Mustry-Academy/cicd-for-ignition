#!/usr/bin/env bash
# Build welcome-package.pdf from welcome-package.html.
#
# Steps:
#   1. Load the cohort links from links.conf
#   2. Generate QR code SVGs (qr/*.svg) for the URLs in QR_TARGETS
#   3. Fill the {{NAME}} link placeholders into a temporary copy of the HTML
#   4. Render that copy to PDF with headless Chrome
#
# Usage:
#   ./build.sh                 # writes welcome-package.pdf next to the HTML
#   ./build.sh out.pdf         # writes to a custom path
#   CHROME=/path/to/chrome ./build.sh   # override browser autodetect
#
# Dependencies (macOS via Homebrew):
#   brew install qrencode
# plus a Chromium-class browser (Chrome / Chromium / Edge / Brave).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML_SRC="$SCRIPT_DIR/welcome-package.html"
HTML_BUILT="$SCRIPT_DIR/welcome-package.built.html"
LINKS_CONF="$SCRIPT_DIR/links.conf"
QR_DIR="$SCRIPT_DIR/qr"
PDF="${1:-$SCRIPT_DIR/welcome-package.pdf}"

# --- 0. preflight ------------------------------------------------------
[ -f "$HTML_SRC" ]   || { echo "error: $HTML_SRC not found"   >&2; exit 1; }
[ -f "$LINKS_CONF" ] || { echo "error: $LINKS_CONF not found" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' not on PATH. ${2:-}" >&2
    exit 1
  }
}
require qrencode "Install with: brew install qrencode"

# --- 1. load links.conf -----------------------------------------------
# shellcheck disable=SC1090
source "$LINKS_CONF"

LINK_VARS=(DISCORD_INVITE_URL PREFLIGHT_REPO_URL SURVEY_URL)
for v in "${LINK_VARS[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "error: $v is unset or empty in $LINKS_CONF" >&2
    exit 1
  fi
done

# --- 2. QR codes -------------------------------------------------------
# Each entry: <output-name>=<URL>. The HTML references qr/<output-name>.svg.
QR_TARGETS=(
  "discord=$DISCORD_INVITE_URL"
  "preflight=$PREFLIGHT_REPO_URL"
  "survey=$SURVEY_URL"
  "linkedin=https://www.linkedin.com/in/jasper-louage/"
)
mkdir -p "$QR_DIR"
echo "generating QR codes…"
for entry in "${QR_TARGETS[@]}"; do
  name="${entry%%=*}"
  url="${entry#*=}"
  out="$QR_DIR/$name.svg"
  qrencode -t SVG -m 1 --foreground="10172A" -o "$out" "$url"
  printf "  qr/%s.svg  ←  %s\n" "$name" "$url"
done

# --- 3. fill in links -------------------------------------------------
# Writes a temporary copy next to the source so relative asset paths still
# resolve. The source HTML is never modified.
echo "filling in links…"
trap 'rm -f "$HTML_BUILT"' EXIT
# perl rather than bash ${var//…} substitution, which is very slow on macOS's bash 3.2.
export "${LINK_VARS[@]}"
LINK_PATTERN="$(IFS='|'; echo "${LINK_VARS[*]}")" \
  perl -pe 's/\{\{($ENV{LINK_PATTERN})\}\}/$ENV{$1}/g' "$HTML_SRC" > "$HTML_BUILT"
if grep -qE '\{\{[A-Z_]+\}\}' "$HTML_BUILT"; then
  echo "error: unknown placeholders in $HTML_SRC:" >&2
  grep -oE '\{\{[A-Z_]+\}\}' "$HTML_BUILT" | sort -u >&2
  exit 1
fi

# --- 4. render PDF -----------------------------------------------------
find_chrome() {
  if [ -n "${CHROME:-}" ]; then
    echo "$CHROME"
    return 0
  fi
  local candidates=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
  )
  for c in "${candidates[@]}"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  for cmd in google-chrome chromium chromium-browser microsoft-edge brave-browser; do
    if command -v "$cmd" >/dev/null 2>&1; then
      command -v "$cmd"
      return 0
    fi
  done
  return 1
}

CHROME_BIN="$(find_chrome)" || {
  echo "error: no Chromium-class browser found." >&2
  echo "       install Google Chrome, or run: CHROME=/path/to/chrome ./build.sh" >&2
  exit 1
}

echo "rendering: $HTML_BUILT"
echo "      via: $CHROME_BIN"
echo "       to: $PDF"

# --virtual-time-budget gives the page time to fetch the brand fonts from
# mustrysolutions.com before Chrome snapshots it. Bump it if the network is slow.
"$CHROME_BIN" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=8000 \
  --print-to-pdf="$PDF" \
  "file://$HTML_BUILT" \
  >/dev/null 2>&1

SIZE="$(du -h "$PDF" | awk '{print $1}')"
echo "done: $PDF ($SIZE)"
