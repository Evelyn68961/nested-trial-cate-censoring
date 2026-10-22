# Lesson 3: the pseudo-outcome, the heart of the method

Goes with step 3: `R/pseudo.R`, `scripts/03_check_pseudo_outcome.R`.

## The problem left by lesson 2

Lesson 2 showed that the outcome model alone gets the right answer only if the model is right. In real data you cannot check that. The paper's method adds a correction that protects you when the outcome model is wrong.

## The recipe

Every patient gets one number, the pseudo-outcome:

- **Patients outside the trial:** the predicted effect, `g1 − g0`. Nothing else.
- **Trial patients:** the predicted effect, plus a correction:

  correction = weight × (what actually happened − what the model predicted)

  weight = 1 ÷ (chance of joining the trial × chance of the arm they were in)

  The correction is added for treated patients and subtracted for untreated ones, because the effect is "treated minus untreated".

## A worked example

A treated trial patient who had the event (y = 1). Chance of joining 0.2; chance of treatment 0.5; so the weight is 1 ÷ (0.2 × 0.5) = 10. The outcome model predicted a risk of 0.30 with the drug and 0.40 without, so the predicted effect is −0.10.

pseudo-outcome = 10 × (1 − 0.30) + (−0.10) = 6.9

An untreated trial patient with the same numbers who also had the event:

pseudo-outcome = −10 × (1 − 0.40) + (−0.10) = −6.1

A patient outside the trial with the same predictions: −0.10.

Single pseudo-outcomes like 6.9 mean nothing on their own. Only averages over many patients mean something. One of the tests checks these exact numbers.

## Why the weight is 1 ÷ (chance of joining)

A patient with a 0.2 chance of joining stands for five similar eligible patients: themselves and four who did not join. A patient with a 0.007 chance stands for about 140. The weight makes the trial patients, taken together, look like the whole hospital again. That is how the correction "knows" about the frail patients the trial is short of.

## The key property: either helper can be wrong, but not both

If the outcome model is wrong, its mistakes show up in the trial patients as residuals (actual minus predicted). The weighted residuals add those mistakes back, in the right mix for the whole hospital. So a wrong outcome model is repaired, as long as the participation model is right.

If the participation model is wrong but the outcome model is right, the residuals are just noise around zero. Wrong weights on noise still average to zero. So no harm is done.

If both are wrong, nothing repairs the error.

This is called **double robustness**: two chances to be right.

## What the simulation shows

Step 3 fitted the helpers in 200 hospitals with the right terms, or with one term left out on purpose. The "wrong" outcome model leaves out frailty. The "wrong" participation model gives everyone the same chance of joining. The table shows the error in the average effect over all eligible patients (estimate minus truth; the truth is +0.003, because harm at the ends of v and benefit in the middle nearly cancel).

| Helper models | Outcome model alone | With the correction |
|---|---|---|
| Both right | 0.001 | 0.000 |
| Outcome model wrong | −0.069 | 0.005 |
| Participation model wrong | 0.001 | 0.001 |
| Both wrong | −0.069 | −0.072 |

Read the second row: the outcome model alone is off by 0.069 (it leans toward the trial's healthier patients), and the correction removes that error. In the last row, both helpers are wrong and the error stays.

## The price

The correction adds noise. With both helpers right, the estimate varied across hospitals with a standard deviation of 0.058 with the correction, against 0.049 for the outcome model alone. The method trades some precision for protection against a wrong model. Trial patients with tiny chances of joining make it worse, because their weights are huge.

## What this lesson does not cover yet

So far we averaged over all patients. We want a curve: one effect for each v. Lesson 4 draws that curve through the pseudo-outcomes.

## Check yourself

1. Why do patients outside the trial get only the predicted effect?
2. A trial patient had a 0.05 chance of joining and was treated (chance 0.5). What is their weight?
3. In one sentence: why does a wrong participation model do no harm when the outcome model is right?
