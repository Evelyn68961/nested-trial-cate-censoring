# Process log

What was decided, changed and checked, in order, with the reason for each. Newest entries at the bottom of each day. Commits are short hashes in this repository.

---

## 2026-10-22

### Setup

- **Language: R only.** The paper's software (Super Learner) is in R, and so is the reference code.
- **Repository private** until Gate 2 passes (Phase 2 checks): nothing goes public before the results have been checked.
- **Raw results were at first not committed.** This changed later: `results/` is no longer in `.gitignore`, only `results/reference/` is, and the run files in `results/` are in the repository. Summary tables and figures in `reports/` are committed.

### Step 1: simulated hospitals (commit 3532169)

**Settings chosen, and why** (`config/phase1.yaml`). The paper's own data-generating mechanism is in its Web Appendix D, which is not in the arXiv PDF. So the mechanism here is our own, built to have the features the paper's simulation needs:

| Setting | Value | Why |
|---|---|---|
| Cohort size | 2,500 | The paper's smaller cohort (it uses 2,500 and 5,000) |
| Trial share | 20% (about 500) | The paper's middle trial size (125, 500, 1,000) |
| Characteristics | frailty (normal), v (uniform 0 to 4), male (0/1), independent | Mirrors the paper's X1, X2, X3; v plays X2, the effect modifier. The paper's figure shows X2 roughly between 0 and 4. Independence makes the exact truth a simple integral. |
| Who joins | frailty −0.8, v +0.4, male +0.2 (log-odds) | Frail patients join less; this creates the gap between trial and target |
| Treatment in trial | 0.5 | Randomization |
| Outcome without treatment | intercept −1.0, frailty +0.6, v +0.3, male +0.3 | Event rate around 30–35%, so a trial of 500 has events to learn from |
| Treatment effect (log-odds) | −0.3 − 0.5 v + 0.15 v² + 0.6 frailty | v² bends the curve, so a straight-line estimator (L) fails. Frailty in the effect makes the trial curve differ from the target curve, so the trial-only estimator (T) fails. |
| Grid | 37 values of v from 0.2 to 3.8 | Avoids the edges at 0 and 4, where few patients sit |

These are design choices, not estimates from any real study.

**Truth.** The target curve is computed exactly by numerical integration over frailty and sex. The paper used Monte Carlo with 10⁷ draws instead; exact integration removes that noise.

**Result.** At v = 2, the trial-population curve is −0.156 and the target curve is −0.120. One hospital: 522 of 2,500 joined; mean frailty −0.65 in the trial against 0.16 outside.

**Tweak.** The first version drew outcomes for everyone and then blanked those outside the trial, which made R warn about missing probabilities. Changed to draw outcomes only for trial patients. Results unchanged.

**Checks.** Seven tests, including that the exact curve matches a brute-force average over two million simulated patients, and that the exact trial curve matches trial patients in a cohort of two million.

### Step 2: helper models (commit 304b878)

**Settings, and why.**

- **Five folds** for cross-fitting. The paper does not state its number of folds; five is common.
- **Folds balanced by trial membership**, so each fold holds a fifth of the trial patients.
- **Two learner settings.** `glm`: logistic regressions with the right terms (fast, for checks). `sl`: Super Learner with logistic regression, a generalized additive model and a random forest. The paper's library also has interaction glm, xgboost, earth and a neural network. It was cut to three to keep run time manageable, and because `earth` is not installed.
- **Treatment model always a simple logistic regression**, because treatment was randomized. The paper says the same.
- **Outcome model fitted separately in each trial arm**, as in Robertson et al.'s code.

**Tweak.** Super Learner could not find its own learners unless the package was attached. Fixed by passing its namespace as the environment.

**A near-mistake, caught.** The first preview averaged the outcome model's predicted effect over patients with v near 2 in 20 hospitals. Both averages appeared to lean about 0.025 too negative. A rerun over 200 hospitals showed no lean (−0.1225, Monte Carlo SE 0.0046, against a truth of −0.1199). The 20-hospital result was chance; the script now uses 200.

**Tweak.** The figure first used equal axis scales, which squeezed the panels. Replaced by fixed axis limits.

**Timing.** One hospital: 0.1 seconds with `glm`, 11 seconds with `sl`.

### Step 3: the pseudo-outcome (commit ba1ea0a)

**Change to step 2 code.** `fit_nuisance` now takes formulas, so a helper model can be made wrong on purpose. It also has a trial-only mode for estimator T, in which no participation model is fitted and the chance of joining is set to 1.

