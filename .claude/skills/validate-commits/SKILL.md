---
name: validate-commits
description: Verifică istoricul git al proiectului TaskChecklist față de regula din Task.pdf „Commit each task separately with clear messages” — un commit per task în ordine, mesaje Conventional Commits ca în PDF, fără secrete/bin/obj în istoric, fiecare commit compilează. Folosește-l după fiecare commit, înainte de push, sau când utilizatorul întreabă dacă istoricul e în regulă.
argument-hint: "[--build-each]"
---

# validate-commits

## Pași

1. **Rulează:**
   ```bash
   .claude/skills/validate-commits/scripts/check_commits.sh               # rapid
   .claude/skills/validate-commits/scripts/check_commits.sh --build-each  # + build pe fiecare commit
   ```
   Folosește `--build-each` înainte de push/predare (exportă fiecare commit cu `git archive` într-un
   folder temporar și rulează `dotnet build`).

2. **Interpretare** — mesajele de referință din PDF:

   | Task | Mesaj așteptat |
   |---|---|
   | 0 | `chore: import base solution` (recomandat, codul primit neschimbat) |
   | 1 | `chore: configure database connection for local development` |
   | 2 | `feat: add ChecklistItem entity and migration` |
   | 3 | `feat: display checklist items on task details page` |
   | 4 | `feat: allow adding checklist items to a task` |
   | 5 | `feat: allow toggling checklist item completion` |
   | 6 | `feat: display project progress summary` |
   | 7 | `feat: filter tasks by completion status` |

   Pentru fiecare commit, uită-te și la conținut (`git show --stat <hash>`): fișierele aparțin task-ului
   din mesaj? (ex. migrația doar în Task 2; `ProjectProgress` doar în Task 6). Un fix mic ulterior e OK
   dacă are mesaj clar (`fix: ...`), dar nu „wip” / „changes”.

3. **Dacă găsești probleme**, propune remedierea — **nu** rescrie istoricul fără acordul explicit al utilizatorului:
   - mesaj greșit pe ultimul commit, neîmpins → `git commit --amend`;
   - commit-uri amestecate, neîmpinse → reorganizare cu `git reset --soft` + commit-uri noi (explică pașii);
   - **parolă sau `.env` / `appsettings.Development.json` în istoric** → oprește-te: e critic; istoricul trebuie
     rescris *înainte* de push, iar dacă a fost deja împins, parola SA trebuie schimbată.

4. **Raportează**: tabel task → commit (hash + mesaj) → OK/problemă, plus igiena repository-ului.
