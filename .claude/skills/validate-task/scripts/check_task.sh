#!/usr/bin/env bash
# Validate one task from Task.pdf against the acceptance criteria in docs/SPECIFICATII.md.
# Usage: check_task.sh <1-7|all> [--static]
#   --static   skip runtime (HTTP) checks
# Env: BASE_URL (default http://localhost:5005), TEST_TASK_ID (default 1),
#      EMPTY_TASK_ID (default 8, a task with no checklist items)
# Exit code: 0 if no FAIL, 1 otherwise.

source "$(dirname "$0")/lib.sh"

TASK="${1:-}"; MODE="${2:-}"
TEST_TASK_ID="${TEST_TASK_ID:-1}"
EMPTY_TASK_ID="${EMPTY_TASK_ID:-8}"
M="$APP/Models"; C="$APP/Controllers"; V="$APP/Views"; MIG="$APP/Migrations"
runtime() { [ "$MODE" != "--static" ] && need_app "$1"; }

# Signature + up to 6 preceding lines (attributes) of an action, from any controller.
action_head() { cat "$C"/*.cs 2>/dev/null | grep -B6 -E "IActionResult> *$1\("; }

# ---------------------------------------------------------------- Task 1
task1() {
  section "Task 1 — Configure Database Connection"
  local tf sdks; tf=$(target_major); sdks=$(sdk_majors | tr '\n' ' ')
  if sdk_majors | grep -qx "$tf"; then pass T1-AC1 "SDK .NET $tf instalat pentru net$tf.0"
  else fail T1-AC1 "csproj țintește net$tf.0, dar SDK-uri instalate: ${sdks:-niciunul} (instalează SDK $tf sau retarget)"; fi

  if dotnet_build; then pass T1-AC1 "dotnet build reușit ($(build_warning_count) warning-uri)"
  else fail T1-AC1 "dotnet build eșuat: $(grep -m1 -E 'error' "$BUILD_LOG" | sed 's/^ *//' | cut -c1-160)"; fi

  local port; port=$(sed -nE 's/^MSSQL_PORT=([0-9]+).*/\1/p' "$ROOT/.env" 2>/dev/null); port=${port:-1433}
  if nc -z -G 2 127.0.0.1 "$port" >/dev/null 2>&1; then pass T1-AC2 "SQL Server ascultă pe 127.0.0.1:$port"
  else fail T1-AC2 "nimic nu ascultă pe 127.0.0.1:$port — rulează: docker compose up -d"; fi

  if grep -Eq 'Password=[^;]*REPLACE_WITH' "$APP/appsettings.json" || ! grep -q 'Password=' "$APP/appsettings.json"; then
    pass T1-AC5 "appsettings.json nu conține o parolă reală"
  else fail T1-AC5 "appsettings.json pare să conțină o parolă reală — mut-o în user-secrets / appsettings.Development.json"; fi
  if grep -Eq 'PASSWORD: *\$\{' "$ROOT/docker-compose.yml"; then pass T1-AC5 "docker-compose.yml citește parola din .env"
  else warn T1-AC5 "verifică manual că docker-compose.yml nu conține parola în clar"; fi
  if [ -d "$ROOT/.git" ]; then
    if (cd "$ROOT" && git ls-files | grep -Eq '(^|/)\.env$|appsettings\.Development\.json$'); then
      fail T1-AC5 ".env sau appsettings.Development.json sunt urmărite de git"
    else pass T1-AC5 ".env și appsettings.Development.json nu sunt în git"; fi
  fi

  if ls "$ROOT"/README* >/dev/null 2>&1 && grep -qiE 'docker compose|docker-compose' "$ROOT"/README*; then
    pass T1-AC6 "README cu instrucțiuni de rulare"
  else warn T1-AC6 "lipsește README cu pașii de rulare (docker compose, connection string, dotnet run)"; fi
  if have_ef; then pass T1 "dotnet-ef disponibil"; else warn T1 "dotnet-ef lipsește (dotnet new tool-manifest && dotnet tool install dotnet-ef)"; fi

  runtime T1-AC3 || return 0
  local code; code=$(http_get /Projects)
  if [ "$code" = 200 ] && grep -q 'Website Redesign' "$TMP/body.html"; then pass T1-AC3 "/Projects afișează date din DB"
  else fail T1-AC3 "/Projects → $code sau fără date seed"; fi
  for p in /Projects/Details/1 /Tasks/Details/1 /Tasks; do
    code=$(http_get "$p"); [ "$code" = 200 ] && pass T1-AC4 "$p → 200" || fail T1-AC4 "$p → $code"
  done
}

