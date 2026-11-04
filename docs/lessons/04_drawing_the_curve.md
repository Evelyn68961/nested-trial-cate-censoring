# Lesson 4: drawing the curve through the pseudo-outcomes

Goes with step 4: `R/smooth.R`, `scripts/04_check_curve.R`. Step 5 (`scripts/05_reference_check.R`) is covered at the end.

## Where we are

Every patient now has a pseudo-outcome (lesson 3). Averaged over many patients, pseudo-outcomes give the right effect. We want that average separately for each profile value v, as a curve.

## Why not just average patients with exactly v = 2?

Almost nobody has exactly v = 2. So we borrow from neighbours: patients with v = 1.9 or 2.1 tell us something about v = 2.

## Local linear smoothing, in plain steps

To estimate the effect at v = 2:

1. Take the patients whose v lies within a window around 2, say from 1.6 to 2.4. The half-width of the window (0.4 here) is the **bandwidth**.
2. Give each of them a weight: highest for v right at 2, falling to zero at the window's edge.
3. Fit a straight line through their pseudo-outcomes, using those weights.
4. Read the line's height at v = 2. That is the estimate.

Repeat at each of the 37 grid values from 0.2 to 3.8, and join the estimates into a curve.

Why a short straight line, and not just a weighted average? Near the edges (v close to 0 or 4), all neighbours lie on one side. A plain average would be pulled toward them. A line corrects for the slope.

## Choosing the bandwidth

A narrow window follows the data closely but is noisy. A wide window is smooth but can flatten real bends.

The bandwidth is chosen by **leave-one-out cross-validation**. For each candidate bandwidth: hide one patient, draw the curve from everyone else, and see how far the curve misses the hidden patient's pseudo-outcome. Do this for every patient and add up the misses. Pick the bandwidth with the smallest total. A shortcut formula gives the same answer without refitting 2,500 times, and a test confirms that it does.

## The intervals

Each estimate gets a 95% interval from the paper's "sandwich" formula. It measures how much the pseudo-outcomes scatter around the line inside the window. More scatter, or fewer patients in the window, gives a wider interval.

One subtlety the paper points out: the interval is centred on a smoothed version of the true curve, not the exact curve. Smoothing always flattens peaks and valleys. With a small bandwidth the difference is tiny; with a large one it is not. In one hospital (`scripts/04_check_curve.R`) the bandwidth was 2.0, half the whole range of v. At v = 2 the true curve is −0.085, but its smoothed version is only −0.032.

## What one hospital looks like

`reports/figures/04_one_hospital_curve.png` shows one hospital. The estimated curve is much flatter than the true one: at v = 2 it says +0.025 when the truth is −0.085. The intervals are wide, and all 37 contain the truth.

This is not a fault in the code. With 500 trial patients, some carrying weights above 100, one hospital simply cannot pin down a profile-specific curve. The paper reports the same level of error for the same sizes. Whether the method is right on average is answered by running hundreds of hospitals (step 7).

## Why the bandwidth is often large

The pilot runs found that cross-validation often picks the widest window allowed. The reason: the pseudo-outcomes are so noisy (some above 50) that every bandwidth predicts the hidden patient about equally badly. In the pilot, the cross-validation scores of the best and worst bandwidths differed by less than 0.1% (`docs/LOG.md`). When the scores are that flat, the choice is close to arbitrary and leans wide, and wide windows flatten the curve. This shows up later as a small but systematic error: too high where the curve dips, too low where it rises. The paper names this as a limitation and future work.

## Step 5: checking against someone else's code

Sarah Robertson, Jon Steingrimsson and Issa Dahabreh published R code for an earlier version of this method (2023). We ran their pseudo-outcome function on our hospitals, giving it our helper predictions. Their numbers and ours agree to 13 decimal places. So our step 3 is not just our own reading of the equation: it matches an independent implementation by the method's authors.

## Check yourself

1. What does the bandwidth control, and what goes wrong if it is too small or too large?
2. Why can one hospital's curve be far from the truth even though the method is correct?
3. What did the comparison with Robertson's code prove, and what did it not prove? (Hint: it checked the pseudo-outcome, not the curve-drawing step.)
