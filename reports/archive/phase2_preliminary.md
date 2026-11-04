# Phase 2: preliminary results (50 hospitals per setting)

> **Superseded** by `reports/phase2_results.md` (200 hospitals per setting, stronger dependent dropout, truncated weights). Kept for the record.
>
> Moved to `reports/archive/` on 5 November 2026. The tables and figures it points to (`reports/tables/10_*.csv`, `reports/figures/10_C*_effect_over_time.png`) now hold the 200-hospital results, so they do not match the numbers below.

22 October 2026, 17:00. Runs finished 16:46 to 17:00, shortly before the computer's scheduled shutdown. **Preliminary:** 50 hospitals per setting is too few to separate methods whose errors differ by about 0.01. Full tables: `reports/tables/10_phase2_by_time.csv` and `10_phase2_time_to_benefit.csv`. Figures: `reports/figures/10_C*_effect_over_time.png`.

## Error at 5 years, when dropout has accumulated most

Integrated absolute bias against the true target curve, and coverage of the 95% intervals:

| Setting | CC (drop them) | NE (count as event-free) | IPCW | AIPCW |
|---|---|---|---|---|
| C0 no dropout | 0.027, 89% | 0.027, 89% | 0.027, 89% | 0.026, 89% |
| C1 random dropout (26%) | 0.018, 92% | **0.061, 79%** | 0.027, 91% | 0.022, 91% |
| C2 dependent dropout (20%) | 0.036, 89% | 0.033, 89% | 0.038, 92% | **0.025, 91%** |
| C3 as C2, dropout model wrong | 0.036, 89% | 0.033, 89% | 0.023, 93% | 0.023, 89% |

## What can and cannot be read from this

- **C0 is right:** with no dropout, all four methods agree, as they must. The error of about 0.026 is the smoothing error seen in Phase 1.
- **NE fails clearly under random dropout:** counting a quarter of patients as event-free understates risk, and the error grows with follow-up (0.019 at year 2, 0.061 at year 5).
- **Under dependent dropout, AIPCW has the smallest error at year 5** (0.025, against 0.033 to 0.038). The difference is close to the Monte Carlo noise at 50 hospitals (about 0.01), so it is a lead, not a result.
- **IPCW did not fail in C3**, as the plan expected it to. The likely reason is the same as in the first Phase 1 pilot: the design is too mild. Only 20% drop out, and frailty's pull on dropout (0.7 on the log scale) is modest. Leaving frailty out of the dropout model then changes the weights little. IPCW's own outcome model also includes frailty, which may absorb part of the error. **This needs a stronger dependent-dropout setting before any conclusion.**
- **IPCW is the noisiest method** (RMSE 0.164 at year 5 in C2), because weights of 1 ÷ (chance of staying) inflate the scatter. AIPCW is less noisy.

## Next steps

1. Strengthen dependent dropout, for example frailty 1.5 and treated 1.0 on the log scale, with a higher base rate so about 35–40% drop out. Compare candidate settings first, as was done for Phase 1. Record the change in `docs/LOG.md`.
2. Rerun C0 to C3 with at least 200 hospitals each.
3. Then judge Gate 2: C0 reproduces Phase 1 at every time; the weighted methods have small bias in C1 and C2; AIPCW holds in C3 while IPCW does not.