# ---------------------------------------------------------------- Task 2
task2() {
  section "Task 2 — ChecklistItem entity + migration"
  local f="$M/ChecklistItem.cs"
  if [ -f "$f" ]; then
    for p in 'int Id' 'int TaskItemId' 'string Title' 'bool IsDone' 'TaskItem TaskItem'; do
      check_has T2-AC1 "ChecklistItem are '$p'" "$f" "public $p *\{"
    done
    check_has T2-AC2 "Title are [Required]" "$f" '\[Required'
    check_has T2-AC2 "Title are [StringLength(200)] / [MaxLength]" "$f" '(StringLength|MaxLength)\(200'
    check_has T2-AC2 "navigarea TaskItem are [ValidateNever]" "$f" 'ValidateNever'
  else fail T2-AC1 "lipsește Models/ChecklistItem.cs"; fi
  check_has T2-AC3 "TaskItem.ChecklistItems (colecție)" "$M/TaskItem.cs" 'ICollection<ChecklistItem> +ChecklistItems'
  check_has T2-AC3 "DbSet<ChecklistItem> în ApplicationDbContext" "$APP/Data/ApplicationDbContext.cs" 'DbSet<ChecklistItem>'
  check_has T2-AC4 "relație configurată WithMany(...ChecklistItems)" "$APP/Data/ApplicationDbContext.cs" 'WithMany\([a-z]+ *=> *[a-z]+\.ChecklistItems\)'
  check_has T2-AC4 "FK TaskItemId configurat" "$APP/Data/ApplicationDbContext.cs" 'HasForeignKey\([a-z]+ *=> *[a-z]+\.TaskItemId\)'

  local mig; mig=$(grep -lE 'name: "ChecklistItems"' "$MIG"/*.cs 2>/dev/null | grep -v -e Designer -e Snapshot | head -1)
  if [ -n "$mig" ]; then
    pass T2-AC5 "migrație care creează ChecklistItems: $(basename "$mig")"
    check_has T2-AC4 "FK cu ReferentialAction.Cascade în migrație" "$mig" 'onDelete: ReferentialAction\.Cascade'
    check_has T2-AC5 "Down() face DropTable(ChecklistItems)" "$mig" 'DropTable\('
    [ -f "${mig%.cs}.Designer.cs" ] && pass T2-AC5 "fișierul Designer există" || fail T2-AC5 "lipsește ${mig##*/} Designer"
  else fail T2-AC5 "nicio migrație nu creează tabelul ChecklistItems (dotnet ef migrations add AddChecklistItems)"; fi
  check_has T2-AC5 "snapshot-ul conține ChecklistItem" "$MIG/ApplicationDbContextModelSnapshot.cs" 'TaskChecklist\.Models\.ChecklistItem"'

  if dotnet_build; then pass T2-AC8 "build reușit"; else fail T2-AC8 "build eșuat"; return 0; fi
  if have_ef; then
    if ef migrations has-pending-model-changes >"$TMP/ef.log" 2>&1; then pass T2-AC7 "nicio modificare de model nemigrată"
    else fail T2-AC7 "modelul are modificări nemigrate: $(tail -1 "$TMP/ef.log" | cut -c1-160)"; fi
    if ef migrations list >"$TMP/ef.log" 2>&1; then
      if grep -q '(Pending)' "$TMP/ef.log"; then fail T2-AC6 "migrații neaplicate: $(grep '(Pending)' "$TMP/ef.log" | tr '\n' ' ')"
      else pass T2-AC6 "toate migrațiile sunt aplicate în DB"; fi
    else warn T2-AC6 "nu am putut lista migrațiile (DB pornit? connection string?)"; fi
  else skip T2-AC6 "dotnet-ef lipsește — nu pot verifica migrațiile aplicate / pending"; fi

  runtime T2-AC8 || return 0
  local code; code=$(http_get "/Tasks/Details/$TEST_TASK_ID")
  [ "$code" = 200 ] && pass T2-AC8 "aplicația încarcă /Tasks/Details/$TEST_TASK_ID" || fail T2-AC8 "/Tasks/Details/$TEST_TASK_ID → $code"
}

