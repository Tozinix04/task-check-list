---
name: validate-rules
description: Verifică regulile transversale din Task.pdf („Requirements & Rules”) pe proiectul TaskChecklist — R1 schimbări de schemă doar prin EF Core migrations, R2 validare server-side (ModelState, antiforgery, POST pentru schimbări de stare, over-posting), R3 cod curat (build, format, separare MVC, LINQ în SQL, fără secrete). Folosește-l înainte de fiecare commit sau când utilizatorul întreabă dacă respectă regulile / cerințele.
---

# validate-rules

Analiza completă a regulilor e în `docs/ANALIZA-REQUIREMENTS.md` (secțiunea 1).

## Pași

1. **Verificări mecanice:**
   ```bash
   .claude/skills/validate-rules/scripts/check_rules.sh            # include dotnet format
   .claude/skills/validate-rules/scripts/check_rules.sh --no-format # mai rapid
   ```
   Scriptul împarte fiecare controller în acțiuni și verifică pentru fiecare `[HttpPost]`:
   antiforgery, `ModelState.IsValid` când leagă un model, entitate legată fără `[Bind]`;
   și pentru acțiunile GET: că nu apelează `SaveChanges`.

2. **Recenzie de judecată** — citește controllerele, ViewModel-urile și view-urile atinse și răspunde explicit:

   **R1 – Migrații**
   - Există o migrație pentru *fiecare* schimbare de model (inclusiv atribute care schimbă coloane: `[StringLength]`, `[Required]`)?
   - Migrația a fost generată (are Designer + snapshot actualizat), nu scrisă/modificată de mână?
   - `sqlserver-init.sql` nu a fost extins cu tabele noi?

   **R2 – Validare server-side**
   - Încearcă mental (sau cu `form_post` din `lib.sh`) un POST fără JavaScript cu: Title gol, doar spații, > 200 caractere, id de task inexistent. Toate sunt respinse pe server?
   - La eroare se re-afișează formularul cu mesajele lângă câmp, fără să salveze nimic?
   - Clientul nu poate trimite `Id`, `TaskItemId`, `ProjectId` pe care nu ar trebui să le controleze?

   **R3 – Cod curat**
   - Stil consecvent cu codul primit (namespace bloc, `_context`, `async`, `NotFound()`, `RedirectToAction(nameof(...))`).
   - Logica stă în controller/ViewModel, nu în `.cshtml`; nicio duplicare evitabilă (ex. construirea `TaskDetailsViewModel` într-o singură metodă).
   - Nume clare, fără cod mort, fără comentarii inutile, fără `using` nefolosite.
   - Interogările agregă în SQL (`CountAsync`, `Where` pe `IQueryable`), nu în memorie.

3. **Raportează** pe reguli: R1 / R2 / R3 → OK / probleme, fiecare problemă cu `fișier:linie`
   și remedierea propusă. Distinge FAIL (încalcă regula din PDF) de WARN (stil / îmbunătățire).
   Nu modifica codul fără acordul utilizatorului.

R4 (commit-uri) e acoperit de skill-ul `validate-commits`.
