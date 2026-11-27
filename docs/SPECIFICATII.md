# Specificații de implementare — Task Checklist & Progress Dashboard

Sursa: `Task.pdf` (Intern Test). Acest document traduce fiecare task din PDF în
decizii concrete de implementare, ancorate în codul existent din `TaskChecklist/`.
Fiecare criteriu de acceptanță are un ID (`T2-AC3`) folosit de skill-urile de
validare din `.claude/skills/`.

---

## 0. Starea actuală (analiză a codului primit)

| Zonă | Ce există | Observații |
|---|---|---|
| Framework | `TaskChecklist.csproj` → `net9.0`, EF Core **9.0.0** (SqlServer, Design, Tools) | PDF-ul spune „.NET 8”, dar codul e .NET 9 (`MapStaticAssets()` / `.WithStaticAssets()` sunt API-uri .NET 9). |
| SDK local | doar **.NET SDK 8.0.428** instalat | `dotnet build` eșuează acum cu `NETSDK1045`. **Blocant pentru Task 1.** |
| `dotnet-ef` | nu e instalat | Necesar pentru Task 2 (`migrations add`). |
| Baza de date | `docker-compose.yml` cu SQL Server 2022, container `taskchecklist-sqlserver-1` **rulează (healthy)** pe `127.0.0.1:1433` | `sqlserver-init` creează DB-ul și aplică `InitialCreate` + seed, folosind același applock ca EF. |
| Connection string | `appsettings.json` → placeholder `REPLACE_WITH_YOUR_PASSWORD`; `appsettings.Development.json` → parola reală | `appsettings.Development.json` e în `.gitignore` → reviewerii **nu** îl vor avea. Trebuie documentat cum se setează. |
| Migrații | `20260102120859_InitialCreate` (+ Designer + Snapshot) | `Program.cs` apelează `db.Database.Migrate()` la pornire → orice migrație nouă se aplică automat. |
| Entități | `Project`, `TaskItem` cu DataAnnotations (`[Required]`, `[StringLength]`), `TaskItem.Project` are `[ValidateNever]` | Respectă deja stilul pe care trebuie să-l continuăm. |
| Controllere | `ProjectsController`, `TasksController` (CRUD complet, `[ValidateAntiForgeryToken]` pe toate POST-urile, `[Bind]`) | `TasksController.ValidateSelectedProjectAsync` = exemplu de validare server-side suplimentară. |
| View-uri | Bootstrap 5, `Tasks/Details.cshtml`, `Projects/Details.cshtml` | Model direct pe entitate (fără ViewModel). |
| Git | folderul **nu** este repository git | Regula „commit each task separately” cere `git init` + commit inițial **înainte** de Task 1. |
| Diverse | `.env` conține și `POSTGRES_PASSWORD`, există `Data/postgres-init.sql` | Aplicația folosește doar SQL Server → fișierele Postgres sunt reziduale. |

### Date seed (folosite la verificări)

| Proiect | Task-uri | Completate | % așteptat |
|---|---|---|---|
| 1 Website Redesign | 1, 2, 3 | 1 (task 1) | **33%** |
| 2 Mobile App Development | 4, 5, 6 | 2 (task 4, 5) | **67%** |
| 3 Database Migration | 7, 8 | 1 (task 7) | **50%** |

(rotunjire `MidpointRounding.AwayFromZero` la întreg)

---

## Pasul 0 — Pregătirea repository-ului (înainte de Task 1)

1. `git init` în `/TaskChecklist` (folderul soluției), branch `main`.
2. Verifică `.gitignore`: `bin/`, `obj/`, `.env`, `appsettings.Development.json`, `.idea/` sunt deja ignorate. ✅
3. Commit inițial cu codul **exact cum a fost primit**:
   `chore: import base solution`
   → astfel fiecare commit următor conține doar diff-ul task-ului respectiv.
4. **Line endings:** fișierele primite au CRLF, iar git-ul local le normalizează la LF la `git add`
   (vezi warning-urile „CRLF will be replaced by LF”). Adaugă în commit-ul inițial un `.gitattributes`
   (`* text=auto`), ca diff-urile task-urilor să nu conțină modificări de whitespace pe fișiere întregi.
   Când editezi fișiere existente, păstrează-le terminațiile de linie.
