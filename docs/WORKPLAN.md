# Work plan

The project is built in small steps. Each step has code, tests and one plain-language lesson. Each step ends only when the code passes its tests and the lesson's "check yourself" questions can be answered.

Full rationale: `nested_trial_CATE_censoring_plan.md` (kept outside this repository).

## Phase 1: rebuild the estimator (binary outcome, no dropout)

| Step | Code | Lesson | State |
|---|---|---|---|
| 1 | Simulated hospitals; the two true effect curves | 01 The question | Done 2026-10-22 |
| 2 | The three helper models, fitted with cross-fitting | 02 Helper models | Done 2026-10-22 |
| 3 | The pseudo-outcome (paper's equation 1) | 03 The pseudo-outcome | |
| 4 | Smoothing: local linear regression, bandwidth, intervals | 04 Drawing the curve | |
| 5 | Cross-check against Robertson et al. 2023 code on one dataset | — | |
| 6 | The three comparison estimators (straight line, trial only, outcome model only) | 05 Why the shortcuts fail | |
| 7 | Run many hospitals (50 pilot, then 500); score bias, RMSE, coverage | 06 Judging a method | |

**Gate 1:** pseudo-outcomes match the reference code; the paper's estimator has small bias; the trial-only estimator is biased; coverage near 90–95%.

## Phase 2: dropout and time

| Step | Code | Lesson | State |
|---|---|---|---|
| 8 | Event times (Weibull per arm); true risk-difference curves at years 1 to 5 | 07 Effects that grow over time | |
| 9 | Dropout settings C0 to C3 | 08 What dropout does | |
| 10 | Four ways of handling dropout, including the weighted one | 09 Weighting for dropout | |
| 11 | Runs, time to benefit by profile, tables and figures | — | |

**Gate 2:** C0 reproduces Phase 1 at every year; the weighted estimator has small bias in C1 and C2.

## Output

Reports in `reports/`, a slide deck, and this repository made public once the results have been checked.
