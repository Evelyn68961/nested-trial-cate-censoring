# Lesson 11: which model to trust

Goes with the last section of `reports/phase2_results.md`.

## The short version

- **There are two ways to deal with a patient who dropped out.** Reweight the patients who stayed (IPCW), or fill in the dropout's likely outcome from a model (Buckley-James, BJ). AIPCW does both.
- **Filling in is stable; reweighting is not.** Under dependent dropout, BJ broke in 1 hospital of 200; IPCW in 92 and AIPCW in 50. So the explosions in lesson 10 came from the dropout weight, not from the trial-joining weight.
- **But filling in trusts the outcome model completely.** With an outcome model that leaves out frailty, BJ was biased, and it put time to benefit 1.5 years too early for one profile.
- **AIPCW survived each wrong model in the typical hospital,** which is what "doubly robust" promises. It did not stop the explosions.
- **A simple check of the weights catches a wrong dropout model, but not a broken curve.**

## Filling in, in one example

A treated patient leaves the study at year 2, event-free. We want their status at year 5.

- **IPCW** drops them and gives extra weight to similar patients who stayed. If almost nobody like them stayed, the few who did carry huge weights.
- **BJ** keeps them and writes in a number instead of a 0 or 1: the outcome model's chance that someone like them, event-free at year 2, has the event by year 5. Say 0.3. No weight is needed, so nothing explodes.
- **AIPCW** reweights, then corrects with the filled-in value. If either the weights or the filled-in value is right, the answer is right.

BJ is AIPCW with the chance of staying set to 1 for everyone. That is how it is coded (`use_dropout_model = FALSE` in `augmented_status()`).

## Why BJ goes wrong with a wrong outcome model

The patients who leave are mostly frail and treated. A model without frailty thinks they are average, so it fills in too low a risk for them. The treated arm then looks better than it is, and the curve crosses the benefit threshold too soon.

## Why BJ's intervals are too narrow

A filled-in 0.3 is less variable than the real 0 or 1 it replaces. The interval formula treats the filled-in values as if they had been observed, so it thinks the data are more certain than they are. Coverage was 72% with the right model. This is the likely reason; it has not been proved here.

## What the weight checks can and cannot do

Each kind of weight should average about 1 over all eligible patients.

- **When the dropout model was wrong (C3),** the combined weights averaged about 0.75 to 0.85 in almost every hospital. So the check works as a test of the dropout model.
- **When the curve broke,** no rule picked out those hospitals. The effective-sample-size rule caught most broken ones, but also flagged most of the unbroken ones. It tells you the design is fragile, not which result is wrong.

## Check yourself

1. In one sentence, what does BJ do with a patient who dropped out?
2. Why did BJ not break in C2, when IPCW did?
3. In C4, why did a wrong outcome model make the drug's benefit appear sooner?
4. The combined weights average 0.75. What does that suggest, and what does it not tell you?
