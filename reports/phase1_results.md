# Phase 1 results: the paper's estimator rebuilt and tested

22 October 2026. Binary outcome, no dropout. Settings: `config/phase1.yaml`. Process and decisions: `docs/LOG.md`.

## Main result

500 simulated hospitals, each with 2,500 eligible patients, of whom about 500 joined the trial. Helper models fitted with Super Learner (logistic regression, generalized additive model, random forest), five-fold cross-fitting. Commit a9a8cd8.

Each estimator's curve is scored against the true target curve (all eligible patients) at 37 values of v, then averaged over v ("integrated"), as in the paper's Table 1.

| Estimator | Integrated absolute bias | Integrated RMSE | Coverage of 95% intervals |
|---|---|---|---|
| **P** the paper's method | **0.020** | 0.099 | **91.9%** of the true curve; 94.0% of the smoothed curve |
| L straight line through the same pseudo-outcomes | 0.060 | 0.097 | 81.0% |
| T trial patients only | 0.056 | 0.095 | 85.0% of the target curve (90.2% of its own trial curve) |
| G outcome model alone, no correction | 0.028 | 0.074 | no interval |

For comparison, the paper's Table 1 (binary outcome, cohort 2,500, trial 500): integrated absolute bias 0.020 for its method against 0.101 for the straight line, coverage 92% against 77%. Our data-generating mechanism is our own (the paper's Web Appendix D is not public), so only the pattern can be compared, not the exact values.

`reports/figures/07_sl_trial20_mean_curves.png` shows the average curve of each estimator against the truth.

## What it shows

1. **The method works as the paper says.** Its average curve follows the true one, with the same small bias and slightly below-nominal coverage that the paper reports.
2. **The trial alone is biased for the target.** T describes the healthier trial population; its intervals cover the target curve only 85% of the time.
3. **A straight line is biased** where the curve bends (81% coverage).
4. **The outcome model alone is more precise but less safe.** With the right terms (logistic pilot), G had bias 0.007; with Super Learner, which is not told the right terms, its bias rose to 0.028. P's protection matters when the outcome model is wrong, which in real data you cannot check.
5. **P's remaining bias comes from smoothing.** It is too high where the curve dips and too low where it rises. Cross-validation often picks a wide bandwidth (median 1.9 of a maximum 2.0) because the noisy pseudo-outcomes make all bandwidths score almost equally (LOG, "Second pilot"). Coverage of the smoothed curve (94.0%) is closer to nominal than coverage of the exact curve (91.9%), which is the distinction the paper draws in section 5.1.

## Checks behind it

- Our pseudo-outcomes equal those from Robertson, Steingrimsson and Dahabreh's published code to 2 × 10⁻¹⁴ (step 5).
- Double robustness of the pseudo-outcome confirmed with true helper values (tests) and with fitted models over 200 hospitals (step 3).
- 22 automatic tests for Phase 1, all passing.

## Preliminary: smaller trial

50 hospitals with about 125 trial patients (5% trial share), from a run interrupted by the scheduled shutdown:

| Estimator | Integrated absolute bias | Integrated RMSE | Coverage |
|---|---|---|---|
| P | 0.052 | 0.276 | 91.7% |
| L | 0.075 | 0.211 | 89.6% |
| T | 0.059 | 0.174 | 89.0% |
| G | 0.044 | 0.144 | — |

With 50 hospitals and RMSE near 0.28, the bias figures carry Monte Carlo error of about 0.04, so they cannot yet be ranked. The paper trimmed the most extreme 5% of estimates in this setting; we have not. To be completed to 500 hospitals.

## Gate 1

| Condition | Result |
|---|---|
| Pseudo-outcomes match the reference code | Yes, to 2 × 10⁻¹⁴ |
| The paper's estimator has small bias | Yes, 0.020 |
| The trial-only estimator is biased for the target | Yes, 0.056; coverage 85% |
| Coverage near 90–95% | Yes, 91.9% (94.0% of the smoothed curve) |

**Passed.**
