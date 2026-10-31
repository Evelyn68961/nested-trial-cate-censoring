# Notes on 14_smoothed_coverage_phase1.csv

**Do not use the smoothed coverage for T: 75.13 (sl_trial20) and 87.89 (sl_trial05).** They use the wrong target.

`scripts/14_check_smoothed_coverage.R` passes the all-eligible target curve through the smoother with v uniform. T is fitted on trial patients only, so its own target is the trial curve under the trial's distribution of v (`R/estimators.R`). The kernel and T's bandwidth match; the curve and the design do not. Neither value is interpreted anywhere.

The CSV is kept as written. P's values are correctly built. L has no bandwidth in the saved rows, so its smoothed value is empty. No reported table is affected: `scripts/08_summarise_phase1.R` gives smoothed coverage for P only.
