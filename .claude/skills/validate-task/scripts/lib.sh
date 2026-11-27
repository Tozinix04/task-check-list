#!/usr/bin/env bash
# Shared helpers for the TaskChecklist validation scripts.
# Sourced by check_task.sh, check_rules.sh, check_commits.sh, check_submission.sh.
# Compatible with macOS bash 3.2 (no associative arrays, no ${var,,}).

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "$LIB_DIR/../../../.." && pwd)}"   # solution folder
APP="$ROOT/TaskChecklist"                              # web project folder
CSPROJ="$APP/TaskChecklist.csproj"
BASE_URL="${BASE_URL:-http://localhost:5005}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/tc-validate.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

N_PASS=0; N_FAIL=0; N_WARN=0; N_SKIP=0
pass() { N_PASS=$((N_PASS+1)); printf '  PASS  [%s] %s\n' "$1" "$2"; }
fail() { N_FAIL=$((N_FAIL+1)); printf '  FAIL  [%s] %s\n' "$1" "$2"; }
warn() { N_WARN=$((N_WARN+1)); printf '  WARN  [%s] %s\n' "$1" "$2"; }
skip() { N_SKIP=$((N_SKIP+1)); printf '  SKIP  [%s] %s\n' "$1" "$2"; }
section() { printf '\n== %s\n' "$1"; }

summary() {
  printf '\nREZULTAT: %d pass, %d fail, %d warn, %d skip\n' "$N_PASS" "$N_FAIL" "$N_WARN" "$N_SKIP"
  [ "$N_FAIL" -eq 0 ]
}

# has FILE REGEX  -> true if the file exists and matches (extended regex)
has() { [ -f "$1" ] && grep -Eq -- "$2" "$1"; }

# check RESULT_ID MESSAGE FILE REGEX  -> PASS if matches, else FAIL
check_has() {
  if has "$3" "$4"; then pass "$1" "$2"; else fail "$1" "$2 (lipsește în ${3#$ROOT/})"; fi
}

# Source files of the app, excluding build output.
cs_files()   { find "$APP" -name '*.cs' -not -path '*/bin/*' -not -path '*/obj/*'; }
view_files() { find "$APP/Views" -name '*.cshtml'; }

# ---------- dotnet helpers ----------
sdk_majors() { dotnet --list-sdks 2>/dev/null | cut -d. -f1 | sort -u; }
target_major() { sed -nE 's/.*<TargetFramework>net([0-9]+)\..*/\1/p' "$CSPROJ" | head -1; }

BUILD_LOG="$TMP/build.log"
BUILD_DONE=""
# dotnet_build -> 0 on success; output in $BUILD_LOG (built once per script run)
dotnet_build() {
  if [ -z "$BUILD_DONE" ]; then
    (cd "$ROOT" && dotnet build "$CSPROJ" -nologo -clp:NoSummary -v q) >"$BUILD_LOG" 2>&1
    BUILD_DONE=$?
  fi
  return "$BUILD_DONE"
}
build_warning_count() { grep -cE 'warning [A-Z]+[0-9]+' "$BUILD_LOG" 2>/dev/null || true; }

# dotnet-ef from the local tool manifest or a global install
have_ef() { (cd "$ROOT" && dotnet ef --version >/dev/null 2>&1); }
ef() { (cd "$ROOT" && dotnet ef "$@" --project "$CSPROJ" --no-build); }

# ---------- HTTP helpers ----------
app_up() { curl -s -o /dev/null -m 3 "$BASE_URL/Projects"; }

# http_get PATH -> prints status code; body in $TMP/body.html
http_get() { curl -s -m 20 -o "$TMP/body.html" -w '%{http_code}' "$BASE_URL$1"; }

# Visible text of $TMP/body.html (tags stripped, whitespace collapsed)
body_text() { sed -E 's/<[^>]+>/ /g' "$TMP/body.html" | tr -s ' \t\n' ' '; }

# form_post PAGE_PATH ACTION_PATH [field=value ...]
# GETs PAGE_PATH to obtain the antiforgery cookie + token, then POSTs to ACTION_PATH.
# Prints "<status> <redirect_url>"; response body in $TMP/post.html.
form_post() {
  local page="$1" action="$2"; shift 2
  local jar="$TMP/cookies.txt"
  curl -s -m 20 -c "$jar" -b "$jar" -o "$TMP/form_page.html" "$BASE_URL$page"
  local token
  token=$(grep -oE 'name="__RequestVerificationToken"[^>]*value="[^"]*"' "$TMP/form_page.html" \
          | head -1 | sed -E 's/.*value="([^"]*)".*/\1/')
  local args=(--data-urlencode "__RequestVerificationToken=$token") kv
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  curl -s -m 20 -b "$jar" -c "$jar" -o "$TMP/post.html" \
       -w '%{http_code} %{redirect_url}' -X POST "${args[@]}" "$BASE_URL$action"
}

need_app() {
  if app_up; then return 0; fi
  skip "$1" "aplicația nu răspunde la $BASE_URL — pornește-o: dotnet run --project TaskChecklist --launch-profile http"
  return 1
}
