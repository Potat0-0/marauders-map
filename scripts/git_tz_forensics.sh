#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# git_tz_forensics.sh
#
# Forensic analysis of a git repository to detect:
#   1. Commits where author and committer timezones differ
#      (strong indicator of history rewriting in a foreign env)
#   2. Commits where the committer timezone is an outlier
#      compared to the repository baseline (majority timezone)
#   3. Reflog entries showing forced history rewrites:
#      forced-update, amend, rebase, reset, filter-branch
#   4. Reflog pairs where the same commit message/author-date
#      appears under two different hashes (rewritten commits)
#
# Usage:
#   ./git_tz_forensics.sh [path/to/repo]
#   ./git_tz_forensics.sh              # uses current directory
#
# Compatible with: bash 3+, zsh, macOS, Linux
# Requires: git
# ═══════════════════════════════════════════════════════════════

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m';     GREEN='\033[0;32m'
YELLOW='\033[1;33m';  CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; BLUE='\033[0;34m'
BOLD='\033[1m';       DIM='\033[2m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
header() { echo -e "\n${BOLD}${CYAN}$1${RESET}"; echo "────────────────────────────────────────────────────────"; }
flag()   { echo -e "  ${RED}${BOLD}⚑  $1${RESET}"; }
warn()   { echo -e "  ${YELLOW}⚠  $1${RESET}"; }
info()   { echo -e "  ${DIM}$1${RESET}"; }
good()   { echo -e "  ${GREEN}✔  $1${RESET}"; }

# ── Usage ─────────────────────────────────────────────────────
usage() {
  echo -e "${BOLD}Usage:${RESET} $0 [repo_path]"
  echo
  echo "  Analyses git log and reflog for timezone anomalies and"
  echo "  signs of history rewriting (amend, rebase, force-push)."
  echo
  echo "  Exits with code 1 if any anomalies are found."
  exit 0
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

# ── Resolve repo ──────────────────────────────────────────────
REPO="${1:-$(pwd)}"
if [ ! -d "$REPO" ]; then
  echo -e "${RED}Error: not a directory: $REPO${RESET}"
  exit 2
fi

cd "$REPO" || exit 2

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}Error: not a git repository: $REPO${RESET}"
  exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
echo -e "${BOLD}Repository:${RESET} $REPO_ROOT"
echo -e "${BOLD}Analysis :${RESET}  $(date '+%Y-%m-%d %H:%M:%S %Z')"

ANOMALIES=0   # total flagged items across all checks

# ═══════════════════════════════════════════════════════════════
# SECTION 1 — ESTABLISH BASELINE TIMEZONE
# Look at all commits, tally committer timezones, find the
# dominant one. Anything else is an outlier.
# ═══════════════════════════════════════════════════════════════
header "SECTION 1 · Baseline Timezone Detection"

# Collect every committer timezone offset from all commits
TZ_TALLY=$(git log --all --format="%cI" 2>/dev/null \
  | grep -oE '[+-][0-9]{2}:[0-9]{2}$' \
  | sort | uniq -c | sort -rn)

if [ -z "$TZ_TALLY" ]; then
  warn "No commits found — empty repository."
  exit 0
fi

echo -e "  ${BOLD}Committer timezone distribution:${RESET}"
echo "$TZ_TALLY" | while read -r COUNT TZ; do
  BAR=$(printf '%*s' "$((COUNT > 40 ? 40 : COUNT))" '' | tr ' ' '█')
  printf "  %6s commits  %-7s  %s\n" "$COUNT" "$TZ" "$BAR"
done

# Dominant timezone = first line (highest count)
BASELINE_TZ=$(echo "$TZ_TALLY" | awk 'NR==1{print $2}')
echo
info "Baseline (dominant) committer timezone: ${BOLD}$BASELINE_TZ${RESET}"

# ═══════════════════════════════════════════════════════════════
# SECTION 2 — AUTHOR vs COMMITTER TIMEZONE MISMATCH
# For every commit, compare the author tz offset to the
# committer tz offset. A mismatch means someone re-committed
# the work in a different environment — the classic rewrite tell.
# ═══════════════════════════════════════════════════════════════
header "SECTION 2 · Author / Committer Timezone Mismatch"

MISMATCH_COUNT=0

# Format: HASH|AUTHOR_ISO|COMMITTER_ISO|SUBJECT
git log --all --format="%H|%aI|%cI|%aN|%cN|%s" 2>/dev/null | \
while IFS='|' read -r HASH AUTHOR_ISO COMMIT_ISO ANAME CNAME SUBJECT; do

  A_TZ=$(echo "$AUTHOR_ISO"  | grep -oE '[+-][0-9]{2}:[0-9]{2}$')
  C_TZ=$(echo "$COMMIT_ISO"  | grep -oE '[+-][0-9]{2}:[0-9]{2}$')

  if [ "$A_TZ" != "$C_TZ" ]; then
    SHORT="${HASH:0:9}"
    echo -e "  ${RED}${BOLD}⚑  $SHORT${RESET}  \"$SUBJECT\""
    echo -e "       Author    date : $AUTHOR_ISO  ${DIM}($ANAME)${RESET}"
    echo -e "       Committer date : ${YELLOW}$COMMIT_ISO${RESET}  ${DIM}($CNAME)${RESET}"
    echo -e "       ${MAGENTA}Timezone shift: author=$A_TZ  committer=$C_TZ${RESET}"
    echo
    MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
  fi
done

MISMATCH_COUNT=$(git log --all --format="%aI|%cI" 2>/dev/null | awk -F'|' '
{
  a_tz = substr($1, length($1)-5)
  c_tz = substr($2, length($2)-5)
  if (a_tz != c_tz) count++
}
END { print count+0 }')

if [ "$MISMATCH_COUNT" -eq 0 ]; then
  good "No author/committer timezone mismatches found."
else
  flag "$MISMATCH_COUNT commit(s) with author≠committer timezone"
  ANOMALIES=$((ANOMALIES + MISMATCH_COUNT))
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 3 — OUTLIER COMMITTER TIMEZONE vs BASELINE
# Even if author==committer, if the committer tz differs from
# the repo baseline it warrants attention.
# ═══════════════════════════════════════════════════════════════
header "SECTION 3 · Outlier Committer Timezone (vs Baseline $BASELINE_TZ)"

OUTLIER_COUNT=0

git log --all --format="%H|%cI|%aI|%cN|%s" 2>/dev/null | \
while IFS='|' read -r HASH COMMIT_ISO AUTHOR_ISO CNAME SUBJECT; do

  C_TZ=$(echo "$COMMIT_ISO" | grep -oE '[+-][0-9]{2}:[0-9]{2}$')

  # Skip if already flagged in section 2 (same tz mismatch)
  A_TZ=$(echo "$AUTHOR_ISO" | grep -oE '[+-][0-9]{2}:[0-9]{2}$')

  if [ "$C_TZ" != "$BASELINE_TZ" ] && [ "$A_TZ" = "$C_TZ" ]; then
    SHORT="${HASH:0:9}"
    echo -e "  ${YELLOW}${BOLD}⚠  $SHORT${RESET}  \"$SUBJECT\""
    echo -e "       Committer date : $COMMIT_ISO  ${DIM}($CNAME)${RESET}"
    echo -e "       ${YELLOW}Timezone $C_TZ differs from repo baseline $BASELINE_TZ${RESET}"
    echo
    OUTLIER_COUNT=$((OUTLIER_COUNT + 1))
  fi
done

OUTLIER_COUNT=$(git log --all --format="%aI|%cI" 2>/dev/null | awk -v base="$BASELINE_TZ" -F'|' '
{
  a_tz = substr($1, length($1)-5)
  c_tz = substr($2, length($2)-5)
  if (c_tz != base && a_tz == c_tz) count++
}
END { print count+0 }')

if [ "$OUTLIER_COUNT" -eq 0 ]; then
  good "No outlier committer timezones found."
else
  warn "$OUTLIER_COUNT commit(s) with committer timezone outside baseline"
  ANOMALIES=$((ANOMALIES + OUTLIER_COUNT))
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 4 — REFLOG: FORCED REWRITES
# Scan all reflog entries for actions that indicate history
# was deliberately altered.
# ═══════════════════════════════════════════════════════════════
header "SECTION 4 · Reflog — Forced Rewrite Events"

# Patterns that indicate rewriting
REWRITE_PATTERNS="forced-update:FORCE PUSH / remote overwrote local ref
commit (amend):COMMIT AMENDED — original hash replaced
rebase:REBASE — commits replayed with new hashes
filter-branch:FILTER-BRANCH — bulk history rewrite
reset:RESET — HEAD moved, commits may be orphaned
cherry-pick:CHERRY-PICK — commit replicated with new hash"

REFLOG_FLAGS=0

# Collect all refs that have reflogs
ALL_REFS=$(git reflog list 2>/dev/null | awk '{print $NF}' || \
           git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ 2>/dev/null)

# Add HEAD always
ALL_REFS="HEAD
$ALL_REFS"

SEEN_ENTRIES=""

while IFS= read -r REF; do
  [ -z "$REF" ] && continue

  # Get reflog for this ref: hash, short-hash, action subject
  git reflog show "$REF" --format="%H %h %gs" 2>/dev/null | \
  while IFS= read -r RLINE; do
    FULL_HASH=$(echo "$RLINE" | awk '{print $1}')
    SHORT_HASH=$(echo "$RLINE" | awk '{print $2}')
    ACTION=$(echo "$RLINE" | cut -d' ' -f3-)

    # Deduplicate entries seen across multiple refs
    KEY="$FULL_HASH:$ACTION"
    case "$SEEN_ENTRIES" in
      *"$KEY"*) continue ;;
    esac
    SEEN_ENTRIES="$SEEN_ENTRIES$KEY
"

    # Check against each rewrite pattern
    echo "$REWRITE_PATTERNS" | while IFS=: read -r PATTERN LABEL; do
      [ -z "$PATTERN" ] && continue
      case "$ACTION" in
        *"$PATTERN"*)
          echo -e "  ${RED}${BOLD}⚑  [$LABEL]${RESET}"
          echo -e "       Ref    : $REF"
          echo -e "       Commit : $SHORT_HASH  (${FULL_HASH:0:12}...)"
          echo -e "       Action : ${YELLOW}$ACTION${RESET}"
          echo
          ;;
      esac
    done
  done

done << REFS_EOF
$ALL_REFS
REFS_EOF

# Count reflog flags for summary
REFLOG_FLAGS=$(
  {
    echo "$ALL_REFS" | while IFS= read -r REF; do
      [ -z "$REF" ] && continue
      git reflog show "$REF" --format="%gs" 2>/dev/null
    done
  } | grep -cEi "forced-update|commit \(amend\)|rebase|filter-branch" || true
)

if [ "${REFLOG_FLAGS:-0}" -eq 0 ]; then
  good "No forced rewrite events found in reflog."
else
  flag "$REFLOG_FLAGS rewrite event(s) found in reflog"
  ANOMALIES=$((ANOMALIES + REFLOG_FLAGS))
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 5 — REFLOG TWIN DETECTION
# Look for pairs of commits in the reflog that share the same
# commit message AND author date but have different hashes.
# This is the fingerprint of a rewritten commit: the rewriter
# preserved the metadata but produced a new object.
# ═══════════════════════════════════════════════════════════════
header "SECTION 5 · Reflog Twin Detection (same message+date, different hash)"

# Collect all hashes ever seen in any reflog
ALL_REFLOG_HASHES=$(
  echo "$ALL_REFS" | while IFS= read -r REF; do
    [ -z "$REF" ] && continue
    git reflog show "$REF" --format="%H" 2>/dev/null
  done | sort -u
)

# For each unique hash in reflog, get: author-date|subject|hash
# Then find duplicates on (author-date, subject) with different hashes
TWIN_DATA=$(
  echo "$ALL_REFLOG_HASHES" | while IFS= read -r H; do
    [ -z "$H" ] && continue
    # git cat-file to read even orphaned commits not in current log
    INFO=$(git log -1 --format="%aI|%s" "$H" 2>/dev/null || true)
    [ -z "$INFO" ] && continue
    echo "$INFO|$H"
  done
)

# Group by "author_date|subject", collect all hashes per group
TWINS=$(echo "$TWIN_DATA" | sort | awk -F'|' '
{
  key = $1 "|" $2
  hashes[key] = hashes[key] (hashes[key] ? " " : "") $3
  count[key]++
}
END {
  for (k in count) {
    if (count[k] > 1) {
      print k "|" hashes[k]
    }
  }
}')

TWIN_COUNT=0

if [ -n "$TWINS" ]; then
  echo "$TWINS" | while IFS='|' read -r ADATE SUBJECT HASHES; do
    echo -e "  ${RED}${BOLD}⚑  Twin commits detected:${RESET}"
    echo -e "       Message     : \"$SUBJECT\""
    echo -e "       Author date : $ADATE"
    echo -e "       ${YELLOW}Hashes (should be unique):${RESET}"
    for H in $HASHES; do
      # Get committer date and tz for each twin
      CDATE=$(git log -1 --format="%cI" "$H" 2>/dev/null || echo "unknown")
      C_TZ=$(echo "$CDATE" | grep -oE '[+-][0-9]{2}:[0-9]{2}$')
      A_TZ=$(echo "$ADATE" | grep -oE '[+-][0-9]{2}:[0-9]{2}$')
      TZ_NOTE=""
      [ "$A_TZ" != "$C_TZ" ] && TZ_NOTE="${RED} ← tz mismatch (committed in $C_TZ)${RESET}"
      echo -e "         ${CYAN}${H:0:12}...${RESET}  committer=$CDATE$TZ_NOTE"
    done
    echo
    TWIN_COUNT=$((TWIN_COUNT + 1))
  done
  TWIN_COUNT=$(echo "$TWINS" | grep -c '.' || true)
fi

if [ "$TWIN_COUNT" -eq 0 ]; then
  good "No twin commits found."
else
  flag "$TWIN_COUNT twin commit group(s) — original and rewritten versions present"
  ANOMALIES=$((ANOMALIES + TWIN_COUNT))
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 6 — CHRONOLOGY VIOLATIONS
# Author date should never be after committer date on the same
# commit (impossible without clock manipulation or rewriting).
# Also flag commits where author date is implausibly far in the
# future or past relative to surrounding commits.
# ═══════════════════════════════════════════════════════════════
header "SECTION 6 · Chronology Violations"

CHRON_COUNT=0

git log --all --format="%H|%at|%ct|%aI|%cI|%s" 2>/dev/null | \
while IFS='|' read -r HASH A_EPOCH C_EPOCH A_ISO C_ISO SUBJECT; do
  SHORT="${HASH:0:9}"

  # Author date after committer date (clock skew or rewrite artifact)
  if [ "$A_EPOCH" -gt "$C_EPOCH" ] 2>/dev/null; then
    DIFF=$((A_EPOCH - C_EPOCH))
    echo -e "  ${RED}${BOLD}⚑  $SHORT${RESET}  \"$SUBJECT\""
    echo -e "       Author date    : $A_ISO"
    echo -e "       Committer date : $C_ISO"
    echo -e "       ${RED}Author is ${DIFF}s AFTER committer — impossible without rewrite${RESET}"
    echo
    CHRON_COUNT=$((CHRON_COUNT + 1))
  fi
done

CHRON_COUNT=$(git log --all --format="%at|%ct" 2>/dev/null | awk -F'|' '
  $1 > $2 { count++ }
  END { print count+0 }')

if [ "$CHRON_COUNT" -eq 0 ]; then
  good "No chronology violations found."
else
  flag "$CHRON_COUNT commit(s) where author date is after committer date"
  ANOMALIES=$((ANOMALIES + CHRON_COUNT))
fi

# ═══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════
echo
echo "════════════════════════════════════════════════════════"
echo -e "${BOLD}FORENSIC SUMMARY${RESET}"
echo "════════════════════════════════════════════════════════"
echo -e "  Repository  : $REPO_ROOT"
echo -e "  Baseline TZ : $BASELINE_TZ"
echo

if [ "$ANOMALIES" -eq 0 ]; then
  good "No anomalies detected. History appears consistent."
  echo
  exit 0
else
  echo -e "  ${RED}${BOLD}⚑  $ANOMALIES anomaly/anomalies detected across all checks.${RESET}"
  echo
  echo -e "  ${BOLD}What to do next:${RESET}"
  echo -e "  • Compare flagged hashes against any remote backup or"
  echo -e "    colleague's clone to confirm what the original tree was"
  echo -e "  • Run: ${CYAN}git show <original_hash>${RESET} vs ${CYAN}git show <rewritten_hash>${RESET}"
  echo -e "  • Check: ${CYAN}git diff <original_hash> <rewritten_hash>${RESET}"
  echo -e "  • Run: ${CYAN}git fsck --full --unreachable${RESET} to find orphaned objects"
  echo -e "  • Check remote refs: ${CYAN}git ls-remote origin${RESET}"
  echo
  exit 1
fi