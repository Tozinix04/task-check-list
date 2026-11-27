#!/usr/bin/env bash
# Validate the cross-cutting "Requirements & Rules" from Task.pdf:
#   R1 EF Core migrations for schema changes
#   R2 Server-side validation
#   R3 Clean, readable code
#   (R4 commits -> check_commits.sh)
# Usage: check_rules.sh [--no-format]
# Exit code: 0 if no FAIL.

source "$(dirname "$0")/../../validate-task/scripts/lib.sh"
MIG="$APP/Migrations"; C="$APP/Controllers"
NO_FORMAT=""; [ "${1:-}" = "--no-format" ] && NO_FORMAT=1
NON_MIG_CS="$TMP/nonmig.txt"; cs_files | grep -v '/Migrations/' > "$NON_MIG_CS"

# ---------------------------------------------------------------- R1
section "R1 — EF Core migrations pentru schimbări de schemă"
if xargs grep -ln 'EnsureCreated' < "$NON_MIG_CS" 2>/dev/null | grep -q .; then
  fail R1 "EnsureCreated() folosit — schema trebuie creată doar prin migrații"
else pass R1 "nu se folosește EnsureCreated()"; fi
if xargs grep -lniE '(CREATE|ALTER|DROP) TABLE' < "$NON_MIG_CS" 2>/dev/null | grep -q .; then
  fail R1 "SQL DDL manual în cod C# în afara Migrations/: $(xargs grep -liE '(CREATE|ALTER|DROP) TABLE' < "$NON_MIG_CS" | sed "s|$ROOT/||" | tr '\n' ' ')"
else pass R1 "fără DDL manual în cod C#"; fi
if grep -q 'Database.Migrate' "$APP/Program.cs"; then pass R1 "migrațiile se aplică la startup (Database.Migrate)"; fi

snapshot="$MIG/ApplicationDbContextModelSnapshot.cs"
for e in $(grep -oE 'DbSet<[A-Za-z]+>' "$APP/Data/ApplicationDbContext.cs" | sed -E 's/DbSet<(.*)>/\1/'); do
  if grep -q "TaskChecklist.Models.$e\"" "$snapshot"; then pass R1 "entitatea $e e în snapshot-ul migrațiilor"
  else fail R1 "entitatea $e nu apare în snapshot — lipsește migrația"; fi
done

for m in $(ls "$MIG"/*.cs 2>/dev/null | grep -v -e '\.Designer\.cs$' -e 'ModelSnapshot'); do
  n=$(basename "$m" .cs); short=${n#*_}
  [ -f "$MIG/$n.Designer.cs" ] && pass R1 "$n are Designer" || fail R1 "$n fără fișier Designer (creat manual?)"
  if awk '/void Down/{f=1} f' "$m" | grep -qE 'Drop(Table|Column|Index|ForeignKey)|DeleteData'; then pass R1 "$n are Down() funcțional"
  else warn R1 "$n: Down() pare gol"; fi
  if echo "$short" | grep -qiE '^(migration|test|update|new|temp|m)[0-9]*$'; then warn R1 "nume de migrație nedescriptiv: $short"; fi
done

if grep -q 'ChecklistItems' "$APP/Data/sqlserver-init.sql" 2>/dev/null; then
  warn R1 "sqlserver-init.sql creează ChecklistItems manual — schema nouă trebuie să vină doar din migrație"
fi
if have_ef; then
  if dotnet_build && ef migrations has-pending-model-changes >"$TMP/ef.log" 2>&1; then pass R1 "model sincronizat cu migrațiile (has-pending-model-changes)"
  else fail R1 "modificări de model nemigrate sau build eșuat: $(tail -1 "$TMP/ef.log" 2>/dev/null | cut -c1-160)"; fi
else skip R1 "dotnet-ef indisponibil — nu pot rula has-pending-model-changes"; fi

# ---------------------------------------------------------------- R2
section "R2 — Validare server-side"
global_af=""; grep -q 'AutoValidateAntiforgeryToken' "$APP/Program.cs" && global_af=1
# Split controllers into actions and report: name, isPost, hasAntiforgery, bindsModel, checksModelState, saves, bindsEntityWithoutBind
for f in "$C"/*.cs; do
  awk -v file="$(basename "$f")" '
    function flush() {
      if (name == "") return
      binds = (sig ~ /[A-Z][A-Za-z0-9_<>?]* +[a-z][A-Za-z0-9_]*[,)]/)
      entity = (sig ~ /(Project|TaskItem|ChecklistItem) +[a-z]/) && (sig !~ /\[Bind/)
      printf "%s|%s|%d|%d|%d|%d|%d|%d\n", file, name, ispost, af, binds, (body ~ /ModelState\.IsValid/), (body ~ /SaveChanges/), entity
      name = ""
    }
    /\[HttpPost/                 { pend_post = 1 }
    /\[ValidateAntiForgeryToken/ { pend_af = 1 }
    /public .*IActionResult> *[A-Za-z0-9_]+\(/ {
      flush()
      match($0, /IActionResult> *[A-Za-z0-9_]+\(/)
      name = substr($0, RSTART, RLENGTH); sub(/IActionResult> */, "", name); sub(/\($/, "", name)
      ispost = pend_post; af = pend_af; pend_post = 0; pend_af = 0
      sig = $0; insig = ($0 !~ /\)/); body = ""; next
    }
    /private |protected / { flush() }
    name != "" && insig { sig = sig $0; if ($0 ~ /\)/) insig = 0; next }
    name != "" { body = body $0 }
    END { flush() }
  ' "$f"
done > "$TMP/actions.txt"

