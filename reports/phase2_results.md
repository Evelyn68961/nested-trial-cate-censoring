# Phase 2 results: dropout, and the effect traced over follow-up

22 October 2026, 20:40; additions (Buckley-James, setting C4, weight checks) on 23 October, at the end. 200 simulated hospitals per setting (2,500 eligible patients, about 500 in the trial). Event times from Weibull models in which the benefit grows over time; follow-up 5 years; effect estimated at ten times from 0.5 to 5 years. Settings: `config/phase2.yaml`. Every decision and change: `docs/LOG.md`. Supersedes `reports/phase2_preliminary.md`.

## The settings

| Setting | Dropout | Share of trial patients dropped out |
|---|---|---|
| C0 | none | 0% |
| C1 | random, 8% a year | 26% |
| C2 | dependent: frail and treated patients leave sooner | 30% |
| C3 | the same hospitals as C2, with a dropout model that leaves out frailty | 30% |

## Error at 5 years

Integrated absolute bias against the true target curve; in brackets, the number of the 200 hospitals whose curve missed the truth by more than 0.5 somewhere (a sign of exploding weights).

| Method | C0 none | C1 random | C2 dependent | C3 dropout model wrong |
|---|---|---|---|---|
| CC drop them | 0.024 (0) | 0.020 (7) | **0.093** (8) | **0.093** (8) |
| NE count as event-free | 0.024 (0) | **0.064** (6) | 0.027 (6) | 0.027 (6) |
| IPCW | 0.024 (0) | 0.026 (10) | 0.116 (**92**) | 0.037 (30) |
| AIPCW | 0.024 (1) | 0.022 (9) | 0.048 (**50**) | 0.027 (4) |
| IPCW, truncated at 0.05 | 0.024 (0) | 0.026 (10) | 0.022 (**83**) | 0.037 (30) |
| AIPCW, truncated at 0.05 | 0.024 (1) | 0.022 (9) | 0.029 (27) | 0.027 (4) |

Coverage of the 95% intervals at 5 years (target 95%; with no dropout, the Phase 1 method gives about 89% here):

| Method | C0 | C1 | C2 | C3 |
|---|---|---|---|---|
| CC | 89% | 90% | **68%** | **68%** |
| NE | 89% | **79%** | 92% | 92% |
| IPCW | 89% | 93% | 97% | 95% |
| AIPCW | 89% | 91% | 93% | **80%** |
| IPCW, truncated | 89% | 93% | 97% | 95% |
| AIPCW, truncated | 89% | 91% | 91% | **80%** |

## What the results show

1. **No dropout: every method gives the same answer**, as it must. The error (0.024) is the smoothing error from Phase 1.
2. **Each simple fix fails somewhere.** Counting dropouts as event-free fails under random dropout (0.064, coverage 79%). Dropping them fails under dependent dropout (0.093, coverage 68%). Each looks fine in the other setting, because its errors in the two arms happen to cancel there. **One setting cannot tell you whether a simple fix is safe.**
3. **Weighting removes the bias, but weights can explode.** Under dependent dropout with the right dropout model, some frail treated patients had an estimated chance of staying near 0.0001, so their weights reached tens of thousands. The curve then broke in 92 (IPCW) and 50 (AIPCW) of 200 hospitals. Measured by medians, which a few broken hospitals cannot drag, AIPCW was the least biased (0.019).
4. **Truncation helps but does not cure it.** With the chance of staying held at 0.05 or above, the average bias fell (IPCW 0.116 to 0.022; AIPCW 0.048 to 0.029), but 83 and 27 hospitals still broke, against 0 or 1 with no dropout. The likely reason: the dropout weight multiplies the trial-joining weight from Phase 1 (which can exceed 100), so the combined weight can still be in the thousands.
5. **AIPCW is the more stable of the two weighting methods** in every setting: fewer broken hospitals and lower RMSE than IPCW.
6. **With a wrong dropout model (C3), AIPCW keeps its bias low (0.027, the C0 level); IPCW is slightly worse (0.037).** This is the direction double robustness predicts, but the gap is small in this design.
7. **AIPCW's intervals undercover when the dropout model is wrong (80%).** The sandwich intervals treat the helper models as known. When one helper model is wrong, the estimate stays right but its variance formula no longer is. Double robustness protects the estimate, not the interval.