5. Decide dacă `docs/` și `.claude/` intră în repo-ul de predare (recomandat: commit separat `docs: ...` la final, sau adăugate în `.gitignore`).

---

## Task 1 — Configure Database Connection

**Obiectiv:** aplicația rulează local, conectată la SQL Server real, iar paginile existente afișează date.

### Decizie: SDK
Recomandat: **instalează .NET 9 SDK** (păstrezi soluția primită neschimbată, diff minim).
Alternativă (doar dacă reviewerii cer explicit .NET 8): retarget la `net8.0`, EF Core `8.0.*`,
înlocuiește `app.MapStaticAssets()` cu `app.UseStaticFiles()` și scoate `.WithStaticAssets()`.
Alegerea se menționează în emailul de predare.

> Alternativa .NET 8 a fost verificată end-to-end pe o copie (EF Core `8.0.11`, `dotnet-ef 8.0.11`):
> `InitialCreate` existentă funcționează, iar implementarea tuturor task-urilor după această
> specificație trece toate cele 84 de verificări din `/validate-task all`.

> Bonus EF 9: `Database.Migrate()` aruncă excepție dacă modelul are modificări nemigrate
> (`PendingModelChangesWarning`) — asta întărește automat regula „EF Core migrations”.

### Implementare
1. SDK 9 instalat; `dotnet --list-sdks` arată `9.0.x`.
2. Tool EF local, reproductibil pentru revieweri:
   ```bash
   dotnet new tool-manifest
   dotnet tool install dotnet-ef --version 9.0.0
   ```
   → se commit-uiește `.config/dotnet-tools.json`.
3. Connection string — **nu** se commit-uiește parola:
   - `appsettings.json` rămâne cu placeholder;
   - local: `appsettings.Development.json` (ignorat) **sau** `dotnet user-secrets set "ConnectionStrings:DefaultConnection" "..."`
     **sau** variabila de mediu `ConnectionStrings__DefaultConnection`.
4. Pornire DB: `docker compose up -d` (necesită `SA_PASSWORD` în `.env`, vezi `.env.example`).
5. README (minimal) cu pașii de rulare: `.env` → `docker compose up -d` → setare connection string → `dotnet run --project TaskChecklist`.
6. Opțional: șterge `POSTGRES_PASSWORD` din `.env` și `postgres-init.sql` dacă nu sunt folosite (sau documentează-le).

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T1-AC1 | `TargetFramework` din csproj este suportat de un SDK instalat; `dotnet build` = 0 erori. |
| T1-AC2 | SQL Server accesibil pe portul configurat. |
| T1-AC3 | `GET /Projects` → 200 și conține „Website Redesign” (date seed). |
| T1-AC4 | `GET /Projects/Details/1` și `GET /Tasks/Details/1` → 200. |
| T1-AC5 | Nicio parolă reală în fișiere care vor fi commit-uite (`appsettings.json`, `docker-compose.yml`, README). |
| T1-AC6 | Există instrucțiuni de rulare (README) pentru revieweri. |

**Commit:** `chore: configure database connection for local development`

---

## Task 2 — ChecklistItem (Entity + Migration)

### Fișiere
| Fișier | Modificare |
|---|---|
| `Models/ChecklistItem.cs` | **nou** |
| `Models/TaskItem.cs` | + colecție de navigare |
| `Data/ApplicationDbContext.cs` | + `DbSet`, configurare Fluent |
| `Migrations/<timestamp>_AddChecklistItems.cs` (+ Designer, Snapshot actualizat) | **generat** |

### Model
```csharp
public class ChecklistItem
{
    public int Id { get; set; }

    public int TaskItemId { get; set; }

    [Required]
    [StringLength(200)]
    public string Title { get; set; } = string.Empty;

    [Display(Name = "Done")]
    public bool IsDone { get; set; }

    [ValidateNever]
    public TaskItem TaskItem { get; set; } = null!;
}
```
În `TaskItem`:
```csharp
public ICollection<ChecklistItem> ChecklistItems { get; set; } = new List<ChecklistItem>();
```