while IFS='|' read -r file name ispost af binds valid saves entity; do
  a="$file:$name"
  if [ "$ispost" = 1 ]; then
    if [ "$af" = 1 ] || [ -n "$global_af" ]; then pass R2 "$a [HttpPost] are antiforgery"
    else fail R2 "$a [HttpPost] fără [ValidateAntiForgeryToken]"; fi
    if [ "$binds" = 1 ]; then
      [ "$valid" = 1 ] && pass R2 "$a verifică ModelState.IsValid" || fail R2 "$a leagă un model dar nu verifică ModelState.IsValid"
    fi
    [ "$entity" = 1 ] && warn R2 "$a leagă direct o entitate fără [Bind] — risc de over-posting"
  else
    [ "$saves" = 1 ] && fail R2 "$a modifică datele (SaveChanges) pe GET — trebuie [HttpPost]"
  fi
done < "$TMP/actions.txt"

for f in "$APP/Models/ChecklistItem.cs" "$APP/ViewModels/ChecklistItemInputModel.cs"; do
  [ -f "$f" ] || continue
  n=$(basename "$f")
  grep -q '\[Required' "$f" && pass R2 "$n: Title [Required]" || fail R2 "$n: Title fără [Required]"
  grep -qE '(StringLength|MaxLength)\(' "$f" && pass R2 "$n: Title are limită de lungime" || fail R2 "$n: Title fără [StringLength]"
done
if [ -f "$APP/Models/ChecklistItem.cs" ]; then
  grep -q 'ValidateNever' "$APP/Models/ChecklistItem.cs" && pass R2 "ChecklistItem.TaskItem are [ValidateNever]" \
    || warn R2 "ChecklistItem.TaskItem fără [ValidateNever] — ModelState poate fi invalid fals"
fi
for v in $(view_files); do
  if grep -q '<form' "$v" && grep -E '<(input|textarea|select)[^>]*asp-for=' "$v" | grep -vq 'type="hidden"'; then
    grep -q 'asp-validation-' "$v" || warn R2 "${v#$APP/} are formular fără asp-validation-for / summary"
  fi
  grep -q 'Html.Raw' "$v" && warn R2 "${v#$APP/} folosește Html.Raw — verifică XSS"
done

# ---------------------------------------------------------------- R3
section "R3 — Cod curat și lizibil"
if dotnet_build; then
  w=$(grep -E 'warning [A-Z]+[0-9]+' "$BUILD_LOG" | sed -E 's/\[[^]]*\]$//' | sort -u | wc -l | tr -d ' ')
  [ "$w" = 0 ] && pass R3 "build fără warning-uri" || warn R3 "build cu $w warning-uri unice (vezi: dotnet build)"
else fail R3 "build eșuat"; fi

if [ -z "$NO_FORMAT" ] && dotnet_build; then
  if (cd "$ROOT" && dotnet format "$CSPROJ" --verify-no-changes --no-restore -v q) >"$TMP/fmt.log" 2>&1; then
    pass R3 "dotnet format: fără diferențe de stil"
  else warn R3 "dotnet format raportează diferențe: $(grep -oE '[A-Za-z]+\.cs\([0-9]+' "$TMP/fmt.log" | sort -u | head -5 | tr '\n' ' ')"; fi
fi

if view_files | xargs grep -lE '_context|DbContext' 2>/dev/null | grep -q .; then fail R3 "acces la DbContext din view-uri"
else pass R3 "view-urile nu accesează DbContext"; fi
if view_files | xargs grep -lE '\* *100|100 *\*|\.Count\([a-z]+ *=>' 2>/dev/null | grep -q .; then
  warn R3 "calcule în view-uri: $(view_files | xargs grep -lE '\* *100|100 *\*|\.Count\([a-z]+ *=>' | sed "s|$APP/||" | tr '\n' ' ')"
else pass R3 "fără calcule de business în view-uri"; fi
hits=$(xargs grep -nE 'Console\.Write|TODO|FIXME|HACK' < "$NON_MIG_CS" 2>/dev/null | sed "s|$ROOT/||")
[ -z "$hits" ] && pass R3 "fără Console.Write / TODO / FIXME" || warn R3 "de curățat: $(echo "$hits" | head -3 | tr '\n' ' ')"
hits=$(xargs grep -nE '^\s*//.*;\s*$' < "$NON_MIG_CS" 2>/dev/null | sed "s|$ROOT/||")
[ -z "$hits" ] && pass R3 "fără cod comentat" || warn R3 "posibil cod comentat: $(echo "$hits" | head -3 | tr '\n' ' ')"
hits=$(xargs grep -nE '(ToList|ToListAsync|AsEnumerable)\(\)\)?\s*\.(Where|Count|Sum)\(' < "$NON_MIG_CS" 2>/dev/null | sed "s|$ROOT/||")
[ -z "$hits" ] && pass R3 "LINQ: fără filtrare în memorie după materializare" || warn R3 "filtrare în memorie: $(echo "$hits" | head -3 | tr '\n' ' ')"

secret_files=$(cd "$ROOT" && { if [ -d .git ]; then git ls-files; else find . -type f -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' -not -path './.claude/*' -not -name '.env' -not -name 'appsettings.Development.json' | sed 's|^\./||'; fi; } \
  | grep -vE '(^|/)\.env\.example$' | xargs grep -lE 'Password=[^;$R{]|PASSWORD="?[^$" ]' 2>/dev/null)
[ -z "$secret_files" ] && pass R3 "nicio parolă în fișierele care se vor commit-ui" || fail R3 "parolă în: $secret_files"

echo
echo "  INFO  R4 (commit-uri) → rulează .claude/skills/validate-commits/scripts/check_commits.sh"
summary
