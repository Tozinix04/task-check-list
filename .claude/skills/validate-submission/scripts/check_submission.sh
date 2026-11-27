#!/usr/bin/env bash
# Pre-submission gate: runs every validator, then checks the Submission Checklist (S1–S4).
# Usage: check_submission.sh [--static]   (--static: no runtime HTTP checks)
# Exit code: 0 when ready to submit (no FAIL anywhere).

source "$(dirname "$0")/../../validate-task/scripts/lib.sh"
SK="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-}"

run_part() { # label command...
  local label="$1"; shift
  printf '\n######## %s\n' "$label"
  "$@" > "$TMP/part.log" 2>&1; local rc=$?
  grep -E '^\s+(FAIL|WARN)' "$TMP/part.log"
  grep -E '^REZULTAT' "$TMP/part.log"
  [ $rc -eq 0 ] && pass S "$label" || fail S "$label — are FAIL-uri (vezi mai sus)"
}

run_part "Task-uri 1–7"  "$SK/validate-task/scripts/check_task.sh" all $MODE
run_part "Reguli R1–R3"  "$SK/validate-rules/scripts/check_rules.sh"
run_part "Commit-uri R4" "$SK/validate-commits/scripts/check_commits.sh" --build-each

section "Submission checklist"
cd "$ROOT" || exit 2
remote=$(git remote get-url origin 2>/dev/null)
if [ -z "$remote" ]; then fail S1 "nu există remote 'origin' — creează repo PRIVAT pe GitHub și: git remote add origin ... && git push -u origin main"
else
  echo "$remote" | grep -q 'github.com' && pass S1 "remote GitHub: $(echo "$remote" | sed -E 's#https://[^@]*@#https://#')" || warn S1 "remote-ul nu e pe GitHub: $remote"
  if command -v gh >/dev/null 2>&1; then
    vis=$(gh repo view --json visibility -q .visibility 2>/dev/null)
    case "$vis" in PRIVATE) pass S1 "repository-ul este PRIVAT";; "") warn S1 "nu am putut citi vizibilitatea (gh auth login?)";; *) fail S1 "repository-ul este $vis — trebuie PRIVATE";; esac
    collab=$(gh api "repos/{owner}/{repo}/collaborators" -q '.[].login' 2>/dev/null | tr '\n' ' ')
    inv=$(gh api "repos/{owner}/{repo}/invitations" -q '.[].invitee.login' 2>/dev/null | tr '\n' ' ')
    if [ -n "$REVIEWERS" ]; then
      for r in $REVIEWERS; do
        echo " $collab $inv " | grep -qi " $r " && pass S2 "reviewer $r are acces/invitație" || fail S2 "reviewer $r NU are acces"
      done
    else warn S2 "colaboratori: ${collab:-?} invitații: ${inv:-?} — setează REVIEWERS=\"user1 user2\" pentru verificare"; fi
  else
    warn S1 "gh CLI lipsește — verifică manual pe GitHub: Settings → General → Danger Zone → visibility = Private"
    warn S2 "verifică manual: Settings → Collaborators → reviewerii invitați"
  fi
  if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    git fetch -q 2>/dev/null
    [ "$(git rev-list --count '@{u}..HEAD')" = 0 ] && pass S1 "toate commit-urile sunt pe remote" || fail S1 "există commit-uri neîmpinse"
  else fail S1 "branch-ul curent nu are upstream (git push -u origin main)"; fi
fi

if [ -f "$ROOT/docs/EMAIL-SUMMARY.md" ]; then
  pass S3 "draft email: docs/EMAIL-SUMMARY.md"
  grep -qiE 'limitation|limitări|improvement|îmbunătățir' "$ROOT/docs/EMAIL-SUMMARY.md" \
    && pass S4 "draftul menționează limitări/îmbunătățiri" || fail S4 "draftul nu are secțiunea de limitări/îmbunătățiri"
  grep -q 'github.com' "$ROOT/docs/EMAIL-SUMMARY.md" && pass S3 "draftul conține link-ul repo-ului" || warn S3 "draftul nu conține link-ul repo-ului"
else fail S3 "lipsește draftul docs/EMAIL-SUMMARY.md (generat de /validate-submission)"; fi
ls "$ROOT"/README* >/dev/null 2>&1 && pass S "README prezent" || warn S "fără README — reviewerii nu știu cum să ruleze proiectul"

summary && echo "GATA DE PREDARE" || echo "NU ESTE GATA — rezolvă FAIL-urile de mai sus"
