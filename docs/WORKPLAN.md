# Work plan

The project is built in small steps. Each step has code, tests and one plain-language lesson. Each step ends only when the code passes its tests and the lesson's "check yourself" questions can be answered.

Full rationale: `nested_trial_CATE_censoring_plan.md` (kept outside this repository).

## Phase 1: rebuild the estimator (binary outcome, no dropout)

| Step | Code | Lesson | State |
|---|---|---|---|
| 1 | Simulated hospitals; the two true effect curves | 01 The question | Done 2026-10-22 |
| 2 | The three helper models, fitted with cross-fitting | 02 Helper models | Done 2026-10-22 |
| 3 | The pseudo-outcome (paper's equation 1) | 03 The pseudo-outcome | Done 2026-10-22 |
| 4 | Smoothing: local linear regression, bandwidth, intervals | 04 Drawing the curve | Done 2026-10-22 |
| 5 | Cross-check against Robertson et al. 2023 code on one dataset | — | Done 2026-10-22: match to 2e-14 |
| 6 | The three comparison estimators (straight line, trial only, outcome model only) | 05 Why the shortcuts fail | Code done; lesson to write |
| 7 | Run many hospitals (50 pilot, then 500); score bias, RMSE, coverage | 06 Judging a method | 500 hospitals done (trial 500); trial 125 at 50 of 500. Gate 1 passed. See reports/phase1_results.md |

**Gate 1:** pseudo-outcomes match the reference code; the paper's estimator has small bias; the trial-only estimator is biased; coverage near 90–95%.

## Phase 2: dropout and time

| Step | Code | Lesson | State |
|---|---|---|---|
| 8 | Event times (Weibull per arm); true risk-difference curves at years 1 to 5 | 07 Effects that grow over time | Done 2026-10-22 |
| 9 | Dropout settings C0 to C3 | 08 What dropout does | Done 2026-10-22 (dependent dropout strengthened after first runs) |
| 10 | Four ways of handling dropout, plus truncated versions of the two weighted ones | 09 Weighting for dropout | Done 2026-10-22 |
| 11 | Runs, time to benefit by profile, tables and figures | 10 Phase 2 results | Done 2026-10-22: 200 hospitals per setting. Gate 2 passed for bias, not for stability or intervals. See reports/phase2_results.md |

**Gate 2:** C0 reproduces Phase 1 at every year; the weighted estimator has small bias in C1 and C2.

## Phase 2 additions from Steingrimsson's work

Ranked in a notes file kept outside this repository.

| Step | Code | Lesson | State |
|---|---|---|---|
| 12 | Buckley-James estimator: no dropout weight, dropouts filled in by the outcome model | 11 Which model to trust | Done 2026-10-23 |
| 13 | Setting C4: right dropout model, outcome models without frailty | 11 | Done 2026-10-23 |
| 14 | Weight checks per hospital, and four flagging rules | 11 | Done 2026-10-23 |
| 15 | Rerun C0 to C4 at 200 hospitals; report and lesson | 11 | Done 2026-10-23, 08:42. Gate 3 passed, except that no weight check identifies broken hospitals (a finding) |
| 16 | Optional: Brier score and calibration of each arm's risk model among all eligible patients, with dropout | 12 | Not started |

**Gate 3:** the six existing estimators reproduce the 22 October numbers exactly; BJ is stable in C2 if the dropout weight caused the breaks; BJ is biased in C4 while IPCW and AIPCW are not; the report says which weight check, if any, flags the broken hospitals.

## Output

Reports in `reports/`, a slide deck, and this repository made public once the results have been checked.
