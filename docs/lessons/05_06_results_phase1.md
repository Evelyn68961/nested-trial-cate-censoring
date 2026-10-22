# Lessons 5 and 6: judging a method, and why the shortcuts fail

Goes with steps 6 and 7: `R/estimators.R`, `scripts/07_run_phase1.R`, `scripts/08_summarise_phase1.R`, and `reports/phase1_results.md`.

## Lesson 6 first: how a method is judged

One hospital tells you almost nothing (lesson 4). So we ran 500 simulated hospitals and asked three questions at each of the 37 values of v:

- **Bias:** on average over the 500 hospitals, how far is the estimate from the truth? A method with no bias is right on average, even if each hospital is noisy.
- **RMSE** (root mean squared error): how far is a typical single hospital's estimate from the truth? It combines bias and noise.
- **Coverage:** of the 500 intervals labelled "95%", how many contain the truth? An honest method gets close to 95%.

"Integrated" means averaged over the 37 values of v, as in the paper's Table 1.

## The result

| Method | Bias | RMSE | Coverage |
|---|---|---|---|
| P the paper's method | 0.020 | 0.099 | 92% |
| L straight line | 0.060 | 0.097 | 81% |
| T trial patients only | 0.056 | 0.095 | 85% |
| G outcome model alone | 0.028 | 0.074 | — |

## Lesson 5: why each shortcut fails

**T, trial patients only.** It answers a different question: the effect in the trial's healthier patients. Its bias of 0.056 is the gap from lesson 1. Its intervals are honest for the trial's own curve (90%) but miss the hospital's curve. This is the paper's main point in one line: a trial-only answer can be precise and still wrong for the people you treat.

**L, straight line.** The true curve bends: harm at both ends of v, benefit in the middle. A straight line cannot bend, so it is wrong at the ends and the middle in opposite directions. More patients would not fix that; it is the wrong shape.

**G, outcome model alone.** It is the most precise, with the lowest RMSE, because it has no noisy correction term. But it is only as good as the outcome model:
- in the pilot, with the right terms given, its bias was 0.007;
- with Super Learner, which has to find the terms itself, its bias rose to 0.028.

In real data you never know whether you have the right terms. The paper's method gives up some precision to be protected against that.

## What is left in the paper's method's error

The paper's method's bias (0.020) is not zero. It comes from smoothing: the curve is drawn with wide windows, which flattens the dip and the rises (lesson 4). The paper reports the same size of bias and coverage just under 95%, and names bias correction as future work. Our numbers match the paper's (0.020 and 92%) closely, which is the best evidence that the rebuild is right.

## Check yourself

1. Which is worse for a prescriber: a method with small bias but large RMSE, or one with small RMSE but large bias? Why?
2. Why would T's bias not shrink with a bigger trial?
3. G had the lowest RMSE. Why is it still not the method to use?
