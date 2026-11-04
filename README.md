# Profile-specific treatment effects from a nested trial, with and without dropout

A simulation study in R. It rebuilds the estimator of Wen, Dahabreh and Chiu, *Generalizing conditional average treatment effects from nested randomized trials to all trial-eligible individuals* (Statistics in Medicine 2026; doi:10.1002/sim.70767; arXiv:2605.14952). It then asks what happens when trial patients drop out before the end of follow-up, a case the paper sets aside ("no dropout in the trial").

**Status:** Phase 1 complete (Gate 1 passed; `reports/phase1_results.md`). Phase 2 complete at 200 hospitals per setting (Gate 2 passed for median bias, not for stability or intervals; `reports/phase2_results.md`). The results have been reviewed and rechecked, and exploratory follow-up runs, pre-specified in `docs/exploratory_prespecification.md`, are done (`reports/phase2_results.md`). Process log: `docs/LOG.md`.

## The question

A trial is nested in a cohort of everyone eligible for a treatment. Characteristics are known for everyone; treatment and outcome only for those randomized. The goal is the treatment effect for each patient profile among all eligible patients, not only those who joined the trial.

Phase 1 rebuilds the paper's estimator for a binary outcome and checks it in simulation, where the true effect is known. Phase 2 replaces the binary outcome with event times, adds dropout, and traces the effect for each profile from year 1 to year 5.

**Gates.** Each phase ended with a gate, a list of conditions fixed before its full runs. **Gate 1** (Phase 1): the pseudo-outcomes match the reference code, the paper's estimator has small bias, the trial-only estimator is biased, and coverage is near 90 to 95%. **Gate 2** (Phase 2): with no dropout, all methods agree; the weighted methods have small bias under random and dependent dropout; and AIPCW holds with a wrong dropout model while IPCW does not. Results against each condition are in the two reports.

## Running it

From the repository root, with R 4.4 and the packages `yaml`, `ggplot2`, `testthat`, `SuperLearner`, `gam`, `ranger`, `future`, `future.apply` and `survival`. Tests and the step checks:

```
Rscript -e 'testthat::test_dir("tests/testthat")'
Rscript scripts/01_check_generator.R
Rscript scripts/02_check_helpers.R
Rscript scripts/03_check_pseudo_outcome.R
Rscript scripts/04_check_curve.R
```

The saved results (about 320 MB, in `results/`) are included, so the summary scripts can be rerun without the long runs. The run scripts skip chunks that already exist. They refuse to start when `R/`, `config/` or `scripts/` have uncommitted changes, and record the commit in every result row; `scripts/13_precision_tables.R` also refuses uncommitted changes in `results/`.

Full order, with what each step needs. Times are rough, for 3 workers on a 4-core laptop.

| Step | Command | Needs | Time |
|---|---|---|---|
| Reference check | `Rscript scripts/05_reference_check.R` | Internet, to download Robertson et al.'s code | under 1 minute |
| Phase 1 runs | `Rscript scripts/07_run_phase1.R sl 0.20 500 3`, then `sl 0.05 500 3`; pilot `glm 0.20 100 3` | — | about 2 hours per 500 hospitals with `sl`; minutes for the pilot |
| Phase 1 summary | `Rscript scripts/08_summarise_phase1.R` | `results/phase1/` | seconds |
| Phase 2 check | `Rscript scripts/09_check_phase2.R` | — | about 1 minute |
| Phase 2 runs | `Rscript scripts/10_run_phase2.R C0 200 3`, and likewise C1 to C4 | — | about 25 minutes per setting |
| Phase 2 summary | `Rscript scripts/11_summarise_phase2.R` | `results/phase2/` | under 1 minute |
| Reproduction check | `Rscript scripts/12_check_reproduction.R` | `results/phase2/`, `results/archive/phase2_200_before_bj/` | seconds |
| Precision tables | `Rscript scripts/13_precision_tables.R` | steps 8 and 11, `results/summary_phase2_20261023.txt` | under 1 minute |
| Review checks | `scripts/14_check_compensator.R` (`integrate`; `run <setting> <steps> 200 3`; `patients <setting> 200 3`), `14_check_cc_propensity.R <setting> 200 3`, `14_check_helpers.R 25 3`, `14_followups.R` | `results/phase2/` | from seconds (`integrate`) to about 1.5 hours per compensator run |
| Review summaries | `14_check_center_coverage.R`, `14_check_smoothed_coverage.R`, `14_summarise_checks.R` | steps 10, 13 and the review checks | 13 minutes, under 1 minute, under 1 minute |
| Exploratory runs | `Rscript scripts/15_run_exploratory.R <run> <setting> 200 3` | — | about 1 hour per setting for Run A, 20 minutes for the others |
| Exploratory summaries | `15_summarise_exploratory.R`, `15_sd_table.R` | exploratory runs, `results/phase2/` | about 40 minutes; seconds |
| Deck tables | `Rscript scripts/16_deck_tables.R 3` | steps 13 and 15 | about 15 minutes |

