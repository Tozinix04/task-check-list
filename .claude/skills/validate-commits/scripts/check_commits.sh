#!/usr/bin/env bash
# Validate rule R4 "Commit each task separately with clear messages" + commit hygiene.
# Usage: check_commits.sh [--build-each]
#   --build-each   export every commit to a temp dir and run dotnet build on it
# Exit code: 0 if no FAIL.

source "$(dirname "$0")/../../validate-task/scripts/lib.sh"
BUILD_EACH=""; [ "${1:-}" = "--build-each" ] && BUILD_EACH=1
cd "$ROOT" || exit 2

section "R4 — Istoric git"
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  fail R4 "folderul nu este repository git — rulează: git init -b main && git add . && git commit -m 'chore: import base solution'"
  summary; exit 1
fi
if ! git rev-parse HEAD >/dev/null 2>&1; then fail R4 "repository fără commit-uri"; summary; exit 1; fi

git log --reverse --format='%h%x09%s' HEAD > "$TMP/log.txt"
count=$(wc -l < "$TMP/log.txt" | tr -d ' ')
echo "  INFO  $count commit-uri pe $(git rev-parse --abbrev-ref HEAD)"

# --- message quality
CC='^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9._-]+\))?!?: [^ ]'
while IFS="$(printf '\t')" read -r h s; do
  if echo "$s" | grep -Eq "$CC"; then
    desc=${s#*: }
    if [ ${#s} -gt 72 ]; then warn R4 "$h subiect > 72 caractere: $s"
    elif echo "$desc" | grep -Eq '^[A-Z][a-z]'; then warn R4 "$h descriere cu majusculă (stil PDF: lowercase): $s"
    elif echo "$s" | grep -Eq '\.$'; then warn R4 "$h subiect se termină cu punct: $s"
    elif echo "$desc" | grep -Eqi '^(wip|update|updates|changes|fix|fixes|stuff|misc|minor|test)$'; then fail R4 "$h mesaj vag: $s"
    else pass R4 "$h $s"; fi
  else
    if echo "$s" | grep -Eqi '^(merge|revert)'; then warn R4 "$h $s"
    else fail R4 "$h nu respectă formatul 'type: descriere' (ex. feat: ...): $s"; fi
  fi
done < "$TMP/log.txt"

# --- one commit per task, in order
section "Acoperire task-uri (un commit per task)"
prev=0
for spec in \
  "T0|import|initial|base solution|optional" \
  "T1|database|connection|db|required" \
  "T2|checklistitem|checklist.*(entity|migration)|migration|required" \
  "T3|display.*checklist|checklist.*(detail|display|show)|show.*checklist|required" \
  "T4|add.*checklist|checklist.*add|creat.*checklist|required" \
  "T5|toggl|completion|required" \
  "T6|progress|summary|required" \
  "T7|filter|bonus"; do
  id=${spec%%|*}; kind=${spec##*|}; rest=${spec#*|}; re=${rest%|*}
  # search only subjects after the previous task's commit, so "add ChecklistItem" (T2) is not taken for T4
  line=$(cut -f2 "$TMP/log.txt" | awk -v p="$prev" 'NR>p{print NR":"$0}' | grep -iE "^[0-9]+:.*($re)" | head -1)
  anywhere=$(cut -f2 "$TMP/log.txt" | grep -iE "$re" | head -1)
  if [ -n "$line" ]; then
    prev=${line%%:*}; pass R4 "$id → ${line#*:}"
  elif [ -n "$anywhere" ]; then
    warn R4 "$id → $anywhere (dar apare înaintea task-ului anterior — ordine neașteptată)"
  else
    case "$kind" in
      required) fail R4 "$id: niciun commit nu pare să corespundă acestui task";;
      bonus) warn R4 "$id (bonus): niciun commit de filtrare";;
      *) warn R4 "$id: nu există commit separat cu codul de bază (recomandat: chore: import base solution)";;
    esac
  fi
done
[ "$count" -gt 1 ] || fail R4 "un singur commit — fiecare task trebuie commit-uit separat"

mig_commit=$(git log --diff-filter=A --format='%h %s' -- 'TaskChecklist/Migrations/*Checklist*' | tail -1)
if [ -n "$mig_commit" ]; then
  echo "$mig_commit" | grep -qiE 'checklist|migration' && pass R4 "migrația ChecklistItems e adăugată în: $mig_commit" \
    || warn R4 "migrația ChecklistItems e adăugată într-un commit neașteptat: $mig_commit"
fi

# --- hygiene
section "Igienă repository"
FORBID='(^|/)(bin|obj)/|(^|/)\.env$|appsettings\.Development\.json$|(^|/)\.idea/|\.user$|(^|/)\.vs/'
bad=$(git ls-files | grep -E "$FORBID")
[ -z "$bad" ] && pass R4 "fără bin/obj/.env/appsettings.Development.json/.idea urmărite" || fail R4 "fișiere care nu trebuie urmărite: $(echo "$bad" | head -5 | tr '\n' ' ')"
hist=$(git log --all --format= --name-only | sort -u | grep -E "$FORBID")
[ -z "$hist" ] && pass R4 "nici în istoric nu apar fișiere interzise" || fail R4 "fișiere interzise în ISTORIC (rămân vizibile!): $(echo "$hist" | head -5 | tr '\n' ' ')"
leaks=$( { git log --all -G'Password=[^;$R{]' --format='%h %s'; git log --all -G'PASSWORD="?[^$" ]' --format='%h %s' -- . ':!*.env.example'; } | sort -u)
[ -z "$leaks" ] && pass R4 "nicio parolă în istoricul git" || fail R4 "posibile parole în commit-urile: $(echo "$leaks" | tr '\n' ';') — rescrie istoricul ÎNAINTE de push"
dirty=$(git status --porcelain | grep -v '^??' | wc -l | tr -d ' ')
[ "$dirty" = 0 ] && pass R4 "working tree curat" || warn R4 "$dirty fișiere modificate necommit-uite"
untracked=$(git status --porcelain | grep '^??' | cut -c4- | grep -vE '^(docs/|\.claude/)' | head -5)
[ -z "$untracked" ] || warn R4 "fișiere neurmărite: $(echo "$untracked" | tr '\n' ' ')"
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  ahead=$(git rev-list --count '@{u}..HEAD')
  [ "$ahead" = 0 ] && pass R4 "tot istoricul e împins pe $(git rev-parse --abbrev-ref '@{u}')" || warn R4 "$ahead commit-uri neîmpinse"
else skip R4 "branch-ul nu are upstream (git push -u origin main)"; fi

# --- optional: every commit compiles
if [ -n "$BUILD_EACH" ]; then
  section "Fiecare commit compilează"
  while IFS="$(printf '\t')" read -r h s; do
    d="$TMP/build-$h"; mkdir -p "$d"
    git archive "$h" | tar -x -C "$d"
    if [ -f "$d/TaskChecklist/TaskChecklist.csproj" ] && dotnet build "$d/TaskChecklist/TaskChecklist.csproj" -nologo -v q >"$d.log" 2>&1; then
      pass R4 "$h compilează ($s)"
    elif [ "$(git rev-parse "$h")" = "$(git rev-list --max-parents=0 HEAD | head -1)" ]; then
      warn R4 "$h (codul primit) nu compilează în mediul curent: $(grep -m1 ' error ' "$d.log" | grep -oE 'error [A-Z]+[0-9]+' | head -1)"
    else fail R4 "$h NU compilează ($s): $(grep -m1 ' error ' "$d.log" | sed 's/^ *//' | cut -c1-140)"; fi
    rm -rf "$d"
  done < "$TMP/log.txt"
fi
summary
