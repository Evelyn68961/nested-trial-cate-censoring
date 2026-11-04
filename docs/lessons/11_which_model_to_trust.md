# Lesson 11: which model to trust

Goes with the last section of `reports/phase2_results.md`.

## The short version

- **There are two ways to deal with a patient who dropped out.** Reweight the patients who stayed (IPCW), or fill in the dropout's likely outcome from a model (Buckley-James, BJ). AIPCW does both.
- **Filling in had far fewer large errors than reweighting.** Under dependent dropout, 1 hospital of 200 had an absolute error above 0.5 for BJ; 92 for IPCW and 50 for AIPCW. So most of the large errors in lesson 10 need the dropout weight. The two weights multiply, though, so this does not clear the trial-joining weight, and the source of the large errors is not established.
- **But filling in trusts the outcome model completely.** With an outcome model that leaves out frailty, BJ was biased, and it put time to benefit 1.5 years too early for one profile.
- **AIPCW's median-based bias stayed small under each wrong model taken alone.** That is the direction the theory predicts: it is consistent if the outcome model is right, or if the participation and dropout models are both right. Large errors remained.
- **A simple check of the weights catches a wrong dropout model, but not a hospital with large errors.**

## Filling in, in one example

A treated patient leaves the study at year 2, event-free. We want their status at year 5.

- **IPCW** drops them and gives extra weight to similar patients who stayed. If almost nobody like them stayed, the few who did carry huge weights.
- **BJ** keeps them and writes in a number instead of a 0 or 1: the outcome model's chance that someone like them, event-free at year 2, has the event by year 5. Say 0.3. No dropout weight is needed.
- **AIPCW** reweights, then corrects with the filled-in value. It is consistent if the filled-in value's model is right, or if the participation and dropout weights are both right.

BJ is AIPCW with the chance of staying set to 1 for everyone. That is how it is coded (`use_dropout_model = FALSE` in `augmented_status()`).

## Why BJ goes wrong with a wrong outcome model

A possible reason, not tested here: the patients who leave are mostly frail and treated. A model without frailty thinks they are average, so it fills in too low a risk for them. The treated arm then looks better than it is, and the curve crosses the benefit threshold too soon.

## Why BJ's intervals are too narrow

A filled-in 0.3 is less variable than the real 0 or 1 it replaces. The interval formula treats the filled-in values as if they had been observed, so it thinks the data are more certain than they are. Coverage was 72% with the right model, and removing the bias only brings it to about 76% (75.6%, coverage of the median estimate; `reports/tables/14_center_coverage_phase2.csv`). This is one candidate reason; it has not been shown here.

## What the weight checks can and cannot do

Each kind of weight should average about 1 over all eligible patients.

- **When the dropout model was wrong (C3),** the middle 80% of hospitals had combined-weight means of 0.71 to 0.79 in the treated arm and 0.80 to 0.88 in the untreated arm (from the saved rows). In C3 the rule flagged 187 of 200 hospitals, against 73 with the right dropout model (C2). One kind of wrong dropout model was tested, so this shows the check can flag that kind, not every kind.
- **When a hospital's error was above 0.5,** no rule picked out those hospitals. The effective-sample-size rule caught most of them, but also flagged most of the others. It tells you the design is fragile, not which result is wrong.

## Check yourself

1. In one sentence, what does BJ do with a patient who dropped out?
2. Why might BJ have so few large errors in C2, when IPCW has many, and what does that not prove?
3. In C4, what is one possible reason a wrong outcome model made the drug's benefit appear sooner?
4. The combined weights average 0.75. What does that suggest, and what does it not tell you?
