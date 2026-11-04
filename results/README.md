# Results

Hospital-level rows saved by the run scripts, in chunks of 25 hospitals (`chunk_<k>.rds`). The summary scripts read them; the reports in `reports/` can be read without them.

| Folder or file | Contents |
|---|---|
| `phase1/sl_trial20/` | Phase 1 main run: 500 hospitals, Super Learner nuisance models, trial share 20% (about 500 trial patients) |
| `phase1/sl_trial05/` | Trial share 5% (about 125 trial patients): 50 of 500 hospitals. **Preliminary** |
| `phase1/glm_trial20/` | **Pilot:** 100 hospitals with logistic-regression nuisance models |
| `phase2/C0/` to `phase2/C4/` | Phase 2: 200 hospitals per setting |
| `exploratory/A/`, `B/`, `C/`, `control/` | Exploratory Runs A to C and their controls, 200 hospitals each (`docs/exploratory_prespecification.md`) |
| `exploratory/zero/` | Control only: every floor scheme at floor 0, 3 hospitals |
| `exploratory_smoke_final/` | The final 3-hospital smoke test before the full exploratory runs. A test of the code, not a result |
| `check_step2/` | Review checks: compensator step size, per-patient compensator error, and CC with full-cohort propensities |
| `summary_phase2_20261023.txt` | Printed summary of the 23 October Phase 2 runs; `scripts/13_precision_tables.R` checks against it |
| `archive/` | Superseded runs, run logs, summaries and earlier smoke tests, kept for the record |

One saved table needs a warning: the T rows of `reports/tables/14_smoothed_coverage_phase1.csv` use the wrong target and are not interpreted; see `reports/tables/14_smoothed_coverage_phase1_NOTES.md`.

`reference/` is not committed: `scripts/05_reference_check.R` downloads Robertson et al.'s code into it at run time, because that code has no licence.