# ---------------------------------------------------------------- Task 3
task3() {
  section "Task 3 — Display checklist items"
  check_has T3-AC1 "TasksController încarcă ChecklistItems" "$C/TasksController.cs" 'ChecklistItems'
  check_has T3-AC2 "Tasks/Details.cshtml afișează ChecklistItems" "$V/Tasks/Details.cshtml" 'ChecklistItems'
  check_has T3-AC3 "mesaj „No checklist items yet” în view" "$V/Tasks/Details.cshtml" 'No checklist items yet'
  check_has T3-AC4 "itemii IsDone se disting vizual" "$V/Tasks/Details.cshtml" 'IsDone'
  if grep -q 'Html.Raw' "$V/Tasks/Details.cshtml"; then warn T3 "Html.Raw în Details.cshtml — verifică să nu fie pe input utilizator"; fi

  runtime T3-AC2 || return 0
  local code; code=$(http_get "/Tasks/Details/$TEST_TASK_ID")
  if [ "$code" = 200 ] && grep -qi 'checklist' "$TMP/body.html"; then pass T3-AC2 "secțiunea Checklist apare pe /Tasks/Details/$TEST_TASK_ID"
  else fail T3-AC2 "/Tasks/Details/$TEST_TASK_ID → $code sau fără secțiune Checklist"; fi
  code=$(http_get "/Tasks/Details/$EMPTY_TASK_ID")
  if grep -q 'No checklist items yet' "$TMP/body.html"; then pass T3-AC3 "task $EMPTY_TASK_ID fără itemi → mesaj prietenos"
  else warn T3-AC3 "task $EMPTY_TASK_ID nu afișează mesajul gol (are deja itemi? setează EMPTY_TASK_ID)"; fi
  code=$(http_get /Tasks/Details/999999); [ "$code" = 404 ] && pass T3-AC5 "id inexistent → 404" || fail T3-AC5 "id inexistent → $code"
  code=$(http_get /Tasks/Details);        [ "$code" = 404 ] && pass T3-AC5 "fără id → 404" || fail T3-AC5 "fără id → $code"
}

# ---------------------------------------------------------------- Task 4
task4() {
  section "Task 4 — Add checklist items"
  local head; head=$(action_head AddChecklistItem)
  if [ -n "$head" ]; then
    pass T4 "acțiunea AddChecklistItem există"
    echo "$head" | grep -q '\[HttpPost' && pass T4-AC2 "AddChecklistItem are [HttpPost]" || fail T4-AC2 "AddChecklistItem fără [HttpPost]"
    echo "$head" | grep -q 'ValidateAntiForgeryToken' && pass T4-AC2 "AddChecklistItem are [ValidateAntiForgeryToken]" || fail T4-AC2 "AddChecklistItem fără [ValidateAntiForgeryToken]"
  else fail T4 "nu găsesc acțiunea AddChecklistItem (numele din specificație)"; fi
  if [ -f "$APP/ViewModels/ChecklistItemInputModel.cs" ]; then
    check_has T4-AC7 "ChecklistItemInputModel.Title are [Required]" "$APP/ViewModels/ChecklistItemInputModel.cs" '\[Required'
    check_has T4-AC4 "ChecklistItemInputModel.Title are [StringLength(200)]" "$APP/ViewModels/ChecklistItemInputModel.cs" 'StringLength\(200'
  else warn T4-AC7 "nu există ViewModels/ChecklistItemInputModel.cs — verifică protecția la over-posting ([Bind])"; fi
  local d="$V/Tasks/Details.cshtml"
  check_has T4-AC1 "formular asp-action=AddChecklistItem" "$d" 'asp-action="AddChecklistItem"'
  check_has T4-AC1 "câmp NewChecklistItem.Title" "$d" 'asp-for="NewChecklistItem\.Title"'
  check_has T4-AC1 "checkbox NewChecklistItem.IsDone" "$d" 'asp-for="NewChecklistItem\.IsDone"'
  check_has T4-AC3 "asp-validation-for pe Title" "$d" 'asp-validation-for="NewChecklistItem\.Title"'

  runtime T4-AC3 || return 0
  local page="/Tasks/Details/$TEST_TASK_ID" act="/Tasks/AddChecklistItem/$TEST_TASK_ID" r
  r=$(form_post "$page" "$act" "NewChecklistItem.Title=" "NewChecklistItem.IsDone=false")
  if [ "${r%% *}" = 200 ] && grep -qi 'required' "$TMP/post.html"; then pass T4-AC3 "Title gol (fără JS) → re-afișare cu eroare"
  else fail T4-AC3 "Title gol → '$r' (așteptat 200 + mesaj 'required')"; fi
  r=$(form_post "$page" "$act" "NewChecklistItem.Title=    " "NewChecklistItem.IsDone=false")
  [ "${r%% *}" = 200 ] && pass T4-AC3 "Title doar spații → respins" || fail T4-AC3 "Title doar spații → '$r' (a fost acceptat?)"
  local long="__validate_long__$(printf 'x%.0s' $(seq 1 200))"
  r=$(form_post "$page" "$act" "NewChecklistItem.Title=$long" "NewChecklistItem.IsDone=false")
  http_get "$page" >/dev/null
  if [ "${r%% *}" = 200 ] && ! grep -q '__validate_long__' "$TMP/body.html"; then pass T4-AC4 "Title > 200 caractere → respins, nesalvat"
  else fail T4-AC4 "Title > 200 → '$r' sau a fost salvat"; fi
  local title="__validate__ $(date +%H%M%S)"
  r=$(form_post "$page" "$act" "NewChecklistItem.Title=$title" "NewChecklistItem.IsDone=false")
  case "$r" in
    302*"/Tasks/Details/$TEST_TASK_ID") pass T4-AC5 "POST valid → 302 la $page";;
    *) fail T4-AC5 "POST valid → '$r' (așteptat 302 către $page)";;
  esac
  http_get "$page" >/dev/null
  grep -qF "$title" "$TMP/body.html" && pass T4-AC5 "itemul „$title” apare în listă" || fail T4-AC5 "itemul nou nu apare pe pagină"
  r=$(form_post "$page" "/Tasks/AddChecklistItem/999999" "NewChecklistItem.Title=x")
  [ "${r%% *}" = 404 ] && pass T4-AC6 "task inexistent → 404" || fail T4-AC6 "task inexistent → '$r'"
  r=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST --data-urlencode "NewChecklistItem.Title=x" "$BASE_URL$act")
  [ "$r" = 400 ] && pass T4-AC2 "POST fără antiforgery token → 400" || fail T4-AC2 "POST fără antiforgery token → $r"
  echo "  INFO  itemi de test creați cu prefixul '__validate__' pe task $TEST_TASK_ID"
}

