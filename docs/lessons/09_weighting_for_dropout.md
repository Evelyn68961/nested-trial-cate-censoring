# Lesson 9: weighting for dropout, and a second safety net

Goes with Phase 2: estimators IPCW and AIPCW in `R/phase2_estimators.R`.

## The idea you already know

In lesson 3, trial patients were weighted by 1 ÷ (chance of joining the trial), so they stood in for the eligible patients who did not join.

Dropout uses the same idea. Weight each patient whose status at t is known by:

1 ÷ (chance of still being followed at that time)

A frail treated patient who stayed, when similar patients often leave, gets a large weight. They stand in for the similar patients who left. This is **IPCW**: inverse probability of censoring weighting. "Censoring" is the statistical word for losing track of a patient.

The chance of still being followed comes from a **dropout model**: a Weibull regression of dropout time on treatment and patient characteristics, fitted in the trial.

## The weakness of IPCW

IPCW is right only if the dropout model is right. In C3 the dropout model leaves out frailty, which is exactly what drives dropout. The weights then stand in for the wrong patients.

## AIPCW: the second safety net

AIPCW (augmented IPCW) adds one more piece. For each patient who left, an **outcome model** predicts how likely they were to have the event by t, given that they were event-free when they left. The outcome model is a Weibull regression in each arm.

As coded, AIPCW is consistent if the outcome model is right, or if the participation and dropout models are both right.

- If the participation and dropout models are both right, the weights do the work and the extra piece averages out.
- If the outcome model is right, the extra piece does the work and the errors in the weights average out.

So the method now has two double-robust layers:
- **who joined the trial:** the participation model or the outcome model;
- **who stayed in it:** the dropout model or the outcome model.

## What the tests showed

In a simulated hospital of 600,000 patients with the true helper values, among treated trial patients at year 3, the average augmented status matched the true risk within the test's limit of 3 Monte Carlo standard errors plus 0.002 (a fixed 0.01 until dropout was strengthened; `docs/LOG.md`):
- with both helpers right;
- with the outcome model replaced by one that ignores every patient characteristic;
- with the dropout model replaced by one that gives everyone the same dropout rate.

With both wrong, it missed.

## What to expect from the runs

Expected before the runs:

| Setting | CC | NE | IPCW | AIPCW |
|---|---|---|---|---|
| C0 no dropout | right | right | right | right |
| C1 random | biased | biased | right | right |
| C2 dependent | biased | biased | right | right |
| C3 dropout model wrong | biased | biased | biased | right (outcome model is right) |

The runs test whether this holds with fitted models, not just in theory. The results go in report 10.

## Check yourself

1. What do the weights in lesson 3 and the weights in IPCW have in common?
2. In C3, why might IPCW be biased while AIPCW is not?
3. What would make AIPCW fail?
