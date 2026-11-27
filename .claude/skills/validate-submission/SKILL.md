---
name: validate-submission
description: Verificarea finală înainte de predarea testului TaskChecklist (Task.pdf) — rulează toate validările (task-uri, reguli, commit-uri), verifică Submission Checklist (repo GitHub privat, acces reviewer, tot istoricul împins) și pregătește draftul de email cu task-urile finalizate și limitările cunoscute. Folosește-l când utilizatorul spune că a terminat, vrea să predea, sau cere emailul de predare.
---

# validate-submission

## Pași

1. **Pornește aplicația** (vezi skill-ul `validate-task`, pasul 1) ca să ruleze și testele HTTP.

2. **Rulează poarta de predare:**
   ```bash
   REVIEWERS="user1 user2" .claude/skills/validate-submission/scripts/check_submission.sh
   ```
   Rulează `check_task.sh all`, `check_rules.sh`, `check_commits.sh --build-each`, apoi S1–S4.
   `REVIEWERS` = username-urile GitHub ale reviewerilor — întreabă utilizatorul dacă nu le știi.
   Fără `gh` CLI, S1/S2 devin verificări manuale: spune-i utilizatorului exact ce să verifice pe GitHub
   (Settings → General → visibility *Private*; Settings → Collaborators → reviewerii invitați).

3. **Draft email (S3 + S4)** — scrie `docs/EMAIL-SUMMARY.md` (în engleză, ca PDF-ul) pe baza
   `git log --reverse --format='%h %s'` și a rezultatelor reale ale validărilor:

   ```markdown
   Subject: Intern Test – Task Checklist & Progress Dashboard – <Nume>

   Hi <...>,

   I've completed the assignment. Repository (private, access shared with <reviewers>):
   <https://github.com/...>

   ## Completed tasks
   | # | Task | Commit |
   |---|---|---|
   | 1 | Configure database connection | <hash> |
   ...
   | ⭐ | Bonus: task filtering (`?status=`) | <hash> |
   | ⭐ | Bonus: checklist progress on project page | <hash> |

   ## How to run
   <3–5 pași din README>

   ## Decisions
   - <ex. kept .NET 9 (solution targets net9.0), status filter values, rounding>

   ## Known limitations / improvements
   - <doar lucruri adevărate pentru implementarea curentă — pornește de la lista din
     docs/ANALIZA-REQUIREMENTS.md §2 și șterge ce nu se aplică>

   Best regards,
   <Nume>
   ```
   Marchează un task ca finalizat **doar** dacă validarea lui a trecut. Nu inventa link-uri sau nume —
   lasă `<...>` acolo unde nu știi.

4. **Nu trimite emailul și nu schimba setările repository-ului** — astea sunt acțiuni ale utilizatorului.
   Nu face push fără acord explicit.

5. **Raportează** un tabel final:

   | Zonă | Stare |
   |---|---|
   | Task 1–6 | … |
   | Bonus | … |
   | R1–R3 | … |
   | R4 commit-uri | … |
   | S1 repo privat + push | … |
   | S2 acces reviewer | … |
   | S3/S4 email | draft în `docs/EMAIL-SUMMARY.md` |

   Verdict: **GATA DE PREDARE** sau lista ordonată de ce mai e de făcut.
