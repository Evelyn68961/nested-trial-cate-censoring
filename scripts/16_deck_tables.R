# Tables for the deck, from saved rows only: no refitting.
#   16_median_bias_precision.csv: integrated absolute median bias with a 95% bootstrap interval
#   16_true_effect_by_time.csv: true effect at v = 1, 2, 3 at every t, and true time to benefit
#   16_time_to_benefit_interval.csv: median time to benefit with a 95% bootstrap interval
# Bootstrap over hospitals, 2,000 resamples, percentile, medians recomputed in each resample.
#
# Usage, from the repository root:  Rscript scripts/16_deck_tables.R [workers]

args <- commandArgs(trailingOnly = TRUE)
workers <- if (length(args) >= 1) as.integer(args[1]) else 3

suppressPackageStartupMessages({
  library(future)
  library(future.apply)
})
for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
source("scripts/14_common.R")
set.seed(20261031)

cfg <- load_config("config/phase2.yaml")
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
truth <- target_effect_grid(v_grid, times, cfg)
column_t <- rep(times, each = length(v_grid))
scopes <- list("t = 5" = which(column_t == 5), "averaged over t" = seq_along(column_t))
seven <- c("CC", "NE", "IPCW", "AIPCW", "IPCW_t", "AIPCW_t", "BJ")
counts <- resample_counts(200)
round_numeric <- function(d) {
  d[] <- lapply(d, function(x) if (is.double(x)) round(x, 6) else x)
  d
}

read_curves <- function(dir) {
  files <- list.files(dir, pattern = "^chunk_.*rds$", full.names = TRUE)
  curves <- do.call(rbind, lapply(files, function(f) readRDS(f)$curves))
  curves$truth <- truth[cbind(match(round(curves$v, 8), round(v_grid, 8)), match(curves$t, times))]
  curves[order(curves$seed, curves$t, curves$v), ]
}

# ---- Median bias ----

run_a <- grep("^A?IPCW_(G|p|pG)_", readRDS("results/exploratory/A/C2/chunk_001.rds")$curves$estimator, value = TRUE)
run_a <- unique(run_a)
jobs <- rbind(
  expand.grid(source = "reported", setting = paste0("C", 0:4), estimator = seven, stringsAsFactors = FALSE),
  expand.grid(source = "run B", setting = c("C2m", "C3m"), estimator = seven, stringsAsFactors = FALSE),
  expand.grid(source = "run C", setting = c("C5a", "C5b"), estimator = seven, stringsAsFactors = FALSE),
  expand.grid(source = "run A", setting = c("C2", "C4"), estimator = run_a, stringsAsFactors = FALSE))
folder_of <- function(source, setting) {
  switch(source, reported = file.path("results", "phase2", setting),
         "run A" = file.path("results", "exploratory", "A", setting),
         "run B" = file.path("results", "exploratory", "B", setting),
         "run C" = file.path("results", "exploratory", "C", setting))
}

score_job <- function(j) {
  job <- jobs[j, ]
  x <- read_curves(folder_of(job$source, job$setting))
  x <- x[x$estimator == job$estimator, ]
  err <- as_hospital_matrix(x, "estimate", 200) - as_hospital_matrix(x, "truth", 200)
  score <- function(e) {
    medians <- apply(e, 2, median)
    sapply(scopes, function(k) mean(abs(medians[k])))
  }
  boots <- sapply(seq_len(n_boot), function(b) score(err[rep(seq_len(200), counts[b, ]), , drop = FALSE]))
  data.frame(source = job$source, setting = job$setting, estimator = job$estimator, n_hospitals = 200,
             time_scope = names(scopes), integrated_absolute_median_bias = score(err),
             ci95_lower = apply(boots, 1, quantile, 0.025), ci95_upper = apply(boots, 1, quantile, 0.975),
             mcse_bootstrap = apply(boots, 1, sd), row.names = NULL)
}
plan(multisession, workers = workers)
precision <- do.call(rbind, future_lapply(seq_len(nrow(jobs)), score_job, future.seed = NULL))
plan(sequential)
write.csv(round_numeric(precision), "reports/tables/16_median_bias_precision.csv", row.names = FALSE)

