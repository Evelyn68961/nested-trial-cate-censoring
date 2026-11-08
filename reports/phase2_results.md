# Phase 2 results: dropout, and the effect traced over follow-up

22 October 2026, 20:40; additions (Buckley-James, setting C4, weight checks) on 23 October, at the end. 200 simulated hospitals per setting (2,500 eligible patients, about 500 in the trial). Event times from Weibull models in which the benefit grows over time; follow-up 5 years; effect estimated at ten times from 0.5 to 5 years. Settings: `config/phase2.yaml`. Every decision and change: `docs/LOG.md`. Supersedes `reports/archive/phase2_preliminary.md`.

**Corrected after review, 31 October 2026.** Every reported number stands; claims the numbers did not support have been corrected, and disclosures added at the end. Exploratory results were added the same day, at commit da5c483 (old ID; public 82c2078, see docs/commit_map.csv). Printed slips corrected on 5 November 2026; no table changed (`docs/LOG.md`).

## The settings

| Setting | Dropout | Share of trial patients dropped out |
|---|---|---|
| C0 | none | 0% |
| C1 | random, hazard 0.08 a year (about 7.7% leave each year) | 26% |
| C2 | dependent: frail and treated patients leave sooner | 30% |
| C3 | the same hospitals as C2, with a dropout model that leaves out frailty | 30% |
| C4 | the same hospitals as C2, with the right dropout model and outcome models that leave out frailty | 30% |

## Error at 5 years

Integrated absolute bias against the true target curve; in brackets, the number of the 200 hospitals with an absolute error above 0.5 somewhere on the curve.

| Method | C0 none | C1 random | C2 dependent | C3 dropout model wrong |
|---|---|---|---|---|
| CC drop them | 0.024 (0) | 0.020 (7) | **0.093** (8) | **0.093** (8) |
| NE count as event-free | 0.024 (0) | **0.064** (6) | 0.027 (6) | 0.027 (6) |
| IPCW | 0.024 (0) | 0.026 (10) | 0.116 (**92**) | 0.037 (30) |
| AIPCW | 0.024 (1) | 0.022 (9) | 0.048 (**50**) | 0.027 (4) |
| IPCW, truncated at 0.05 | 0.024 (0) | 0.026 (10) | 0.022 (**83**) | 0.037 (30) |
| AIPCW, truncated at 0.05 | 0.024 (1) | 0.022 (9) | 0.029 (27) | 0.027 (4) |

Coverage of the exact target by the 95% intervals at 5 years (target 95%; with no dropout, the Phase 1 method gives about 89% here). These intervals are not validated for this estimator; see "Coverage against other targets" below.

| Method | C0 | C1 | C2 | C3 |
|---|---|---|---|---|
| CC | 89% | 90% | **68%** | **68%** |
| NE | 89% | **79%** | 92% | 92% |
| IPCW | 89% | 92% | 97% | 95% |
| AIPCW | 89% | 91% | 93% | **80%** |
| IPCW, truncated | 89% | 92% | 97% | 95% |
| AIPCW, truncated | 89% | 91% | 91% | **80%** |

## What the results show

