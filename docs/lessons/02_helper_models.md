# Lesson 2: the three helper models

Goes with step 2: `R/nuisance.R`, `scripts/02_check_helpers.R`.

## Where we are

We want the drug's effect for each value of v, among all 2,500 patients. Lesson 1 showed that the trial alone overstates the benefit, because the trial is short of frail patients.

The paper's method starts by fitting three helper models. The paper calls them "nuisance functions". "Nuisance" only means that we need them on the way but do not report them.

## The three helpers, as three questions

**1. Who joins the trial?**
Fitted on all 2,500 patients, because we know who joined and who did not. It gives each patient a chance of joining, based on frailty, v and sex.

In one hospital the smallest chance was 0.007 (`reports/tables/02_helper_errors.csv`). That patient resembles almost nobody in the trial. Remember this patient: in lesson 3, patients like this get very large weights.

**2. Who got the drug inside the trial?**
A coin decided, so the answer is 0.5 for everyone. The paper still fits a simple model for it, and so do we.

**3. What is the risk with the drug, and without it?**
Fitted on trial patients only, separately in the treated and the untreated arm. Then it is used on all 2,500 patients. Every patient gets two predicted risks: with the drug (`g1`) and without it (`g0`). The difference `g1 − g0` is the predicted effect for that patient.

## What the numbers show

The outcome model alone already gives an estimate: average `g1 − g0` over the patients with a given v. We tried this for v near 2, in 200 simulated hospitals (printed by `scripts/02_check_helpers.R`; not saved in a table):

| Averaged over | Mean of 200 hospitals | Truth |
|---|---|---|
| All eligible patients | −0.088 | −0.085 (target) |
| Trial patients only | −0.151 | −0.148 (trial) |

So when the outcome model is applied to the 2,000 non-trial patients, it lands on the target, not on the trial's value. This is how the non-trial patients help: they bring the right mix of frail and not frail people, even without outcomes.

Two warnings come with it:

- **One hospital is very noisy.** Single hospitals ranged from −0.24 to +0.05. The average over 200 is right; any one hospital can be far off.
- **Predictions are worst for the patients least like the trial.** In `reports/figures/02_outcome_model_vs_truth.png`, the blue points (trial patients) sit close to the grey line, which marks a perfect prediction. The red points (non-trial patients) scatter much more. The model learned from healthier patients and is guessing about frail ones.

The right panel shows the same with Super Learner, which was not told the right formula. In real data nobody knows the right formula, so this is the realistic case.

## So why not stop at the outcome model?

The outcome model gets the right answer only if the model itself is right. In real data you never know whether it is. Lesson 3 adds a correction that uses helpers 1 and 2 to repair the outcome model's errors. That correction is the heart of the paper's method.

## Two techniques used in this step

**Cross-fitting.** Think of it as never grading your own exam. Patients are split into five groups. To make predictions for group 1, the models are fitted on groups 2 to 5 only; and so on for each group. No patient's own outcome is used to make that patient's predictions.

Why it matters: a flexible model can memorise noise in the patients it was trained on. Its predictions for those same patients would then look better than they really are. One of the tests flips the outcomes of the trial patients in group 1 and checks that group 1's predictions do not change. They do not.

**Super Learner.** It tries three methods on the same data: ordinary logistic regression, a smooth-curve model (generalized additive model) and a random forest. It checks how well each predicts patients it was not trained on, and blends them according to that. The paper uses the same approach with a larger set of methods. It takes about 11 seconds per hospital, against 0.1 seconds for plain logistic regression. We will use plain logistic regression for fast checks and Super Learner for the main runs.

## Check yourself

1. Which helper is fitted on all 2,500 patients, and why can it be?
2. Why are the outcome model's predictions worse for the patients who did not join the trial?
3. In one sentence: what does cross-fitting protect against?
