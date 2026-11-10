# Lessons 5 and 6: judging a method, and why the shortcuts fail

Goes with steps 6 and 7: `R/estimators.R`, `scripts/07_run_phase1.R`, `scripts/08_summarise_phase1.R`, and `reports/phase1_results.md`.

## Lesson 6 first: how a method is judged

One dataset tells you almost nothing (lesson 4). So we ran 500 simulated datasets and asked three questions at each of the 37 values of v:

- **Bias:** on average over the 500 datasets, how far is the estimate from the truth? A method with no bias is right on average, even if each dataset is noisy.
- **RMSE** (root mean squared error): how far is a typical single dataset's estimate from the truth? It combines bias and noise.
- **Coverage:** of the 500 intervals labelled "95%", how many contain the truth? An honest method gets close to 95%.

"Integrated" means averaged over the 37 values of v, as in the paper's Table 1.

## The result

| Method | Bias | RMSE | Coverage |
|---|---|---|---|
| P the paper's method | 0.020 | 0.099 | 92% |
| L linear regression on V | 0.060 | 0.097 | 81% |
| T trial-only estimator | 0.056 | 0.095 | 85% |
| G outcome model-based estimator | 0.028 | 0.074 | — |

## Lesson 5: why each shortcut fails

**T, trial-only estimator.** It answers a different question: the effect in the trial's healthier patients. Its bias of 0.056 comes from the gap of lesson 1. Its intervals cover its own trial curve 90% of the time and the hospital's 85%. This is the paper's main point in one line: a trial-only answer can be precise and still wrong for the people you treat.

**L, linear regression on V.** The true curve bends: harm at both ends of v, benefit in the middle. A straight line cannot bend, so it is wrong at the ends and the middle in opposite directions. More patients would not fix that; it is the wrong shape.

**G, outcome model-based estimator.** It is the most precise, with the lowest RMSE, because it has no noisy correction term. But it is only as good as the outcome model:
- in the pilot, with the right terms given, its bias was 0.007;
- with Super Learner, which has to find the terms itself, its bias rose to 0.028.

In real data you never know whether you have the right terms. The paper's method gives up some precision to be protected against that.

## What is left in the error of the paper's method

The bias of the paper's method (0.020) is not zero. It comes from smoothing: the curve is drawn with wide windows, which flattens the dip and the rises (lesson 4). The paper reports the same size of bias and coverage just under 95%, and names bias correction as future work. Our numbers are similar to the paper's. The direct check is the match to Robertson et al.'s code (lesson 4).

## Check yourself

1. Which is worse for a prescriber: a method with small bias but large RMSE, or one with small RMSE but large bias? Why?
2. Why would T's bias not shrink with a bigger trial?
3. G had the lowest RMSE. Why is it still not the method to use?