## Time to benefit for each profile

The first time at which the drug lowers the risk by at least 5 points (δ = 0.05), on the half-year grid. True values: 3.5 years for v = 1, 2.0 for v = 2, 2.5 for v = 3.

| Profile | True | C0 truncated AIPCW, median | Share of hospitals within half a year | C2 CC median | C2 truncated AIPCW median |
|---|---|---|---|---|---|
| v = 1 | 3.5 | 3.0 | 32% | 4.5 | 3.0 |
| v = 2 | 2.0 | 2.5 | 54% | 3.0 | 2.0 |
| v = 3 | 2.5 | 3.0 | 46% | 4.0 | 2.5 |

- **Even with no dropout, one trial of 500 pins down a profile's time to benefit only roughly.** About a third to a half of hospitals land within half a year of the truth. The medians run about half a year late, because smoothing flattens the curve (Phase 1).
- **Dropping dropouts delays time to benefit** under dependent dropout by 1 to 1.5 years. Truncated AIPCW keeps the median on target.

## Gate 2

| Condition | Result |
|---|---|
| C0 reproduces Phase 1 at every time | **Yes.** All methods identical; bias 0.022 averaged over time, coverage 90% |
| Weighted methods have small bias in C1 and C2 | **C1 yes.** C2 yes for the median and after truncation, but **not stable**: 27 to 92 hospitals break |
| AIPCW holds in C3 while IPCW does not | **Partly.** AIPCW holds (0.027); IPCW is only slightly worse (0.037); AIPCW intervals undercover (80%) |

**Gate 2 is passed for bias, but not for stability or intervals.** These are not coding errors. They are known limits of weighting methods under strong, selective dropout, and they are findings in their own right.

## What these results mean for the method

The estimator of Wen, Dahabreh and Chiu can be carried to censored outcomes and traced over follow-up by adding a dropout weight (or the augmented version) inside its pseudo-outcome. In simulation, this removes the bias that the simple fixes leave. Two problems appear that the no-dropout setting hides:

- The trial-joining weight and the dropout weight multiply, so practical positivity fails sooner.
- The usual sandwich intervals undercover when one helper model is wrong.

Both are open questions: how to stabilise the combined weights, and how to build intervals that account for estimated dropout weights.

## Limits

- The data-generating mechanism is ours and is not calibrated to any disease.
- The helper models are parametric Weibull and logistic regressions; the Super Learner was not used in Phase 2.
- One truncation level (0.05) was tried. Truncation shifts the estimand (Dahabreh et al., Stat Med 2020, p. 16), so the truncated methods' small bias is partly a change of target.
- Time to benefit is read on a half-year grid.
- 200 hospitals per setting: Monte Carlo error on integrated bias is about 0.005 to 0.01.

## Additions of 23 October: where the instability comes from, and a wrong outcome model

Three additions taken from Steingrimsson's work, rerun on the same 200 hospitals per setting. The six methods above reproduced the 22 October numbers exactly (largest difference 0, `scripts/12_check_reproduction.R`), so the tables above stand. Full output: `results/summary_phase2_20261023.txt`.

- **BJ (Buckley-James):** no dropout weight. Each dropout's status is filled in with the outcome model's chance of an event after leaving. Right only if the outcome model is right.
- **C4:** the C2 hospitals, with the right dropout model and outcome models that leave out frailty.
- **Weight checks:** for each hospital, the mean of the weights (which should be close to 1), the largest weight's share, and the effective sample size.

### Error and coverage at 5 years

Integrated absolute bias, (hospitals off by more than 0.5), and coverage. In brackets after the bias: the bias from medians, which broken hospitals cannot drag.

