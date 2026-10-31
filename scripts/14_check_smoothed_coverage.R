# Step 2a, check 2: coverage against the smoothed target theta*(v), from saved rows, no refitting.
# As in scripts/08: the true curve is passed through smoothed_curve with each hospital's own
# bandwidth, with v uniform. Also, for Phase 1, coverage of the mean estimated curve across
# hospitals, the approximation of theta* used in the paper.
#
# Run from the repository root:  Rscript scripts/14_check_smoothed_coverage.R
# Writes reports/tables/14_smoothed_coverage_phase2.csv and 14_smoothed_coverage_phase1.csv

for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
source("scripts/14_common.R")
set.seed(20261031)

integrated <- function(covered, j) mean(colMeans(covered[, j, drop = FALSE]))
boot_se <- function(covered, j, counts, n) sd(rowMeans((counts %*% covered / n)[, j, drop = FALSE]))
u <- seq(0, 4, length.out = 801)

# Phase 2
cfg2 <- load_config("config/phase2.yaml")
v_grid2 <- make_v_grid(cfg2)
times <- unlist(cfg2$times)
truth2 <- target_effect_grid(v_grid2, times, cfg2)
bandwidths2 <- c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0)
target_u <- sapply(times, function(t) target_effect_t(u, t, cfg2))
smoothed2 <- array(NA_real_, c(length(v_grid2), length(times), length(bandwidths2)))
for (j in seq_along(times)) for (b in seq_along(bandwidths2)) {
  smoothed2[, j, b] <- smoothed_curve(u, target_u[, j], rep(1, length(u)), v_grid2, bandwidths2[b])
}
column_t <- rep(times, each = length(v_grid2))
scopes <- list("t = 5" = which(column_t == 5), "averaged over t" = seq_along(column_t))
estimators2 <- c("CC", "NE", "IPCW", "AIPCW", "IPCW_t", "AIPCW_t", "BJ")
counts2 <- resample_counts(200)
rows2 <- list()
for (setting in paste0("C", 0:4)) {
  curves <- read_chunks(file.path("results", "phase2", setting))
  curves <- curves[order(curves$seed, curves$t, curves$v), ]
  vi <- match(round(curves$v, 8), round(v_grid2, 8))
  ti <- match(curves$t, times)
  curves$truth <- truth2[cbind(vi, ti)]
  curves$smoothed <- smoothed2[cbind(vi, ti, match(round(curves$h, 2), round(bandwidths2, 2)))]
  stopifnot(!anyNA(curves$smoothed))
  for (est in estimators2) {
    x <- curves[curves$estimator == est, ]
    n <- length(unique(x$seed))
    lower <- as_hospital_matrix(x, "lower", n)
    upper <- as_hospital_matrix(x, "upper", n)
    exact <- 100 * (lower <= as_hospital_matrix(x, "truth", n) & as_hospital_matrix(x, "truth", n) <= upper)
    smooth <- 100 * (lower <= as_hospital_matrix(x, "smoothed", n) & as_hospital_matrix(x, "smoothed", n) <= upper)
    for (scope in names(scopes)) {
      j <- scopes[[scope]]
      rows2[[length(rows2) + 1]] <- data.frame(
        setting = setting, estimator = est, time_scope = scope, n_hospitals = n,
        integrated_coverage_exact_target_percent = integrated(exact, j),
        integrated_coverage_exact_target_mcse_bootstrap = boot_se(exact, j, counts2, n),
        integrated_coverage_smoothed_target_percent = integrated(smooth, j),
        integrated_coverage_smoothed_target_mcse_bootstrap = boot_se(smooth, j, counts2, n))
    }
  }
}
phase2 <- do.call(rbind, rows2)