### DbContext
```csharp
public DbSet<ChecklistItem> ChecklistItems { get; set; }

modelBuilder.Entity<ChecklistItem>(entity =>
{
    entity.HasKey(e => e.Id);
    entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
    entity.HasOne(e => e.TaskItem)
        .WithMany(t => t.ChecklistItems)
        .HasForeignKey(e => e.TaskItemId)
        .OnDelete(DeleteBehavior.Cascade);
});
```
Cascade: ștergerea unui task (sau proiect) șterge și checklist-ul — consistent cu `Project → TaskItem`.
Seed pentru checklist: **opțional** (dacă adaugi, folosește `HasData` ca să rămână în migrație, cu ID-uri fixe).

### Migrație
```bash
dotnet ef migrations add AddChecklistItems --project TaskChecklist
dotnet ef database update --project TaskChecklist   # sau pornește aplicația (Migrate() la startup)
```
Verifică în fișierul generat: `CreateTable("ChecklistItems")`, FK `FK_ChecklistItems_TaskItems_TaskItemId` cu `Cascade`,
index `IX_ChecklistItems_TaskItemId`, `Title nvarchar(200) NOT NULL`, `Down()` face `DropTable`.
**Nu** edita manual migrația sau DB-ul; nu folosi `EnsureCreated()`.

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T2-AC1 | `Models/ChecklistItem.cs` are `Id`, `TaskItemId`, `Title`, `IsDone`, `TaskItem`. |
| T2-AC2 | `Title` are `[Required]` + `[StringLength(200)]`; `TaskItem` are `[ValidateNever]`. |
| T2-AC3 | `TaskItem.ChecklistItems` există; `DbSet<ChecklistItem>` există în context. |
| T2-AC4 | Relația e configurată (FK `TaskItemId`, cascade). |
| T2-AC5 | Există o migrație nouă care creează `ChecklistItems`; snapshot-ul conține entitatea. |
| T2-AC6 | Migrația e aplicată (`__EFMigrationsHistory` / `dotnet ef migrations list` fără „Pending”). |
| T2-AC7 | Nu există modificări de model nemigrate (`dotnet ef migrations has-pending-model-changes`). |
| T2-AC8 | Build fără erori; aplicația pornește și paginile existente încarcă. |

**Commit:** `feat: add ChecklistItem entity and migration`

---

## Task 3 — Afișare checklist în Task Details

### Decizie: ViewModel
`Tasks/Details` va avea nevoie (Task 4) și de un formular de adăugare → introducem acum ViewModel-ul:

```csharp
// ViewModels/TaskDetailsViewModel.cs
public class TaskDetailsViewModel
{
    public TaskItem Task { get; set; } = null!;
    public IReadOnlyList<ChecklistItem> ChecklistItems { get; set; } = [];
    public ChecklistItemInputModel NewChecklistItem { get; set; } = new();   // folosit din Task 4
}
```

### Controller (`TasksController.Details`)
- Extrage construirea VM-ului într-o metodă privată reutilizabilă: `Task<TaskDetailsViewModel?> BuildDetailsViewModelAsync(int id)`.
- Query:
  ```csharp
  var task = await _context.TaskItems
      .AsNoTracking()
      .Include(t => t.Project)
      .Include(t => t.ChecklistItems)
      .FirstOrDefaultAsync(t => t.Id == id);
  ```
- Ordonare stabilă: `ChecklistItems.OrderBy(c => c.IsDone).ThenBy(c => c.Id)` (nefinalizate sus) — sau doar `ThenBy(Id)`; alegerea se documentează.
- `id` null / inexistent → `NotFound()` (comportament existent păstrat).

### View (`Views/Tasks/Details.cshtml`)
- `@model TaskChecklist.ViewModels.TaskDetailsViewModel`; înlocuiește `Model.X` cu `Model.Task.X`.
- Secțiune nouă sub cardul de detalii: card cu header **„Checklist”** + contor `done/total`.
- Listă `<ul class="list-group">`; fiecare item: titlu, iar cele `IsDone` cu `text-decoration-line-through text-muted` + badge.
- Mesaj prietenos dacă nu există: `<div class="alert alert-info">No checklist items yet. Add the first one below.</div>`
  (textul **„No checklist items yet”** este fix — folosit de validare).
