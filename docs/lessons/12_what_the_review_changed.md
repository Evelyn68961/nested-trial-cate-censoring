# Lesson 12: what the review changed

Goes with the sections "Corrections, disclosures and checks after review" and "Exploratory runs" of `reports/phase2_results.md`.

## The short version

- **The review changed no reported number.** It corrected claims the numbers did not support, and added disclosures.
- **A control checks the code before you trust a new result.** You run something whose answer you already know.
- **A second method, written separately, agreed on the true values.** Its standard deviation was far larger, because of a single replicate.
- **Coverage can be split into bias and interval width.** That helps you diagnose a problem. It does not validate the intervals.
- **Three exploratory runs followed.** No prediction failed, three held, and two could not be settled.
- **No floor was chosen, and several questions stay open.**

## Controls

A control is a run whose right answer is known before it starts. Here the known answer is a saved result. If new code is sent down a new path with the settings of an old run, it must give the old answer.

"Largest difference 0" means that, comparing the new estimates with the saved ones, the biggest gap anywhere was exactly 0. It was not just small. The 23 October rerun of the six methods gave this result, and so did every control in the exploratory runs.

Examples from those runs:

- A floor of 0 changes nothing, so each floor scheme at 0 must return the plain IPCW and AIPCW.
- A floor of 0.05 on G must return the truncated methods.
- The reported analysis, sent through the new code, must return the saved rows at 200 datasets.

What a control shows is narrow. It shows the new path did not change the old answer. It does not show the old answer is right, and it says nothing about settings the old runs never used.

## The second method, and replicate 161

A separate script was written without reading the estimators, and run on the same design. Its true values at t = 5 for v = 1, 2 and 3 agreed with the repository's to 4e-16, through a different integration routine. So both agree on what the right answer is.

At v = 1 in C2, the median bias was close: -0.010 for the repository and -0.012 for the script. The SD was not: 1.20 against 14.34.

One replicate explains most of that gap. Replicate 161 gave -201.5 at v = 1. SD squares each distance from the mean, so a single value that far out dominates it. Dropping that replicate takes the script's SD to 1.70, and dropping replicates 161 and 4 takes it to 0.52.

So SD is unreliable as a summary here. A number that one replicate of 200 can move this much tells you about that replicate, not the typical dataset. That is why the report leans on medians and on counts above 0.5.

The two did not agree everywhere. Signed median bias at v = 2 was -0.021 for the repository and 0.031 for the script. That difference of 0.05 is not explained.

## Three kinds of coverage

An interval can miss for two reasons: it sits in the wrong place (bias), or it is too narrow (width). Coverage of the exact target mixes the two.

Bias-eliminated coverage (Morris et al. 2019, who centre on the mean; here centred on the median) asks how often the interval contains the method's own median estimate. Bias is removed by construction, so what is left is about width.

| Setting, method | Exact | Bias-eliminated |
|---|---|---|
| C0 AIPCW, BJ | 89.2 | 92.5 |
| C2 CC | 68.1 | 92.5 |
| C2 BJ | 72.4 | 75.6 |
| C3 AIPCW | 79.9 | 84.0 |

- **CC in C2:** with bias removed, coverage climbs to 92.5%. Its shortfall is mostly bias.
- **BJ in C2 and AIPCW in C3:** they stay at 75.6% and 84.0%. Most of the shortfall remains, so it is not bias.

This is not validation. A method could be far from the truth and still score well here, because the check never looks at the truth. It sorts the problem into bias or width, and that is all.

## Runs A, B and C

These came after the first results were seen, so they are exploratory. Each cell below is a count of datasets of 200 with an absolute error above 0.5 at t = 5.

**Run A: floors.** Reported, with no floor, C2 had 92 for IPCW and 50 for AIPCW.

| Floor of 0.10 on | C2 IPCW | C2 AIPCW | C4 IPCW | C4 AIPCW |
|---|---|---|---|---|
| G alone | 72 | 19 | 73 | 48 |
| p alone | 58 | 29 | 59 | 51 |
| Product p G | 2 | 2 | 3 | 3 |

The bound on the product cut large errors the most, and it had a cost. AIPCW's coverage fell to 76.7% in C2 and 79.4% in C4. In C4, its median bias reached 0.063. Why was not tested.