# ---------------------------------------------------------------- Task 5
task5() {
  section "Task 5 — Toggle IsDone"
  local head; head=$(action_head ToggleChecklistItem)
  if [ -n "$head" ]; then
    echo "$head" | grep -q '\[HttpPost' && pass T5-AC1 "ToggleChecklistItem are [HttpPost]" || fail T5-AC5 "ToggleChecklistItem nu e POST (schimbare de stare prin GET)"
    echo "$head" | grep -q 'ValidateAntiForgeryToken' && pass T5-AC1 "ToggleChecklistItem are [ValidateAntiForgeryToken]" || fail T5-AC1 "ToggleChecklistItem fără antiforgery"
  else fail T5 "nu găsesc acțiunea ToggleChecklistItem"; fi
  if cat "$C"/*.cs | grep -Eq 'IsDone *= *!|IsDone *\^= *true'; then pass T5-AC2 "IsDone este inversat în controller"
  else warn T5-AC2 "nu găsesc 'IsDone = !...' — verifică manual logica de toggle"; fi
  check_has T5-AC1 "view: form asp-action=ToggleChecklistItem" "$V/Tasks/Details.cshtml" 'asp-action="ToggleChecklistItem"'

  runtime T5-AC2 || return 0
  local page="/Tasks/Details/$TEST_TASK_ID"
  http_get "$page" >/dev/null
  local id; id=$(grep -oE 'ToggleChecklistItem/[0-9]+' "$TMP/body.html" | head -1 | cut -d/ -f2)
  if [ -z "$id" ]; then skip T5-AC2 "task $TEST_TASK_ID nu are itemi — rulează întâi validarea Task 4"; return 0; fi
  snap() { http_get "$page" >/dev/null; grep -vE 'RequestVerificationToken|alert' "$TMP/body.html" > "$TMP/$1"; }
  snap s0
  local r; r=$(form_post "$page" "/Tasks/ToggleChecklistItem/$id")
  case "$r" in 302*"/Tasks/Details/$TEST_TASK_ID") pass T5-AC3 "toggle → 302 la $page";; *) fail T5-AC3 "toggle → '$r'";; esac
  snap s1
  cmp -s "$TMP/s0" "$TMP/s1" && fail T5-AC2 "pagina nu s-a schimbat după toggle (item $id)" || pass T5-AC2 "starea itemului $id s-a schimbat"
  form_post "$page" "/Tasks/ToggleChecklistItem/$id" >/dev/null
  snap s2
  cmp -s "$TMP/s0" "$TMP/s2" && pass T5-AC4 "două toggle-uri → starea inițială" || fail T5-AC4 "după două toggle-uri starea diferă"
  r=$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$BASE_URL/Tasks/ToggleChecklistItem/$id")
  snap s3
  case "$r" in 404|405) cmp -s "$TMP/s0" "$TMP/s3" && pass T5-AC5 "GET pe toggle → $r, fără efect" || fail T5-AC5 "GET a modificat starea!";;
    *) fail T5-AC5 "GET pe toggle → $r (așteptat 404/405)";; esac
  r=$(form_post "$page" "/Tasks/ToggleChecklistItem/999999")
  [ "${r%% *}" = 404 ] && pass T5-AC5 "id inexistent → 404" || fail T5-AC5 "id inexistent → '$r'"
}

# ---------------------------------------------------------------- Task 6
task6() {
  section "Task 6 — Project progress summary"
  local d="$V/Projects/Details.cshtml"
  if cat "$C/ProjectsController.cs" "$APP"/ViewModels/*.cs 2>/dev/null | grep -Eq 'Count(Async)?\([a-z]+ *=> *[a-z]+\.IsCompleted\)'; then
    pass T6-AC4 "task-urile completate sunt numărate cu LINQ în controller/ViewModel"
  else warn T6-AC4 "nu găsesc Count(t => t.IsCompleted) în controller/ViewModels — verifică unde se face calculul"; fi
  if cat "$C/ProjectsController.cs" "$APP"/ViewModels/*.cs 2>/dev/null | grep -Eq '== *0|> *0|<= *0'; then
    pass T6-AC3 "există o gardă pentru împărțirea la zero"
  else warn T6-AC3 "nu găsesc gardă pentru total == 0"; fi
  if grep -Eq '\* *100|100 *\*|\.Count\(.*IsCompleted' "$d" 2>/dev/null; then fail T6-AC4 "calcul de procente/numărare în Projects/Details.cshtml"
  else pass T6-AC4 "fără calcule în view"; fi
  check_has T6-AC1 "bară de progres în view" "$d" 'progress-bar'
  check_has T6-AC6 "bara are aria-valuenow" "$d" 'aria-valuenow'

  runtime T6-AC2 || return 0
  local p code total done pct
  for p in 1 2 3; do
    code=$(http_get "/Projects/Details/$p?status=all")
    [ "$code" = 200 ] || { fail T6-AC1 "/Projects/Details/$p → $code"; continue; }
    total=$(grep -oE '/Tasks/Details/[0-9]+"' "$TMP/body.html" | sort -u | wc -l | tr -d ' ')
    done=$(grep -oE 'badge bg-success">Completed</span>' "$TMP/body.html" | wc -l | tr -d ' ')
    pct=$(awk -v d="$done" -v t="$total" 'BEGIN{ if (t==0) print 0; else printf "%d", d*100/t + 0.5 }')
    local first; first=$(body_text | grep -oE '[0-9]+ ?%' | head -1 | tr -d ' %')
    if [ "$first" = "$pct" ]; then pass T6-AC2 "proiect $p: $done/$total → $pct% afișat"
    elif body_text | grep -qE "(^|[^0-9])$pct ?%"; then warn T6-AC2 "proiect $p: $pct% apare, dar nu e primul procent de pe pagină (primul: ${first:-?}%) — verifică vizual"
    else fail T6-AC2 "proiect $p: tabelul are $done/$total completate, dar nu găsesc „$pct%” pe pagină"; fi
  done
  if body_text | grep -qi 'checklist'; then pass T6-AC5 "(bonus) progres checklist afișat"; else warn T6-AC5 "(bonus) progresul checklist nu apare"; fi

  # Empty project: create, check 0%, delete (uses the app's own Create/Delete).
  local name="__validate_empty__$(date +%H%M%S)" r pid
  r=$(form_post /Projects/Create /Projects/Create "Name=$name" "Description=temp")
  http_get /Projects >/dev/null
  pid=$(awk -v n="$name" 'index($0,n){f=1} f && match($0,/\/Projects\/Details\/[0-9]+/){print substr($0,RSTART+18,RLENGTH-18); exit}' "$TMP/body.html")
  if [ -n "$pid" ]; then
    code=$(http_get "/Projects/Details/$pid")
    if [ "$code" = 200 ] && body_text | grep -qE '(^|[^0-9])0 ?%'; then pass T6-AC3 "proiect fără task-uri → 0%, fără excepție"
    else fail T6-AC3 "proiect fără task-uri → $code / fără 0%"; fi
    form_post "/Projects/Delete/$pid" "/Projects/Delete/$pid" "Id=$pid" >/dev/null
  else warn T6-AC3 "nu am putut crea proiectul de test ($r)"; fi
}

# ---------------------------------------------------------------- Task 7 (bonus)
task7() {
  section "Bonus — Task filtering (?status=all|completed|pending)"
  if grep -Eq 'IActionResult> *Details\([^)]*[Ss]tatus' "$C/ProjectsController.cs"; then pass T7-AC4 "Projects/Details primește parametrul status"
  else fail T7-AC4 "Projects/Details nu are parametru 'status'"; fi
  if grep -Eq 'Where\([a-z]+ *=> *!?[a-z]+\.IsCompleted\)' "$C/ProjectsController.cs"; then pass T7-AC7 "filtrarea se face în query-ul EF"
  else warn T7-AC7 "nu găsesc Where(t => t.IsCompleted) în ProjectsController"; fi
  if grep -Eq 'IsCompleted' "$V/Projects/Details.cshtml" && grep -Eq '@if *\(.*[Ss]tatus' "$V/Projects/Details.cshtml"; then
    warn T7-AC7 "logică de filtrare în view?"
  fi

  runtime T7-AC2 || return 0
  local done_t="Create wireframes" pend_t="Implement responsive design" code
  code=$(http_get "/Projects/Details/1?status=all")
  local pct; pct=$(body_text | grep -oE '[0-9]+ ?%' | head -1)
  if ! grep -q "$done_t" "$TMP/body.html" || ! grep -q "$pend_t" "$TMP/body.html"; then
    skip T7-AC2 "datele seed ale proiectului 1 au fost modificate — verifică manual"; return 0; fi
  grep -qE 'status=completed' "$TMP/body.html" && grep -qE 'status=pending' "$TMP/body.html" \
    && pass T7-AC1 "linkuri de filtru All/Completed/Pending" || fail T7-AC1 "nu găsesc linkuri ?status=completed / ?status=pending"
  code=$(http_get "/Projects/Details/1?status=completed")
  if grep -q "$done_t" "$TMP/body.html" && ! grep -q "$pend_t" "$TMP/body.html"; then pass T7-AC2 "status=completed → doar completate"
  else fail T7-AC2 "status=completed nu filtrează corect ($code)"; fi
  grep -qE 'active[^>]*status=completed|status=completed[^>]*active|aria-current' "$TMP/body.html" \
    && pass T7-AC4 "butonul activ e marcat" || warn T7-AC4 "nu văd marcarea filtrului activ (class active / aria-current)"
  local pct_f; pct_f=$(body_text | grep -oE '[0-9]+ ?%' | head -1)
  [ -n "$pct" ] && [ "$pct" = "$pct_f" ] && pass T7-AC6 "sumarul ($pct) rămâne neschimbat cu filtrul" \
    || fail T7-AC6 "sumarul de progres se schimbă cu filtrul: $pct fără filtru vs ${pct_f:-?} cu status=completed"
  code=$(http_get "/Projects/Details/1?status=pending")
  if grep -q "$pend_t" "$TMP/body.html" && ! grep -q "$done_t" "$TMP/body.html"; then pass T7-AC3 "status=pending → doar nefinalizate"
  else fail T7-AC3 "status=pending nu filtrează corect ($code)"; fi
  code=$(http_get "/Projects/Details/1?status=xyz")
  if [ "$code" = 200 ] && grep -q "$done_t" "$TMP/body.html" && grep -q "$pend_t" "$TMP/body.html"; then pass T7-AC5 "valoare invalidă → toate task-urile"
  else fail T7-AC5 "status=xyz → $code / nu afișează toate"; fi
}

case "$TASK" in
  1|2|3|4|5|6|7) "task$TASK";;
  all) for t in 1 2 3 4 5 6 7; do "task$t"; done;;
  *) echo "Usage: $0 <1-7|all> [--static]"; exit 2;;
esac
summary