- Titlurile se afișează prin Razor (`@item.Title`) → encodare HTML automată (fără `Html.Raw`).

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T3-AC1 | `Details` încarcă checklist-ul (`Include(t => t.ChecklistItems)` sau query explicit), fără N+1. |
| T3-AC2 | Pagina afișează secțiunea „Checklist” sub detaliile task-ului. |
| T3-AC3 | Task fără itemi → mesajul „No checklist items yet”. |
| T3-AC4 | Itemii finalizați se disting vizual de cei nefinalizați. |
| T3-AC5 | `/Tasks/Details/99999` → 404; `/Tasks/Details` → 404. |

**Commit:** `feat: display checklist items on task details page`

---

## Task 4 — Adăugare checklist items din UI

### Input model (nu legăm direct entitatea → evităm over-posting)
```csharp
// ViewModels/ChecklistItemInputModel.cs
public class ChecklistItemInputModel
{
    [Required(ErrorMessage = "Title is required.")]
    [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
    [Display(Name = "Title")]
    public string Title { get; set; } = string.Empty;

    [Display(Name = "Done")]
    public bool IsDone { get; set; }
}
```

### Endpoint
`POST /Tasks/AddChecklistItem/{id}` (`id` = TaskItemId)
```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> AddChecklistItem(int id,
    [Bind(Prefix = nameof(TaskDetailsViewModel.NewChecklistItem))] ChecklistItemInputModel input)
```
Flux:
1. Task-ul nu există → `NotFound()`.
2. Titlu doar din spații: `[Required]` îl respinge deja (implicit `AllowEmptyStrings = false` tratează
   whitespace-ul ca gol) — nu e nevoie de verificare manuală. La salvare folosește `input.Title.Trim()`
   ca să nu persiste spațiile de la capete.
3. `!ModelState.IsValid` → reconstruiește VM-ul cu `BuildDetailsViewModelAsync(id)`, setează `vm.NewChecklistItem = input`,
   `return View("Details", vm)` (**fără redirect**, ca să se păstreze erorile și valorile introduse).
4. Valid → `_context.ChecklistItems.Add(new ChecklistItem { TaskItemId = id, Title = input.Title, IsDone = input.IsDone })`,
   `SaveChangesAsync()`, `TempData["Success"] = "Checklist item added."`,
   `return RedirectToAction(nameof(Details), new { id })` (PRG — fără dublă trimitere la refresh).

### View
Formular sub listă:
```html
<form asp-action="AddChecklistItem" asp-route-id="@Model.Task.Id" method="post">
    <div asp-validation-summary="ModelOnly" class="text-danger"></div>
    <input asp-for="NewChecklistItem.Title" class="form-control" placeholder="New checklist item" />
    <span asp-validation-for="NewChecklistItem.Title" class="text-danger"></span>
    <input asp-for="NewChecklistItem.IsDone" class="form-check-input" />
    <label asp-for="NewChecklistItem.IsDone" class="form-check-label"></label>
    <button type="submit" class="btn btn-primary">Add item</button>
</form>
```
- `@section Scripts { <partial name="_ValidationScriptsPartial" /> }` pentru validare client (în plus față de server, nu în loc).
- Afișează `TempData["Success"]` ca `alert-success` dismissible.
- Câmpurile trimise: `NewChecklistItem.Title`, `NewChecklistItem.IsDone` (nume fixe — folosite de validare).

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T4-AC1 | Formularul există pe Task Details cu Title (required) și checkbox IsDone. |
| T4-AC2 | Acțiunea POST are `[HttpPost]` + `[ValidateAntiForgeryToken]`. |
| T4-AC3 | Validare **server-side**: POST cu Title gol/doar spații (fără JS) → 200, mesaj de eroare, **nimic salvat**. |
| T4-AC4 | Title > 200 caractere → respins cu mesaj. |
| T4-AC5 | POST valid → salvat în DB, 302 către `/Tasks/Details/{id}`, itemul apare în listă. |
| T4-AC6 | POST pentru task inexistent → 404. |
| T4-AC7 | Nu se poate seta `TaskItemId`/`Id` prin over-posting (input model dedicat sau `[Bind]`). |

**Commit:** `feat: allow adding checklist items to a task`

---

## Task 5 — Toggle IsDone