**Run B: mild dropout.** 19.9% of trial patients dropped out, against 30% in C2. The floor of 0.05 never applied, so the truncated methods equal the plain ones exactly. Large errors fell but stayed: in C2m, 25 for IPCW and 14 for AIPCW. So an error above 0.5 does not need a dropout weight near the floor. This run does not separate the two weights.

**Run C: wrong participation model.** In C5a only the participation model is wrong. In C5b the outcome model is wrong too. AIPCW's median bias stayed small in C5a (0.023), yet 23 datasets remained above 0.5. A small median does not make an estimate stable.

## Pre-specified predictions

A pre-specified prediction is written down and committed before the runs, along with the rule for scoring it. Without that, it is easy to read a result as what you expected all along. That is also why the merge kept the history: it shows the rule came first.

The rule uses the change in median bias against C2 on the same seeds, its 95% interval, and a margin of 0.01.

| Prediction | Held if | Failed if | Otherwise |
|---|---|---|---|
| Stays consistent | upper limit below 0.01 | lower limit above 0.01 | not determined |
| Biased at n = 2,500 | lower limit above 0.01 | upper limit below 0.01 | not determined |

| Expected | Difference (95% interval) | Result |
|---|---|---|
| C5a: AIPCW stays consistent | 0.003 (-0.004, 0.008) | Held |
| C5a: BJ stays consistent | -0.001 (-0.004, 0.003) | Held |
| C5a: IPCW uncertain | -0.003 (-0.020, 0.011) | No decision, as fixed in advance |
| C5b: AIPCW biased | 0.021 (-0.002, 0.036) | Not determined |
| C5b: BJ biased | 0.047 (0.034, 0.060) | Held |
| C5b: IPCW biased | 0.005 (-0.018, 0.024) | Not determined |

"Not determined" is an honest result. AIPCW's difference in C5b is 0.021, above the margin, but its interval runs from below 0.01 to above it, so the rule cannot say. You report it as it stands, and you do not widen the margin afterwards. A prediction that fails is reported as failed.

"Held" is also limited. Every run uses one cohort size, 2,500, so whether a bias shrinks with more patients cannot be seen. "Stays consistent, held" means only that bias did not rise by 0.01 at this size.

## Why no floor is chosen

- **The floors were compared on the data they would be judged on.** Picking the best one afterwards would look like a finding, when it was a choice made after seeing the answer.
- **The answer depends on a setting you would not know in practice.** IPCW's median bias under the 0.10 bound on the product was 0.017 in C2 and 0.038 in C4. The outcome model is the difference, and in real data you cannot see whether it is right.
- **Truncation shifts the estimand.** Part of a truncated method's small bias is a change of target.
- **The rule was fixed in advance:** no floor is selected or called best anywhere.

## What "exploratory" lets you say

You can say what was measured, on this design, and with what uncertainty: "In C2 at t = 5, the bound on the product at 0.10 left 2 of 200 datasets with an absolute error above 0.5."

You cannot say a run confirms something, that a method or floor is best, or that a result holds beyond this design. Runs chosen after seeing results can suggest questions. They do not settle them.

## Still open

- **Why the intervals undercover.** The sandwich formula treats nuisance models as known, and for BJ treats filled-in values as observed. Both are candidates, not shown.
- **The source of the large errors.** The two weights multiply, and these runs involve both without separating them.
- **CC in C5b.** Its median bias fell to 0.021 from 0.091. The reason was not examined, so this does not show that CC improved.
- **Median bias at v = 2.** The repository and the script differ by 0.05, not explained.
- **Seed 145.** The same patient (1/G = 16,469.6) has a 30-step compensator error (against 3,000 steps) of 14.08 in C2 and 1.21 in C4. G is the same in both, so the difference comes from the outcome-model term; how was not examined.

## Check yourself

1. A control shows "largest difference 0". What does that show, and what does it not show?
2. One replicate of 200 moved the script's SD from 1.70 to 14.34 at v = 1. Why can one value do that to SD and not to the median?
3. CC in C2 has exact coverage of 68.1% and bias-eliminated coverage of 92.5%. BJ has 72.4% and 75.6%. What does each pair suggest, and why does neither validate the intervals?
4. A floor cuts datasets with an absolute error above 0.5 from 50 to 2 but coverage falls to 76.7%. Why is that a trade-off to describe and not a floor to choose?
5. A "biased" prediction gives a difference of 0.02 with an interval of -0.01 to 0.03. Is it held, failed or not determined under a margin of 0.01?
6. Why does it matter that the rule was committed before the runs?
