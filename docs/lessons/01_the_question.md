# Lesson 1: the question, with one imaginary hospital

Goes with step 1: `R/generate.R`, `R/truth.R`, `scripts/01_check_generator.R`.

## The hospital

A hospital has 2,500 patients who could all receive a new drug. The drug prevents a bad event, such as death within 10 years.

The hospital runs a randomized trial. It invites everyone, but only about 500 agree to join. A coin decides who gets the drug in the trial.

The other 2,000 patients do not join. We still know their age, frailty and other characteristics. We do not use their outcomes, because their doctors chose their treatment, not a coin.

## The characteristics

Each simulated patient has three:

- **frailty**: higher means frailer.
- **v**: a score from 0 to 4. This is the characteristic a doctor would look at when deciding to prescribe. In the paper's data analysis (CASS), V was the ejection fraction.
- **male**: 0 or 1.

## The question

For patients with a given score v, how much does the drug lower the risk, among all 2,500 patients and not only the 500 in the trial?

The answer is a curve: one risk reduction for each value of v. The paper calls it the conditional average treatment effect. "Conditional" means "for patients with this v".

## Why the trial alone gives the wrong answer

Two facts are built into the simulation:

1. Frail patients join the trial less often.
2. Frail patients benefit less from the drug.

So the trial is full of patients who benefit more than average. If you read the curve from the trial alone, the drug looks better than it is for the hospital's whole population.

Step 1 shows this with exact numbers. At v = 2:

| Who | Risk reduction |
|---|---|
| Trial patients | 14.8 percentage points |
| All 2,500 eligible patients (the truth we want) | 8.5 percentage points |

The figure `reports/figures/01_true_curves.png` shows both curves across all values of v. Below zero means the drug lowers the risk. The drug helps in the middle of v and harms at both ends: for all eligible patients, the risk goes up by 16 points at v = 0.2. The dashed curve (trial) lies below the solid one (everyone) at every v, so the trial makes the drug look better everywhere.

(These numbers changed on 22 October, after the first pilot run showed the original curve was too flat. See `docs/LOG.md`.)

## Why we simulate

In real data we never know the true curve, so we cannot tell whether a method is right. In a simulation we wrote the rules, so the true curve is known exactly. We then give a method only what a real analyst would have (characteristics for everyone, treatment and outcome for trial patients) and see how close it gets.

## What step 1 does

- `generate.R` creates one dataset: 2,500 patients, who joins the trial, the coin toss, and the outcomes.
- `truth.R` computes the two true curves exactly from the rules.
- The tests check that about 20% join, that the coin gives about half treated, that trial patients are less frail, and that the exact curves agree with a brute-force count over two million simulated patients.

## Check yourself

You understand lesson 1 if you can answer these in one or two sentences each:

1. Why are the 2,000 patients who did not join still useful, even though we do not use their outcomes?
2. Why does the trial overstate the benefit in this simulation?
3. What would happen to the gap between the two curves if frail patients joined the trial as often as anyone else?

Lesson 2 will explain how the paper's method uses the 2,000 non-trial patients to fix the gap.
