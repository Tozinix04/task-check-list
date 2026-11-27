# Analiza „Requirements & Rules”, „Submission Checklist” și „What We Evaluate”

Secțiunile de la finalul `Task.pdf` sunt scurte și vagi. Aici fiecare regulă e
interpretată în verificări concrete, cu riscurile specifice acestui cod și cu
skill-ul care o verifică.

Legendă skill-uri: **VT** = `/validate-task`, **VR** = `/validate-rules`,
**VC** = `/validate-commits`, **VS** = `/validate-submission`.

---

## 1. Requirements & Rules

### R1 — „Use EF Core migrations for schema changes”

**Ce înseamnă concret**
- Orice modificare de schemă (tabel `ChecklistItems`, FK, index) apare într-un fișier din `Migrations/` generat cu `dotnet ef migrations add`.
- `ApplicationDbContextModelSnapshot.cs` e sincronizat cu modelul (zero „pending model changes”).
- Fără `EnsureCreated()`, fără SQL manual (`CREATE/ALTER TABLE`) în cod sau rulat direct în DB.
- Migrația are `Up()` **și** `Down()` funcționale și un nume descriptiv (`AddChecklistItems`, nu `Migration1`).
- Migrația e **aplicată** (aici automat prin `Database.Migrate()` din `Program.cs`).

**Riscuri în acest proiect**
| Risc | De ce | Mitigare |
|---|---|---|
| `sqlserver-init.sql` creează schema „de mână” | Scriptul replică `InitialCreate` (nu e o schimbare nouă) și scrie în `__EFMigrationsHistory` | OK pentru baza inițială; **nu** adăuga `ChecklistItems` în acest script. |
| Migrația editată manual după generare | ar desincroniza snapshot-ul | regenerează: `migrations remove` + `migrations add`. |
| Modificări de model fără migrație | ex. `[StringLength]` adăugat ulterior pe `ChecklistItem.Title` | EF 9 aruncă la `Migrate()`; verificat cu `has-pending-model-changes`. |
| Migrația adăugată în alt commit decât Task 2 | regula R4 | VC verifică în ce commit apare fișierul migrației. |

**Verificat de:** VR (static + `dotnet ef`), VT 2.

---

### R2 — „Server-side validation required”

**Ce înseamnă concret**
- Validarea **nu** se bazează pe jQuery Validation: un POST trimis cu `curl` (fără JS) cu date invalide trebuie respins.
- Fiecare acțiune `[HttpPost]` care primește date de la utilizator verifică `ModelState.IsValid` și, la eroare,
  re-afișează formularul cu mesaje (`asp-validation-for` / `asp-validation-summary`), **fără** să salveze.
- Reguli declarate pe model/input model: `[Required]`, `[StringLength(200)]` pe `Title`.
- Validări care nu pot fi exprimate prin atribute se fac în controller cu `ModelState.AddModelError`:
  - titlu format doar din spații → invalid;
  - `TaskItemId` / id-ul din rută trebuie să existe (altfel 404) — modelul existent `ValidateSelectedProjectAsync` e exemplul de urmat.
- Toate POST-urile au `[ValidateAntiForgeryToken]` (convenția deja prezentă în proiect).
- Protecție la over-posting: input model dedicat sau `[Bind(...)]` — nu legăm entitatea direct cu `Id`/`TaskItemId` modificabile.
- Acțiunile care schimbă starea (toggle) sunt POST, nu GET.

**Verificat de:** VR (static: perechi HttpPost/Antiforgery, `ModelState.IsValid`, atribute pe model) + VT 4/5 (runtime: POST fără JS).

---

### R3 — „Keep code clean and readable”

Interpretare măsurabilă (fără a inventa reguli pe care reviewerii nu le-au cerut):
| Verificare | Prag |
|---|---|
| `dotnet build` | 0 erori; **nu** se adaugă warning-uri noi față de baza primită |
| Formatare | `dotnet format --verify-no-changes` pe fișierele modificate (stilul existent: namespace bloc, 4 spații) |
| Convenții | aceleași ca în codul existent: `async/await` + `...Async`, `NotFound()` pentru id lipsă, `RedirectToAction(nameof(...))`, `_context` |
| Separare MVC | fără calcule (procente, filtre) sau acces la `DbContext` în `.cshtml`; ViewModel-uri în `ViewModels/` |
| Igienă | fără cod comentat, `Console.WriteLine`, `TODO` rămase, fișiere moarte, `Html.Raw` pe input utilizator |
| LINQ | agregări/filtre traduse în SQL (`CountAsync`, `Where` pe `IQueryable`), nu `ToList()` urmat de filtrare în memorie |
| Denumiri | descriptive, în engleză, consistente cu cele existente (`TaskItem`, `ChecklistItem`, `IsDone`) |

**Verificat de:** VR (mecanic) + recenzie ghidată din `/validate-rules` (judecată).

---

### R4 — „Commit each task separately with clear messages”