The independent second method is in `independent_check/`; see its scripts' headers.

## Layout

| Folder or file | Contents |
|---|---|
| `config/` | Simulation settings (design choices, not estimates from real data) |
| `R/` | Functions: data generation, true effects, estimators |
| `scripts/` | Numbered scripts, one per step |
| `tests/testthat/` | Automatic checks |
| `results/` | Saved hospital-level rows; `results/README.md` labels each folder |
| `reports/` | Figures, tables and write-ups |
| `independent_check/` | A second method written without reading the estimators, and its comparison with the repository |
| `docs/lessons/` | Plain-language lessons, one per step |
| `docs/LOG.md` | Every decision, change and check, in order, with reasons |
| `docs/exploratory_prespecification.md` | Expected directions and the decision rule for the exploratory runs, committed before them |
| `docs/WORKPLAN.md` | Steps and their state |
| `docs/HANDOFF.md` | Current status, open questions, how to continue |

## What this does not claim

- It proposes no new estimator. Weighting for dropout is a standard technique.
- All numbers depend on a synthetic data-generating mechanism and say nothing about any real treatment.
- The 95% intervals are not validated for these estimators, and several undercover.
- Dependent dropout was strengthened after the first results, because the first setting was too mild to show a wrong dropout model (`docs/LOG.md`).
- Time to benefit uses δ = 0.05, a departure from the plan, which set δ = 0.01 and 0.02.
- The exploratory runs use one cohort size (2,500), so whether a bias shrinks with sample size cannot be seen.

## Reference implementation

Robertson, Steingrimsson and Dahabreh (Eur J Epidemiol 2023) published R code for a related estimator: https://github.com/serobertson/GeneralizabilityCATE. It is used here only as an independent check. No code is copied from it.

## How this was built

The code, reports and lessons were written with an AI coding assistant (Claude Code). The commit history shows this. The author chose the question, decided each step in discussion with the assistant, and approved the corrections and further runs.

- **Checks that changed the work.** A blind code review found no sign, target or leakage errors. Its other findings are disclosed in `reports/phase2_results.md`. Four were tested: the compensator step size, the coverage target, complete case's trial-joining model, and the logistic outcome model. None changed a conclusion. Claims the numbers did not support were corrected, and every reported number was kept.
- **Second methods.** The pseudo-outcomes match the code of Robertson et al. 2023 to 1.4e-14 over 7 runs on 5 generated datasets (`reports/tables/05_reference_check.csv`). An independent script, written without reading the estimators, reproduces the true values at t = 5 for v = 1, 2 and 3 to 4e-16 (`independent_check/compare_truth.R`), and the pattern of large errors (`independent_check/`).
- **Separate sessions.** The blind code review and the independent script were each done by a separate AI session, not by the session that wrote the estimators.
- **Two computers.** The first Phase 1 and Phase 2 runs were made on an earlier computer. One assistant session then ran the review's checks and the later runs. A second session, on another computer, checked each result before it counted.
- **Fixed in advance.** The later runs are exploratory. Their expected directions and the rule for scoring them were committed before the full runs (`docs/exploratory_prespecification.md`).
- **What is reproducible.** The hospital-level rows of the later runs and `reports/tables/15_runs.csv` record the commit of the code that produced them.

## References

- Wen, Dahabreh and Chiu. Generalizing conditional average treatment effects from nested randomized trials to all trial-eligible individuals. Statistics in Medicine 2026. doi:10.1002/sim.70767.
- Robertson, Steingrimsson and Dahabreh. European Journal of Epidemiology 2023. Code: https://github.com/serobertson/GeneralizabilityCATE.
- Steingrimsson and Morrison. Statistics in Medicine 2020.
- Dahabreh, Robertson, Steingrimsson, Stuart and Hernán. Statistics in Medicine 2020.
- Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate statistical methods. Statistics in Medicine 2019;38:2074–2102. doi:10.1002/sim.8086.
- Pawel S, Kook L, Reeve K. Pitfalls and potentials in simulation studies: questionable research practices in comparative simulation studies allow for spurious claims of superiority of any method. Biometrical Journal 2023;e2200091. doi:10.1002/bimj.202200091.

## Licence

Code: MIT (`LICENSE`). Documents and reports in `docs/` and `reports/`: CC BY 4.0 (`LICENSE-docs`).