**Tweak to tests.** The first double-robustness tests failed. Two reasons, both in the tests, not the method: `testthat`'s `tolerance` is relative (0.01 meant ±0.0012 here), and the narrow band near v = 2 had Monte Carlo noise of about 0.014. The tests now check the average over all patients in a cohort of one million, with absolute limits.

**Result** (200 hospitals; error in the average effect over all eligible patients; truth −0.082):

| Helpers | Outcome model alone | With correction |
|---|---|---|
| Both right | 0.000 | 0.000 |
| Outcome model wrong (frailty left out) | −0.037 | 0.003 |
| Participation model wrong (same chance for all) | 0.000 | 0.001 |
| Both wrong | −0.037 | −0.039 |

The correction's price: standard deviation across hospitals 0.060, against 0.052 for the outcome model alone.

### Steps 4 and 5: the curve, and the reference check (commit 6bea4ef)

**Settings, and why.**

- **Epanechnikov kernel.** The paper's conditions require a kernel on [−1, 1]; this is the standard one.
- **Bandwidth by leave-one-out cross-validation**, as in the paper. Grid 0.3 to 2.0 in steps of 0.1. Computed with the closed form for linear smoothers (residual ÷ (1 − own weight)). A test confirms it equals refitting without each patient.
- **Intervals:** the paper's sandwich formula (section 5.1), estimate ± 1.96 × σ/√n, with n all eligible patients.
- **Smoothed target θ\*(v):** the same local linear fit applied to the true curve, with v uniform, using each hospital's own bandwidth. The paper reports coverage against this as well as against θ(v).
- **L's intervals:** robust (sandwich) variance of the straight-line fit. **G** gets no interval, because none is justified when the correction term is left out.

**One hospital** (Super Learner): pseudo-outcomes ranged from −30 to 84, because some trial patients carry weights above 100. Bandwidth 0.4. The estimate at v = 0.2 was +0.72 against a truth of −0.04, yet 35 of 37 intervals contained the truth. This noise level fits the paper's Table 1 (integrated RMSE about 0.17 at the same sizes).

**Reference check (step 5).** Robertson, Steingrimsson and Dahabreh's `DGM_Sim` (commit 0bace88 of their repository) was run unchanged, with only its CASS-specific model-fitting step replaced by our helper predictions. Largest difference from our pseudo-outcomes over 7 hospitals: 2 × 10⁻¹⁴. Their file has no licence, so it is downloaded at run time into `results/` and never committed.

### Step 7: runs

**Runner settings, and why.**

- 25 hospitals per saved chunk; an interrupted run resumes at the next missing chunk.
- 3 parallel workers on a 4-core laptop with 16 GB memory (about 6 GB free), leaving one core free.
- The runner refuses to start if `R/`, `config/` or `scripts/` have uncommitted changes, and records the commit in every result row.
- Warnings inside a hospital's fit are suppressed in the runner (mostly Super Learner learners failing on small arms); failures show up as missing estimates, which the summary counts.
- **Scoring** as in the paper's Table 1: bias, RMSE and coverage at each grid value, then averaged over the 37 values ("integrated").
- **Plan:** pilot of 50 hospitals with `glm` helpers, then 500 hospitals each for `sl` with 20% and 5% trial shares (about 500 and 125 trial patients).

### First pilot, and a change to the design (commit c6a650d)

**First pilot:** 50 hospitals, logistic-regression helpers, original effect settings. It ran cleanly (5 minutes, no missing estimates), but could not tell the estimators apart:

| Estimator | Integrated absolute bias | Integrated RMSE | Coverage |
|---|---|---|---|
| P (paper) | 0.023 | 0.098 | 94.3% |
| L (straight line) | 0.029 | 0.082 | 94.3% |
| T (trial only) | 0.029 | 0.071 | 92.6% of the target curve |
| G (outcome model alone) | 0.015 | 0.070 | — |

**Why:** the true curve only ran from −0.12 to −0.02. The trial-to-target gap (about 0.036 on average) and the straight line's misfit were small against the noise of one hospital. The paper's own curve runs from about +0.4 to −0.7.

**Change:** treatment-effect coefficients from (intercept −0.3, v −0.5, v² 0.15, frailty 0.6) to (1.0, −1.6, 0.4, 1.0). Three candidate designs were compared on their exact curves before choosing:

| Design | Target curve range | Mean trial-to-target gap | Largest straight-line misfit |
|---|---|---|---|
| Original | −0.120 to −0.017 | 0.039 | 0.062 |
| A (chosen) | −0.086 to +0.158 | 0.072 | 0.138 |
| B | −0.095 to +0.128 | 0.060 | 0.129 |

