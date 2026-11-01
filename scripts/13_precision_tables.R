# Step 3: precision of the reported results, computed from the saved chunks with no refitting.
#
# Monte Carlo standard errors by a nonparametric bootstrap over hospitals (2,000 resamples, fixed
# seed). All estimators in a setting share the same resamples, so comparisons resample hospitals
# jointly. Before any table is written, the values already reported are recomputed; the script
# stops if one differs.
#
# Run from the repository root:  Rscript scripts/13_precision_tables.R
# Writes reports/tables/13_*.csv only.

for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))

if (length(system("git status --porcelain -- R config results", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or results/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)

n_boot <- 2000
threshold <- 0.5
delta <- 0.05
set.seed(20261031)

read_curves <- function(dir) {
  files <- list.files(dir, pattern = "^chunk_.*rds$", full.names = TRUE)
  do.call(rbind, lapply(files, function(f) readRDS(f)$curves))
}

# One row per resample, one column per hospital: how often the resample drew that hospital
resample_counts <- function(n) {
  t(sapply(seq_len(n_boot), function(b) tabulate(sample.int(n, n, replace = TRUE), nbins = n)))
}

wilson <- function(x, n, z = qnorm(0.975)) {
  p <- x / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(centre - half, centre + half)
}

# Hospitals in rows; columns ordered by time, then v
as_hospital_matrix <- function(x, column, n) matrix(x[[column]], nrow = n, byrow = TRUE)

# Everything for one estimator in one setting. x holds that estimator's rows sorted by seed, t, v.
# scopes: named list of column indices. Returns a table row per scope and the bootstrap replicates.
score_estimator <- function(x, n, scopes, counts) {
  estimate <- as_hospital_matrix(x, "estimate", n)
  truth <- as_hospital_matrix(x, "truth", n)
  lower <- as_hospital_matrix(x, "lower", n)
  upper <- as_hospital_matrix(x, "upper", n)
  err <- estimate - truth
  covered <- 100 * (lower <= truth & truth <= upper)
  width <- upper - lower
  has_interval <- !all(is.na(width))

  boot_bias <- counts %*% err / n
  boot_mse <- counts %*% err^2 / n
  boot_coverage <- if (has_interval) counts %*% covered / n

  rows <- list()
  replicates <- list()
  for (scope in names(scopes)) {
    j <- scopes[[scope]]
    bias_v <- colMeans(err[, j, drop = FALSE])
    median_v <- apply(err[, j, drop = FALSE], 2, median)
    rmse_v <- sqrt(colMeans(err[, j, drop = FALSE]^2))
    boot_abs_bias <- rowMeans(abs(boot_bias[, j, drop = FALSE]))
    boot_rmse <- rowMeans(sqrt(boot_mse[, j, drop = FALSE]))
    worst <- apply(abs(err[, j, drop = FALSE]), 1, max)
    exceeds <- worst > threshold
    x_exceed <- sum(exceeds)
    interval <- wilson(x_exceed, n)
    boot_exceed <- as.vector(counts %*% exceeds) / n

    if (has_interval) {
      coverage_v <- colMeans(covered[, j, drop = FALSE])
      binomial_se_v <- sqrt(coverage_v * (100 - coverage_v) / n)
      boot_cover <- rowMeans(boot_coverage[, j, drop = FALSE])
      boot_width <- as.vector(counts %*% rowMeans(width[, j, drop = FALSE])) / n
      coverage <- mean(coverage_v)
      coverage_binomial_se <- mean(binomial_se_v)
      coverage_boot_se <- sd(boot_cover)
      width_mean <- mean(colMeans(width[, j, drop = FALSE]))
      width_median <- mean(apply(width[, j, drop = FALSE], 2, median))
      width_p90 <- mean(apply(width[, j, drop = FALSE], 2, quantile, probs = 0.9))
    } else {
      boot_cover <- boot_width <- rep(NA_real_, n_boot)
      coverage <- coverage_binomial_se <- coverage_boot_se <- NA_real_
      width_mean <- width_median <- width_p90 <- NA_real_
    }

    rows[[scope]] <- data.frame(
      time_scope = scope, n_hospitals = n,
      integrated_absolute_bias = mean(abs(bias_v)),
      integrated_absolute_bias_mcse_bootstrap = sd(boot_abs_bias),
      integrated_absolute_bias_ci95_lower = unname(quantile(boot_abs_bias, 0.025)),
      integrated_absolute_bias_ci95_upper = unname(quantile(boot_abs_bias, 0.975)),
      integrated_absolute_median_bias = mean(abs(median_v)),
      integrated_rmse = mean(rmse_v),
      integrated_rmse_mcse_bootstrap = sd(boot_rmse),
      integrated_coverage_percent = coverage,
      integrated_coverage_mcse_binomial = coverage_binomial_se,
      integrated_coverage_mcse_bootstrap = coverage_boot_se,
      interval_width_integrated_mean = width_mean,
      interval_width_integrated_median = width_median,
      interval_width_integrated_p90 = width_p90,
      # Counts are not averaged: over all times, a hospital counts if it exceeds at any time
      max_abs_error_scope = c("t = 5" = "t = 5", "averaged over t" = "any t (maximum over v and t)",
                              "binary outcome" = "v grid")[[scope]],
      n_hospitals_max_abs_error_gt_0.5 = x_exceed,
      proportion_max_abs_error_gt_0.5 = x_exceed / n,
      proportion_mcse = sqrt(x_exceed / n * (1 - x_exceed / n) / n),
      proportion_wilson_ci95_lower = interval[1],
      proportion_wilson_ci95_upper = interval[2],
      n_missing_estimates = sum(is.na(estimate[, j])))
    replicates[[scope]] <- list(
      integrated_absolute_bias = boot_abs_bias, integrated_rmse = boot_rmse,
      integrated_coverage_percent = boot_cover, interval_width_mean = boot_width,
      proportion_max_abs_error_gt_0.5 = boot_exceed)
  }
  list(rows = do.call(rbind, rows), replicates = replicates)
}

# Phase 2 ----------------------------------------------------------------------------------------

cfg2 <- load_config("config/phase2.yaml")
v_grid2 <- make_v_grid(cfg2)
times <- unlist(cfg2$times)
truth2 <- target_effect_grid(v_grid2, times, cfg2)
estimators2 <- c("CC", "NE", "IPCW", "AIPCW", "IPCW_t", "AIPCW_t", "BJ")
settings2 <- paste0("C", 0:4)
column_t <- rep(times, each = length(v_grid2))
scopes2 <- list("t = 5" = which(column_t == 5), "averaged over t" = seq_along(column_t))

counts2 <- resample_counts(200)
phase2_rows <- list()
phase2_reps <- list()
per_time <- list()
ttb_rows <- list()
for (setting in settings2) {
  curves <- read_curves(file.path("results", "phase2", setting))
  curves$truth <- truth2[cbind(match(round(curves$v, 8), round(v_grid2, 8)), match(curves$t, times))]
  curves <- curves[order(curves$seed, curves$t, curves$v), ]
  n <- length(unique(curves$seed))
  stopifnot(n == 200, nrow(curves) == n * length(estimators2) * length(column_t))

  for (est in estimators2) {
    x <- curves[curves$estimator == est, ]
    res <- score_estimator(x, n, scopes2, counts2)
    phase2_rows[[length(phase2_rows) + 1]] <- cbind(setting = setting, estimator = est, res$rows)
    phase2_reps[[setting]][[est]] <- res$replicates
    # Values at each time, for the check against reports/tables/10_phase2_by_time.csv
    for (tt in times) {
      y <- x[x$t == tt, ]
      by_v <- split(y, y$v)
      per_time[[length(per_time) + 1]] <- data.frame(
        setting = setting, estimator = est, t = tt,
        integrated_abs_bias = mean(sapply(by_v, function(d) abs(mean(d$estimate - d$truth)))),
        integrated_rmse = mean(sapply(by_v, function(d) sqrt(mean((d$estimate - d$truth)^2)))),
        integrated_coverage = 100 * mean(sapply(by_v, function(d) mean(d$lower <= d$truth & d$truth <= d$upper))),
        integrated_abs_median_bias = mean(sapply(by_v, function(d) abs(median(d$estimate - d$truth)))))
    }
    # Time to benefit. As in scripts/11: not reached by 5 years counts as 5.5 for the median.
    for (p in c(1, 2, 3)) {
      pv <- which(abs(v_grid2 - p) < 1e-9)
      true_ttb <- time_to_benefit(truth2[pv, , drop = FALSE], times, delta)
      y <- x[abs(x$v - p) < 1e-9, ]
      estimated <- time_to_benefit(matrix(y$estimate, nrow = n, byrow = TRUE), times, delta)
      reached <- !is.na(estimated)
      filled <- ifelse(reached, estimated, 5.5)
      ttb_rows[[length(ttb_rows) + 1]] <- data.frame(
        setting = setting, estimator = est, v = p, delta = delta, n_hospitals = n,
        true_time_to_benefit = true_ttb,
        median_estimated = median(filled),
        share_earlier = mean(filled < true_ttb),
        share_equal = mean(filled == true_ttb),
        share_later = mean(filled > true_ttb),
        share_not_reached_by_5y = mean(!reached),
        share_within_half_year = round(mean(abs(filled - true_ttb) <= 0.5), 2))
    }
  }
}
phase2 <- do.call(rbind, phase2_rows)
per_time <- do.call(rbind, per_time)
ttb <- do.call(rbind, ttb_rows)

# Phase 1 ----------------------------------------------------------------------------------------

cfg1 <- load_config("config/phase1.yaml")
v_grid1 <- make_v_grid(cfg1)
truth1 <- target_effect(v_grid1, cfg1)
estimators1 <- c("P", "L", "T", "G")
phase1_rows <- list()
for (setting in c("sl_trial20", "sl_trial05")) {
  curves <- read_curves(file.path("results", "phase1", setting))
  curves$truth <- truth1[match(round(curves$v, 8), round(v_grid1, 8))]
  curves <- curves[order(curves$seed, curves$v), ]
  n <- length(unique(curves$seed))
  counts <- resample_counts(n)
  for (est in estimators1) {
    x <- curves[curves$estimator == est, ]
    res <- score_estimator(x, n, list("binary outcome" = seq_along(v_grid1)), counts)
    phase1_rows[[length(phase1_rows) + 1]] <- cbind(
      setting = setting, status = if (setting == "sl_trial05") "preliminary" else "final",
      estimator = est, res$rows)
  }
}
phase1 <- do.call(rbind, phase1_rows)
phase1$time_scope <- NULL

# Paired comparisons -----------------------------------------------------------------------------

pairs <- list(c("C2", "IPCW", "AIPCW"), c("C3", "IPCW", "AIPCW"), c("C4", "IPCW", "AIPCW"),
              c("C2", "AIPCW_t", "AIPCW"), c("C2", "AIPCW", "BJ"), c("C4", "AIPCW", "BJ"))
point_column <- c(integrated_absolute_bias = "integrated_absolute_bias", integrated_rmse = "integrated_rmse",
                  integrated_coverage_percent = "integrated_coverage_percent",
                  interval_width_mean = "interval_width_integrated_mean",
                  proportion_max_abs_error_gt_0.5 = "proportion_max_abs_error_gt_0.5")
pair_rows <- list()
for (pr in pairs) for (scope in names(scopes2)) for (metric in names(point_column)) {
  point <- function(est) phase2[[point_column[metric]]][phase2$setting == pr[1] & phase2$estimator == est &
                                                          phase2$time_scope == scope]
  boot <- phase2_reps[[pr[1]]][[pr[2]]][[scope]][[metric]] - phase2_reps[[pr[1]]][[pr[3]]][[scope]][[metric]]
  pair_rows[[length(pair_rows) + 1]] <- data.frame(
    setting = pr[1], estimator_a = pr[2], estimator_b = pr[3], time_scope = scope,
    metric = if (metric == "proportion_max_abs_error_gt_0.5" && scope == "averaged over t") {
      "proportion_max_abs_error_gt_0.5_at_any_t"
    } else metric,
    value_a = point(pr[2]), value_b = point(pr[3]), difference_a_minus_b = point(pr[2]) - point(pr[3]),
    difference_mcse_bootstrap = sd(boot),
    difference_ci95_lower = unname(quantile(boot, 0.025)),
    difference_ci95_upper = unname(quantile(boot, 0.975)))
}
paired <- do.call(rbind, pair_rows)

# Check against what is already reported -----------------------------------------------------------

checks <- list()
add_check <- function(source, label, expected, actual, digits) {
  checks[[length(checks) + 1]] <<- data.frame(source = source, item = label, expected = expected,
                                              actual = round(actual, digits))
}

by_time <- read.csv("reports/tables/10_phase2_by_time.csv")
m <- merge(by_time, per_time, by = c("setting", "estimator", "t"), suffixes = c("", ".new"))
stopifnot(nrow(m) == nrow(by_time), nrow(m) == nrow(per_time))
for (k in c("integrated_abs_bias", "integrated_rmse", "integrated_coverage", "integrated_abs_median_bias")) {
  add_check("10_phase2_by_time.csv", paste(m$setting, m$estimator, m$t, k), m[[k]], m[[paste0(k, ".new")]], 3)
}

# results/summary_phase2_20261023.txt: averages over time and hospitals off by more than 0.5
lines <- readLines("results/summary_phase2_20261023.txt")
current <- NA
for (line in lines) {
  if (grepl("^C[0-4] ", line)) current <- substr(line, 1, 2)
  tok <- strsplit(trimws(line), "\\s+")[[1]]
  if (length(tok) == 8 && tok[1] %in% estimators2) {
    a <- phase2[phase2$setting == current & phase2$estimator == tok[1], ]
    five <- a[a$time_scope == "t = 5", ]
    avg <- a[a$time_scope == "averaged over t", ]
    label <- paste(current, tok[1])
    src <- "summary_phase2_20261023.txt"
    add_check(src, paste(label, "abs_bias_avg_over_t"), as.numeric(tok[2]), avg$integrated_absolute_bias, 3)
    add_check(src, paste(label, "rmse_avg_over_t"), as.numeric(tok[3]), avg$integrated_rmse, 3)
    add_check(src, paste(label, "coverage_avg_over_t"), as.numeric(tok[4]), avg$integrated_coverage_percent, 1)
    add_check(src, paste(label, "abs_bias_at_5y"), as.numeric(tok[5]), five$integrated_absolute_bias, 3)
    add_check(src, paste(label, "coverage_at_5y"), as.numeric(tok[6]), five$integrated_coverage_percent, 1)
    add_check(src, paste(label, "median_bias_at_5y"), as.numeric(tok[7]), five$integrated_absolute_median_bias, 3)
    add_check(src, paste(label, "hospitals_off_by_0.5"), as.numeric(tok[8]), five$n_hospitals_max_abs_error_gt_0.5, 0)
  }
}

summary1 <- read.csv("reports/tables/07_phase1_summary.csv")
for (i in which(summary1$setting %in% phase1$setting)) {
  s <- summary1[i, ]
  a <- phase1[phase1$setting == s$setting & phase1$estimator == s$estimator, ]
  label <- paste(s$setting, s$estimator)
  add_check("07_phase1_summary.csv", paste(label, "bias"), s$integrated_abs_bias, a$integrated_absolute_bias, 3)
  add_check("07_phase1_summary.csv", paste(label, "rmse"), s$integrated_rmse, a$integrated_rmse, 3)
  if (!is.na(s$integrated_coverage)) {
    add_check("07_phase1_summary.csv", paste(label, "coverage"), s$integrated_coverage, a$integrated_coverage_percent, 1)
  }
  add_check("07_phase1_summary.csv", paste(label, "missing"), s$missing_estimates, a$n_missing_estimates, 0)
}

ttb_old <- read.csv("reports/tables/10_phase2_time_to_benefit.csv")
ttb_old <- ttb_old[ttb_old$delta == delta, ]
m <- merge(ttb_old, ttb, by.x = c("setting", "profile_v", "estimator"), by.y = c("setting", "v", "estimator"))
stopifnot(nrow(m) == nrow(ttb_old), nrow(m) == nrow(ttb))
label <- paste(m$setting, m$estimator, "v", m$profile_v)
add_check("10_phase2_time_to_benefit.csv", paste(label, "true"), m$true_ttb, m$true_time_to_benefit, 1)
add_check("10_phase2_time_to_benefit.csv", paste(label, "median"), m$median_estimated.x, m$median_estimated.y, 2)
add_check("10_phase2_time_to_benefit.csv", paste(label, "within half a year"), m$share_within_half_year.x, m$share_within_half_year.y, 2)
add_check("10_phase2_time_to_benefit.csv", paste(label, "never reached"), m$share_never_reached, m$share_not_reached_by_5y, 2)

# Figures as printed in reports/phase2_results.md and reports/phase1_results.md
quoted <- list(c("C2", "IPCW", 0.116, 92), c("C2", "AIPCW", 0.048, 50), c("C2", "AIPCW_t", 0.029, 27),
               c("C2", "BJ", 0.025, 1), c("C0", "AIPCW", 0.024, 1), c("C4", "AIPCW", 0.065, 73),
               c("C4", "BJ", 0.064, 4), c("C3", "IPCW", 0.037, 30))
for (q in quoted) {
  a <- phase2[phase2$setting == q[1] & phase2$estimator == q[2] & phase2$time_scope == "t = 5", ]
  add_check("phase2_results.md", paste(q[1], q[2], "bias"), as.numeric(q[3]), a$integrated_absolute_bias, 3)
  add_check("phase2_results.md", paste(q[1], q[2], "broken"), as.numeric(q[4]), a$n_hospitals_max_abs_error_gt_0.5, 0)
}
a <- phase1[phase1$setting == "sl_trial20" & phase1$estimator == "P", ]
add_check("phase1_results.md", "P bias", 0.020, a$integrated_absolute_bias, 3)
add_check("phase1_results.md", "P rmse", 0.099, a$integrated_rmse, 3)
add_check("phase1_results.md", "P coverage", 91.9, a$integrated_coverage_percent, 1)

checks <- do.call(rbind, checks)
checks$difference <- checks$actual - checks$expected
bad <- checks[abs(checks$difference) > 1e-9, ]
cat(sprintf("Check against reported values: %d compared, %d differ. Commit %s.\n", nrow(checks), nrow(bad), commit))
print(aggregate(difference ~ source, checks, function(d) sum(abs(d) > 1e-9)), row.names = FALSE)
if (nrow(bad)) {
  print(head(bad, 40), row.names = FALSE)
  write.csv(bad, "reports/tables/13_check_mismatches.csv", row.names = FALSE)
  stop("Values differ from the reports. No tables written.")
}

# Tables -----------------------------------------------------------------------------------------

round_numeric <- function(d) {
  d[] <- lapply(d, function(x) if (is.double(x)) round(x, 5) else x)
  d
}
write.csv(round_numeric(phase2), "reports/tables/13_phase2_precision.csv", row.names = FALSE)
write.csv(round_numeric(phase1), "reports/tables/13_phase1_precision.csv", row.names = FALSE)
write.csv(round_numeric(paired), "reports/tables/13_paired_comparisons.csv", row.names = FALSE)
write.csv(round_numeric(ttb), "reports/tables/13_time_to_benefit.csv", row.names = FALSE)
cat("Tables written to reports/tables/13_*.csv\n")
