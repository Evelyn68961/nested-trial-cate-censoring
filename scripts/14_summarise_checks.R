# Step 2a: tables for checks 1 and 3, against the saved runs, on the same hospitals.
# Stops if a saved estimator that should not move has moved, if a control fails, or if a hospital
# failed. Run from the repository root:  Rscript scripts/14_summarise_checks.R

for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
source("scripts/14_common.R")
set.seed(20261031)

cfg <- load_config("config/phase2.yaml")
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
truth <- target_effect_grid(v_grid, times, cfg)
column_t <- rep(times, each = length(v_grid))
scopes <- list("t = 5" = which(column_t == 5), "averaged over t" = seq_along(column_t))
counts <- resample_counts(200)

prepare <- function(curves) {
  curves$truth <- truth[cbind(match(round(curves$v, 8), round(v_grid, 8)), match(curves$t, times))]
  curves[order(curves$seed, curves$t, curves$v), ]
}
run_info <- function(dir, label) {
  i <- read_chunks(dir, "info")
  if (nrow(i) != 200 || length(unique(i$seed)) != 200) stop(sprintf("%s: %d hospitals found, 200 expected", dir, nrow(i)))
  if (any(i$failed != "")) {
    print(i[i$failed != "", ])
    stop("Failed hospitals in ", dir)
  }
  data.frame(run = label, n_hospitals = nrow(i), median_seconds = median(i$seconds),
             total_warnings = sum(i$n_warnings), failed_fits = sum(i$failed != ""),
             commit = paste(unique(i$commit), collapse = ","))
}

score_rows <- list()
pair_rows <- list()
ttb <- list()
info_rows <- list()

# Check 1
for (setting in c("C2", "C4")) {
  saved <- prepare(read_chunks(file.path("results", "phase2", setting)))
  base <- lapply(c("AIPCW", "AIPCW_t", "BJ"), function(est) score_estimator(saved[saved$estimator == est, ], 200, scopes, counts))
  names(base) <- c("AIPCW", "AIPCW_t", "BJ")
  for (est in names(base)) {
    score_rows[[length(score_rows) + 1]] <- cbind(check = "compensator", setting = setting, estimator = est,
                                                  variant = "n_steps 30 (saved)", base[[est]]$rows)
    ttb[[length(ttb) + 1]] <- ttb_rows(saved[saved$estimator == est, ], 200, setting, est, "n_steps 30 (saved)",
                                       v_grid, times, truth)
  }
  for (steps in c(300, 3000)) {
    dir <- file.path("results", "check_step2", "compensator", paste0("n", steps), setting)
    new <- prepare(read_chunks(dir))
    info_rows[[length(info_rows) + 1]] <- run_info(dir, sprintf("compensator %s n_steps %d", setting, steps))
    stopifnot(nrow(new) == nrow(saved))
    key <- paste(new$seed, new$estimator, new$t, new$v)
    stopifnot(identical(key, paste(saved$seed, saved$estimator, saved$t, saved$v)))
    same <- !new$estimator %in% c("AIPCW", "AIPCW_t", "BJ")
    moved <- max(abs(new$estimate[same] - saved$estimate[same]))
    cat(sprintf("%s n_steps %d: CC, NE, IPCW, IPCW_t largest change %.3g\n", setting, steps, moved))
    if (moved != 0) stop("An estimator that does not use the compensator moved.")
    for (est in names(base)) {
      x <- new[new$estimator == est, ]
      old <- saved[saved$estimator == est, ]
      cat(sprintf("%s n_steps %d %s: largest change in estimate %.3g, bandwidth changed in %d hospitals\n",
                  setting, steps, est, max(abs(x$estimate - old$estimate)),
                  length(unique(x$seed[x$h != old$h]))))
      res <- score_estimator(x, 200, scopes, counts)
      label <- sprintf("n_steps %d", steps)
      score_rows[[length(score_rows) + 1]] <- cbind(check = "compensator", setting = setting, estimator = est,
                                                    variant = label, res$rows)
      pair_rows[[length(pair_rows) + 1]] <- paired_rows(setting, est, label, "n_steps 30 (saved)", res, base[[est]], scopes)
      ttb[[length(ttb) + 1]] <- ttb_rows(x, 200, setting, est, label, v_grid, times, truth)
    }
  }
}

