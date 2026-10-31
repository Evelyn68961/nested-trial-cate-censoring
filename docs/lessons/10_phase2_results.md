# Lesson 10: what dropout did, in the end

Goes with `reports/phase2_results.md`.

## The short version

- **No dropout:** CC, NE and IPCW agree exactly, and the Weibull-based methods almost exactly. Good.
- **Each simple fix fails somewhere.** Counting dropouts as event-free fails when dropout is random. Dropping them fails when frail and treated patients leave sooner. Counting them as event-free looked fine under dependent dropout because its errors in the two arms cancelled there. Dropping them looked fine under random dropout because nothing links random leaving to the outcome. So passing one test proves little.
- **Weighting lowers the median-based bias, but large errors remain.** When frail treated patients almost all leave, the few who stay get enormous weights (one stood in for thousands). 92 (IPCW) and 50 (AIPCW) of 200 hospitals had an absolute error above 0.5.
- **AIPCW had fewer hospitals above 0.5 than IPCW under dependent dropout,** though not in every setting, and its bias stayed low with a wrong dropout model. Several of these rankings are not resolved at 200 hospitals.
- **Its 95% intervals were too narrow with a wrong dropout model** (80% coverage). Removing the bias does not close most of that gap, and why the intervals are too narrow is not established.

## Two weights multiplied

A trial patient's pseudo-outcome is multiplied by:

1 ÷ (chance of joining the trial) × 1 ÷ (chance of their arm) × 1 ÷ (chance of still being followed)

A frail treated patient might have a 0.01 chance of joining, 0.5 of their arm, and 0.01 of staying. The product is 20,000. Truncation, which never lets the chance of staying fall below 0.05, cut the last factor to at most 20. But 1 ÷ (0.01 × 0.5) × 20 is still 4,000. That may be why 27 to 83 hospitals still had an absolute error above 0.5 after truncation, though the source of the large errors is not established.

This has a name: a **practical positivity** problem. Some kinds of patients are almost never in the data you need. No formula can recover information that is not there.

## Time to benefit, by profile

With a trial of 500, even with no dropout, a single trial put a profile's time to benefit within half a year of the truth only a third to a half of the time. The answer from one trial is rough, not a point. Dropping the dropouts made it worse: it delayed the estimated time to benefit by one to one and a half years under dependent dropout. Truncated AIPCW's median was on target at v = 2 and 3, and half a year early at v = 1.

For a prescriber this matters. A profile-specific time to benefit from one trial should come with its uncertainty, and the way dropout is handled can shift it by a year.

## Check yourself

1. Why can "count dropouts as event-free" look fine in one setting and fail in another?
2. A patient has a 0.02 chance of joining the trial, was treated (0.5), and had a 0.05 chance of staying. What is the combined weight?
3. AIPCW's median-based bias stayed small with a wrong dropout model, but its intervals undercovered. What would you check to see whether bias explains that?