A was chosen because it separates the estimators most. Its curve also changes sign: the drug harms at both ends of v and helps in the middle, so the question "for whom does it help?" has a real answer. Steps 1 to 5 were rerun: all 22 tests pass, and the reference check still matches to 10⁻¹⁴. Lessons 1 to 3 were updated to the new numbers (commit a9a8cd8). The old pilot's results are kept in `results/archive/`.

### Second pilot, and the bandwidth question

**Second pilot:** 100 hospitals, logistic-regression helpers, new design:

| Estimator | Integrated absolute bias | Integrated RMSE | Coverage |
|---|---|---|---|
| P (paper) | 0.021 | 0.104 | 91.4% of θ(v); 93.0% of θ\*(v) |
| L (straight line) | 0.060 | 0.098 | 80.4% |
| T (trial only) | 0.060 | 0.097 | 83.6% of the target curve; 90.6% of its own trial curve |
| G (outcome model alone) | 0.007 | 0.075 | — |

The shortcuts now fail as they should. P's numbers are close to the paper's Table 1 for the same sizes (integrated absolute bias 0.020, coverage 92%).

G does best here because its outcome model has exactly the right terms. That is the point of running Super Learner next: in real data nobody hands you the right terms.

**P's bias has a pattern:** too high in the middle of v (about +0.03), too low at the ends (about −0.02). That is what over-smoothing does. In 48 of 100 hospitals, cross-validation picked the largest allowed bandwidth, 2.0.

