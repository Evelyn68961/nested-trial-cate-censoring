# Step 7 summary: score each estimator against the truth, for every finished setting.
#
# For each estimator and grid value v, across hospitals:
#   bias      mean(estimate) - truth
#   RMSE      sqrt(mean((estimate - truth)^2))
#   coverage  share of 95% intervals that contain the truth
# "Integrated" = averaged over the 37 grid values, as in the paper's Table 1.
# The truth is the target curve (all eligible patients) for every estimator. For T, coverage
# of its own trial-population curve is also reported. For P, coverage of the smoothed target
# theta*(v), computed with each hospital's own bandwidth, is reported as the paper does.
#
# Run from the repository root:  Rscript scripts/08_summarise_phase1.R

source("R/generate.R")
source("R/truth.R")
source("R/smooth.R")
library(ggplot2)

cfg0 <- load_config("config/phase1.yaml")
v_grid <- make_v_grid(cfg0)
u <- seq(0, 4, length.out = 801)
target_u <- target_effect(u, cfg0)
target_grid <- target_effect(v_grid, cfg0)
bandwidths <- seq(0.3, 2.0, by = 0.1)
smoothed_P <- sapply(bandwidths, function(h) smoothed_curve(u, target_u, rep(1, length(u)), v_grid, h))

settings <- list.dirs(file.path("results", "phase1"), recursive = FALSE, full.names = FALSE)
tables <- list()
for (setting in settings) {
  files <- list.files(file.path("results", "phase1", setting), pattern = "^chunk_.*rds$", full.names = TRUE)
  if (length(files) == 0) next
  parts <- lapply(files, readRDS)
  curves <- do.call(rbind, lapply(parts, `[[`, "curves"))
  info <- do.call(rbind, lapply(parts, `[[`, "info"))

  cfg <- cfg0
  cfg$trial_fraction <- as.numeric(sub(".*_trial", "", setting)) / 100
  b0 <- participation_intercept(cfg)
  trial_grid <- trial_effect(v_grid, cfg, b0)

  grid_index <- match(round(curves$v, 8), round(v_grid, 8))
  curves$truth <- target_grid[grid_index]
  curves$trial_truth <- trial_grid[grid_index]
  curves$smoothed_truth <- NA_real_
  is_P <- curves$estimator == "P"
  curves$smoothed_truth[is_P] <- smoothed_P[cbind(grid_index[is_P], match(round(curves$h[is_P], 2), round(bandwidths, 2)))]

  per_v <- do.call(rbind, lapply(split(curves, list(curves$estimator, curves$v), drop = TRUE), function(x) {
    data.frame(estimator = x$estimator[1], v = x$v[1], truth = x$truth[1], trial_truth = x$trial_truth[1],
               mean_estimate = mean(x$estimate, na.rm = TRUE),
               bias = mean(x$estimate - x$truth, na.rm = TRUE),
               bias_mcse = sd(x$estimate, na.rm = TRUE) / sqrt(sum(!is.na(x$estimate))),
               rmse = sqrt(mean((x$estimate - x$truth)^2, na.rm = TRUE)),
               coverage = mean(x$lower <= x$truth & x$truth <= x$upper),
               coverage_smoothed = mean(x$lower <= x$smoothed_truth & x$smoothed_truth <= x$upper),
               coverage_trial_curve = mean(x$lower <= x$trial_truth & x$trial_truth <= x$upper),
               missing = sum(is.na(x$estimate)))
  }))
  write.csv(per_v, file.path("reports", "tables", sprintf("07_%s_by_v.csv", setting)), row.names = FALSE)

  summary <- do.call(rbind, lapply(split(per_v, per_v$estimator), function(x) {
    data.frame(setting = setting, hospitals = nrow(info), estimator = x$estimator[1],
               integrated_abs_bias = round(mean(abs(x$bias)), 3),
               integrated_rmse = round(mean(x$rmse), 3),
               integrated_coverage = round(100 * mean(x$coverage), 1),
               coverage_smoothed = round(100 * mean(x$coverage_smoothed), 1),
               coverage_trial_curve = round(100 * mean(x$coverage_trial_curve), 1),
               missing_estimates = sum(x$missing))
  }))
  summary <- summary[match(c("P", "L", "T", "G"), summary$estimator), ]
  summary$integrated_coverage[summary$estimator == "G"] <- NA
  summary$coverage_smoothed[summary$estimator != "P"] <- NA
  summary$coverage_trial_curve[summary$estimator != "T"] <- NA
  tables[[setting]] <- summary

  cat(sprintf("\n%s: %d hospitals, mean trial size %.0f, median bandwidth P %.1f, median seconds %.1f, commits %s\n",
              setting, nrow(info), mean(info$n_trial), median(info$h_P), median(info$seconds),
              paste(unique(info$commit), collapse = ",")))
  print(summary[, -1], row.names = FALSE)

  plot_data <- per_v[per_v$estimator %in% c("P", "L", "T", "G"), ]
  plot_data$estimator <- factor(plot_data$estimator, levels = c("P", "L", "T", "G"),
                                labels = c("P: paper's method", "L: straight line", "T: trial only", "G: outcome model alone"))
  p <- ggplot(plot_data, aes(v)) +
    geom_hline(yintercept = 0, colour = "grey75") +
    geom_line(aes(y = truth), linetype = "dashed") +
    geom_line(aes(y = mean_estimate), colour = "steelblue", linewidth = 0.8) +
    facet_wrap(~estimator, nrow = 1) +
    labs(x = "Profile value v", y = "Risk difference",
         title = sprintf("Average estimated curve over %d hospitals (blue) against the true target curve (dashed)", nrow(info)),
         subtitle = setting) +
    theme_minimal(base_size = 10)
  ggsave(file.path("reports", "figures", sprintf("07_%s_mean_curves.png", setting)), p, width = 10, height = 3.4, dpi = 150)
}
if (length(tables)) write.csv(do.call(rbind, tables), "reports/tables/07_phase1_summary.csv", row.names = FALSE)
