# Handoff: where the project stands, and what is next

Updated 31 October 2026, 23:30.

## 31 October 2026: exploratory runs done

Runs A, B and C finished at 200 hospitals on branch `step4-exploratory`, and await review. Results: the section "Exploratory runs" of `reports/phase2_results.md`. No floor was chosen.

## 23 October 2026: steps 12 to 15 done

Buckley-James estimator, setting C4 (wrong outcome model), weight checks, and a rerun of all five settings at 200 hospitals. Gate 3 passed, except that no weight check identifies the broken hospitals, which is itself a finding. Results: the last section of `reports/phase2_results.md`; lesson 11; `docs/LOG.md`.

Next, optional: step 16 (Brier score and calibration of each arm's risk model among all eligible patients, with dropout), about 1 to 2 days. Plan in `docs/WORKPLAN.md`.

New open questions from the additions:
- BJ's intervals undercover even with the right outcome model (72% in C2). A bootstrap would test the likely reason.
- AIPCW has small median-based bias under either wrong model taken alone, but its large errors remain. Truncating the combined weight (open question 1 below) was Run A in `docs/exploratory_prespecification.md`.

## State

| Part | State |
|---|---|
| Phase 1 (binary outcome, no dropout) | **Done.** 500 hospitals, Gate 1 passed. `reports/phase1_results.md` |
| Phase 1, trial of about 125 | 50 of 500 hospitals (preliminary) |
| Phase 2 (dropout, effect over time) | **Done.** 200 hospitals per setting, with truncated weights. Gate 2 passed for bias, not for stability or intervals. `reports/phase2_results.md` |
| Lessons | 1 to 11 written, in `docs/lessons/` (lessons 5 and 6 share one file) |
| Process log | `docs/LOG.md`: every setting, change and check, with reasons |
| Slide deck | Not started |

All code, documents and results are on GitHub (private repository).

## Open questions from Phase 2, in order of value

1. **Combined weights.** With only the dropout weight truncated, 27 to 83 hospitals still had an absolute error above 0.5 under strong dependent dropout. Truncating the product of the joining and staying chances, and other floors, was Run A in `docs/exploratory_prespecification.md`, exploratory, with no floor chosen. Large errors fell furthest under the bound on the product, while coverage fell and, in C4, bias rose (`reports/phase2_results.md`).
2. **AIPCW intervals with a wrong dropout model** covered 80%. A bootstrap over the whole procedure would show whether the undercoverage is the variance formula. Expensive: about 200 refits per hospital. Try on 50 hospitals first.
3. **Phase 1, trial of about 125:** extend from 50 to 500 hospitals (`Rscript scripts/07_run_phase1.R sl 0.05 500 3`, about 1.5 hours).

## Still to do

- An 8–10 slide deck from the two reports. Only after you have read the lessons and the reports, and can explain each slide yourself.
- The README section "How this was built": your own account of your role.
- Make the repository public only when you decide to share it.

## If a chunk file is damaged

If a summary script stops with an error reading a `.rds` file, that chunk was being written at a shutdown. Delete that one file and rerun its run command; it will be recomputed with the same seeds.

## For a new Claude Code session

Read, in this order: this file, `docs/LOG.md`, `docs/WORKPLAN.md`, `reports/phase1_results.md`, `reports/phase2_results.md`, and the project plan (kept outside this repository).
