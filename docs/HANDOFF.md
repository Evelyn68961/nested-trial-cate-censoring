# Handoff: where the project stopped, and how to continue

Written 22 October 2026, 16:45, before the computer's scheduled shutdown at 17:30.

## State

| Part | State |
|---|---|
| Phase 1 code (steps 1 to 7) | Done, tested (22 tests) |
| Phase 1 main run: Super Learner, trial about 500 | **Done, 500 hospitals. Gate 1 passed.** `reports/phase1_results.md` |
| Phase 1 run: Super Learner, trial about 125 | 50 of 500 hospitals |
| Phase 2 code (dropout, effect over time) | Done, tested (7 tests) |
| Phase 2 runs | D3 dropout; 200 hospitals done at 18:44 but IPCW/AIPCW blew up from extreme weights (LOG). Truncated versions added; all four settings rerun from 18:48 in order C2, C3, C1, C0 (about 70 min). Check `results/phase2/*` for how far it got |
| Lessons | 1 to 9 written; 10 (Phase 2 results) not yet |
| Report for Phase 2 | Preliminary only: `reports/phase2_preliminary.md` |

All code, documents and finished result chunks are on GitHub. An autosave loop pushed new chunks every 4 minutes until 17:28. A chunk that was being written at shutdown is lost, not half-saved, unless the shutdown hit the moment of writing. See "If a chunk file is damaged" below.

## To continue

1. Turn the computer on. Open the repository folder `nested-trial-cate-censoring`.
2. Make sure the local copy is complete: `git pull`
3. Check what finished: `ls results/phase2/*` (each chunk file = 25 hospitals).
4. Resume the 200-hospital runs (D3 dropout is already in the config; the old mild-dropout C2/C3 results are in `results/archive/`). Each command continues from saved chunks and only adds missing ones:

```
Rscript scripts/10_run_phase2.R C2 200 3
Rscript scripts/10_run_phase2.R C3 200 3
Rscript scripts/10_run_phase2.R C1 200 3
Rscript scripts/10_run_phase2.R C0 200 3
Rscript scripts/11_summarise_phase2.R
```

At about 15 seconds per hospital with 3 workers, 200 hospitals take about 17 minutes per setting.

5. Then, when the computer is free for longer:

```
Rscript scripts/07_run_phase1.R sl 0.05 500 3     # trial about 125: from 50 to 500 hospitals, about 1.5 hours
Rscript scripts/08_summarise_phase1.R
```

## If a chunk file is damaged

If a summary script stops with an error reading a `.rds` file, that chunk was being written at the moment of shutdown. Delete that one file and rerun its run command; it will be recomputed with the same seeds.

## Still to write after the runs

- `reports/phase2_results.md`: bias and coverage for CC, NE, IPCW and AIPCW under C0 to C3; time to benefit by profile.
- Lesson 10 (Phase 2 results).
- An 8–10 slide deck, once Phase 2 holds up (Gate 2).
- The README section "How this was built": your own account of your role.

## For a new Claude Code session

Ask it to read, in this order: this file, `docs/LOG.md` (every decision and its reason), `docs/WORKPLAN.md`, and the project plan (kept outside this repository).
