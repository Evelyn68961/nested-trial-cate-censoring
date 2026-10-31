# Phase 2 results: dropout, and the effect traced over follow-up

22 October 2026, 20:40; additions (Buckley-James, setting C4, weight checks) on 23 October, at the end. 200 simulated hospitals per setting (2,500 eligible patients, about 500 in the trial). Event times from Weibull models in which the benefit grows over time; follow-up 5 years; effect estimated at ten times from 0.5 to 5 years. Settings: `config/phase2.yaml`. Every decision and change: `docs/LOG.md`. Supersedes `reports/phase2_preliminary.md`.

**Draft corrected after review, 31 October 2026.** Every reported number stands; claims the numbers did not support have been corrected, and disclosures added at the end. Gaps for the exploratory runs are marked **[PENDING]**.

## The settings

| Setting | Dropout | Share of trial patients dropped out |
|---|---|---|
| C0 | none | 0% |
| C1 | random, 8% a year | 26% |
| C2 | dependent: frail and treated patients leave sooner | 30% |
| C3 | the same hospitals as C2, with a dropout model that leaves out frailty | 30% |

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
| IPCW | 89% | 93% | 97% | 95% |
| AIPCW | 89% | 91% | 93% | **80%** |
| IPCW, truncated | 89% | 93% | 97% | 95% |
| AIPCW, truncated | 89% | 91% | 91% | **80%** |

## What the results show

