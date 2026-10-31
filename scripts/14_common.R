# Step 2a: functions shared by the scripts/14_*.R checks. Scoring as in scripts/13_precision_tables.R.

n_boot <- 2000
threshold <- 0.5
delta <- 0.05

read_chunks <- function(dir, part = "curves") {
  files <- list.files(dir, pattern = "^chunk_.*rds$", full.names = TRUE)
  do.call(rbind, lapply(files, function(f) readRDS(f)[[part]]))
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

# Rows for one estimator in one setting, sorted by seed, t, v, with a truth column.
score_estimator <- function(x, n, scopes, counts) {
  estimate <- as_hospital_matrix(x, "estimate", n)
  truth <- as_hospital_matrix(x, "truth", n)
  lower <- as_hospital_matrix(x, "lower", n)
  upper <- as_hospital_matrix(x, "upper", n)
  err <- estimate - truth
  covered <- 100 * (lower <= truth & truth <= upper)
  width <- upper - lower

  boot_bias <- counts %*% err / n
  boot_mse <- counts %*% err^2 / n
  boot_coverage <- counts %*% covered / n

  rows <- list()
  replicates <- list()
  for (scope in names(scopes)) {
    j <- scopes[[scope]]
    bias_v <- colMeans(err[, j, drop = FALSE])
    median_v <- apply(err[, j, drop = FALSE], 2, median)
    rmse_v <- sqrt(colMeans(err[, j, drop = FALSE]^2))
    coverage_v <- colMeans(covered[, j, drop = FALSE])
    boot_abs_bias <- rowMeans(abs(boot_bias[, j, drop = FALSE]))
    boot_rmse <- rowMeans(sqrt(boot_mse[, j, drop = FALSE]))
    boot_cover <- rowMeans(boot_coverage[, j, drop = FALSE])
    boot_width <- as.vector(counts %*% rowMeans(width[, j, drop = FALSE])) / n
    worst <- apply(abs(err[, j, drop = FALSE]), 1, max)
    exceeds <- worst > threshold
    x_exceed <- sum(exceeds)
    interval <- wilson(x_exceed, n)
    rows[[scope]] <- data.frame(
      time_scope = scope, n_hospitals = n,
      integrated_absolute_bias = mean(abs(bias_v)),
      integrated_absolute_bias_mcse_bootstrap = sd(boot_abs_bias),
      integrated_absolute_median_bias = mean(abs(median_v)),
      integrated_rmse = mean(rmse_v),
      integrated_rmse_mcse_bootstrap = sd(boot_rmse),
      integrated_coverage_percent = mean(coverage_v),
      integrated_coverage_mcse_bootstrap = sd(boot_cover),
      interval_width_integrated_mean = mean(colMeans(width[, j, drop = FALSE])),
      interval_width_integrated_median = mean(apply(width[, j, drop = FALSE], 2, median)),
      max_abs_error_scope = c("t = 5" = "t = 5", "averaged over t" = "any t (maximum over v and t)")[[scope]],
      n_hospitals_max_abs_error_gt_0.5 = x_exceed,
      proportion_max_abs_error_gt_0.5 = x_exceed / n,
      proportion_wilson_ci95_lower = interval[1],
      proportion_wilson_ci95_upper = interval[2],
      n_missing_estimates = sum(is.na(estimate[, j])))
    replicates[[scope]] <- list(
      integrated_absolute_bias = boot_abs_bias, integrated_rmse = boot_rmse,
      integrated_coverage_percent = boot_cover, interval_width_integrated_mean = boot_width,
      proportion_max_abs_error_gt_0.5 = as.vector(counts %*% exceeds) / n,
      mean_estimate = rowMeans(counts %*% estimate[, j, drop = FALSE] / n))
  }
  list(rows = do.call(rbind, rows), replicates = replicates, estimate = estimate)
}

# Same rows as a paired table: variant minus reference, with percentile intervals
paired_rows <- function(setting, estimator, label_a, label_b, a, b, scopes) {
  metrics <- c("integrated_absolute_bias", "integrated_rmse", "integrated_coverage_percent",
               "interval_width_integrated_mean", "proportion_max_abs_error_gt_0.5")
  rows <- list()
  for (scope in names(scopes)) {
    ra <- a$rows[a$rows$time_scope == scope, ]
    rb <- b$rows[b$rows$time_scope == scope, ]
    for (metric in c(metrics, "mean_estimate")) {
      boot <- a$replicates[[scope]][[metric]] - b$replicates[[scope]][[metric]]
      if (metric == "mean_estimate") {
        j <- scopes[[scope]]
        value_a <- mean(a$estimate[, j])
        value_b <- mean(b$estimate[, j])
      } else {
        value_a <- ra[[metric]]
        value_b <- rb[[metric]]
      }
      rows[[length(rows) + 1]] <- data.frame(
        setting = setting, estimator = estimator, variant_a = label_a, variant_b = label_b,
        time_scope = scope,
        metric = if (metric == "proportion_max_abs_error_gt_0.5" && scope == "averaged over t") {
          "proportion_max_abs_error_gt_0.5_at_any_t"
        } else metric,
        value_a = value_a, value_b = value_b, difference_a_minus_b = value_a - value_b,
        difference_mcse_bootstrap = sd(boot),
        difference_ci95_lower = unname(quantile(boot, 0.025)),
        difference_ci95_upper = unname(quantile(boot, 0.975)))
    }
  }
  do.call(rbind, rows)
}

# Time to benefit, delta = 0.05, as in scripts/11: not reached by 5 years counts as 5.5
ttb_rows <- function(x, n, setting, estimator, variant, v_grid, times, truth) {
  rows <- list()
  for (p in c(1, 2, 3)) {
    pv <- which(abs(v_grid - p) < 1e-9)
    true_ttb <- time_to_benefit(truth[pv, , drop = FALSE], times, delta)
    y <- x[abs(x$v - p) < 1e-9, ]
    estimated <- time_to_benefit(matrix(y$estimate, nrow = n, byrow = TRUE), times, delta)
    reached <- !is.na(estimated)
    filled <- ifelse(reached, estimated, 5.5)
    rows[[length(rows) + 1]] <- data.frame(
      setting = setting, estimator = estimator, variant = variant, v = p, delta = delta,
      n_hospitals = n, true_time_to_benefit = true_ttb, median_estimated = median(filled),
      share_earlier = mean(filled < true_ttb), share_equal = mean(filled == true_ttb),
      share_later = mean(filled > true_ttb), share_not_reached_by_5y = mean(!reached))
  }
  do.call(rbind, rows)
}

round_numeric <- function(d) {
  d[] <- lapply(d, function(x) if (is.double(x)) round(x, 6) else x)
  d
}
