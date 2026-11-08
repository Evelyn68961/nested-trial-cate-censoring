# Profile-specific treatment effects from a nested trial, with and without dropout

A simulation study in R. It rebuilds the estimator of Wen, Dahabreh and Chiu, *Generalizing Conditional Average Treatment Effects From Nested Randomized Trials to Trial-Eligible Individuals* (Statistics in Medicine 2026; doi:10.1002/sim.70767; arXiv:2605.14952). It then asks what happens when trial patients drop out before the end of follow-up, a case the paper sets aside ("no dropout in the trial").

**Status:** Phase 1 complete (Gate 1 passed; `reports/phase1_results.md`). Phase 2 complete at 200 hospitals per setting. Gate 2: the first two conditions were met for median bias; the third (AIPCW holds with a wrong dropout model while IPCW does not) was met only partly; stability and intervals failed (`reports/phase2_results.md`). The results have been reviewed and rechecked, and exploratory follow-up runs, pre-specified in `docs/exploratory_prespecification.md`, are done (`reports/phase2_results.md`). Process log: `docs/LOG.md`.

## The question

A trial is nested in a cohort of everyone eligible for a treatment. Characteristics are known for everyone; treatment and outcome only for those randomized. The goal is the treatment effect for each patient profile among all eligible patients, not only those who joined the trial.

Phase 1 rebuilds the paper's estimator for a binary outcome and checks it in simulation, where the true effect is known. Phase 2 replaces the binary outcome with event times, adds dropout, and traces the effect for each profile from 0.5 to 5 years.

**Gates.** Each phase ended with a gate, a list of conditions fixed before its full runs. **Gate 1** (Phase 1): the pseudo-outcomes match the reference code, the paper's estimator has small bias, the trial-only estimator is biased, and coverage is near 90 to 95%. **Gate 2** (Phase 2): with no dropout, all methods agree; the weighted methods have small bias under random and dependent dropout; and AIPCW holds with a wrong dropout model while IPCW does not. Results against each condition are in the two reports.

## Running it

From a git clone of the repository root (a ZIP download will not run), with git, R 4.4 and the packages `yaml`, `ggplot2`, `testthat`, `SuperLearner`, `gam`, `ranger`, `future`, `future.apply` and `survival`. Tests and the step checks (on Windows, write the first command as `Rscript -e "testthat::test_dir('tests/testthat')"`):

```
Rscript -e 'testthat::test_dir("tests/testthat")'
Rscript scripts/01_check_generator.R
Rscript scripts/02_check_helpers.R
Rscript scripts/03_check_pseudo_outcome.R
Rscript scripts/04_check_curve.R
```

The saved results (about 320 MB, in `results/`) are included, so the summary scripts can be rerun without the long runs. The run scripts skip chunks that already exist. They refuse to start when `R/`, `config/` or `scripts/` have uncommitted changes, and record the commit in every result row; `scripts/13_precision_tables.R` also refuses uncommitted changes in `results/`.

Full order, with what each step needs. Times are approximate, from one laptop. They are measured with 3 workers on a 4-core laptop, from the reproduction runs of 5 November 2026 or from `docs/LOG.md`; a per-hospital median comes from the run tables. A blank time was not measured.

| Step | Command | Needs | Time |
|---|---|---|---|
| Reference check | `Rscript scripts/05_reference_check.R` | Internet, to download Robertson et al.'s code | under 1 minute |
| Phase 1 runs | `Rscript scripts/07_run_phase1.R sl 0.20 500 3`, then `sl 0.05 50 3` (the saved preliminary run, 50 of 500); pilot `glm 0.20 100 3` | — | about 5.5 minutes per 25 hospitals with `sl`; about 5 minutes per 50 hospitals with `glm` (`docs/LOG.md`) |
| Phase 1 summary | `Rscript scripts/08_summarise_phase1.R` | `results/phase1/` | under 1 minute |
| Phase 2 check | `Rscript scripts/09_check_phase2.R` | — | 16 to 20 seconds per setting (`docs/LOG.md`) |
| Phase 2 runs | `Rscript scripts/10_run_phase2.R C0 200 3`, and likewise C1 to C4 | — | about 25 minutes per setting (`docs/LOG.md`) |
| Phase 2 summary | `Rscript scripts/11_summarise_phase2.R` | `results/phase2/` | under 1 minute |
| Reproduction check | `Rscript scripts/12_check_reproduction.R` | `results/phase2/`, `results/archive/phase2_200_before_bj/` | under 1 minute |
| Precision tables | `Rscript scripts/13_precision_tables.R` | steps 8 and 11, `results/summary_phase2_20261023.txt` | under 1 minute |
| Compensator checks | `Rscript scripts/14_check_compensator.R integrate`; `run <setting> <steps> 200 3` for C2 and C4 at 300 and 3000 steps; `patients <setting> 200 3` for C2 and C4 | `results/phase2/`, for the `integrate` and `patients` modes | under 1 minute; median 72 to 77 seconds per hospital (`reports/tables/14_checks_runs.csv`); 4 minutes per setting |
| CC propensity check | `Rscript scripts/14_check_cc_propensity.R <setting> 200 3` for C1 and C2 | — | median 8 seconds per hospital (`reports/tables/14_checks_runs.csv`) |
| Nuisance-model check | `Rscript scripts/14_check_helpers.R 25 3` | — | under 1 minute |
| Follow-ups | `Rscript scripts/14_followups.R warnings <setting> 3` for C2 and C4; `warnings_cc <setting> 3` for C1 and C2; `slope` | `results/phase2/`, `results/check_step2/` | 8.5 to 8.8 minutes per setting; under 1 minute; under 1 minute |
| Review summaries | `14_check_center_coverage.R`, `14_check_smoothed_coverage.R`, `14_summarise_checks.R`; `14_check_smoothed_coverage.R fine_grid` writes the Phase 2 table on an 80,001-point grid (`14_smoothed_coverage_phase2_fine_grid.csv`) | `results/phase2/`; the smoothed check also reads `results/phase1/`; the summary reads `results/check_step2/` | 13 minutes; under 1 minute; under 1 minute |
| Exploratory runs | `Rscript scripts/15_run_exploratory.R <run> <setting> 200 3` for A with C2 and C4, B with C2m and C3m, C with C5a and C5b, and control with C2 and C4; zero control `Rscript scripts/15_run_exploratory.R zero C2 3 3` and `zero C4 3 3` | — | median 59 seconds per hospital for Run A, 17 to 18 seconds for the others (`reports/tables/15_runs.csv`) |
| Exploratory summaries | `15_summarise_exploratory.R`, `15_sd_table.R` | exploratory runs, `results/phase2/` | 41 minutes; under 1 minute |
| Deck tables | `Rscript scripts/16_deck_tables.R 3` | steps 13 and 15 | 14.5 minutes |

