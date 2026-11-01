# Step 2a, check 2 follow-up: how often each hospital's interval contains the mean, and the median,
# of the estimated curves across hospitals. From saved rows, no refitting. This separates bias from
# interval width. It is not validation: it removes bias by construction. The mean and the median are
# recomputed in each resample, as a Monte Carlo approximation would be.
# Also, for BJ at t = 5, signed bias against the exact and the smoothed target. BJ is fitted on all
# eligible patients, whose v is uniform, with its own bandwidth, as in that target.
#
# Run from the repository root:  Rscript scripts/14_check_center_coverage.R
# Writes reports/tables/14_center_coverage_phase2.csv and 14_bj_smoothed_target.csv

for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
source("scripts/14_common.R")
set.seed(20261031)

cfg <- load_config("config/phase2.yaml")
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
truth <- target_effect_grid(v_grid, times, cfg)
bandwidths <- c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0)
u <- seq(0, 4, length.out = 801)
target_u <- sapply(times, function(t) target_effect_t(u, t, cfg))
smoothed <- array(NA_real_, c(length(v_grid), length(times), length(bandwidths)))
for (j in seq_along(times)) for (b in seq_along(bandwidths)) {
  smoothed[, j, b] <- smoothed_curve(u, target_u[, j], rep(1, length(u)), v_grid, bandwidths[b])
}
column_t <- rep(times, each = length(v_grid))
scopes <- list("t = 5" = which(column_t == 5), "averaged over t" = seq_along(column_t))
counts <- resample_counts(200)

covers <- function(lower, upper, centre, w = rep(1 / nrow(lower), nrow(lower))) {
  colSums(w * (sweep(lower, 2, centre, "<=") * sweep(upper, 2, centre, ">=")))
}

rows <- list()
for (setting in c("C0", "C2", "C3", "C4")) {
  curves <- read_chunks(file.path("results", "phase2", setting))
  curves <- curves[order(curves$seed, curves$t, curves$v), ]
  for (est in c("CC", "NE", "IPCW", "AIPCW", "IPCW_t", "AIPCW_t", "BJ")) {
    x <- curves[curves$estimator == est, ]
    n <- length(unique(x$seed))
    estimate <- as_hospital_matrix(x, "estimate", n)
    lower <- as_hospital_matrix(x, "lower", n)
    upper <- as_hospital_matrix(x, "upper", n)
    of_mean <- covers(lower, upper, colMeans(estimate))
    of_median <- covers(lower, upper, apply(estimate, 2, median))
    boots <- t(sapply(seq_len(n_boot), function(b) {
      w <- counts[b, ] / n
      idx <- rep(seq_len(n), counts[b, ])
      a <- covers(lower, upper, colSums(estimate * w), w)
      m <- covers(lower, upper, apply(estimate[idx, , drop = FALSE], 2, median), w)
      sapply(scopes, function(j) c(mean(a[j]), mean(m[j])))
    }))
    for (s in seq_along(scopes)) {
      j <- scopes[[s]]
      rows[[length(rows) + 1]] <- data.frame(
        setting = setting, estimator = est, time_scope = names(scopes)[s], n_hospitals = n,
        integrated_coverage_mean_estimate_target_percent = 100 * mean(of_mean[j]),
        integrated_coverage_mean_estimate_target_mcse_bootstrap = 100 * sd(boots[, 2 * s - 1]),
        integrated_coverage_median_estimate_target_percent = 100 * mean(of_median[j]),
        integrated_coverage_median_estimate_target_mcse_bootstrap = 100 * sd(boots[, 2 * s]))
    }
  }
}
out <- do.call(rbind, rows)
write.csv(round_numeric(out), "reports/tables/14_center_coverage_phase2.csv", row.names = FALSE)

bj <- list()
for (setting in c("C2", "C4")) {
  x <- read_chunks(file.path("results", "phase2", setting))
  x <- x[x$estimator == "BJ" & x$t == 5, ]
  x <- x[order(x$seed, x$v), ]
  vi <- match(round(x$v, 8), round(v_grid, 8))
  x$truth <- truth[cbind(vi, match(5, times))]
  x$smoothed <- smoothed[cbind(vi, match(5, times), match(round(x$h, 2), round(bandwidths, 2)))]
  stopifnot(!anyNA(x$smoothed))
  by_v <- aggregate(cbind(estimate, truth, smoothed, half_width = (upper - lower) / 2) ~ v, x, mean)
  medians <- aggregate(estimate ~ v, x, median)$estimate
  hospital_h <- x$h[!duplicated(x$seed)]
  bj[[setting]] <- data.frame(
    setting = setting, estimator = "BJ", t = 5, n_hospitals = length(hospital_h),
    median_bandwidth = median(hospital_h),
    mean_signed_bias_vs_exact = mean(by_v$estimate - by_v$truth),
    mean_signed_bias_vs_smoothed = mean(by_v$estimate - by_v$smoothed),
    integrated_abs_bias_vs_exact = mean(abs(by_v$estimate - by_v$truth)),
    integrated_abs_bias_vs_smoothed = mean(abs(by_v$estimate - by_v$smoothed)),
    integrated_abs_median_bias_vs_exact = mean(abs(medians - by_v$truth)),
    integrated_abs_median_bias_vs_smoothed = mean(abs(medians - by_v$smoothed)),
    integrated_abs_smoothing_shift = mean(abs(by_v$smoothed - by_v$truth)),
    mean_half_width = mean(by_v$half_width))
}
bj <- do.call(rbind, bj)
write.csv(round_numeric(bj), "reports/tables/14_bj_smoothed_target.csv", row.names = FALSE)

options(width = 200)
s <- out
names(s)[5:8] <- c("mean_tgt", "mean_se", "median_tgt", "median_se")
print(s[, -4], row.names = FALSE, digits = 4)
print(t(bj), digits = 4)