1. **No dropout: CC, NE, IPCW and truncated IPCW give the same answer, as they must, and the Weibull-based methods give almost the same.** AIPCW, truncated AIPCW and BJ use a different outcome model: 0.02428 against 0.02412 at 5 years, 1 hospital against 0 above 0.5, coverage 89.19% against 89.23%. The error (0.024) is close to the Phase 1 smoothing error.
2. **Each simple fix fails somewhere.** Counting dropouts as event-free fails under random dropout (0.064, coverage 79%). Dropping them fails under dependent dropout (0.093, coverage 68%). Each looks fine in the other setting, for different reasons. NE's errors in the two arms cancel in C2 (helper mean errors -0.227 and -0.182). CC needs no cancelling in C1, because dropout there is random. **One setting cannot tell you whether a simple fix is safe.**
3. **Weighting lowers median-based bias, but large errors remain in many hospitals.** Under dependent dropout with the right dropout model, some frail treated patients had an estimated chance of staying near 0.0001, so their weights reached tens of thousands. 92 (IPCW) and 50 (AIPCW) of 200 hospitals had an absolute error above 0.5, and the standard deviation across hospitals at 5 years was 1.65 and 1.27, against 0.09 with no dropout. The mean-based bias is not resolved at this number of hospitals (MCSE 0.079 and 0.049). Median-based bias, which a few hospitals cannot drag, was 0.035 and 0.019.
4. **Truncation lowers the spread but does not remove the large errors.** With the chance of staying held at 0.05 or above, the standard deviation fell (IPCW 1.65 to 0.31; AIPCW 1.27 to 0.17) and so did RMSE, and the difference for AIPCW is resolved (-1.10, 95% interval -1.81 to -0.29). The average bias also fell (IPCW 0.116 to 0.022; AIPCW 0.048 to 0.029), but the AIPCW difference is not resolved (-0.019, interval -0.184 to 0.007). 83 and 27 hospitals still had an absolute error above 0.5, against 0 or 1 with no dropout. A possible reason, not tested here: the dropout weight multiplies the trial-joining weight from Phase 1 (which can exceed 100), so the combined weight can still be in the thousands.
5. **AIPCW had fewer hospitals above 0.5 than IPCW under dependent dropout, not in every setting.** C2: 50 against 92; C3: 4 against 30; C4: 73 against 90. C1: 9 against 10. C0: 1 against 0, so AIPCW was not better there. The RMSE difference is resolved in C3 and C4 but not in C2 (0.38 in IPCW's disfavour, interval -0.77 to 1.37). The bias ranking of IPCW against AIPCW is unresolved in C2, C3 and C4.
6. **With a wrong dropout model (C3), AIPCW's bias stayed low (0.027, near the C0 level); IPCW's was 0.037.** This is the direction the theory predicts, but the difference is not resolved (0.010, interval -0.006 to 0.024).
7. **AIPCW's intervals undercover when the dropout model is wrong (80%).** Bias does not account for most of this: coverage of the mean estimate, which removes bias by construction, is 83.8%, against about 92.5% for the same method in C0. Why the intervals are too narrow is not established. The sandwich intervals treat the helper models as known, which is one candidate.

## Time to benefit for each profile

The first time at which the drug lowers the risk by at least 5 points (δ = 0.05), on the half-year grid. True values: 3.5 years for v = 1, 2.0 for v = 2, 2.5 for v = 3.

| Profile | True | C0 truncated AIPCW, median | Share of hospitals within half a year | C2 CC median | C2 truncated AIPCW median |
|---|---|---|---|---|---|
| v = 1 | 3.5 | 3.0 | 32% | 4.5 | 3.0 |
| v = 2 | 2.0 | 2.5 | 54% | 3.0 | 2.0 |
| v = 3 | 2.5 | 3.0 | 46% | 4.0 | 2.5 |

- **Even with no dropout, one trial of 500 pins down a profile's time to benefit only roughly.** About a third to a half of hospitals land within half a year of the truth. The direction depends on the profile and method. At v = 1, the C0 medians are 3.5 for CC, NE and IPCW, on target, and 3.0 for AIPCW, early. At v = 2 and 3, they are half a year late for every method.
- **Dropping dropouts delays time to benefit** under dependent dropout by 1 to 1.5 years. Truncated AIPCW's median is on target at v = 2 and 3, and half a year early at v = 1.

## Gate 2

| Condition | Result |
|---|---|
| C0 reproduces Phase 1 at every time | **Yes.** CC, NE, IPCW and truncated IPCW identical; the Weibull-based methods nearly so; bias 0.022 averaged over time, coverage 90% |
| Weighted methods have small bias in C1 and C2 | **C1 yes.** C2 yes for the median; the mean is unresolved, and **27 to 92 hospitals have an absolute error above 0.5** |
| AIPCW holds in C3 while IPCW does not | **Partly.** AIPCW 0.027, IPCW 0.037, difference unresolved; AIPCW intervals undercover (80%) |

**Gate 2 is passed for median-based bias, but not for stability or intervals.** The review found no coding error that changes these conclusions (Step 2a). They are consistent with known limits of weighting methods under strong, selective dropout.

## What these results mean for the method

The estimator of Wen, Dahabreh and Chiu can be carried to censored outcomes and traced over follow-up by adding a dropout weight (or the augmented version) inside its pseudo-outcome. In this simulation, median-based bias at 5 years was 0.019 for AIPCW against 0.091 for CC in C2, and 0.025 for AIPCW against 0.067 for NE in C1. NE in C2 (0.029) and CC in C1 (0.022) were not worse by this measure. We found no paper with all of these elements. Two problems appear that the no-dropout setting hides:

- The trial-joining weight and the dropout weight multiply, so practical positivity may fail sooner. The source of the large errors is not established.
- The sandwich intervals are not validated for this estimator, and they undercover in several settings.

Both are open questions: how to stabilise the combined weights, and how to build intervals that account for estimated dropout weights.

## Limits

- The data-generating mechanism is ours and is not calibrated to any disease.
- The helper models are parametric Weibull and logistic regressions; the Super Learner was not used in Phase 2.
- One truncation level (0.05) was tried. Truncation shifts the estimand (Dahabreh et al., Stat Med 2020, p. 16), so the truncated methods' small bias is partly a change of target.
- Time to benefit is read on a half-year grid.
- 200 hospitals per setting: bootstrap Monte Carlo error on integrated bias at 5 years is 0.003 to 0.005 for most methods, but 0.007 to 0.010 for the truncated methods in C2 and C4, and 0.049 to 0.079 for untruncated IPCW and AIPCW there (`reports/tables/13_phase2_precision.csv`). Rankings between these are marked unresolved where intervals cross zero: IPCW against AIPCW in C2, C3 and C4; truncated AIPCW against AIPCW in C2; AIPCW against BJ in C2 and C4.

## Additions of 23 October: where the instability comes from, and a wrong outcome model

Three additions taken from Steingrimsson's work, rerun on the same 200 hospitals per setting. The six methods above reproduced the 22 October numbers exactly (largest difference 0, `scripts/12_check_reproduction.R`), so the tables above stand. Full output: `results/summary_phase2_20261023.txt`.

- **BJ (Buckley-James):** no dropout weight. Each dropout's status is filled in with the outcome model's chance of an event after leaving. Right only if the outcome model is right.
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

BJ in C0: identical to AIPCW (0.024, 89%), as it must be. In C1: 0.021, 4 hospitals above 0.5, coverage 86%. BJ gives the same answer in C2 and C3 because it never uses the dropout model.

### What the additions show

1. **Removing the dropout weight removes most of the large errors.** BJ keeps the trial-joining weight and drops the dropout weight; 1 of 200 hospitals had an absolute error above 0.5 in C2, against 92 for IPCW and 50 for AIPCW, and its standard deviation was 0.09 against 1.65 and 1.27. This shows the dropout weight is needed for most of them. It does not show the trial-joining weight plays no part, since the two multiply. The trial-joining weight's mean stayed between 0.96 and 1.06 in 98% of hospitals.
2. **BJ is biased when the outcome model is wrong** (C4: 0.064 against 0.025 with the right model), and the bias moves time to benefit: for v = 1, the median estimate is 2.0 years against a true 3.5. A possible reason, not tested here: the wrong model underestimates the risk of the frail patients who leave, most of whom were treated, so the drug looks better sooner.
3. **IPCW and AIPCW have small median-based bias in C4** (0.030 and 0.027), as the theory predicts. But 90 and 73 hospitals had an absolute error above 0.5, and the means are not resolved. AIPCW had more such hospitals in C4 (73) than in C2 (50). A possible reason, not tested here: with a wrong outcome model, the augmentation term cancels less of the weights' noise.
4. **BJ's intervals are too narrow even with the right outcome model** (72% coverage in C2). Bias does not account for most of this: coverage of the median estimate is 75.6%, against about 92.5% in C0. Why the intervals are too narrow is not established. One candidate: the filled-in chance replaces an unknown 0 or 1, and the sandwich formula treats it as observed.
5. **So there is a trade-off, and no method wins every setting.** BJ has few large errors but relies on the outcome model, and its intervals undercover. **AIPCW as coded is consistent if the outcome model is right, or if participation and dropout are both right.** IPCW needs dropout right and either participation or its own outcome model right. BJ needs the outcome model right. AIPCW's errors are large when weights are extreme. Truncated AIPCW had the smallest average error in C4 (0.019), at the cost of a shifted target; its ranking against AIPCW in C2 and AIPCW's against BJ in C2 and C4 are unresolved on bias.

### Do the weight checks flag the hospitals with large errors?

Rules fixed before the results were seen. Counts out of 200 hospitals, for AIPCW (hospitals with an absolute error above 0.5: 50 in C2, 4 in C3, 73 in C4):

| Rule | C2: flagged / above 0.5 caught | C3: flagged / above 0.5 caught | C4: flagged / above 0.5 caught |
|---|---|---|---|
| Combined-weight mean off 1 by more than 0.2 | 73 / 33 | **187** / 4 | 73 / 41 |
| One patient carries more than 10% of an arm's weight | 145 / 43 | 0 / 0 | 145 / 64 |
| Effective sample size below 50 in an arm | 171 / 47 | 0 / 0 | 171 / 68 |
| Trial-joining weight mean off 1 by more than 0.2 | 0 / 0 | 0 / 0 | 0 / 0 |

- **No rule picks out the hospitals with large errors.** The effective-sample-size rule catches most of them (47 of 50), but flags 171 of 200 hospitals. It says "this design is fragile", not "this hospital's curve is wrong".
- **The mean-weight check detects a wrong dropout model.** In C3, the middle 80% of hospitals had combined-weight means of 0.71 to 0.79 in the treated arm and 0.80 to 0.88 in the untreated arm, and the rule flagged 187 of 200. With the right dropout model (C2), the medians were 0.95 and 0.99. This is a check of the dropout model, not of stability.
- **The trial-joining weight never failed a check.** The check looks at its mean, so this does not rule out a part for it in the large errors.

### What this adds to the open questions

- The large errors under dependent dropout mostly disappear without the dropout weight. Methods that avoid it (BJ) have few large errors but lean entirely on the outcome model. How to choose between them, or combine them, is open.
- A simple check (the mean of the combined weights) detects a wrong dropout model, but no simple check identified the hospitals with an absolute error above 0.5.

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
| IPCW | 0.087 | 0.115 | 1.651 | 0.148 | 1.645 |
| AIPCW | 0.087 | 0.102 | 1.274 | 0.094 | 1.174 |
| IPCW, truncated | 0.087 | 0.115 | 0.315 | 0.148 | 0.301 |
| AIPCW, truncated | 0.087 | 0.102 | 0.172 | 0.094 | 0.249 |
| BJ | 0.087 | 0.090 | 0.089 | 0.089 | 0.094 |

### Disclosures

- **Dropout was strengthened after first results.** The dependent setting went from (0.06, 0.7, 0.6) to (0.10, 1.5, 1.0) on 22 October, because the first setting was too mild to expose a wrong dropout model (`docs/LOG.md`).
- **δ = 0.05 departs from the plan,** which set δ = 0.01 and 0.02 for time to benefit.
- **The compensator is a 30-step midpoint rule.** Going to 3,000 steps in C2 and C4 changed AIPCW only slightly. At 5 years in C2, RMSE moved from 1.272 to 1.264 (difference -0.0079, interval -0.0153 to 0.0004) and coverage from 92.65% to 92.64%. The count above 0.5 and time to benefit did not change. BJ did not move; truncated AIPCW moved by at most 0.0011. In the hospitals with the largest change, one patient accounts for 96 to 99.96% of it.
- **CC and NE keep frailty in C4,** so their C4 rows repeat C2. The C3 and C4 rows for CC and NE carry no wrong model, and neither do BJ's C3 rows.
- **CC refits the trial-joining model on the reduced data,** so its p_join is P(S = 1, status known | X). Taking both models from the full cohort does not repair it: at 5 years in C2, bias falls from 0.093 to 0.084, but coverage falls from 68.1% to 50.6%. Reported CC is unchanged.
- **IPCW's outcome model is logistic, while the generator has a complementary log-log form.** Over 25 hospitals at 5 years, logistic RMSE exceeded Weibull RMSE on average in every row, by about 0.01 in C0 (interval 0.004 to 0.016, logistic worse in 19 of 25 hospitals) and 0.013 to 0.054 for IPCW in C2. CC's and NE's larger errors in C2 come mostly from their mean errors, not from the link.
- **Run sizes differ:** Phase 1 used 500 hospitals with a Super Learner, its 5% trial setting 50 hospitals (preliminary), and Phase 2 200 hospitals with parametric models. These are not directly comparable.
- **Warnings.** The original runs suppressed warnings. Counted later, over 200 hospitals, C2 and C4 each gave 246 "fitted probabilities 0 or 1" (77 hospitals) and 4 "did not converge" (3 hospitals), all from logistic fits. CC's fits account for 123 of the 250; the rest were not attributed. The exploratory runs record each by fit. **[PENDING]**
- **The original tables give coverage of the exact target only.** Coverage of the smoothed and median targets is added below.

### Coverage against other targets

At 5 years, all from saved rows, MCSE about 0.5 to 1.9. Exact is the reported value. Smoothed passes the true curve through each hospital's own bandwidth. Median estimate removes bias by construction, so it separates bias from interval width and is not validation.

| Setting, method | Exact | Smoothed | Median estimate |
|---|---|---|---|
| C0 CC, NE, IPCW | 89.2 | 93.2 | 92.9 |
| C0 AIPCW, BJ | 89.2 | 93.4 | 92.5 |
| C2 CC | 68.1 | 80.8 | 92.5 |
| C2 NE | 92.3 | 90.7 | 93.5 |
| C2 IPCW | 97.3 | 96.8 | 97.2 |
| C2 AIPCW | 92.6 | 93.4 | 93.2 |
| C2 AIPCW, truncated | 91.4 | 92.2 | 91.8 |
| C2 BJ | 72.4 | 76.9 | 75.6 |
| C3 AIPCW | 79.9 | 85.1 | 84.0 |
| C4 IPCW | 97.3 | 96.6 | 97.4 |
| C4 AIPCW | 95.2 | 93.7 | 96.2 |
| C4 BJ | 75.5 | 65.8 | 86.2 |

- With bias removed, BJ in C2 stays at 75.6% and AIPCW in C3 at 84.0%, while C0 reaches about 92.5%. Most of the shortfall remains, so it is not bias. CC in C2 is the reverse: its shortfall is mostly bias.
- BJ's fall to 65.8% in C4 is bias against a correctly built target: signed bias -0.064 against the exact target and -0.085 against the smoothed one.
- The mean-estimate version is in `reports/tables/14_center_coverage_phase2.csv`. For untruncated IPCW and AIPCW in C2 and C4 the mean is unstable (MCSE 4 to 11), so the median is shown.
- **Limits of this check.** The smoothed target assumes v uniform, which matches the methods fitted on all eligible patients; CC is fitted on a reduced set, so for CC it is close, not exact. Median-estimate coverage says nothing about bias. In Phase 1, L has no smoothed value, and T's values may be used only as noted: 75.13 and 87.89 in `reports/tables/14_smoothed_coverage_phase1.csv` use the wrong target, and are not interpreted (`reports/tables/14_smoothed_coverage_phase1_NOTES.md`).

### Independent second method

An independent script, written without reading the estimators, was run on the same design (`independent_check/`). Its true values at t = 5, v = 1, 2, 3 agree with the repository's to 4e-16, through a different quadrature, and with its own Monte Carlo check.

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
- The script's mean biases are each about 1.1 to 1.2 MCSE from 0, so they show spread, not a mean shift. Its one 500,000-patient cohort shows no sign of systematic bias, which is not proof, since its approximate standard error is not validated for a heavy-tailed pseudo-outcome. Its `ipcw` is plain, with no outcome term, so it is not the repository's IPCW and is not ranked against AIPCW.
- Differences that remain, none tuned: Weibull in the repository against Cox in the script (both parametric); cross-validated bandwidth against h = 1; 30-step midpoint compensator against a sum on the jump times; fitted against known treatment probability.

## Exploratory runs

**These runs follow first results and are exploratory (Pawel et al.).** Pre-specification, with expected directions fixed before any run: `docs/exploratory_prespecification.md`. All use the reported seeds, parametric models and 30 compensator steps, so they compare directly with the rows above; the effect of 30 steps is the Check 1 result under Disclosures. A prediction that fails is reported as failed.

### Run A: truncation range

Floors 0.01, 0.02, 0.05 and 0.10, on G alone, on p(S=1|X) alone, and on their product, for IPCW and AIPCW in C2 and C4. The lower bound on the product also floors p where p is below the floor. **No floor was chosen, and none is called best.**

**[PENDING: results table, `reports/tables/15_runA_performance.csv`, `15_runA_paired.csv`.]**

### Run B: mild dropout

Rates (0.06, 0.7, 0.6), dropout model right (C2m) and wrong (C3m), all seven methods.

**[PENDING: results table, `15_runB_performance.csv`, `15_runB_paired.csv`; share with G(5) below 0.05 and smallest chance of staying, `15_runB_dropout_summary.csv`.]**

### Run C: wrong participation model

C2 data, participation model omitting frailty. C5a: outcome model right. C5b: outcome model also wrong, for every helper including CC and NE. This differs from C4, where CC and NE keep frailty.

**[PENDING: results table, `15_runC_performance.csv`, `15_runC_paired.csv`.]**

| Expected, fixed in advance | Result |
|---|---|
| C5a: AIPCW and BJ stay consistent | **[PENDING]** |
| C5a: IPCW uncertain | **[PENDING]** |
| C5b: AIPCW biased at n = 2,500 | **[PENDING]** |
| C5b: BJ biased at n = 2,500 | **[PENDING]** |
| C5b: IPCW biased at n = 2,500 | **[PENDING]** |

Every run uses one cohort size, so whether a bias shrinks with sample size cannot be observed here.

### Warnings by fit

These totals are not comparable with the 250 above, because warnings that the code suppresses are now counted too.

**[PENDING: `reports/tables/15_warnings_by_fit.csv`.]**
