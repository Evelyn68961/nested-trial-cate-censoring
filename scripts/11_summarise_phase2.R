# Phase 2 summary: score the four dropout estimators against the truth at each follow-up time,
# and compare estimated with true time to benefit for three profiles.
# Run from the repository root:  Rscript scripts/11_summarise_phase2.R

for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
library(ggplot2)

cfg <- load_config("config/phase2.yaml")
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
truth <- target_effect_grid(v_grid, times, cfg)
profiles <- c(1, 2, 3)
deltas <- c(0.05, 0.10)
estimators <- c("CC", "NE", "IPCW", "AIPCW")
labels <- c(C0 = "C0 no dropout", C1 = "C1 random dropout", C2 = "C2 dependent dropout",
            C3 = "C3 dependent dropout, dropout model wrong")

settings <- intersect(names(labels), list.dirs(file.path("results", "phase2"), recursive = FALSE, full.names = FALSE))
by_time <- list()
ttb_rows <- list()
for (setting in settings) {
  files <- list.files(file.path("results", "phase2", setting), pattern = "^chunk_.*rds$", full.names = TRUE)
  if (!length(files)) next
  parts <- lapply(files, readRDS)
  curves <- do.call(rbind, lapply(parts, `[[`, "curves"))
  info <- do.call(rbind, lapply(parts, `[[`, "info"))
  vi <- match(round(curves$v, 8), round(v_grid, 8))
  ti <- match(curves$t, times)
  curves$truth <- truth[cbind(vi, ti)]

  cat(sprintf("\n%s: %d hospitals; %.0f%% of trial patients dropped out on average; median %.0f s per hospital; commits %s\n",
              labels[setting], nrow(info), 100 * mean(info$share_dropped), median(info$seconds),
              paste(unique(info$commit), collapse = ",")))

  per <- do.call(rbind, lapply(split(curves, list(curves$estimator, curves$t, curves$v), drop = TRUE), function(x) {
    data.frame(estimator = x$estimator[1], t = x$t[1], v = x$v[1], truth = x$truth[1],
               mean_estimate = mean(x$estimate), bias = mean(x$estimate - x$truth),
               rmse = sqrt(mean((x$estimate - x$truth)^2)),
               coverage = mean(x$lower <= x$truth & x$truth <= x$upper))
  }))
  summ <- do.call(rbind, lapply(split(per, list(per$estimator, per$t), drop = TRUE), function(x) {
    data.frame(setting = setting, estimator = x$estimator[1], t = x$t[1],
               integrated_abs_bias = mean(abs(x$bias)), integrated_rmse = mean(x$rmse),
               integrated_coverage = 100 * mean(x$coverage))
  }))
  by_time[[setting]] <- summ

  overall <- do.call(rbind, lapply(split(summ, summ$estimator), function(x) {
    data.frame(estimator = x$estimator[1],
               abs_bias_avg_over_t = round(mean(x$integrated_abs_bias), 3),
               rmse_avg_over_t = round(mean(x$integrated_rmse), 3),
               coverage_avg_over_t = round(mean(x$integrated_coverage), 1),
               abs_bias_at_5y = round(x$integrated_abs_bias[x$t == 5], 3),
               coverage_at_5y = round(x$integrated_coverage[x$t == 5], 1))
  }))
  print(overall[match(estimators, overall$estimator), ], row.names = FALSE)

  # Time to benefit by profile
  for (p in profiles) {
    pv <- which(abs(v_grid - p) < 1e-9)
    for (dl in deltas) {
      true_ttb <- time_to_benefit(truth[pv, , drop = FALSE], times, dl)
      for (est in estimators) {
        x <- curves[curves$estimator == est & abs(curves$v - p) < 1e-9, ]
        m <- tapply(seq_len(nrow(x)), x$seed, function(i) {
          e <- x$estimate[i][order(x$t[i])]
          time_to_benefit(matrix(e, nrow = 1), times, dl)
        })
        m <- unlist(m)
        never <- 5.5   # "not reached by 5 years" counted as 5.5 for distances
        ttb_rows[[length(ttb_rows) + 1]] <- data.frame(
          setting = setting, profile_v = p, delta = dl, estimator = est,
          true_ttb = true_ttb, median_estimated = median(ifelse(is.na(m), never, m)),
          share_within_half_year = round(mean(abs(ifelse(is.na(m), never, m) -
                                                    ifelse(is.na(true_ttb), never, true_ttb)) <= 0.5), 2),
          share_never_reached = round(mean(is.na(m)), 2))
      }
    }
  }

  # Figure: mean estimated effect over follow-up for three profiles, against the truth
  fig <- per[abs(per$v - 1) < 1e-9 | abs(per$v - 2) < 1e-9 | abs(per$v - 3) < 1e-9, ]
  fig$profile <- factor(sprintf("v = %.0f", fig$v))
  fig$estimator <- factor(fig$estimator, levels = estimators)
  p <- ggplot(fig, aes(t, colour = profile)) +
    geom_hline(yintercept = 0, colour = "grey75") +
    geom_line(aes(y = truth), linetype = "dashed") +
    geom_line(aes(y = mean_estimate), linewidth = 0.8) +
    geom_point(aes(y = mean_estimate), size = 1) +
    facet_wrap(~estimator, nrow = 1) +
    labs(x = "Years since treatment start", y = "Risk difference (treated minus untreated)", colour = NULL,
         title = sprintf("%s: average estimate over %d hospitals (solid) against the truth (dashed)",
                         labels[setting], nrow(info))) +
    theme_minimal(base_size = 10) + theme(legend.position = "bottom")
  ggsave(file.path("reports", "figures", sprintf("10_%s_effect_over_time.png", setting)), p,
         width = 10, height = 3.8, dpi = 150)
}
if (length(by_time)) {
  out <- do.call(rbind, by_time)
  out[, 4:6] <- round(out[, 4:6], 3)
  write.csv(out, "reports/tables/10_phase2_by_time.csv", row.names = FALSE)
}
if (length(ttb_rows)) {
  ttb <- do.call(rbind, ttb_rows)
  write.csv(ttb, "reports/tables/10_phase2_time_to_benefit.csv", row.names = FALSE)
  cat("\nTime to benefit (years), delta = 0.05:\n")
  print(ttb[ttb$delta == 0.05, -3], row.names = FALSE)
}
