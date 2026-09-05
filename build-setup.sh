#!/usr/bin/env bash
# Builds the self-extracting `setup` file from setup-template.sh + glassy-lyrics.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-setup}"
MARKER="__GLASSY_LYRICS_PAYLOAD_7f3a__"

{
  cat setup-template.sh
  printf '\n%s\n' "$MARKER"
  cat glassy-lyrics
} > "$OUT"

chmod +x "$OUT"
echo "built: $OUT ($(wc -c < "$OUT") bytes)"