# Check 3
for (setting in c("C1", "C2")) {
  dir <- file.path("results", "check_step2", "cc_fullp", setting)
  new <- prepare(read_chunks(dir))
  info_rows[[length(info_rows) + 1]] <- run_info(dir, sprintf("cc_fullp %s", setting))
  saved <- prepare(read_chunks(file.path("results", "phase2", setting)))
  saved <- saved[saved$estimator == "CC", ]
  cc <- new[new$estimator == "CC", ]
  control <- max(abs(cc$estimate - saved$estimate))
  cat(sprintf("%s control: recomputed CC against saved CC, largest difference %.3g\n", setting, control))
  if (control != 0) stop("Recomputed CC does not reproduce the saved CC.")
  full <- new[new$estimator == "CC_fullp", ]
  a <- score_estimator(full, 200, scopes, counts)
  b <- score_estimator(cc, 200, scopes, counts)
  score_rows[[length(score_rows) + 1]] <- cbind(check = "cc_propensity", setting = setting, estimator = "CC",
                                                variant = "CC (saved)", b$rows)
  score_rows[[length(score_rows) + 1]] <- cbind(check = "cc_propensity", setting = setting, estimator = "CC_fullp",
                                                variant = "CC_fullp", a$rows)
  pair_rows[[length(pair_rows) + 1]] <- paired_rows(setting, "CC_fullp vs CC", "CC_fullp", "CC (saved)", a, b, scopes)
  ttb[[length(ttb) + 1]] <- ttb_rows(cc, 200, setting, "CC", "CC (saved)", v_grid, times, truth)
  ttb[[length(ttb) + 1]] <- ttb_rows(full, 200, setting, "CC_fullp", "CC_fullp", v_grid, times, truth)
}

scores <- do.call(rbind, score_rows)
paired <- do.call(rbind, pair_rows)
ttb <- do.call(rbind, ttb)
info <- do.call(rbind, info_rows)
write.csv(round_numeric(scores), "reports/tables/14_checks_performance.csv", row.names = FALSE)
write.csv(round_numeric(paired), "reports/tables/14_checks_paired.csv", row.names = FALSE)
write.csv(round_numeric(ttb), "reports/tables/14_checks_time_to_benefit.csv", row.names = FALSE)
write.csv(info, "reports/tables/14_checks_runs.csv", row.names = FALSE)

options(width = 220)
print(info, row.names = FALSE)
s <- scores[, c("setting", "estimator", "variant", "time_scope", "integrated_absolute_bias",
                "integrated_absolute_bias_mcse_bootstrap", "integrated_absolute_median_bias", "integrated_rmse",
                "integrated_coverage_percent", "interval_width_integrated_mean", "interval_width_integrated_median",
                "n_hospitals_max_abs_error_gt_0.5", "n_missing_estimates")]
names(s)[5:13] <- c("bias", "se", "medb", "rmse", "cov", "wMean", "wMed", "nGt", "miss")
print(s, row.names = FALSE, digits = 4)
print(paired[, c("setting", "estimator", "variant_a", "time_scope", "metric", "value_a", "value_b",
                 "difference_a_minus_b", "difference_ci95_lower", "difference_ci95_upper")], row.names = FALSE, digits = 4)
print(ttb[, c("setting", "estimator", "variant", "v", "true_time_to_benefit", "median_estimated", "share_earlier",
              "share_equal", "share_later", "share_not_reached_by_5y")], row.names = FALSE, digits = 3)
