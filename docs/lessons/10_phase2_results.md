# Lesson 10: what dropout did, in the end

Goes with `reports/phase2_results.md`.

## The short version

- **No dropout:** all methods agree. Good.
- **Each simple fix fails somewhere.** Counting dropouts as event-free fails when dropout is random. Dropping them fails when frail and treated patients leave sooner. Each looked fine in the other setting, because its errors in the treated and untreated arms happened to cancel. So passing one test proves little.
- **Weighting fixes the bias but can explode.** When frail treated patients almost all leave, the few who stay get enormous weights (one stood in for thousands). One patient's outcome then swings the whole curve.
- **AIPCW, the method with two safety nets, was the steadiest weighting method,** and kept its bias low even with a wrong dropout model.
- **Its 95% intervals were too narrow with a wrong dropout model** (80% coverage). The safety net protects the estimate, not the interval.

## Why weights explode: two weights multiplied

A trial patient's pseudo-outcome is multiplied by:

1 ÷ (chance of joining the trial) × 1 ÷ (chance of their arm) × 1 ÷ (chance of still being followed)

A frail treated patient might have a 0.01 chance of joining, 0.5 of their arm, and 0.01 of staying. The product is 20,000. Truncation, which never lets the chance of staying fall below 0.05, cut the last factor to at most 20. But 1 ÷ (0.01 × 0.5) × 20 is still 4,000. That is why truncation helped but did not cure it.

This has a name: a **practical positivity** problem. Some kinds of patients are almost never in the data you need. No formula can recover information that is not there; it can only spread the damage less badly.

## Time to benefit, by profile

With a trial of 500, even with no dropout, a single trial put a profile's time to benefit within half a year of the truth only a third to a half of the time. The answer from one trial is rough, not a point. Dropping the dropouts made it worse: it delayed the estimated time to benefit by one to one and a half years under dependent dropout. AIPCW kept it on target.

For a prescriber this matters. A profile-specific time to benefit from one trial should come with its uncertainty, and the way dropout is handled can shift it by a year.

## Check yourself

1. Why can "count dropouts as event-free" look fine in one setting and fail in another?
2. A patient has a 0.02 chance of joining the trial, was treated (0.5), and had a 0.05 chance of staying. What is the combined weight?
3. AIPCW's estimate stayed right with a wrong dropout model, but its intervals did not. In one sentence, why?