### Endpoint
`POST /Tasks/ToggleChecklistItem/{id}` (`id` = ChecklistItemId)
```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> ToggleChecklistItem(int id)
{
    var item = await _context.ChecklistItems.FindAsync(id);
    if (item == null) return NotFound();
    item.IsDone = !item.IsDone;
    await _context.SaveChangesAsync();
    return RedirectToAction(nameof(Details), new { id = item.TaskItemId });
}
```
- **POST, nu GET** — o schimbare de stare prin GET poate fi declanșată de crawlere/prefetch și ocolește antiforgery.
- Redirect folosește `item.TaskItemId` din DB, nu o valoare trimisă de client.

### View
În fiecare rând din listă, un mini-form:
```html
<form asp-action="ToggleChecklistItem" asp-route-id="@item.Id" method="post" class="d-inline">
    <button type="submit" class="btn btn-sm @(item.IsDone ? "btn-outline-secondary" : "btn-outline-success")"
            aria-label="@(item.IsDone ? "Mark as not done" : "Mark as done"): @item.Title">
        @(item.IsDone ? "Undo" : "Done")
    </button>
</form>
```
(Alternativă: checkbox cu `onchange="this.form.submit()"` — tot POST.)

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T5-AC1 | Fiecare item are buton/checkbox de toggle care face POST cu antiforgery. |
| T5-AC2 | Toggle inversează `IsDone` și persistă în DB. |
| T5-AC3 | După toggle → redirect (302) la `/Tasks/Details/{TaskItemId}`. |
| T5-AC4 | Două toggle-uri consecutive revin la starea inițială. |
| T5-AC5 | Id inexistent → 404; GET pe endpoint → 404/405 (nu modifică starea). |

**Commit:** `feat: allow toggling checklist item completion`

---

## Task 6 — Project Progress Summary

### ViewModel
```csharp
// ViewModels/ProjectProgress.cs
public class ProjectProgress
{
    public int TotalTasks { get; init; }
    public int CompletedTasks { get; init; }
    public int PercentCompleted => Percent(CompletedTasks, TotalTasks);

    // Bonus
    public int TotalChecklistItems { get; init; }
    public int DoneChecklistItems { get; init; }
    public int ChecklistPercent => Percent(DoneChecklistItems, TotalChecklistItems);

    private static int Percent(int part, int total) =>
        total == 0 ? 0 : (int)Math.Round(part * 100.0 / total, MidpointRounding.AwayFromZero);
}

// ViewModels/ProjectDetailsViewModel.cs
public class ProjectDetailsViewModel
{
    public Project Project { get; set; } = null!;
    public IReadOnlyList<TaskItem> Tasks { get; set; } = [];   // lista afișată (filtrată în Bonus)
    public ProjectProgress Progress { get; set; } = null!;
    public string StatusFilter { get; set; } = "all";          // Bonus
}
```

### Controller (`ProjectsController.Details`) — calcul cu LINQ pe server (în DB)
```csharp
var projectTasks = _context.TaskItems.Where(t => t.ProjectId == project.Id);
var projectChecklist = _context.ChecklistItems.Where(c => c.TaskItem.ProjectId == project.Id);

var progress = new ProjectProgress
{
    TotalTasks = await projectTasks.CountAsync(),
    CompletedTasks = await projectTasks.CountAsync(t => t.IsCompleted),
    TotalChecklistItems = await projectChecklist.CountAsync(),
    DoneChecklistItems = await projectChecklist.CountAsync(c => c.IsDone)
};
```
Fiecare `CountAsync` devine un `SELECT COUNT(*)` în SQL — nu încărcăm rândurile ca să le numărăm în memorie.
(Un singur query cu `GroupBy` e posibil, dar mai greu de citit; nu merită pentru 4 numere.)

Reguli:
- Proiect fără task-uri → 0 / 0 / 0%, **fără** `DivideByZeroException`.
- Sumarul se calculează **pe toate task-urile proiectului**, indiferent de filtrul din Bonus.
- Calculul nu se face în `.cshtml`.