The independent second method is in `independent_check/`; see its scripts' headers. `independent_check.R` uses 4 workers.

Analysis settings (G floor 0.05, 30 compensator steps, bandwidth grids, the mild dropout rates) are set in the code, not in `config/`.

`docs/sessionInfo_reproduction.txt` records the R session of the machine that reproduced the tables on 5 November 2026. The original runs were made on another computer.

The figure scripts use the Cairo PNG device. The saved figures were drawn on the original computer; figures redrawn on another machine can differ in anti-aliasing, but not in content.

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
| `docs/commit_map.csv` | Old and new commit IDs, for IDs recorded before the history was rewritten |

## What this does not claim

- It proposes no new estimator. Weighting for dropout is a standard technique.
- All numbers depend on a synthetic data-generating mechanism and say nothing about any real treatment.
- The 95% intervals are not validated for these estimators, and several undercover.
- Dependent dropout was strengthened after the first results, because the first setting was too mild to show a wrong dropout model (`docs/LOG.md`).
- Time to benefit uses δ = 0.05, a departure from the plan, which set δ = 0.01 and 0.02. `reports/tables/10_phase2_time_to_benefit.csv` also holds rows for δ = 0.10.
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
- **What is reproducible.** The hospital-level rows of the later runs and `reports/tables/15_runs.csv` record the commit of the code that produced them. IDs saved in results refer to the old history; see `docs/commit_map.csv`.
- **Full reproduction.** On 5 November 2026, on a second computer, every summary table was regenerated from the saved results and matched exactly, and one chunk per run setting (16 in all) was regenerated from its seeds and matched exactly (`docs/LOG.md`).
- **Commit IDs.** Before publication, on 5 November 2026, the history was rewritten to remove private file paths and notes unrelated to this project. Code, tables and saved results were not changed by it; every saved result file is byte-identical. Commit IDs recorded in the saved results, tables and documents refer to the history before that rewrite. `docs/commit_map.csv` gives the new ID for each.

## References

- Wen, Dahabreh and Chiu. Generalizing Conditional Average Treatment Effects From Nested Randomized Trials to Trial-Eligible Individuals. Statistics in Medicine 2026;45(23-24):e70767. doi:10.1002/sim.70767.
- Robertson, Steingrimsson and Dahabreh. European Journal of Epidemiology 2023. Code: https://github.com/serobertson/GeneralizabilityCATE.
- Steingrimsson JA, Morrison S. Deep learning for survival outcomes. Statistics in Medicine 2020;39:2339–2349.
- Dahabreh IJ, Robertson SE, Steingrimsson JA, Stuart EA, Hernán MA. Extending inferences from a randomized trial to a new target population. Statistics in Medicine 2020;39:1999–2014.
- Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate statistical methods. Statistics in Medicine 2019;38:2074–2102. doi:10.1002/sim.8086.
- Pawel S, Kook L, Reeve K. Pitfalls and potentials in simulation studies: questionable research practices in comparative simulation studies allow for spurious claims of superiority of any method. Biometrical Journal 2023;e2200091. doi:10.1002/bimj.202200091.

## Licence

Code: MIT (`LICENSE`). Documents, reports, the READMEs and the saved results (`docs/`, `reports/`, `README.md`, `results/README.md`, `results/`): CC BY 4.0 (`LICENSE-docs`).
