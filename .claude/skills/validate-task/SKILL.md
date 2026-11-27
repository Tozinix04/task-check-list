---
name: validate-task
description: Validează un task din Task.pdf (Task Checklist & Progress Dashboard) față de criteriile de acceptanță din docs/SPECIFICATII.md — verificări statice în cod, build, migrații și teste HTTP pe aplicația pornită. Folosește-l după ce implementezi un task și înainte de commit, sau când utilizatorul întreabă „e gata task-ul X?”, „verifică task 4”, „validate task”.
argument-hint: "<1-7|all> [--static]"
---

# validate-task

Verifică task-ul `$ARGUMENTS` (1–6, 7 = bonus filtrare, `all` = toate).
Sursa adevărului: `docs/SPECIFICATII.md` (criterii `T<n>-AC<m>`). Dacă implementarea
s-a abătut intenționat de la specificație (alt nume de acțiune, alt parametru), actualizează
întâi specificația și scriptul, nu ignora FAIL-ul.

## Pași

1. **Pornește aplicația** (dacă nu rulează deja și nu s-a cerut `--static`), în background:
   ```bash
   dotnet run --project TaskChecklist --launch-profile http
   ```
   Așteaptă până răspunde `curl -s -o /dev/null -w '%{http_code}' http://localhost:5005/Projects` cu 200.
   Dacă build-ul eșuează, raportează eroarea — nu încerca alte porturi/profile la întâmplare.
   SQL Server trebuie să ruleze (`docker compose ps`); dacă nu, `docker compose up -d`.

2. **Rulează validatorul mecanic:**
   ```bash
   .claude/skills/validate-task/scripts/check_task.sh <N> [--static]
   ```
   Variabile utile: `BASE_URL` (implicit `http://localhost:5005`), `TEST_TASK_ID` (implicit 1),
   `EMPTY_TASK_ID` (implicit 8 — un task fără checklist).
   Fiecare linie e `PASS|FAIL|WARN|SKIP [ID] mesaj`; exit code ≠ 0 dacă există FAIL.

3. **Recenzie de judecată** (ce scriptul nu poate verifica) — citește diff-ul task-ului și bifează:

   | Task | Verifică manual |
   |---|---|
   | 1 | README-ul permite unui reviewer să ruleze proiectul de la zero; nicio parolă commit-uită |
   | 2 | migrația generată de `dotnet ef`, needitată manual; cascade logic; nume `AddChecklistItems` |
   | 3 | query-ul nu face N+1; ordonare stabilă a itemilor; textul gol e prietenos |
   | 4 | la eroare: re-render (nu redirect), valoarea introdusă rămâne în câmp; mesaj de succes după PRG; input model fără `Id`/`TaskItemId` |
   | 5 | toggle e POST; redirect folosește `TaskItemId` din DB; butonul are text/aria clar |
   | 6 | calcul prin LINQ în controller/ViewModel; 0 task-uri → 0%; rotunjire consistentă |
   | 7 | filtrul nu afectează sumarul; valoare invalidă → All; butonul activ marcat; mesaj gol contextual |

4. **Verificare vizuală** (Task 3–7): deschide pagina în browser-ul integrat
   (`/Tasks/Details/1`, `/Projects/Details/1`) și fă un screenshot; verifică lizibilitatea,
   starea goală și că mesajele de validare apar lângă câmp.

5. **Raportează** ca tabel: criteriu → PASS/FAIL → dovadă (linie din script, fișier:linie sau screenshot).
   Încheie cu verdict clar: „Task N gata de commit” sau lista exactă de ce lipsește.
   Sugerează mesajul de commit din specificație (ex. `feat: allow adding checklist items to a task`),
   dar **nu** face commit fără acordul utilizatorului.

## Note

- Testele runtime pentru Task 4/5/6 **scriu în DB**: itemi checklist cu prefixul `__validate__` pe
  task-ul `TEST_TASK_ID`; pentru Task 6 se creează și se șterge un proiect `__validate_empty__`.
  Spune-i utilizatorului că au fost creați. Nu există UI de ștergere a itemilor; dacă vrea curățenie,
  oferă-i (cu confirmare) un `DELETE FROM ChecklistItems WHERE Title LIKE '\_\_validate%' ESCAPE '\'`.
- Task 7 folosește titlurile seed ale proiectului 1; dacă datele au fost modificate, check-ul face SKIP.
- `lib.sh` oferă `form_post PAGE ACTION field=value…` (ia token-ul antiforgery + cookie) pentru teste ad-hoc:
  `source .claude/skills/validate-task/scripts/lib.sh; form_post /Tasks/Details/1 /Tasks/AddChecklistItem/1 "NewChecklistItem.Title=x"`.