### View (`Projects/Details.cshtml`)
Card „Progress” deasupra tabelului de task-uri:
- „Total tasks: **3**”, „Completed: **1**”, „**33%** completed”;
- `progress-bar` Bootstrap cu `role="progressbar"`, `aria-valuenow`, `aria-valuemin="0"`, `aria-valuemax="100"`, `style="width: 33%"`;
- Bonus: a doua bară „Checklist items: 2 / 5 done (40%)”; dacă nu există itemi → „No checklist items yet”.

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T6-AC1 | Project Details afișează Total tasks, Completed tasks, Percentage. |
| T6-AC2 | Valori corecte pe seed: P1 = 3/1/33%, P2 = 3/2/67%, P3 = 2/1/50% (dacă datele nu au fost modificate). |
| T6-AC3 | Proiect fără task-uri → 0%, fără excepție. |
| T6-AC4 | Calcul în controller/ViewModel prin LINQ, nu în view. |
| T6-AC5 | (Bonus) Progres checklist (done/total/%) afișat. |
| T6-AC6 | Bara de progres are atribute ARIA. |

**Commit:** `feat: display project progress summary`

---

## Bonus — Task Filtering

### Decizii
- Loc principal: lista de task-uri din **Project Details** (`/Projects/Details/{id}?status=...`).
  Extensie opțională: același filtru pe `/Tasks` (All Tasks).
- Parametru query: **`status`** cu valori `all` (implicit) | `completed` | `pending`.
- Valoare lipsă/necunoscută → tratată ca `all` (nu eroare).
- UI: `btn-group` cu 3 link-uri (`<a asp-route-status="completed">`), butonul activ are `active` + `aria-current="page"`.
  Linkuri GET → filtrul rămâne în URL (bookmark/refresh/back funcționează). Alternativă: `<select>` într-un `<form method="get">`.

### Implementare
```csharp
public async Task<IActionResult> Details(int? id, string? status)
{
    var filter = (status ?? "all").ToLowerInvariant();
    var query = _context.TaskItems.Where(t => t.ProjectId == id);
    query = filter switch
    {
        "completed" => query.Where(t => t.IsCompleted),
        "pending"   => query.Where(t => !t.IsCompleted),
        _           => query
    };
    if (filter is not ("completed" or "pending")) filter = "all";
    ...
}
```
- Recomandat: `enum TaskStatusFilter { All, Completed, Pending }` + model binding, cu fallback la `All`.
- Mesaj gol contextual: „No completed tasks in this project.” / „No pending tasks…”.
- Progress summary (Task 6) **nu** se schimbă cu filtrul.
- După Edit/Delete task, redirect-ul existent spre Project Details poate pierde filtrul — acceptabil; menționat ca limitare sau rezolvat cu `returnUrl` local validat (`Url.IsLocalUrl`).

### Criterii de acceptanță
| ID | Criteriu |
|---|---|
| T7-AC1 | Butoane/dropdown All / Completed / Not Completed vizibile. |
| T7-AC2 | `?status=completed` → doar task-uri completate (P1: doar „Create wireframes”). |
| T7-AC3 | `?status=pending` → doar task-uri nefinalizate. |
| T7-AC4 | Filtrul e păstrat în query string; butonul activ e marcat. |
| T7-AC5 | `?status=xyz` → toate task-urile, fără eroare. |
| T7-AC6 | Sumarul de progres rămâne calculat pe toate task-urile. |
| T7-AC7 | Filtrarea se face în query-ul EF (server), nu în view. |

**Commit:** `feat: filter tasks by completion status`

---

## Ordinea commit-urilor (rezumat)

| # | Commit | Conținut |
|---|---|---|
| 0 | `chore: import base solution` | codul primit, neschimbat |
| 1 | `chore: configure database connection for local development` | SDK/target, tool manifest, README, config |
| 2 | `feat: add ChecklistItem entity and migration` | model, context, migrație |
| 3 | `feat: display checklist items on task details page` | `TaskDetailsViewModel`, `Details` |
| 4 | `feat: allow adding checklist items to a task` | input model, `AddChecklistItem`, formular |
| 5 | `feat: allow toggling checklist item completion` | `ToggleChecklistItem`, butoane |
| 6 | `feat: display project progress summary` | `ProjectProgress`, `ProjectDetailsViewModel` |
| 7 | `feat: filter tasks by completion status` | filtru `status` |
| (8) | `docs: ...` | opțional: README final, limitări |

Fiecare commit trebuie să compileze și să ruleze singur. Validare după fiecare task:
`/validate-task <N>` → apoi commit → `/validate-commits`.
