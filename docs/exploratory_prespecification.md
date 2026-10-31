# Pre-specification of the exploratory runs

Committed before any full run of A, B or C. Only a 3-hospital smoke test has been run through this code. It was read for controls, timing, and a check that each new setting changes the estimates, and not for performance.

**These runs follow first results and are exploratory (Pawel et al.).** They were chosen after the reported Phase 2 results and the review of them had been seen. They do not confirm anything, and their results are labelled exploratory throughout. A prediction that fails is reported as failed, not revised.

## Settings for all new runs

- 200 hospitals, the same seeds as the reported runs (1 to 200).
- Parametric nuisances: logistic regression for participation, treatment and the outcome models of CC, NE and IPCW; Weibull for dropout and for the outcome model of AIPCW and BJ.
- Bandwidth grid and selection unchanged: one bandwidth per estimator, cross-validated at the last time, used at every time.
- Compensator 30 steps, so each run compares directly with the reported rows. The report states the effect measured in Check 1 of Step 2a.
- Nothing in `R/` or `config/` changes its default behaviour, and no reported table changes. New outputs go under `results/exploratory/` and `reports/tables/15_*`.
- Warnings are recorded per fit, with fit type and estimator, so none is left unattributed.
- Metrics at t = 5 and over t: integrated absolute bias, median-based bias, RMSE, coverage of the exact target, coverage of the median estimate, mean and median width, count of hospitals with absolute error above 0.5, bootstrap MCSE, and paired differences with intervals against the reported estimator on the same seeds.

## Run A: truncation range (exploratory)

- Floors 0.01, 0.02, 0.05, 0.10.
- Applied three ways: on G alone; on p(S=1|X) alone; on the product p(S=1|X) G, by a lower bound on the product.
- Estimators IPCW and AIPCW. Settings C2 and C4.
- For the product, with p_eff = max(p, f), G is floored at f / p_eff per patient, so that 1 / (p_eff G_eff) = 1 / max(p G, f), G_eff stays between 0 and 1, and G_eff(0) = 1. Where p is below f, the patient's joining chance is held at f and their chance of staying is taken as 1.
- For schemes on G and on the product, IPCW's logistic outcome model uses the same floored weights, as IPCW_t does at 0.05. For the scheme on p it is the reported IPCW model, whose weights do not involve p.
- **No floor is to be selected or called best anywhere, and the report says none was chosen.**
- Control: G floor 0.05 must reproduce saved AIPCW_t and IPCW_t exactly on 3 hospitals.
- Control: schemes G, p and the product at floor 0 must reproduce saved IPCW and AIPCW exactly in C2 and C4 on 3 hospitals. Floor 0 is a control only and is not one of the reported floors.
- Control: the reported analysis through this path must reproduce the saved rows exactly in C2 and C4 at 200 hospitals.

## Run B: mild dropout

- Rates (0.06, 0.7, 0.6) as baseline, frailty and treated coefficients.
- Dropout model right (C2m) and wrong (C3m, leaving out frailty, as C3).
- All seven estimators, with the same floor 0.05 for the _t estimators.
- Also reported: the share of trial patients with G(5) below 0.05, and the smallest chance of staying.

## Run C: wrong participation model

- On C2 data, all seven estimators, with the participation model omitting frailty.
- C5a: outcome model right.
- C5b: outcome model also wrong, omitting frailty, for every helper including CC and NE. This differs from C4, where CC and NE keep frailty, and the report states the difference.
- Dropout model right in both. The treatment model stays right in both.

## Expected directions

From the algebra, with no result seen.

AIPCW as coded is consistent if the outcome model is right, or if participation and dropout are both right. So:

| Setting | Estimator | Expected |
|---|---|---|
| C5a | AIPCW, BJ | Stay consistent |
| C5a | IPCW | Uncertain, given its logistic gamma. IPCW needs dropout right and either participation or its own gamma right |
| C5b | AIPCW | Biased at n = 2,500 |
| C5b | BJ | Biased at n = 2,500 |
| C5b | IPCW | Biased at n = 2,500 |

No direction is stated for CC, NE, Run A or Run B.

**Limit on testing these.** Every run uses one cohort size, 2,500, so whether a bias shrinks with sample size cannot be observed. These runs show only the size of the bias at this size, against C2 on the same seeds.

## Decision rule

Fixed before the runs, because "held" is otherwise undefined at one cohort size.

- **Metric:** integrated absolute median-based bias at t = 5, as the paired difference against C2 on the same seeds, with its 95% bootstrap interval over hospitals. Medians are recomputed in each resample.
- **Margin:** 0.01.
- **"Stay consistent":** held if the upper limit is below 0.01, failed if the lower limit is above 0.01, otherwise not determined.
- **"Biased at n = 2,500":** held if the lower limit is above 0.01, failed if the upper limit is below 0.01, otherwise not determined.
- Mean-based bias is shown but does not decide, because it is unstable.
- IPCW in C5a is uncertain in advance, so it is reported without a decision.

## How results will be reported

Each prediction is reported as held, failed or not determined by this rule. A failed prediction is reported as failed and is not revised. Nothing beyond the runs above starts without a separate decision.