| Method | C2 dependent | C3 dropout model wrong | C4 outcome model wrong |
|---|---|---|---|
| IPCW | 0.116 [0.035] (92), 97% | 0.037 [0.030] (30), 95% | 0.112 [0.030] (90), 97% |
| AIPCW | 0.048 [0.019] (50), 93% | 0.027 [0.029] (4), 80% | 0.065 [0.027] (73), 95% |
| AIPCW, truncated | 0.029 [0.024] (27), 91% | 0.027 [0.029] (4), 80% | 0.019 [0.026] (55), 95% |
| **BJ** | **0.025** [0.026] (**1**), **72%** | 0.025 [0.026] (1), 72% | **0.064** [0.066] (4), **76%** |

BJ in C0: identical to AIPCW (0.024, 89%), as it must be. In C1: 0.021, 4 hospitals broken, coverage 86%. BJ gives the same answer in C2 and C3 because it never uses the dropout model.

### What the additions show

1. **The dropout weight causes the breaks, not the trial-joining weight.** BJ keeps the trial-joining weight and drops the dropout weight; it broke in 1 of 200 hospitals in C2, against 92 for IPCW and 50 for AIPCW. The trial-joining weight's mean stayed between 0.96 and 1.06 in 98% of hospitals.
2. **BJ is biased when the outcome model is wrong** (C4: 0.064 against 0.025 with the right model), and the bias moves time to benefit: for v = 1, the median estimate is 2.0 years against a true 3.5. The wrong model underestimates the risk of the frail patients who leave, most of whom were treated, so the drug looks better sooner.
3. **IPCW and AIPCW are unbiased in C4 in the typical hospital** (median-based bias 0.030 and 0.027), as double robustness predicts. But the averages are dragged up by broken hospitals (90 and 73). With a wrong outcome model, the augmentation term cancels less of the weights' noise, so AIPCW breaks more often in C4 (73) than in C2 (50).
4. **BJ's intervals are too narrow even with the right outcome model** (72% coverage in C2). The likely reason: the filled-in chance replaces an unknown 0 or 1, so the data look less variable than they are, and the sandwich formula treats the filled-in values as observed.
5. **So there is a trade-off, and no method wins every setting.** BJ is stable but trusts the outcome model completely, and its intervals undercover. AIPCW is right if either model is right, but unstable when weights are extreme. Truncated AIPCW had the smallest average error in C4 (0.019), at the cost of a shifted target.

### Do the weight checks flag the broken hospitals?

Rules fixed before the results were seen. Counts out of 200 hospitals, for AIPCW (broken: 50 in C2, 4 in C3, 73 in C4):

| Rule | C2: flagged / broken caught | C3: flagged / broken caught | C4: flagged / broken caught |
|---|---|---|---|
| Combined-weight mean off 1 by more than 0.2 | 73 / 33 | **187** / 4 | 73 / 41 |
| One patient carries more than 10% of an arm's weight | 145 / 43 | 0 / 0 | 145 / 64 |
| Effective sample size below 50 in an arm | 171 / 47 | 0 / 0 | 171 / 68 |
| Trial-joining weight mean off 1 by more than 0.2 | 0 / 0 | 0 / 0 | 0 / 0 |

- **No rule picks out the broken hospitals.** The effective-sample-size rule catches most of them (47 of 50), but flags 171 of 200 hospitals. It says "this design is fragile", not "this hospital's curve is wrong".
- **The mean-weight check detects a wrong dropout model.** In C3, the middle 80% of hospitals had combined-weight means of 0.71 to 0.79 in the treated arm and 0.80 to 0.88 in the untreated arm, and the rule flagged 187 of 200. With the right dropout model (C2), the medians were 0.95 and 0.99. This is a check of the dropout model, not of stability.
- **The trial-joining weight never failed a check,** consistent with point 1.

### What this adds to the open questions

- The instability under dependent dropout comes from the dropout weight. Methods that avoid it (BJ) are stable but lean entirely on the outcome model. How to choose between them, or combine them, is open.
- A simple check (the mean of the combined weights) detects a wrong dropout model, but no simple check identified the hospitals whose curve broke.

### Limits of the additions

- One misspecification per model (frailty left out). Other kinds of wrong model could behave differently.
- BJ's undercoverage is explained by a likely reason, not a demonstrated one. A bootstrap would test it.
- The weight-check thresholds (0.2, 10%, 50) are conventional choices, not tuned.
