# Lesson 7: effects that grow over time

Goes with Phase 2: `config/phase2.yaml`, `R/phase2_generate.R`, `R/phase2_truth.R`.

## From yes/no to "when"

In Phase 1 each trial patient had one yes/no outcome: did the bad event happen? Now each patient has an event time: when did it happen?

The question is no longer only "does the drug help?" but "by when does it help, and for whom?"

## The new target

For each follow-up time t (0.5, 1, 1.5 … 5 years) and each profile v:

risk of the event by t if treated − risk of the event by t if not treated

among all eligible patients with that v. It is the Phase 1 curve, drawn again at ten follow-up times. You can picture it as a surface: profile along one side, time along the other.

## How the simulation makes the benefit grow

Event times come from Weibull models. The drug changes two things:

- the overall event rate, by an amount that depends on v and frailty (as in Phase 1);
- the **shape**: 1.3 without the drug, 1.0 with it. A smaller shape means the drug's advantage grows with time. Early on the two arms look alike; later they separate.

## What the true effects look like

Among all eligible patients (risk difference; negative means fewer events with the drug):

| Profile | Year 1 | Year 3 | Year 5 |
|---|---|---|---|
| v = 0.2 | +0.11 (harm) | +0.11 | +0.05 |
| v = 1 | +0.03 | −0.04 | −0.13 |
| v = 2 | 0.00 | −0.13 | −0.24 |
| v = 3 | +0.03 | −0.10 | −0.19 |
| v = 3.8 | +0.17 (harm) | +0.05 | −0.05 |

## Time to benefit, for each profile

Time to benefit is the first time at which the drug lowers the risk by at least some amount δ. The true times, on the half-year grid:

| Profile | δ = 0.05 (5 points) | δ = 0.10 (10 points) |
|---|---|---|
| v = 0.2 | not within 5 years | not within 5 years |
| v = 1 | 3.5 years | 4.5 years |
| v = 2 | 2.0 years | 3.0 years |
| v = 3 | 2.5 years | 3.5 years |
| v = 3.8 | not within 5 years | not within 5 years |

The plan set δ = 0.01 and 0.02. The reports use δ = 0.05, a departure from the plan; see the Disclosures in `reports/phase2_results.md`.

Trial data reconstructed from published Kaplan–Meier curves carry no patient characteristics, so they can give time to benefit only by baseline risk. A nested trial carries the characteristics, so time to benefit can be given by profile.

## Check yourself

1. In one sentence: what does the Weibull shape control in this simulation?
2. Why can a nested trial give time to benefit by profile, when reconstructed Kaplan–Meier data cannot?
3. Patients with v = 0.2 never reach a 5-point benefit by year 5. What would you tell a prescriber about them?