# Phase 1
cfg1 <- load_config("config/phase1.yaml")
v_grid1 <- make_v_grid(cfg1)
truth1 <- target_effect(v_grid1, cfg1)
target_u1 <- target_effect(u, cfg1)
bandwidths1 <- seq(0.3, 2.0, by = 0.1)
smoothed1 <- sapply(bandwidths1, function(h) smoothed_curve(u, target_u1, rep(1, length(u)), v_grid1, h))
rows1 <- list()
for (setting in c("sl_trial20", "sl_trial05")) {
  curves <- read_chunks(file.path("results", "phase1", setting))
  curves <- curves[order(curves$seed, curves$v), ]
  vi <- match(round(curves$v, 8), round(v_grid1, 8))
  curves$truth <- truth1[vi]
  curves$smoothed <- NA_real_
  has_h <- !is.na(curves$h)
  curves$smoothed[has_h] <- smoothed1[cbind(vi[has_h], match(round(curves$h[has_h], 2), round(bandwidths1, 2)))]
  n <- length(unique(curves$seed))
  counts <- resample_counts(n)
  j <- seq_along(v_grid1)
  for (est in c("P", "L", "T")) {
    x <- curves[curves$estimator == est, ]
    lower <- as_hospital_matrix(x, "lower", n)
    upper <- as_hospital_matrix(x, "upper", n)
    estimate <- as_hospital_matrix(x, "estimate", n)
    truth <- as_hospital_matrix(x, "truth", n)
    exact <- 100 * (lower <= truth & truth <= upper)
    # The mean curve is recomputed in each resample, as a Monte Carlo approximation would be
    mean_curve <- colMeans(estimate)
    of_mean <- 100 * sweep(lower, 2, mean_curve, "<=") * sweep(upper, 2, mean_curve, ">=")
    boot_mean <- sapply(seq_len(n_boot), function(b) {
      w <- counts[b, ] / n
      m <- colSums(estimate * w)
      mean(colSums(w * (sweep(lower, 2, m, "<=") * sweep(upper, 2, m, ">="))))
    })
    if (est == "L") {
      s_value <- s_se <- NA_real_
    } else {
      smoothed <- as_hospital_matrix(x, "smoothed", n)
      smooth <- 100 * (lower <= smoothed & smoothed <= upper)
      s_value <- integrated(smooth, j)
      s_se <- boot_se(smooth, j, counts, n)
    }
    rows1[[length(rows1) + 1]] <- data.frame(
      setting = setting, status = if (setting == "sl_trial05") "preliminary" else "final",
      estimator = est, n_hospitals = n,
      integrated_coverage_exact_target_percent = integrated(exact, j),
      integrated_coverage_exact_target_mcse_bootstrap = boot_se(exact, j, counts, n),
      integrated_coverage_smoothed_target_percent = s_value,
      integrated_coverage_smoothed_target_mcse_bootstrap = s_se,
      integrated_coverage_mean_estimate_target_percent = integrated(of_mean, j),
      integrated_coverage_mean_estimate_target_mcse_bootstrap = 100 * sd(boot_mean))
  }
}
phase1 <- do.call(rbind, rows1)

# Check against reported values
reported <- read.csv("reports/tables/07_phase1_summary.csv")
for (s in c("sl_trial20", "sl_trial05")) {
  a <- phase1[phase1$setting == s & phase1$estimator == "P", ]
  r <- reported[reported$setting == s & reported$estimator == "P", ]
  stopifnot(round(a$integrated_coverage_smoothed_target_percent, 1) == r$coverage_smoothed,
            round(a$integrated_coverage_exact_target_percent, 1) == r$integrated_coverage)
}
accepted <- read.csv("reports/tables/13_phase2_precision.csv")
m <- merge(phase2, accepted, by = c("setting", "estimator", "time_scope"))
stopifnot(nrow(m) == nrow(phase2),
          max(abs(m$integrated_coverage_exact_target_percent - m$integrated_coverage_percent)) < 1e-4)
cat("Check passed: Phase 1 smoothed and exact coverage and Phase 2 exact coverage reproduce the reported values.\n")

write.csv(round_numeric(phase2), "reports/tables/14_smoothed_coverage_phase2.csv", row.names = FALSE)
write.csv(round_numeric(phase1), "reports/tables/14_smoothed_coverage_phase1.csv", row.names = FALSE)
options(width = 200)
s <- phase2[phase2$setting %in% c("C0", "C2", "C3", "C4"), c(1:3, 5, 7, 8)]
names(s) <- c("set", "est", "scope", "exact", "smoothed", "se")
print(s, row.names = FALSE, digits = 4)
names(phase1) <- sub("integrated_coverage_", "", names(phase1))
print(phase1, row.names = FALSE, digits = 4)