**Ce înseamnă concret**
- Un commit (sau un grup mic, coerent) per task, în ordinea task-urilor; commit inițial cu codul de bază separat.
- Mesaje în stil Conventional Commits, ca în exemplele din PDF: `type: descriere la imperativ, lowercase`, ≤ 72 caractere subiect.
- Fiecare commit compilează (reviewerul poate face checkout la oricare).
- Fără fișiere generate/secrete: `bin/`, `obj/`, `.env`, `appsettings.Development.json`, `.idea/`.
- Fără commit-uri „wip”, „fix”, „changes”, „asdf”; fără un singur commit gigant cu tot.
- Fișierele unui task nu „scapă” în commit-ul altui task (ex. migrația Task 2 nu apare în commit-ul Task 3).

**Atenție:** folderul nu e încă repository git → `git init` + commit inițial **înainte** de Task 1.

**Verificat de:** VC.

---

## 2. Submission Checklist

| ID | Cerință | Interpretare / pași | Verificare |
|---|---|---|---|
| S1 | Private GitHub repository | repo **privat**, tot istoricul împins (`main` local == `origin/main`) | VS (`gh` lipsește local → verificare manuală sau instalare `gh`) |
| S2 | Share access with reviewers | Settings → Collaborators → invită username-urile reviewerilor | VS (manual; cere lista de username-uri) |
| S3 | Email summary with completed tasks | listă task-uri (1–6 + bonus) cu link la commit-uri, cum se rulează, decizii | VS generează **draft** în `docs/EMAIL-SUMMARY.md` (nu trimite nimic) |
| S4 | Known limitations / improvements | listă onestă (vezi mai jos) | inclus în draft |

### Limitări / îmbunătățiri candidate (de ajustat după implementare)
- Nu există editare/ștergere pentru checklist items (nu au fost cerute).
- Toggle prin reîncărcare de pagină (PRG); îmbunătățire: AJAX/fetch cu fallback.
- Filtrul se pierde după Edit/Delete task (redirect fără `returnUrl`).
- Fără teste automate (îmbunătățire: teste de integrare cu `WebApplicationFactory` + SQLite/Testcontainers).
- Fără autentificare/autorizare.
- `Database.Migrate()` la startup — OK local, în producție migrațiile ar rula separat (pipeline/bundle).
- Dacă s-a ales .NET 9 față de .NET 8 din PDF — menționat explicit.

---

## 3. What We Evaluate → unde se câștigă/pierd puncte

| ID | Criteriu | Ce urmăresc reviewerii (probabil) | Cum ne asigurăm |
|---|---|---|---|
| E1 | Implementation correctness | toate criteriile de acceptanță T1–T6 îndeplinite | VT 1…7 (static + runtime) |
| E2 | Proper use of MVC and EF Core | ViewModel-uri, relații Fluent, `Include`, migrații, async, PRG, `NotFound` | VR + specificația |
| E3 | Code structure & validation handling | input models, `ModelState`, antiforgery, mesaje de eroare clare | VR + VT 4 |
| E4 | UI clarity & usability | mesaje goale prietenoase, bară de progres, feedback după acțiuni, butoane clare, accesibilitate | checklist UI în VT (verificare vizuală în browser) |
| E5 | Commit history quality | R4 | VC |
| E6 | Bonus task effort | Bonus filtering + bonus checklist progress (T6-AC5) | VT 7 + VT 6 |

---

## 4. Ambiguități în PDF și decizia luată

| Ambiguitate | Decizie (vezi SPECIFICATII.md) |
|---|---|
| .NET 8 în PDF vs .NET 9 în cod | păstrăm .NET 9 (instalăm SDK 9); menționăm în email |
| Unde se face filtrarea (bonus)? | Project Details (principal), opțional `/Tasks` |
| Nume parametru query | `status` = `all` / `completed` / `pending` |
| „redirect back” după add | PRG către `/Tasks/Details/{id}`; la eroare re-render fără redirect |
| Toggle = buton sau checkbox? | buton într-un form POST (sau checkbox cu auto-submit, tot POST) |
| Rotunjire procent | întreg, `AwayFromZero` (1/3 → 33%, 2/3 → 67%) |
| Progres checklist (bonus) — pe ce nivel? | agregat pe proiect (toți itemii din toate task-urile) |

---

## 5. Matrice de trasabilitate

| Cerință | Task | Skill |
|---|---|---|
| Aplicația rulează pe DB real | T1 | VT 1 |
| Entitate + migrație | T2, R1 | VT 2, VR |
| Afișare checklist + mesaj gol | T3 | VT 3 |
| Adăugare + validare | T4, R2 | VT 4, VR |
| Toggle | T5, R2 | VT 5, VR |
| Progres proiect | T6 | VT 6 |
| Filtrare (bonus) | T7 | VT 7 |
| Cod curat | R3 | VR |
| Commit-uri separate | R4, E5 | VC |
| Predare | S1–S4 | VS |
