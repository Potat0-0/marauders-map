#!/usr/bin/env bash
# ─────────────────────────────────────────────
# find_vscode_tasks.sh
# Searches one or more root directories for
# .vscode/tasks.json files and lists them.
# Compatible with bash 3+, zsh, macOS, Linux.
# ─────────────────────────────────────────────

# ── Colours ──────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

# ── Usage ─────────────────────────────────────
usage() {
  echo -e "${BOLD}Usage:${RESET} $0 [directory1] [directory2] ..."
  echo
  echo "  Recursively searches each supplied directory for '.vscode/tasks.json'."
  echo "  Falls back to the current working directory if none are supplied."
  echo
  echo -e "${BOLD}Examples:${RESET}"
  echo "  $0                          # search current directory"
  echo "  $0 ~/projects               # search a single root"
  echo "  $0 ~/projects ~/work /srv   # search multiple roots"
  exit 0
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

# ── Resolve search roots ──────────────────────
if [ $# -eq 0 ]; then
  set -- "$(pwd)"
  echo -e "${YELLOW}No directory supplied — searching current directory: $(pwd)${RESET}"
fi

# ── Search ────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}Searching for .vscode/tasks.json …${RESET}"
echo "════════════════════════════════════════════════"

TOTAL=0
FOUND_LIST=""

for ROOT in "$@"; do
  if [ ! -d "$ROOT" ]; then
    echo -e "${RED}  ✗ Not a directory (skipped): $ROOT${RESET}"
    continue
  fi

  echo -e "${BOLD}Root: $ROOT${RESET}"

  # Find tasks.json files whose immediate parent is ".vscode"
  # Read results line-by-line — no mapfile/readarray needed
  COUNT=0
  while IFS= read -r MATCH; do
    [ -z "$MATCH" ] && continue
    REL="${MATCH#"$ROOT"/}"
    echo -e "  ${GREEN}✔${RESET}  $REL"
    echo -e "       ${CYAN}→ $MATCH${RESET}"
    FOUND_LIST="$FOUND_LIST$MATCH
"
    COUNT=$((COUNT + 1))
    TOTAL=$((TOTAL + 1))
  done < <(find "$ROOT" -type f -name "tasks.json" 2>/dev/null \
    | awk -F/ '$(NF-1) == ".vscode"' \
    | sort)

  if [ "$COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}No .vscode/tasks.json found.${RESET}"
  fi
  echo
done

# ── Summary ───────────────────────────────────
echo "════════════════════════════════════════════════"
if [ "$TOTAL" -eq 0 ]; then
  echo -e "${YELLOW}No .vscode/tasks.json files found in the specified location(s).${RESET}"
else
  echo -e "${BOLD}${GREEN}Found $TOTAL file(s):${RESET}"
  echo "$FOUND_LIST" | grep -v '^$' | while IFS= read -r F; do
    echo "  $F"
  done
fi
echo