**Check:** is the cap of 2.0 (my choice, not the paper's) causing this? 60 hospitals were rerun with bandwidths allowed up to 4.0.

- Cross-validation's choices spread over the whole range (10 of 60 at the new cap of 4.0).
- The average cross-validation score is almost flat: the best and worst bandwidths differ by under 0.1%. The pseudo-outcomes are so noisy that cross-validation cannot tell bandwidths apart.
- Bias and RMSE barely changed: 0.022 and 0.105 with the wider range, against 0.020 and 0.103 with the cap at 2.0.

**Decision:** keep the range 0.3 to 2.0. The over-smoothing is a property of cross-validation on noisy pseudo-outcomes, not of the cap. The paper's discussion points the same way: it names bias correction and undersmoothing as future work, because coverage of the exact curve suffers.

### Main runs started

Super Learner helpers, 500 hospitals each: trial share 20% (about 500 trial patients) and 5% (about 125). Commit a9a8cd8. While they run, no file they use (`R/` files and `config/phase1.yaml`) is edited; Phase 2 code goes in new files.

### Phase 2 code (commit ef4577a)

Written while the Phase 1 main runs were going, in new files only.

**Event times, and why** (`config/phase2.yaml`). Patients, trial participation and randomization are the same as in Phase 1. Each patient's event time under each treatment comes from a Weibull model. The risk by time t under treatment a is 1 − exp(−exp(lp0 + a × effect) × t^shape_a).

| Setting | Value | Why |
|---|---|---|
| Untreated log-scale lp0 | −3.0 + 0.6 frailty + 0.3 v + 0.3 male | Untreated risk about 12% by year 1 and 58% by year 5: enough events in a trial of 500 |
| Treatment shift | 0.8 − 1.4 v + 0.35 v² + 0.8 frailty | Same shape as Phase 1: harm at the ends of v, benefit in the middle, less benefit for frail patients |
| Weibull shape | 1.3 untreated, 1.0 treated | A flatter shape under treatment makes the benefit grow over time. |
| Follow-up | 5 years | |
| Times | 0.5 to 5 years in steps of 0.5 | Ten time points, so time to benefit can be read to half a year |

Two candidate designs were compared on their exact curves first. The chosen one (A) gives, for all eligible patients: at v = 2, no effect at year 1 and −0.235 by year 5; at v = 0.2, early harm (+0.11) fading to +0.05; at v = 3.8, harm that turns into a small benefit by year 5. So time to benefit differs by profile.

**Dropout settings.** Exponential dropout times, plus everyone censored at 5 years.

| Setting | Dropout | Share of trial patients dropped out (one hospital) |
|---|---|---|
| C0 | none | 0% |
| C1 | random, rate 0.08 per year | 26% |
| C2 | rate 0.06 per year × exp(0.7 frailty + 0.6 treated): frail and treated patients leave sooner | 20% |
| C3 | the same hospitals as C2, analysed with a dropout model that leaves out frailty | 20% |

C2 and C3 use the same seeds, so the only difference between them is the dropout model used in the analysis.

**The four estimators**, each feeding the Phase 1 method (pseudo-outcome, then local linear curve) at each time:

- **CC (complete case):** trial patients whose status at t is unknown are removed.
- **NE (no event):** unknown status is counted as no event by t.
- **IPCW:** status known at t, divided by the estimated chance of still being followed at min(time, t). The outcome model is a logistic regression of status at t, weighted the same way.
- **AIPCW (augmented IPCW):** IPCW plus a correction for each dropout, using a Weibull outcome model fitted in each arm to predict what would likely have happened after they left. The outcome model is that Weibull model. As coded, AIPCW is consistent if the outcome model is right, or if the participation and dropout models are both right.

**Helper models.** All parametric, not Super Learner:
- the dropout model is a Weibull regression on treatment, frailty, v and sex;
- the outcome model is a Weibull regression in each arm on frailty, v, v² and sex, which is the true form;
- participation and treatment are logistic models.

All are cross-fitted with five folds. Parametric models were chosen because the question here is dropout, not flexible learning, and because the AIPCW correction needs a model that predicts survival over time. CC and NE use the Phase 1 logistic helpers for status at t.

**Bandwidth.** One bandwidth per estimator per hospital, chosen by cross-validation at 5 years and used at every time. Grid 0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0. Reasons: Phase 1 showed the cross-validation score is nearly flat anyway, and choosing it ten times per hospital would multiply the run time.

**The AIPCW correction, in formula form.** For a trial patient with follow-up time T̃ and status at t:

Y\* = known × status / G(min(T̃, t)) + [dropped before t] × F(t | T̃) / G(T̃) − ∫₀^min(T̃,t) F(t | u) d(1/G(u))

Here G is the chance of not having dropped out, and F(t | u) is the chance of the event by t given event-free at u, from the Weibull outcome model. The integral is computed with 30 midpoint steps.

**Tweaks during writing.**

- The first version computed F(t | u) as 1 − S(t)/S(u). For very high-risk patients both survival values underflow to 0, giving 0/0. It is now computed from cumulative hazards: 1 − exp(−(H(t) − H(u))).
- A test first used single numbers for the Weibull scales where the code expects one value per patient, which produced NA. The test was fixed; the code was right.
- One planned test expected simple dropping to be biased among treated patients at year 3 under dependent dropout. In this setting it was not (difference 0.0008): frail patients drop out more and also have more events, and the two biases cancel. The test now checks counting dropouts as event-free, which is biased in a known direction.

**Checks.** Seven tests. The key ones use true helper values in a hospital of 600,000. The augmented status averages to the true risk among treated patients at year 3 with both helpers right, with the outcome model wrong, and with the dropout model wrong (each within 0.01). It misses when both are wrong. All 29 tests pass.

**One hospital per setting** (`scripts/09_check_phase2.R`): 16 to 20 seconds each while the Phase 1 runs shared the computer. With no dropout, CC, NE and IPCW give identical answers, as they should (all weights 1), and AIPCW differs slightly because it uses the Weibull outcome model.

### Main runs shortened: the computer shuts down at 17:30

Learned at 14:55 that this computer shuts down automatically at 17:30. At about 5.5 minutes per 25 hospitals, the planned runs (500 + 500 hospitals in Phase 1, then Phase 2) would not finish. Changed at 14:58:

- The first main run (Super Learner, 20% trial share) was stopped after 25 hospitals. The chunk in progress was lost (at most 25 hospitals, about 5 minutes).
- It was restarted with **300 hospitals** instead of 500.
- Then **Phase 2 at 100 hospitals per setting** (C0 to C3) instead of 200.
- The 5% trial-share run (about 125 trial patients) is **postponed**.

Nothing is lost by shortening. Chunks hold 25 hospitals with fixed seeds, so rerunning a command with a larger number continues from the saved chunks and adds only the missing ones.

**To resume on the next session**, from the repository root:

```
Rscript scripts/07_run_phase1.R sl 0.20 500 3     # extends Phase 1 from 300 to 500 hospitals
Rscript scripts/07_run_phase1.R sl 0.05 500 3     # the postponed 125-trial-patient setting
Rscript scripts/10_run_phase2.R C0 200 3          # and likewise C1, C2, C3: extends Phase 2 to 200
Rscript scripts/08_summarise_phase1.R
Rscript scripts/11_summarise_phase2.R
```

Raw results are in `results/` on this computer's D: drive (not on GitHub). If the next session runs on another computer, either copy `results/` across, or rerun from scratch: the same seeds give the same hospitals.

Also checked before restarting: six R processes still running were started at 12:03, before this work began. They are VS Code's R language servers, not simulation workers, and were left alone.

### Phase 2 first runs, before the shutdown

Ran 16:41 to 17:00: C2, C3, C1, C0, 50 hospitals each, about 15 seconds per hospital. Order chosen so the settings that matter most (dependent dropout) ran first. The results files record different commits per setting (2053465, eaae050, 0d9a0a8, e14f16e). These differ only in results and documents committed by the autosave loop; the R code and config are the same in all four.

**Also found:** the Phase 1 run I thought I had stopped at about 15:00 had kept running and finished all 500 hospitals, and started the 5% trial-share setting (50 hospitals done). Duplicate work would have been harmless, because every hospital has a fixed seed. I had also not checked the clock between 14:53 and 16:40 and assumed much less time had passed.

**Results** (preliminary; `reports/archive/phase2_preliminary.md`). No dropout: all four methods agree. Random dropout: counting dropouts as event-free fails (bias 0.061 at year 5, coverage 79%). Dependent dropout: AIPCW has the smallest error at year 5 (0.025 against 0.033 to 0.038), but within about one Monte Carlo error. Wrong dropout model (C3): IPCW did not fail (0.023).

**Diagnosis:** the dependent-dropout setting is too mild to expose a wrong dropout model. The same problem as the first Phase 1 pilot. Next: a stronger setting chosen by comparing candidates first, then 200 hospitals per setting.

**Saving progress:** `results/` is now committed to git (2.7 MB at the time), except `results/reference/` (the unlicensed download). An autosave loop pushed new results every 4 minutes until 17:28. `docs/HANDOFF.md` lists the state and the commands to resume.

### Session resumed 17:34: stronger dependent dropout

The computer was still on (or back) at 17:34; all results and commits were intact.

**Why the preliminary C2/C3 results were flat.** Five candidate analyses were run on one hospital of 400,000 at year 5. The dropout bias appears in each arm's risk, but it partly **cancels when the arms are subtracted**. Bias in the effect at year 5 (treated arm minus untreated arm):

| Dropout setting (base rate, frailty, treated) | Share dropped | CC | NE | IPCW, dropout model without frailty |
|---|---|---|---|---|
| (0.06, 0.7, 0.6), the old setting | 20% | +0.006 | −0.004 | −0.015 |
| D2 (0.08, 1.2, 0.8) | 25% | −0.005 | −0.016 | −0.031 |
| D3 (0.10, 1.5, 1.0), chosen | 30% | −0.016 | −0.026 | −0.046 |

With the old setting, a wrong dropout model cost only 0.015, less than the smoothing error (about 0.026), so no number of hospitals in this design would show it clearly. D3 makes it 0.046. **Changed `config/phase2.yaml` to D3.** Only C2 and C3 use this setting, so their 50-hospital results moved to `results/archive/phase2_mild_dropout/`; C0 and C1 are unaffected and their chunks are kept and extended.

**The price of D3.** About 8% of trial patients now have under a 5% chance of staying to year 5, and 4.5% under 1%. These patients get very large weights in IPCW and AIPCW (a practical positivity problem for dropout), so those methods will be noisier. This is realistic for strongly selective dropout and will be reported, not hidden.

**Test change.** The AIPCW check with both helpers right missed by 0.011 against a fixed limit of 0.01 in a hospital of 600,000. Diagnosis: one patient's extreme weight gave this seed a Monte Carlo standard error of 0.012, so the miss was within one standard error. Two other seeds missed by 0.002, with standard errors of 0.003. Using 200 integration steps instead of 30 changed nothing. The AIPCW tests now use a limit of 3 Monte Carlo standard errors plus 0.002 instead of a fixed 0.01. All 12 Phase 2 tests pass.

### 200-hospital Phase 2 runs, and weight truncation added

**Runs** (17:37 to 18:44, D3 dropout, 200 hospitals per setting). Averages over the ten times:

| Setting | CC | NE | IPCW | AIPCW |
|---|---|---|---|---|
| C0 no dropout | 0.022 | 0.022 | 0.022 | 0.022 |
| C1 random (26% dropped) | 0.020 | **0.038** | 0.025 | 0.021 |
| C2 dependent (30%) | 0.069 | 0.029 | 0.073, **RMSE 1.10** | 0.038, **RMSE 0.76** |
| C3 dependent, dropout model wrong | 0.069 | 0.029 | 0.031 | 0.022 |

(Integrated absolute bias; RMSE given only where it is abnormal.)

**Diagnosis of the large errors in C2.** With the right dropout model, the estimated chance of staying to 5 years reached 0.00006 in the worst hospital, and was below 0.034 in half of them. The weights (1 ÷ chance) then reach tens of thousands. At year 5, the curve missed the truth by more than 0.5 somewhere in 92 of 200 hospitals for IPCW and 50 of 200 for AIPCW, against 6 to 8 for CC and NE. Bias based on medians, which such outliers cannot drag, puts AIPCW best (0.019), then NE (0.029), IPCW (0.035) and CC (0.091). In C3 the wrong dropout model cannot produce small chances (lowest 0.30), so the weights stay moderate. This is the classic practical-positivity problem of weighting, and it is worse for the right dropout model than for the wrong one.

**Two further points.**
- NE does well in C2 and C3 (0.029), unlike in C1. Its errors in the two arms happen to cancel in this setting. This is a property of the setting, not a merit of the method; C1 shows it failing.
- In C3, IPCW is only slightly worse than AIPCW (0.031 against 0.022 on average; 0.037 against 0.027 at year 5). The direction is as expected.

**Change: weight truncation added as two extra estimators,** IPCW_t and AIPCW_t. The estimated chance of staying is never allowed below 0.05, so no weight exceeds 20. Truncation is the standard remedy, at the price of a little bias. The untruncated estimators are kept unchanged, so both are reported. The summary now also reports bias from medians and the number of hospitals whose curve misses by more than 0.5. The 200-hospital results without truncation moved to `results/archive/phase2_200_before_truncation/`, and their summary to `results/archive/summary_phase2_no_truncation.txt`. All four settings are rerun; with the same seeds, the untruncated estimators reproduce exactly.

### Phase 2 final runs with truncation (18:48 to 20:36)

All four settings, 200 hospitals each, with IPCW_t and AIPCW_t added. The untruncated estimators reproduced the archived numbers exactly (same seeds), as expected. The runs took about 25 minutes per setting (21 s per hospital), longer than estimated, because the AIPCW status is now computed twice.

**Key results at 5 years** (full tables in `reports/phase2_results.md`):
- No dropout: all methods identical (bias 0.024).
- Random dropout: NE fails (0.064, coverage 79%).
- Dependent dropout: CC fails (0.093, coverage 68%). Untruncated IPCW and AIPCW have an absolute error above 0.5 in 92 and 50 of 200 hospitals; truncated in 83 and 27, against 0 or 1 with no dropout.
- Wrong dropout model: AIPCW 0.027, IPCW 0.037; AIPCW coverage 80%.

**Why truncation did not cure it:** the dropout weight multiplies the trial-joining weight (which can exceed 100), so the combined weight stays in the thousands even with the dropout part capped at 20. Not yet tried: truncating the combined weight, or a higher floor. [Superseded 31 Oct: see reports/phase2_results.md]

**AIPCW undercoverage in C3:** the sandwich treats helper models as known. With one helper model wrong, the estimate stays consistent but that variance formula is no longer valid. [Superseded 31 Oct: see reports/phase2_results.md]

**Time to benefit:** even with no dropout, only 32% to 54% of hospitals put a profile's time to benefit within half a year of the truth. Medians run about half a year late, from smoothing. CC delays it by 1 to 1.5 years under dependent dropout; truncated AIPCW keeps the median on target. [Superseded 31 Oct: see reports/phase2_results.md]

**Gate 2:** passed for bias; not for stability under strong dependent dropout, and not for AIPCW intervals with a wrong dropout model. Both are known limits of weighting methods, reported as findings. Report: `reports/phase2_results.md`; lesson 10.

### Note from reading Steingrimsson and Morrison (Stat Med 2020) and Dahabreh et al. (Stat Med 2020) (22 October, evening)

- **Truncation changes the target.** Dahabreh, Robertson, Steingrimsson, Stuart and Hernán's tutorial warns that truncating extreme weights "may also help, but these strategies shift the causal estimand, which is often undesirable" (Stat Med 2020; arXiv v3, p. 16). So the small bias of IPCW_t and AIPCW_t in C2 is partly a change of target, not only a cure.
- **Phase 2 is the combination that tutorial left as future work.** It says methods for right censoring can be combined with its methods "in a modular fashion", and that "Future work should assess the properties of such combined procedures" (p. 17).
- **Candidate additions** from these papers were ranked in notes kept outside this repository:
  - a Buckley–James version with no dropout weight;
  - a wrong-outcome-model setting C4;
  - weight diagnostics;
  - counterfactual Brier scores with dropout.

## 23 October 2026: three additions from Steingrimsson and Morrison (Stat Med 2020) and Dahabreh et al. (Stat Med 2020) (steps 12 to 14)

Planned and timed against the 17:30 shutdown: code by 08:30, runs by 12:30, write-up by 15:30. Started 05:58.

### Step 12: a Buckley-James estimator (BJ)

**What it is.** [Superseded 31 Oct: see reports/phase2_results.md] No dropout weight at all. A trial patient whose status at t is known keeps it. A patient who dropped out before t gets the outcome model's chance of an event between leaving and t. In code it is `augmented_status()` with the chance of staying set to 1 for everyone (`use_dropout_model = FALSE`). With G ≡ 1 the compensator is zero, so only the observed status and the filled-in chance are left. Steingrimsson & Morrison (Stat Med 2020; arXiv:1904.10345v1, p. 7) show this is the doubly robust loss with G ≡ 1.

**Why.** In C2, 92 (IPCW) and 50 (AIPCW) of 200 hospitals had an absolute error above 0.5. BJ keeps the trial-joining weight but drops the dropout weight. If it rarely has such errors, the dropout weight is needed for them.

**Price.** BJ is right only if the outcome model is right.

**Tests added:**
- BJ status equals the AIPCW status computed with a dropout model that says nobody leaves.
- With the true outcome model, the BJ status averages to the true risk; with an outcome model that ignores every characteristic, it does not.
- With no dropout, the BJ curve equals the AIPCW curve exactly.

### Step 13: setting C4, a wrong outcome model

**What it is.** The C2 hospitals (same seeds), the right dropout model, and outcome models that leave out frailty: the Weibull models in each arm and the IPCW logistic models (`~ v + I(v^2) + male`). The Phase 1 helper models used by CC and NE are unchanged.

**Why.** C3 tested a wrong dropout model with a right outcome model. C4 is the other half of the double-robustness test. Expected: BJ biased, IPCW and AIPCW not.

**Pilot (25 hospitals, 06:03 to 06:07).** The risk was that leaving out frailty biases BJ too little to see; the threshold set in advance was 0.02. At 5 years, BJ's bias was 0.066 with 72% coverage, and only 1 of 25 hospitals had an absolute error above 0.5. So C4 was kept as designed, with no stronger misspecification. The pilot's 25 hospitals are the first chunk of the full C4 run (same code and seeds).

### Step 14: weight checks

Recorded per hospital at 5 years, over all eligible patients (`weight_checks()` in `R/phase2_estimators.R`):
- the mean of the trial-joining weight S / P(trial), which should be close to 1 (Dahabreh et al., Stat Med 2020; arXiv v3, p. 16);
- in each arm, the mean of the trial and arm weight, and of the combined weight (also divided by the chance of still being followed, untruncated), each close to 1;
- in each arm, the largest combined weight, the share of the arm's total weight that it carries, and the effective sample size (sum of weights squared over sum of squared weights).

The summary script tests four rules, fixed before seeing the full results:
- a combined-weight mean off 1 by more than 0.2;
- one patient carrying more than 10% of an arm's weight;
- an effective sample size below 50 in an arm;
- a trial-joining weight mean off 1 by more than 0.2.

For each rule, it counts how many hospitals with an absolute error above 0.5 (somewhere at 5 years) it flags, and how many others.

### Runs

The 200-hospital results of 22 October moved to `results/archive/phase2_200_before_bj/`. All five settings were rerun at commit 2b38cab, 3 workers, starting 06:08. The six existing estimators use the same seeds and code paths, so they must reproduce the archived numbers exactly; this is checked below.

Commits after 2b38cab during the runs change only docs/ (checked with `git diff --stat 2b38cab -- R config scripts`, which is empty), so settings that started later may record a later commit hash with the same code.

### Results (runs 06:08 to 08:42)

**Reproduction.** The six existing estimators reproduced the archived 22 October results exactly in C0 to C3 (444,000 rows each; largest difference in estimate, standard error and bandwidth: 0). Script: `scripts/12_check_reproduction.R`.

**Gate 3:** [Superseded 31 Oct: see reports/phase2_results.md]

| Condition | Result |
|---|---|
| Existing estimators reproduce exactly | **Yes** |
| BJ stable in C2 | **Yes.** 1 of 200 hospitals with an absolute error above 0.5, against 92 (IPCW) and 50 (AIPCW); bias 0.025 at 5 years. The dropout weight is needed for most of these errors. |
| BJ biased in C4; IPCW and AIPCW not | **Yes for BJ** (0.064, coverage 76%). **IPCW and AIPCW: yes by medians** (0.030, 0.027), but averages are dragged by hospitals with an absolute error above 0.5 (90 and 73). |
| A weight check flags the hospitals with an absolute error above 0.5 | **No.** Effective sample size below 50 catches 47 of 50 such AIPCW hospitals in C2 but flags 171 of 200. The combined-weight mean instead flags a wrong dropout model (187 of 200 in C3). |

**Unplanned finding.** [Superseded 31 Oct: see reports/phase2_results.md] BJ's intervals undercover even with the right outcome model: 72% in C2, 86% in C1. The likely reason is that filled-in values are less variable than real outcomes and the sandwich treats them as observed. Not tested; a bootstrap would.

**Time to benefit under C4.** BJ puts it too early: for v = 1, median 2.0 years against a true 3.5; for v = 3, 2.0 against 2.5.

Report: the new last section of `reports/phase2_results.md`. Lesson 11. Summary output: `results/summary_phase2_20261023.txt`; tables in `reports/tables/10_*.csv` and `11_weight_checks.csv`.

## 31 October 2026: review corrections and exploratory runs

The review of Phase 2 (Steps 2a and 2b, issue #1) found claims the numbers did not support. Reported numbers stand. Entries above stay as written, as history, and some of their wording is superseded by:

- `reports/phase2_results.md`: corrected claims, and the section "Corrections, disclosures and checks after review". This includes the condition for AIPCW's consistency, and that the source of the large errors is not established.
- `docs/lessons/10_phase2_results.md` and `11_which_model_to_trust.md`: the same corrections.
- `docs/exploratory_prespecification.md`: Runs A, B and C, exploratory, with expected directions and a decision rule fixed before any full run.

Full runs at commit `da5c483`, 3 workers, 200 hospitals, finished at 22:55. All 30 controls were exactly 0 and no hospital failed. Predictions: AIPCW and BJ in C5a held; BJ in C5b held; AIPCW and IPCW in C5b not determined; IPCW in C5a reported without a decision, as fixed in advance. No floor was chosen. The floor of 0.05 never applied in Run B. Results are in the section "Exploratory runs" of `reports/phase2_results.md`, tables in `reports/tables/15_*`, chunks in `results/exploratory/`, and the final smoke test in `results/exploratory_smoke_final/`.

Checked and accepted at commit `cfd8b88`, then merged into `main` without squashing on 1 November 2026. Lesson 12 added.

## 5 November 2026: checks before the repository is made public

- **δ = 0.05 departs from the plan.** The plan set δ = 0.01 and 0.02 for time to benefit; the reports use δ = 0.05. This is disclosed in `reports/phase2_results.md` and now also stated in lesson 7 and the README.
- **Files moved to archives, unchanged:** `results/summary_phase2.txt`, `summary_phase2_partial.txt`, the run logs `run_C0.log` to `run_C3.log`, `run_log_20261023.txt`, `run_sl05.log` and `run_sl20.log`, and `results/exploratory_smoke/`, into `results/archive/`; `reports/phase2_preliminary.md` into `reports/archive/`. `results/README.md` labels the folders that remain.
- **Wording corrected** in the reports, lessons and this log: neutral wording, claims and numbers checked against the tables, and consistent terms (median bias, bias-eliminated coverage, nuisance models). No reported table or saved result changed. Entries above that the review superseded are marked inline.
- **Printed slips corrected** against the saved tables: C1 IPCW coverage 92%, BJ in C1 85%, C2 AIPCW bias-eliminated coverage 93.1, SDs 0.149 and 0.173, lesson 7's −0.19, the reference-check figure (1.4 × 10⁻¹⁴ over 7 runs on 5 datasets), and the Phase 1 small-trial MCSE (0.017). A sentence that traced to no table (truncated AIPCW moved by at most 0.0011) was replaced by the traced value.
- **Citations:** the arXiv version is now given with page citations of Dahabreh et al.; full references are in the README and the report. In `docs/exploratory_prespecification.md` only the citation changed (Pawel et al. 2023, with a reference added). The pre-specification keeps its original terms (for example "median-based bias" and "coverage of the median estimate") as a dated record of what was fixed before the runs.
- **Safeguards in the summary scripts:** they stop if the number of hospitals is not as expected; the compensator integration check uses a relative error; figures use the Cairo PNG device. No output changed.