1. **No dropout: CC, NE, IPCW and truncated IPCW give the same answer, as they must, and the Weibull-based methods give almost the same.** AIPCW, truncated AIPCW and BJ use a different outcome model: 0.02428 against 0.02412 at 5 years, 1 hospital against 0 above 0.5, coverage 89.19% against 89.23%. The error (0.024) is close to the Phase 1 smoothing error.
2. **Each simple fix fails somewhere.** Counting dropouts as event-free fails under random dropout (0.064, coverage 79%). Dropping them fails under dependent dropout (0.093, coverage 68%). Each looks fine in the other setting, for different reasons. In C2, no event's outcome-model errors in the two arms were both negative (−0.227 and −0.182 over 25 hospitals) and largely offset in the difference. This was not tested as the reason for its small bias. CC's small bias in C1 (0.020) does not mean CC is right there: under random dropout, each arm's risk from CC is biased upward (lesson 8), and the small bias comes from the arms offsetting, which was not examined. **One setting cannot tell you whether a simple fix is safe.**
3. **AIPCW had the lowest median bias, but large errors remain in many hospitals.** Under dependent dropout with the right dropout model, some frail treated patients had an estimated probability of remaining uncensored (G) as low as 0.00006 (worst hospital; `docs/LOG.md`), so their weights exceeded 10,000 (largest recorded 1/G: 16,470). 92 (IPCW) and 50 (AIPCW) of 200 hospitals had an absolute error above 0.5, and the standard deviation across hospitals at 5 years was 1.65 and 1.27, against 0.09 with no dropout. The mean bias is imprecise at this number of hospitals (MCSE 0.079 and 0.049). Median bias, which a few hospitals cannot drag, was 0.035 and 0.019.
4. **Truncation lowers the spread but does not remove the large errors.** With G held at 0.05 or above, the standard deviation fell (IPCW 1.65 to 0.31; AIPCW 1.27 to 0.17) and so did RMSE, and for AIPCW the 95% Monte Carlo interval of the difference excludes zero (-1.10, interval -1.81 to -0.29). The average bias also fell (IPCW 0.116 to 0.022; AIPCW 0.048 to 0.029), but for AIPCW the 95% Monte Carlo interval of the difference includes zero (-0.019, interval -0.184 to 0.007). 83 and 27 hospitals still had an absolute error above 0.5, against 0 or 1 with no dropout. A possible reason, not tested here: the dropout weight multiplies the trial-joining weight from Phase 1 (above 100 for some patients in one Phase 1 hospital; `docs/LOG.md`), so the combined weight can still be in the thousands.
5. **AIPCW had fewer hospitals above 0.5 than IPCW under dependent dropout, not in every setting.** C2: 50 against 92; C3: 4 against 30; C4: 73 against 90. C1: 9 against 10. C0: 1 against 0, so AIPCW was not better there. The 95% Monte Carlo interval of the RMSE difference excludes zero in C3 and C4 but includes zero in C2 (0.38 in IPCW's disfavour, interval -0.77 to 1.37). For bias, the interval of the IPCW against AIPCW difference includes zero in C2, C3 and C4.
6. **With a wrong dropout model (C3), AIPCW's bias stayed low (0.027, near the C0 level); IPCW's was 0.037.** This is the direction the theory predicts, but the 95% Monte Carlo interval of the difference includes zero (0.010, interval -0.006 to 0.024).
7. **AIPCW's intervals undercover when the dropout model is wrong (80%).** Bias does not account for most of this: bias-eliminated coverage (Morris et al. 2019), centred on the median estimate, which removes bias by construction, is 84.0%, against 92.5% for the same method in C0. Why the intervals are too narrow is not established. The sandwich intervals treat the nuisance models as known, which is one candidate.

## Time to benefit for each profile

The first time at which the drug lowers the risk by at least 5 points (δ = 0.05), on the half-year grid. True values: 3.5 years for v = 1, 2.0 for v = 2, 2.5 for v = 3.

| Profile | True | C0 truncated AIPCW, median | Share of hospitals within half a year | C2 CC median | C2 truncated AIPCW median |
|---|---|---|---|---|---|
| v = 1 | 3.5 | 3.0 | 32% | 4.5 | 3.0 |
| v = 2 | 2.0 | 2.5 | 54% | 3.0 | 2.0 |
| v = 3 | 2.5 | 3.0 | 46% | 4.0 | 2.5 |

- **Even with no dropout, one trial of 500 pins down a profile's time to benefit only roughly.** About a third to a half of hospitals land within half a year of the truth. The direction depends on the profile and method. At v = 1, the C0 medians are 3.5 for CC, NE and IPCW, on target, and 3.0 for AIPCW, early. At v = 2 and 3, they are half a year late for every method.
- **Dropping dropouts delays time to benefit.** Under dependent dropout, CC's median time to benefit was 0.5 to 1.0 years later than with no dropout, and 1.0 to 1.5 years later than the truth. Truncated AIPCW's median is on target at v = 2 and 3, and half a year early at v = 1.
- Under dependent dropout, no event, IPCW and truncated IPCW put v = 1 a year early (median 2.5 against 3.5). With a wrong outcome model, AIPCW did the same.

## Gate 2

| Condition | Result |
|---|---|
| With no dropout, all methods agree | **Yes.** CC, NE, IPCW and truncated IPCW identical; the Weibull-based methods nearly so; bias 0.022 averaged over time, coverage 90% |
| Weighted methods have small bias in C1 and C2 | **C1 yes.** C2 yes for the median; the mean is imprecise, and **27 to 92 hospitals have an absolute error above 0.5** |
| AIPCW holds in C3 while IPCW does not | **Partly.** AIPCW 0.027, IPCW 0.037, the 95% Monte Carlo interval of the difference includes zero; AIPCW intervals undercover (80%) |

**Gate 2: the first two conditions were met for median bias; the third (AIPCW holds with a wrong dropout model while IPCW does not) was met only partly; stability and intervals failed.** The review found no coding error that changes these conclusions (Step 2a). They are consistent with known limits of weighting methods under strong, selective dropout.

## What these results mean for the method

The estimator of Wen, Dahabreh and Chiu can be carried to censored outcomes and traced over follow-up by adding a dropout weight (or the augmented version) inside its pseudo-outcome. In this simulation, median bias at 5 years was 0.019 for AIPCW against 0.091 for CC in C2, and 0.025 for AIPCW against 0.067 for NE in C1. NE in C2 (0.029) and CC in C1 (0.022) were not worse by this measure. We did not find a paper with all of these elements. Two problems appear that the no-dropout setting hides:

- The trial-joining weight and the dropout weight multiply, so practical positivity may fail sooner. The source of the large errors is not established. In C2 at t = 5, against 50 of 200 hospitals with an absolute error above 0.5 for AIPCW, the exploratory runs measured the following. BJ, without the dropout weight, has 1 hospital above 0.5. For AIPCW, a floor of 0.10 on p alone leaves 29, omitting frailty from the participation model leaves 23, and the bound on the product at 0.10 leaves 2. These results are exploratory, and they involve both weights without separating them.
- The sandwich intervals are not validated for this estimator, and they undercover in several settings.

Both are open questions: how to stabilise the combined weights, and how to build intervals that account for estimated dropout weights.

## Limits

- The data-generating mechanism is ours and is not calibrated to any disease.
- The nuisance models are parametric Weibull and logistic regressions; the Super Learner was not used in Phase 2.
- The reported tables use one truncation level, 0.05; a range was run later as exploratory (Run A). Truncation shifts the estimand (Dahabreh et al., Stat Med 2020; arXiv v3, p. 16), so the truncated methods' small bias is partly a change of target. In Run A, bias is still measured against the original target.
- Time to benefit is read on a half-year grid.
- One bandwidth per estimator per hospital, chosen by cross-validation at 5 years from a grid of 7 values (0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0) and used at every time (`docs/LOG.md`).
- 200 hospitals per setting: bootstrap Monte Carlo error on integrated bias at 5 years is 0.003 to 0.005 for most methods, but 0.007 to 0.010 for the truncated methods in C2 and C4, and 0.049 to 0.079 for untruncated IPCW and AIPCW there (`reports/tables/13_phase2_precision.csv`). The 95% Monte Carlo interval of the difference includes zero for: IPCW against AIPCW in C2, C3 and C4; truncated AIPCW against AIPCW in C2; AIPCW against BJ in C2 and C4.

## Additions of 23 October: where the instability comes from, and a wrong outcome model

BJ and the weight checks come from Steingrimsson and Morrison (Stat Med 2020) and Dahabreh et al. (Stat Med 2020); C4 completes the double-robustness test. All three were run on the same 200 hospitals per setting. The six methods above reproduced the 22 October numbers exactly (largest difference 0, `scripts/12_check_reproduction.R`), so the tables above stand. Full output: `results/summary_phase2_20261023.txt`.

- **BJ (Buckley-James):** no dropout weight. Each dropout's status is filled in with the outcome model's probability of an event after leaving. Right only if the outcome model is right.
- **C4:** the C2 hospitals, with the right dropout model and outcome models that leave out frailty.
- **Weight checks:** for each hospital, the mean of the weights (which should be close to 1), the largest weight's share, and the effective sample size.

### Error and coverage at 5 years

Integrated absolute bias, (hospitals with an absolute error above 0.5), and coverage. In brackets after the bias: the bias from medians, which a few hospitals cannot drag.

| Method | C2 dependent | C3 dropout model wrong | C4 outcome model wrong |
|---|---|---|---|
| IPCW | 0.116 [0.035] (92), 97% | 0.037 [0.030] (30), 95% | 0.112 [0.030] (90), 97% |
| AIPCW | 0.048 [0.019] (50), 93% | 0.027 [0.029] (4), 80% | 0.065 [0.027] (73), 95% |
| AIPCW, truncated | 0.029 [0.024] (27), 91% | 0.027 [0.029] (4), 80% | 0.019 [0.026] (55), 95% |
| **BJ** | **0.025** [0.026] (**1**), **72%** | 0.025 [0.026] (1), 72% | **0.064** [0.066] (4), **76%** |

BJ in C0: identical to AIPCW (0.024, 89%), as it must be. In C1: 0.021, 4 hospitals above 0.5, coverage 85%. BJ gives the same answer in C2 and C3 because it never uses the dropout model.

### What the additions show

1. **Removing the dropout weight removes most of the large errors.** BJ keeps the trial-joining weight and drops the dropout weight; 1 of 200 hospitals had an absolute error above 0.5 in C2, against 92 for IPCW and 50 for AIPCW, and its standard deviation was 0.09 against 1.65 and 1.27. This shows the dropout weight is needed for most of them. It does not show the trial-joining weight plays no part, since the two multiply. The trial-joining weight's mean stayed between 0.96 and 1.06 in 194 of 200 hospitals (97%; from the saved rows in `results/phase2/C2`; not in a table).
2. **BJ is biased when the outcome model is wrong** (C4: 0.064 against 0.025 with the right model), and the bias moves time to benefit: for v = 1, the median estimate is 2.0 years against a true 3.5. A possible reason, not tested here: the wrong model underestimates the risk of the frail patients who leave, most of whom were treated, so the drug looks better sooner.
3. **IPCW and AIPCW have small median bias in C4** (0.030 and 0.027), as the theory predicts. But 90 and 73 hospitals had an absolute error above 0.5, and the mean bias is imprecise. AIPCW had more such hospitals in C4 (73) than in C2 (50). A possible reason, not tested here: with a wrong outcome model, the augmentation term cancels less of the weights' noise.
4. **BJ's intervals are too narrow even with the right outcome model** (72% coverage in C2). Bias does not account for most of this: bias-eliminated coverage is 75.6%, against about 92.5% in C0. Why the intervals are too narrow is not established. One candidate: the filled-in probability replaces an unknown 0 or 1, and the sandwich formula treats it as observed.
5. **So there is a trade-off, and no method wins every setting.** BJ has few large errors but relies on the outcome model, and its intervals undercover. **AIPCW as coded is consistent if the outcome model is right, or if participation and dropout are both right.** IPCW needs dropout right and either participation or its own outcome model right. This is the theory. Its logistic outcome model is never exactly right here (see Limits), so only the participation branch was tested. BJ needs the outcome model right. AIPCW's errors are large when weights are extreme. Truncated AIPCW had the smallest average error in C4 (0.019), at the cost of a shifted target; for bias, the 95% Monte Carlo interval of the difference includes zero for truncated AIPCW against AIPCW in C2, and for AIPCW against BJ in C2 and C4.

### Do the weight checks flag the hospitals with large errors?

Rules fixed before the results were seen. Counts out of 200 hospitals, for AIPCW (hospitals with an absolute error above 0.5: 50 in C2, 4 in C3, 73 in C4):

| Rule | C2: flagged / above 0.5 caught | C3: flagged / above 0.5 caught | C4: flagged / above 0.5 caught |
|---|---|---|---|
| Combined-weight mean off 1 by more than 0.2 | 73 / 33 | **187** / 4 | 73 / 41 |
| One patient carries more than 10% of an arm's weight | 145 / 43 | 0 / 0 | 145 / 64 |
| Effective sample size below 50 in an arm | 171 / 47 | 0 / 0 | 171 / 68 |
| Trial-joining weight mean off 1 by more than 0.2 | 0 / 0 | 0 / 0 | 0 / 0 |

- **No rule picks out the hospitals with large errors.** The effective-sample-size rule catches most of them (47 of 50), but flags 171 of 200 hospitals. It says "this design is fragile", not "this hospital's curve is wrong".
- **The mean-weight check flagged the wrong dropout model in this design.** In C3, the middle 80% of hospitals had combined-weight means of 0.71 to 0.79 in the treated arm and 0.80 to 0.88 in the untreated arm (from the saved rows in `results/phase2/`; not in a table). In C3 the rule flagged 187 of 200 hospitals, against 73 with the right dropout model (C2), where the medians were 0.95 and 0.99. One kind of wrong dropout model was tested. This is a check of the dropout model, not of stability.
- **The trial-joining weight never failed a check.** The check looks at its mean, so this does not rule out a part for it in the large errors.

### What this adds to the open questions

- The large errors under dependent dropout mostly disappear without the dropout weight. Methods that avoid it (BJ) have few large errors but lean entirely on the outcome model. How to choose between them, or combine them, is open.
- A simple check (the mean of the combined weights) flagged the wrong dropout model tested here in 187 of 200 hospitals, and 73 with the right one; no simple check identified the hospitals with an absolute error above 0.5.

### Limits of the additions

- One misspecification per model (frailty left out). Other kinds of wrong model could behave differently.
- BJ's undercoverage has a candidate explanation, not a demonstrated one. A bootstrap would test it.
- The weight-check thresholds (0.2, 10%, 50) are conventional choices, not tuned.

## Corrections, disclosures and checks after review

### Standard deviation across hospitals at 5 years

Averaged over the v grid, from saved rows (`reports/tables/15_sd_at_t5.csv`).

| Method | C0 | C1 | C2 | C3 | C4 |
|---|---|---|---|---|---|
| CC | 0.087 | 0.103 | 0.095 | 0.095 | 0.095 |
| NE | 0.087 | 0.098 | 0.097 | 0.097 | 0.097 |
| IPCW | 0.087 | 0.115 | 1.651 | 0.149 | 1.645 |
| AIPCW | 0.087 | 0.102 | 1.274 | 0.094 | 1.174 |
| IPCW, truncated | 0.087 | 0.115 | 0.315 | 0.149 | 0.301 |
| AIPCW, truncated | 0.087 | 0.102 | 0.173 | 0.094 | 0.249 |
| BJ | 0.087 | 0.090 | 0.089 | 0.089 | 0.094 |

### Disclosures

- **Dropout was strengthened after first results.** The dependent setting went from (0.06, 0.7, 0.6) to (0.10, 1.5, 1.0) on 22 October, because the first setting was too mild to expose a wrong dropout model (`docs/LOG.md`).
- **δ = 0.05 departs from the plan,** which set δ = 0.01 and 0.02 for time to benefit.
- **The compensator is a 30-step midpoint rule.** Going to 3,000 steps in C2 and C4 changed AIPCW only slightly. At 5 years in C2, RMSE moved from 1.272 to 1.264 (difference -0.0079, interval -0.0153 to 0.0004) and coverage from 92.65% to 92.64%. The count above 0.5 and time to benefit did not change. BJ did not move; truncated AIPCW's bias and RMSE moved by less than 0.00001 (`reports/tables/14_checks_paired.csv`). For the 20 patients with the largest 1/G in the C2 hospital with the smallest G (seed 145), 3,000 steps differ from stats::integrate by at most 0.0014, for the patient with 1/G = 16,469.6 (3.4 × 10⁻⁷ relative; `reports/tables/14_compensator_integrate_check.csv`). In the hospitals with the largest change, one patient accounts for 96 to 99.96% of it.
- **Run A's bound on the product uses two estimates of p.** IPCW's outcome model is floored with the in-sample p of its training folds, and the pseudo-outcome with the cross-fitted p (`scripts/15_common.R`).
- **Seed 145, not examined.** The same patient (1/G = 16,469.6) has a 30-step compensator error (against 3,000 steps) of 14.08 in C2 and 1.21 in C4. G is the same in both, so the difference comes from the outcome-model term; how was not examined. (`reports/tables/14_compensator_patients_C2.csv`, `_C4.csv`, `14_compensator_slope.csv`)
- **CC and NE keep frailty in C4,** so their C4 rows repeat C2. The C3 and C4 rows for CC and NE carry no wrong model, and neither do BJ's C3 rows.
- **CC refits the trial-joining model on the reduced data,** so its p_join is P(S = 1, status known | X). Taking both models from the full cohort does not repair it: at 5 years in C2, bias falls from 0.093 to 0.084, but coverage falls from 68.1% to 50.6%. Reported CC is unchanged.
- **IPCW's outcome model is logistic, while the generator has a complementary log-log form.** Over 25 hospitals at 5 years, logistic RMSE exceeded Weibull RMSE on average in every row, by 0.011 in the treated arm (interval 0.006 to 0.016) and 0.008 in the untreated arm (0.004 to 0.012) in C0, logistic worse in 19 of 25 hospitals in each, and for IPCW in C2 by 0.054 in the treated arm (0.041 to 0.067) and 0.013 in the untreated arm (0.006 to 0.020) (`reports/tables/14_helper_specification_paired.csv`). About half of CC's and NE's extra error in C2 comes from their mean errors (25 hospitals); the link was not separated from the rest.
- **Run sizes differ:** Phase 1 used 500 hospitals with a Super Learner, its 5% trial setting 50 hospitals (preliminary), and Phase 2 200 hospitals with parametric models. These are not directly comparable.
- **Warnings.** The original runs suppressed warnings. Counted later, over 200 hospitals, C2 and C4 each gave 246 "fitted probabilities 0 or 1" (77 hospitals) and 4 "did not converge" (3 hospitals), all from logistic fits. The exploratory control runs attribute all 250 in each setting: 123 to CC's fits and 127 to NE's. The code also suppresses warnings in IPCW's outcome fits, which that count did not include; see "Warnings by fit" below.
- **The original tables give coverage of the exact target only.** Coverage of the smoothed and median targets is added below.

### Coverage against other targets

At 5 years, all from saved rows, MCSE about 0.5 to 1.9. Exact is the reported value. Smoothed passes the true curve through each hospital's own bandwidth (`reports/tables/14_smoothed_coverage_phase2_fine_grid.csv`, built on 80,001 grid points; corrected 8 November 2026, see `docs/LOG.md`). Bias-eliminated coverage (Morris et al. 2019), centred on the median estimate, removes bias by construction, so it separates bias from interval width and is not validation.

| Setting, method | Exact | Smoothed | Bias-eliminated |
|---|---|---|---|
| C0 CC, NE, IPCW | 89.2 | 93.2 | 92.9 |
| C0 AIPCW, BJ | 89.2 | 93.4 | 92.5 |
| C2 CC | 68.1 | 80.8 | 92.5 |
| C2 NE | 92.3 | 90.7 | 93.5 |
| C2 IPCW | 97.3 | 96.8 | 97.2 |
| C2 AIPCW | 92.6 | 93.4 | 93.1 |
| C2 AIPCW, truncated | 91.4 | 92.2 | 91.8 |
| C2 BJ | 72.4 | 76.9 | 75.6 |
| C3 AIPCW | 79.9 | 85.1 | 84.0 |
| C4 IPCW | 97.3 | 96.6 | 97.4 |
| C4 AIPCW | 95.2 | 93.7 | 96.2 |
| C4 BJ | 75.5 | 65.9 | 86.2 |

- With bias removed, BJ in C2 stays at 75.6% and AIPCW in C3 at 84.0%, while C0 reaches about 92.5%. Most of the shortfall remains, so it is not bias. CC in C2 is the reverse: its shortfall is mostly bias.
- BJ's fall to 65.9% in C4 is bias against a correctly built target: signed bias -0.064 against the exact target and -0.085 against the smoothed one.
- The version centred on the mean estimate is in `reports/tables/14_center_coverage_phase2.csv`. For untruncated IPCW and AIPCW in C2 and C4 the mean is unstable (MCSE 5 to 11), so the median is shown.
- **Limits of this check.** The smoothed target assumes v uniform, which matches the methods fitted on all eligible patients; CC is fitted on a reduced set, so for CC it is close, not exact. Bias-eliminated coverage says nothing about bias. In Phase 1, L has no smoothed value, and T's values may be used only as noted: 75.13 and 87.89 in `reports/tables/14_smoothed_coverage_phase1.csv` use the wrong target, and are not interpreted (`reports/tables/14_smoothed_coverage_phase1_NOTES.md`).

### Independent second method

An independent script, written without reading the estimators, was run on the same design (`independent_check/`). Its true values at t = 5 for v = 1, 2 and 3, the only points it stores, agree with the repository's to 4e-16 (`independent_check/compare_truth.R`), through a different integration routine, and with its own Monte Carlo check.

Compared at t = 5 in C2, on the survival difference with repository signs flipped, 200 hospitals or replicates (`independent_check/comparison_C2_t5.csv`):

| v | Source | Mean bias (95% interval) | Median bias (95% interval) | SD | Largest abs. error | Count above 0.5 |
|---|---|---|---|---|---|---|
| 1 | Repository | -0.023 (-0.189, 0.150) | -0.010 (-0.034, 0.021) | 1.20 | 9.72 | 23 |
| 1 | Script | -1.100 (-3.220, 0.058) | -0.012 (-0.047, 0.022) | 14.34 | 201.49 | 17 |
| 2 | Repository | 0.043 (-0.107, 0.284) | -0.021 (-0.055, -0.002) | 1.50 | 20.20 | 12 |
| 2 | Script | -1.287 (-3.844, 0.034) | 0.031 (0.003, 0.051) | 16.52 | 232.32 | 15 |
| 3 | Repository | 0.051 (-0.046, 0.218) | -0.031 (-0.045, -0.014) | 1.06 | 14.51 | 8 |
| 3 | Script | -0.023 (-0.062, 0.011) | 0.001 (-0.020, 0.013) | 0.27 | 2.76 | 6 |

- **The gap in SD is one replicate, not a disagreement in kind.** Replicate 161 gives -201.5 at v = 1 and -232.3 at v = 2. Dropping it gives SD 1.70 and 1.87, and dropping replicates 161 and 4 gives 0.52 and 0.55, against the repository's 1.20 and 1.50. SD is unreliable as a summary here.
- **Median bias at v = 2 does disagree:** repository -0.021, script 0.031, a difference of 0.05 that is not explained.
- The script's mean biases are each about 1.1 to 1.2 MCSE from 0 (`independent_check/comparison_C2_t5.csv`), so they show spread, not a mean shift. Its one 500,000-patient cohort shows no clear bias (largest −0.040 at v = 1, 1.5 approximate SE), which is not proof, since its approximate standard error is not validated for a heavy-tailed pseudo-outcome. Its `ipcw` is plain, with no outcome term, so it is not the repository's IPCW and is not ranked against AIPCW.
- Differences that remain, none tuned: Weibull models in the repository (parametric) against Cox models with a Breslow baseline in the script (semiparametric); cross-validated bandwidth against h = 1; 30-step midpoint compensator against a sum on the jump times; fitted against known treatment probability.

## Exploratory runs

**These runs follow first results and are exploratory (Pawel et al. 2023).** Pre-specification, with expected directions fixed before any run: `docs/exploratory_prespecification.md`. All use the reported seeds, parametric models and 30 compensator steps, so they compare directly with the rows above; the effect of 30 steps is the Check 1 result under Disclosures. A prediction that fails is reported as failed.

### Run A: truncation range

Floors 0.01, 0.02, 0.05 and 0.10, on G alone, on p(S=1|X) alone, and on their product, for IPCW and AIPCW in C2 and C4. The lower bound on the product also floors p where p is below the floor. **No floor was chosen, and none is called best.**

Each cell, at t = 5: median bias / RMSE / coverage of the exact target, % / median interval width / hospitals of 200 with absolute error above 0.5. All metrics, and paired differences against the reported rows: `reports/tables/15_runA_performance.csv`, `15_runA_paired.csv`.

**C2**

| Scheme | Floor | IPCW | AIPCW |
|---|---|---|---|
| G | 0.01 | 0.034 / 0.733 / 97.3 / 0.78 / 92 | 0.020 / 0.369 / 92.4 / 0.46 / 47 |
| G | 0.02 | 0.034 / 0.481 / 97.4 / 0.78 / 92 | 0.020 / 0.256 / 92.3 / 0.46 / 40 |
| G | 0.05 | 0.033 / 0.315 / 97.3 / 0.78 / 83 | 0.024 / 0.175 / 91.4 / 0.44 / 27 |
| G | 0.10 | 0.030 / 0.246 / 97.1 / 0.74 / 72 | 0.026 / 0.141 / 90.6 / 0.41 / 19 |
| p | 0.01 | 0.035 / 1.652 / 97.3 / 0.78 / 92 | 0.019 / 1.272 / 92.6 / 0.47 / 50 |
| p | 0.02 | 0.036 / 1.651 / 97.2 / 0.77 / 90 | 0.019 / 1.272 / 92.6 / 0.47 / 50 |
| p | 0.05 | 0.031 / 1.047 / 97.0 / 0.72 / 85 | 0.019 / 1.179 / 92.6 / 0.46 / 46 |
| p | 0.10 | 0.026 / 0.608 / 95.3 / 0.57 / 58 | 0.017 / 0.893 / 91.4 / 0.40 / 29 |
| p G | 0.01 | 0.032 / 0.215 / 96.7 / 0.72 / 66 | 0.026 / 0.129 / 90.4 / 0.39 / 13 |
| p G | 0.02 | 0.029 / 0.182 / 95.8 / 0.63 / 45 | 0.029 / 0.117 / 89.0 / 0.35 / 6 |
| p G | 0.05 | 0.023 / 0.145 / 95.0 / 0.48 / 14 | 0.029 / 0.105 / 84.2 / 0.28 / 2 |
| p G | 0.10 | 0.017 / 0.109 / 93.9 / 0.36 / 2 | 0.025 / 0.097 / 76.7 / 0.22 / 2 |

**C4**

| Scheme | Floor | IPCW | AIPCW |
|---|---|---|---|
| G | 0.01 | 0.029 / 0.726 / 97.3 / 0.71 / 90 | 0.026 / 0.585 / 95.2 / 0.62 / 71 |
| G | 0.02 | 0.029 / 0.471 / 97.3 / 0.71 / 90 | 0.025 / 0.387 / 95.1 / 0.61 / 68 |
| G | 0.05 | 0.029 / 0.301 / 97.2 / 0.70 / 80 | 0.026 / 0.250 / 95.0 / 0.60 / 55 |
| G | 0.10 | 0.027 / 0.234 / 96.9 / 0.68 / 73 | 0.028 / 0.198 / 94.4 / 0.57 / 48 |
| p | 0.01 | 0.030 / 1.645 / 97.3 / 0.71 / 89 | 0.027 / 1.173 / 95.2 / 0.62 / 73 |
| p | 0.02 | 0.030 / 1.645 / 97.4 / 0.71 / 89 | 0.027 / 1.173 / 95.2 / 0.62 / 72 |
| p | 0.05 | 0.031 / 1.045 / 97.0 / 0.68 / 84 | 0.030 / 0.850 / 94.5 / 0.60 / 63 |
| p | 0.10 | 0.032 / 0.608 / 94.7 / 0.56 / 59 | 0.031 / 0.511 / 92.8 / 0.49 / 51 |
| p G | 0.01 | 0.029 / 0.198 / 96.7 / 0.66 / 57 | 0.028 / 0.173 / 93.7 / 0.56 / 35 |
| p G | 0.02 | 0.028 / 0.166 / 95.8 / 0.57 / 25 | 0.028 / 0.145 / 92.1 / 0.48 / 16 |
| p G | 0.05 | 0.025 / 0.124 / 93.4 / 0.41 / 8 | 0.046 / 0.118 / 88.8 / 0.36 / 3 |
| p G | 0.10 | 0.038 / 0.105 / 88.2 / 0.30 / 3 | 0.063 / 0.109 / 79.4 / 0.26 / 3 |

Reported rows without a floor, as RMSE / coverage / hospitals above 0.5: C2 IPCW 1.652 / 97.3 / 92, C2 AIPCW 1.272 / 92.6 / 50, C4 IPCW 1.645 / 97.3 / 90, C4 AIPCW 1.173 / 95.2 / 73.

- **Large errors fell furthest under the bound on the product.** At 0.10 it left 2 to 3 hospitals above 0.5 for each method. A floor of 0.10 on G alone left 19 to 73, and on p alone 29 to 59. So flooring either weight alone did not remove them, at any floor tried.
- **The cost grew with the bound for AIPCW in both settings, and for IPCW in C4.** At 0.10, AIPCW's coverage was 76.7% in C2 and 79.4% in C4, and IPCW's was 88.2% in C4. In C2, IPCW's median bias fell as the bound rose. Intervals narrowed. In C4, where the outcome model is wrong, AIPCW's median bias rose from 0.028 at 0.02 to 0.046 at 0.05 and 0.063 at 0.10, and IPCW's reached 0.038 at 0.10. Why was not tested.
- **Floors of 0.01 and 0.02 on p alone left the rows almost as reported.**

These rows describe a trade-off. They do not select a floor.

### Run B: mild dropout

Rates (0.06, 0.7, 0.6), dropout model right (C2m) and wrong (C3m), all seven methods.

Each cell as in Run A, at t = 5. All metrics: `reports/tables/15_runB_performance.csv`, `15_runB_paired.csv`.

| Method | C2m dropout model right | C3m dropout model wrong |
|---|---|---|
| CC | 0.043 / 0.108 / 87.2 / 0.32 / 3 | 0.043 / 0.108 / 87.2 / 0.32 / 3 |
| NE | 0.033 / 0.109 / 90.6 / 0.33 / 3 | 0.033 / 0.109 / 90.6 / 0.33 / 3 |
| IPCW | 0.032 / 0.156 / 93.1 / 0.45 / 25 | 0.022 / 0.121 / 93.9 / 0.38 / 13 |
| AIPCW | 0.026 / 0.117 / 91.0 / 0.35 / 14 | 0.023 / 0.097 / 88.6 / 0.29 / 4 |
| BJ | 0.022 / 0.091 / 84.4 / 0.25 / 2 | 0.022 / 0.091 / 84.4 / 0.25 / 2 |

CC, NE and BJ use no dropout model, so their two columns are the same by construction. C2m and C3m are the same data.

From `15_runB_dropout_summary.csv`: 19.9% of trial patients dropped out, against 30% in C2. The true G(5) was below 0.05 for 0.04% of trial patients; the estimated G(5) for 0.15% in C2m and for none in C3m. The smallest G, taken at each patient's own follow-up time up to 5 years, was 0.084 in C2m and 0.390 in C3m.

- **The floor of 0.05 never applied.** In all 200 hospitals G stayed above 0.05, so IPCW_t and AIPCW_t equal IPCW and AIPCW exactly, at every point of every curve, and are not shown. The equality is also seen in `15_runB_performance.csv`, where their rows are identical. The smallest G is taken from the dropout model used in the status weights; it does not cover the weights inside IPCW's outcome model, which use the in-sample G of each fold's training patients.
- **Large errors fell but did not vanish.** In C2m, hospitals above 0.5 at t = 5 were 25 for IPCW (92 in C2) and 14 for AIPCW (50 in C2). So dropout weights near the floor are not needed for an error above 0.5. Those errors could come from the joining weight, from the dropout weights that remain, or from both; this run does not separate them.
- **BJ's coverage rose to 84.4% from 72.4%, and stayed below 95%,** with RMSE about the same.

### Run C: wrong participation model

C2 data, participation model omitting frailty. C5a: outcome model right. C5b: outcome model also wrong, for every nuisance model including CC and NE. This differs from C4, where CC and NE keep frailty.

Each cell as in Run A, at t = 5. All metrics: `reports/tables/15_runC_performance.csv`, `15_runC_paired.csv`.

| Method | C5a outcome model right | C5b outcome model wrong |
|---|---|---|
| CC | 0.090 / 0.128 / 66.7 / 0.29 / 3 | 0.021 / 0.095 / 95.1 / 0.34 / 5 |
| NE | 0.029 / 0.087 / 87.2 / 0.24 / 2 | 0.052 / 0.091 / 85.8 / 0.24 / 2 |
| IPCW | 0.031 / 0.504 / 93.3 / 0.42 / 35 | 0.040 / 0.493 / 95.2 / 0.42 / 31 |
| AIPCW | 0.023 / 0.557 / 90.3 / 0.34 / 23 | 0.040 / 0.419 / 93.0 / 0.39 / 32 |
| IPCW_t | 0.029 / 0.152 / 93.1 / 0.42 / 23 | 0.041 / 0.140 / 94.8 / 0.42 / 20 |
| AIPCW_t | 0.027 / 0.118 / 89.0 / 0.33 / 11 | 0.040 / 0.130 / 92.6 / 0.38 / 16 |
| BJ | 0.025 / 0.094 / 75.3 / 0.21 / 1 | 0.073 / 0.108 / 72.3 / 0.23 / 2 |

Scored by the rule fixed before the runs (`15_runC_predictions.csv`): the paired difference in median bias at t = 5 against C2 on the same seeds, with its 95% interval, and a margin of 0.01.

| Expected, fixed in advance | Difference (95% interval) | Result |
|---|---|---|
| C5a: AIPCW stays consistent | 0.003 (-0.004, 0.008) | Held |
| C5a: BJ stays consistent | -0.001 (-0.004, 0.003) | Held |
| C5a: IPCW uncertain | -0.003 (-0.020, 0.011) | No decision, as fixed in advance |
| C5b: AIPCW biased at n = 2,500 | 0.021 (-0.002, 0.036) | Not determined |
| C5b: BJ biased at n = 2,500 | 0.047 (0.034, 0.060) | Held |
| C5b: IPCW biased at n = 2,500 | 0.005 (-0.018, 0.024) | Not determined |

Every run uses one cohort size, so whether a bias shrinks with sample size cannot be observed here. "Held" for "stays consistent" means only that bias did not rise by 0.01 at this size. It is not a proof of consistency. "Held" for "biased" means only that bias rose by more than 0.01 at this size.

- **AIPCW's and IPCW's large errors remained in C5a,** with 23 and 35 hospitals above 0.5. A small median bias does not make an estimate stable.
- **Those counts were lower than in C2,** where they were 50 and 92. For IPCW the paired difference in the proportion is -0.285 (-0.350, -0.215) and for AIPCW -0.135 (-0.185, -0.085). Leaving frailty out of the participation model is the change that produced this. A possible reason, not tested: a model that ignores frailty gives less extreme participation probabilities.
- **No direction was fixed for CC and NE.** In C5b, CC's median bias was 0.021 against 0.091 in C2, a difference of -0.071 (-0.081, -0.061), with coverage of 95.1%. This run does not show that CC improved: its participation and outcome models were wrong together, and the reason was not examined. NE's rose by 0.023 (0.017, 0.030).

### Warnings by fit

These totals are not directly comparable with the 250 above, because warnings that the code suppresses are now counted too. Details by time, arm and estimator: `reports/tables/15_warnings_by_fit.csv`.

| Run, setting | CC outcome fits | NE outcome fits | IPCW outcome fits |
|---|---|---|---|
| Control, C2 | 123 | 127 | 14 |
| Control, C4 | 123 | 127 | 0 |
| A, C2 | not refitted | not refitted | 70 |
| A, C4 | not refitted | not refitted | 0 |
| B, C2m | 83 | 80 | 4 |
| B, C3m | 83 | 80 | 4 |
| C, C5a | 123 | 127 | 14 |
| C, C5b | 91 | 100 | 0 |

- **CC and NE reproduce the 250 exactly** in both control runs, as 246 "fitted probabilities 0 or 1" and 4 "did not converge".
- **All IPCW warnings are "did not converge".** Each variant has its own fits: 7 warnings for each of IPCW and IPCW_t in the control, and 7 for each of 10 variants in Run A. The floor on p shares IPCW's fits.
- **No other fit gave a warning:** none from the Weibull, participation or treatment models. All warnings fall at t = 2 or earlier.

## References

- Wen, Dahabreh and Chiu. Generalizing Conditional Average Treatment Effects From Nested Randomized Trials to Trial-Eligible Individuals. Statistics in Medicine 2026;45(23-24):e70767. doi:10.1002/sim.70767.
- Steingrimsson JA, Morrison S. Deep learning for survival outcomes. Statistics in Medicine 2020;39:2339–2349.
- Dahabreh IJ, Robertson SE, Steingrimsson JA, Stuart EA, Hernán MA. Extending inferences from a randomized trial to a new target population. Statistics in Medicine 2020;39:1999–2014.
- Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate statistical methods. Statistics in Medicine 2019;38:2074–2102. doi:10.1002/sim.8086.
- Pawel S, Kook L, Reeve K. Pitfalls and potentials in simulation studies: questionable research practices in comparative simulation studies allow for spurious claims of superiority of any method. Biometrical Journal 2023;e2200091. doi:10.1002/bimj.202200091.
