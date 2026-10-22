# Phase 2 results: dropout, and the effect traced over follow-up

22 October 2026, 20:40. 200 simulated hospitals per setting (2,500 eligible patients, about 500 in the trial). Event times from Weibull models in which the benefit grows over time; follow-up 5 years; effect estimated at ten times from 0.5 to 5 years. Settings: `config/phase2.yaml`. Every decision and change: `docs/LOG.md`. Supersedes `reports/phase2_preliminary.md`.

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
- One truncation level (0.05) was tried.
- Time to benefit is read on a half-year grid.
- 200 hospitals per setting: Monte Carlo error on integrated bias is about 0.005 to 0.01.