# ---- True effect ----

profile_row <- sapply(1:3, function(p) which(abs(v_grid - p) < 1e-9))
true_ttb <- time_to_benefit(truth[profile_row, , drop = FALSE], times, delta)
true_rows <- do.call(rbind, lapply(1:3, function(p) {
  data.frame(v = p, t = times, true_risk_difference = truth[profile_row[p], ], delta = delta,
             true_time_to_benefit = true_ttb[p], row.names = NULL)
}))
write.csv(round_numeric(true_rows), "reports/tables/16_true_effect_by_time.csv", row.names = FALSE)

# ---- Time to benefit ----

# As in scripts/11: not reached by 5 years counts as 5.5 for the median
ttb_rows <- list()
for (setting in c("C0", "C2")) {
  curves <- read_curves(folder_of("reported", setting))
  for (est in seven) for (p in 1:3) {
    y <- curves[curves$estimator == est & abs(curves$v - p) < 1e-9, ]
    estimated <- time_to_benefit(matrix(y$estimate, nrow = 200, byrow = TRUE), times, delta)
    filled <- ifelse(is.na(estimated), 5.5, estimated)
    boots <- sapply(seq_len(n_boot), function(b) median(rep(filled, counts[b, ])))
    ttb_rows[[length(ttb_rows) + 1]] <- data.frame(
      setting = setting, estimator = est, v = p, delta = delta, n_hospitals = 200,
      true_time_to_benefit = true_ttb[p], median_estimated = median(filled),
      ci95_lower = unname(quantile(boots, 0.025)), ci95_upper = unname(quantile(boots, 0.975)),
      share_not_reached_by_5y = mean(is.na(estimated)))
  }
}
ttb <- do.call(rbind, ttb_rows)
write.csv(round_numeric(ttb), "reports/tables/16_time_to_benefit_interval.csv", row.names = FALSE)

# ---- Checks against tables already reported ----

# Each check prints its result and stops the script if the difference exceeds tol. The tables
# above are already written by then, so a stop leaves them changed in the working tree.
check <- function(label, new, old, tol) {
  d <- max(abs(new - old))
  cat(sprintf("%-46s largest difference %.6f %s\n", label, d, if (d <= tol) "OK" else "DIFFERS"))
  if (!(d <= tol)) stop(sprintf("%s: largest difference %g is above %g", label, d, tol))
}
old <- read.csv("reports/tables/13_time_to_benefit.csv")
old <- old[old$setting %in% c("C0", "C2") & old$delta == delta, ]
m <- merge(ttb, old, by = c("setting", "estimator", "v"))
stopifnot(nrow(m) == nrow(ttb))
check("median time to benefit, against 13", m$median_estimated.x, m$median_estimated.y, 1e-9)
check("not reached, against 13", m$share_not_reached_by_5y.x, m$share_not_reached_by_5y.y, 1e-3)
check("true time to benefit, against 13", m$true_time_to_benefit.x, m$true_time_to_benefit.y, 1e-9)
pred <- read.csv("reports/tables/15_runC_predictions.csv")
m <- merge(precision[precision$time_scope == "t = 5", ], pred, by = c("setting", "estimator"))
check("median bias, against 15_runC_predictions", m$integrated_absolute_median_bias, m$value_a, 1e-5)
m <- merge(precision[precision$time_scope == "t = 5" & precision$setting == "C2" & precision$source == "reported", ],
           pred[pred$setting == "C5b", ], by = "estimator")
check("C2 median bias, against 15_runC_predictions", m$integrated_absolute_median_bias, m$value_b, 1e-5)
perf <- read.csv("reports/tables/15_runA_performance.csv")
m <- merge(precision[precision$source == "run A", ], perf, by = c("setting", "estimator", "time_scope"))
stopifnot(nrow(m) == 96)
check("median bias, against 15_runA_performance", m$integrated_absolute_median_bias.x, m$integrated_absolute_median_bias.y, 1e-5)
cat("rows:", nrow(precision), nrow(true_rows), nrow(ttb), "\n")
