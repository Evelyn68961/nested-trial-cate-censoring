# Phase 2 check: one hospital per dropout setting; run time, share dropped, and the four
# estimators at v = 2 over follow-up, against the true curve.
# Run from the repository root:  Rscript scripts/09_check_phase2.R

for (f in c("generate", "truth", "nuisance", "pseudo", "smooth",
            "phase2_generate", "phase2_truth", "phase2_estimators")) source(sprintf("R/%s.R", f))

cfg <- load_config("config/phase2.yaml")
b0 <- participation_intercept(cfg)
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
right_censor <- ~ a + frailty + v + male
wrong_censor <- ~ a + v + male          # leaves out frailty, which drives dropout

settings <- list(
  C0 = list(censoring = "none", formula = right_censor),
  C1 = list(censoring = "random", formula = right_censor),
  C2 = list(censoring = "dependent", formula = right_censor),
  C3 = list(censoring = "dependent", formula = wrong_censor),
  C4 = list(censoring = "dependent", formula = right_censor, out_formula = ~ v + I(v^2) + male)
)

truth_v2 <- sapply(times, function(t) target_effect_t(2, t, cfg))
for (name in names(settings)) {
  st <- settings[[name]]
  d <- simulate_cohort_surv(cfg, st$censoring, seed = 1, b0 = b0)$observed
  t0 <- Sys.time()
  res <- if (is.null(st$out_formula)) {
    run_phase2_estimators(d, cfg, st$formula, seed = 1, v_grid = v_grid)
  } else {
    run_phase2_estimators(d, cfg, st$formula, seed = 1, v_grid = v_grid, out_formula = st$out_formula)
  }
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  at2 <- res$curves[abs(res$curves$v - 2) < 1e-9, ]
  tab <- reshape(at2[, c("estimator", "t", "estimate")], idvar = "t", timevar = "estimator", direction = "wide")
  tab$truth <- truth_v2
  cat(sprintf("\n%s (%s dropout): %.0f s; %.0f%% of trial patients dropped out; smallest chance of staying %.2f\n",
              name, st$censoring, secs, 100 * res$info$share_dropped, res$info$min_g))
  print(round(tab[tab$t %in% c(1, 2, 3, 4, 5), ], 3), row.names = FALSE)
}
