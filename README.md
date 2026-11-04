# Profile-specific treatment effects from a nested trial, with and without dropout

A simulation study in R. It rebuilds the estimator of Wen, Dahabreh and Chiu, *Generalizing conditional average treatment effects from nested randomized trials to all trial-eligible individuals* (Statistics in Medicine 2026; arXiv:2605.14952). It then asks what happens when trial patients drop out before the end of follow-up, a case the paper sets aside ("no dropout in the trial").

**Status:** Phase 1 complete (Gate 1 passed; `reports/phase1_results.md`). Phase 2 complete at 200 hospitals per setting (Gate 2 passed for median-based bias, not for stability or intervals; `reports/phase2_results.md`). The results have been reviewed and rechecked, and exploratory follow-up runs, pre-specified in `docs/exploratory_prespecification.md`, are done (`reports/phase2_results.md`). Process log: `docs/LOG.md`.

## The question

A trial is nested in a cohort of everyone eligible for a treatment. Characteristics are known for everyone; treatment and outcome only for those randomized. The goal is the treatment effect for each patient profile among all eligible patients, not only those who joined the trial.

Phase 1 rebuilds the paper's estimator for a binary outcome and checks it in simulation, where the true effect is known. Phase 2 replaces the binary outcome with event times, adds dropout, and traces the effect for each profile from year 1 to year 5.

## Running it

From the repository root, with R 4.4 and the packages `yaml`, `ggplot2`, `testthat`, `SuperLearner`, `gam`, `ranger`, `future`, `future.apply` and `survival`:

```
Rscript scripts/01_check_generator.R
Rscript scripts/02_check_helpers.R
Rscript scripts/03_check_pseudo_outcome.R
Rscript -e 'testthat::test_dir("tests/testthat")'
```

## Layout

| Folder | Contents |
|---|---|
| `config/` | Simulation settings (design choices, not estimates from real data) |
| `R/` | Functions: data generation, true effects, estimators |
| `scripts/` | Numbered scripts, one per step |
| `tests/testthat/` | Automatic checks |
| `reports/` | Figures, tables and write-ups |
| `docs/lessons/` | Plain-language lessons, one per step |
| `docs/WORKPLAN.md` | Steps and their state |

## What this does not claim

It proposes no new estimator. Weighting for dropout is a standard technique. All numbers depend on a synthetic data-generating mechanism and say nothing about any real treatment.

## Reference implementation

Robertson, Steingrimsson and Dahabreh (Eur J Epidemiol 2023) published R code for a related estimator: https://github.com/serobertson/GeneralizabilityCATE. It is used here only as an independent check. No code is copied from it.

## How this was built

The code, reports and lessons were written with an AI coding assistant (Claude Code), as the commit history shows. The author chose the question, decided each step in discussion with the assistant, and approved the corrections and further runs.

- **Checks that changed the work.** A blind code review found no sign, target or leakage errors. Its other findings are disclosed in `reports/phase2_results.md`. Four were tested: the compensator step size, the coverage target, complete case's trial-joining model, and the logistic outcome model. None changed a conclusion. Claims the numbers did not support were corrected, and every reported number was kept.
- **Second methods.** The pseudo-outcomes match the code of Robertson et al. 2023 to 1.4e-14 over 7 runs on 5 generated datasets (`reports/tables/05_reference_check.csv`). An independent script, written without reading the estimators, reproduces the true values at t = 5 for v = 1, 2 and 3 to 4e-16 (`independent_check/compare_truth.R`), and the pattern of large errors (`independent_check/`).
- **Two computers.** The first Phase 1 and Phase 2 runs were made on an earlier computer. One assistant session then ran the review's checks and the later runs. A second session, on another computer, checked each result before it counted.
- **Fixed in advance.** The later runs are exploratory. Their expected directions and the rule for scoring them were committed before the full runs (`docs/exploratory_prespecification.md`).
- **What is reproducible.** The hospital-level rows of the later runs and `reports/tables/15_runs.csv` record the commit of the code that produced them.
