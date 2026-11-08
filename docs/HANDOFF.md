# Status

Updated 5 November 2026.

## Done

| Part | State |
|---|---|
| Phase 1 (binary outcome, no dropout) | 500 hospitals, Gate 1 passed. `reports/phase1_results.md` |
| Phase 1, trial of about 125 | 50 of 500 hospitals, preliminary |
| Phase 2 (dropout, effect over time) | 200 hospitals per setting, C0 to C4. Gate 2: the first two conditions were met for median bias; the third (AIPCW holds with a wrong dropout model while IPCW does not) was met only partly; stability and intervals failed. `reports/phase2_results.md` |
| Review of Phase 2 | Claims corrected, disclosures added, no reported number changed. `reports/phase2_results.md`, section "Corrections, disclosures and checks after review" |
| Exploratory Runs A, B and C | 200 hospitals each, pre-specified in `docs/exploratory_prespecification.md`. No floor chosen. `reports/phase2_results.md`, section "Exploratory runs" |
| Lessons | 1 to 12 in `docs/lessons/` (lessons 5 and 6 share one file) |
| Process log | `docs/LOG.md` |

## Open questions

1. **Signed median bias at v = 2.** At t = 5 in C2, the repository's AIPCW has signed median bias -0.021 and the independent script's 0.031 (`independent_check/comparison_C2_t5.csv`). The difference of 0.05 is not explained.
2. **Seed 145.** The same patient (1/G = 16,469.6) has a 30-step compensator error (against 3,000 steps) of 14.08 in C2 and 1.21 in C4. G is the same in both, so the difference comes from the outcome-model term; how was not examined. (`reports/tables/14_compensator_patients_C2.csv`, `_C4.csv`, `14_compensator_slope.csv`)
3. **CC in C5b.** CC's median bias was 0.021 in C5b against 0.091 in C2. Its participation and outcome models were wrong together, and the reason was not examined, so this does not show that CC improved.

Other limits, such as the intervals that undercover and the source of the large errors, are listed in `reports/phase2_results.md` and lesson 12.

## How to continue

- The run order, with what each script needs, is in `README.md`. Runners refuse to start when `R/`, `config/` or `scripts/` have uncommitted changes, and record the commit in every result row.
- The Phase 1 trial of about 125 can be extended from 50 to 500 hospitals with `Rscript scripts/07_run_phase1.R sl 0.05 500 3`. Finished chunks are skipped. Then change `sl_trial05 = 50` to 500 in `scripts/08_summarise_phase1.R` and `scripts/13_precision_tables.R`.
- Step 16 of `docs/WORKPLAN.md` (Brier score and calibration of each arm's risk model among all eligible patients, with dropout) is not started. It is unrelated to `scripts/16_deck_tables.R`.
- Read, in this order: this file, `docs/LOG.md`, `docs/WORKPLAN.md`, `reports/phase1_results.md` and `reports/phase2_results.md`.

## If a chunk file is damaged

If a summary script stops with an error reading a `.rds` file, that chunk was being written when a run stopped. Delete that one file and rerun its run command; it is recomputed with the same seeds.
