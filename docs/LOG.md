# Process log

What was decided, changed and checked, in order, with the reason for each. Newest entries at the bottom of each day. Commits are short hashes in this repository.

---

## 2026-10-22

### Setup

- **Language: R only.** The paper's software (Super Learner) is in R and the reference code is in R.
- **Repository private** until Gate 2 passes (Phase 2 checks). Nothing goes public before the results have been checked.
- **Raw results are not committed** (`results/` is in `.gitignore`). Summary tables and figures in `reports/` are committed.

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
