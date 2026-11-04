# Tables for the exploratory runs: metrics, paired differences against the reported estimator on
# the same seeds, controls, and warnings by fit. Runs that have not finished are skipped.
#
# Usage, from the repository root:  Rscript scripts/15_summarise_exploratory.R [folder] [tables]
#   folder: results/exploratory; tables: reports/tables. Files are named 15_*.csv.
#   A third argument, controls, stops after the controls and reads no performance.
# Stops if a control differs from the saved rows or a hospital failed.

args <- commandArgs(trailingOnly = TRUE)
folder <- if (length(args) >= 1) args[1] else file.path("results", "exploratory")
tables <- if (length(args) >= 2) args[2] else file.path("reports", "tables")
controls_only <- length(args) >= 3 && args[3] == "controls"
dir.create(tables, recursive = TRUE, showWarnings = FALSE)

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

prepare <- function(curves) {
  curves$truth <- truth[cbind(match(round(curves$v, 8), round(v_grid, 8)), match(curves$t, times))]
  curves[order(curves$seed, curves$t, curves$v), ]
}
read_part <- function(dir, part) {
  files <- list.files(dir, pattern = "^chunk_.*rds$", full.names = TRUE)
  do.call(rbind, lapply(files, function(f) readRDS(f)[[part]]))
}
covers <- function(lower, upper, centre, w = rep(1 / nrow(lower), nrow(lower))) {
  colSums(w * (sweep(lower, 2, centre, "<=") * sweep(upper, 2, centre, ">=")))
}
# Bias-eliminated coverage (Morris et al. 2019), centred on the median estimate: the median is
# recomputed in each resample
median_target <- function(x, n, counts) {
  estimate <- as_hospital_matrix(x, "estimate", n)
  lower <- as_hospital_matrix(x, "lower", n)
  upper <- as_hospital_matrix(x, "upper", n)
  value <- covers(lower, upper, apply(estimate, 2, median))
  boots <- sapply(seq_len(n_boot), function(b) {
    m <- covers(lower, upper, apply(estimate[rep(seq_len(n), counts[b, ]), , drop = FALSE], 2, median), counts[b, ] / n)
    sapply(scopes, function(j) mean(m[j]))
  })
  data.frame(time_scope = names(scopes), label = "exploratory",
             integrated_coverage_median_estimate_percent = 100 * sapply(scopes, function(j) mean(value[j])),
             integrated_coverage_median_estimate_mcse_bootstrap = 100 * apply(boots, 1, sd), row.names = NULL)
}

# Paired difference in integrated absolute median bias, the metric of the decision rule.
# Both medians are recomputed in each resample, on the same hospitals. Columns as paired_rows.
paired_median_bias <- function(setting, estimator, label_b, x, y, n, counts) {
  err_a <- as_hospital_matrix(x, "estimate", n) - as_hospital_matrix(x, "truth", n)
  err_b <- as_hospital_matrix(y, "estimate", n) - as_hospital_matrix(y, "truth", n)
  score <- function(err) {
    medians <- apply(err, 2, median)
    sapply(scopes, function(j) mean(abs(medians[j])))
  }
  value_a <- score(err_a)
  value_b <- score(err_b)
  boots <- sapply(seq_len(n_boot), function(b) {
    idx <- rep(seq_len(n), counts[b, ])
    score(err_a[idx, , drop = FALSE]) - score(err_b[idx, , drop = FALSE])
  })
  data.frame(setting = setting, estimator = estimator, variant_a = estimator, variant_b = label_b,
             time_scope = names(scopes), metric = "integrated_absolute_median_bias",
             value_a = value_a, value_b = value_b, difference_a_minus_b = value_a - value_b,
             difference_mcse_bootstrap = apply(boots, 1, sd),
             difference_ci95_lower = apply(boots, 1, quantile, 0.025),
             difference_ci95_upper = apply(boots, 1, quantile, 0.975), row.names = NULL)
}

# The decision rule in docs/exploratory_prespecification.md
margin <- 0.01
decide <- function(expected, lower, upper) {
  if (expected == "consistent") {
    if (upper < margin) "held" else if (lower > margin) "failed" else "not determined"
  } else {
    if (lower > margin) "held" else if (upper < margin) "failed" else "not determined"
  }
}
predictions <- data.frame(setting = c("C5a", "C5a", "C5b", "C5b", "C5b"),
                          estimator = c("AIPCW", "BJ", "AIPCW", "BJ", "IPCW"),
                          expected = c("consistent", "consistent", "biased", "biased", "biased"))

reference_setting <- c(C2 = "C2", C4 = "C4", C2m = "C2", C3m = "C3", C5a = "C2", C5b = "C2")
info_rows <- list()
warning_rows <- list()

dirs <- function(run) {
  found <- list.dirs(file.path(folder, run), recursive = FALSE, full.names = FALSE)
  found[vapply(file.path(folder, run, found), function(p) length(list.files(p, pattern = "^chunk_")) > 0, logical(1))]
}
read_run <- function(run, setting) {
  dir <- file.path(folder, run, setting)
  info <- read_part(dir, "info")
  if (any(info$failed != "")) {
    print(info[info$failed != "", ])
    stop("Failed hospitals in ", dir)
  }
  info_rows[[length(info_rows) + 1]] <<- cbind(run = run, setting = setting, info[, c("seed", "seconds", "commit")])
  w <- read_part(dir, "warnings")
  if (!is.null(w)) warning_rows[[length(warning_rows) + 1]] <<- cbind(run = run, setting = setting, w)
  list(curves = prepare(read_part(dir, "curves")), info = info)
}
saved_rows <- function(setting, seeds) {
  x <- read_chunks(file.path("results", "phase2", setting))
  prepare(x[x$seed %in% seeds, ])
}

# Controls
controls <- list()
compare <- function(new, saved, label_new, label_saved, setting, run) {
  a <- new[new$estimator == label_new, ]
  b <- saved[saved$estimator == label_saved, ]
  stopifnot(nrow(a) == nrow(b), identical(paste(a$seed, a$t, a$v), paste(b$seed, b$t, b$v)))
  data.frame(run = run, setting = setting, new = label_new, saved = label_saved, n_hospitals = length(unique(a$seed)),
             n_rows = nrow(a), largest_difference_estimate = max(abs(a$estimate - b$estimate)),
             largest_difference_interval = max(abs(a$lower - b$lower), abs(a$upper - b$upper)),
             bandwidth_differs_in_hospitals = length(unique(a$seed[a$h != b$h])))
}
for (setting in dirs("control")) {
  new <- read_run("control", setting)$curves
  saved <- saved_rows(setting, unique(new$seed))
  for (est in seven) controls[[length(controls) + 1]] <- compare(new, saved, est, est, setting, "control")
}
for (setting in dirs("zero")) {
  new <- read_run("zero", setting)$curves
  saved <- saved_rows(setting, unique(new$seed))
  for (type in c("IPCW", "AIPCW")) for (scheme in c("G", "p", "pG")) {
    controls[[length(controls) + 1]] <- compare(new, saved, paste(type, scheme, 0, sep = "_"), type, setting, "zero")
  }
}

score_rows <- list()
pair_rows <- list()
for (run in c("A", "B", "C")) {
  for (setting in dirs(run)) {
    res <- read_run(run, setting)
    curves <- res$curves
    n <- length(unique(curves$seed))
    counts <- resample_counts(n)
    saved <- saved_rows(reference_setting[[setting]], unique(curves$seed))
    if (run == "A") {
      for (type in c("IPCW", "AIPCW")) {
        controls[[length(controls) + 1]] <- compare(curves, saved, paste0(type, "_G_0.05"), paste0(type, "_t"), setting, "A")
      }
    }
    if (controls_only) next
    reference <- list()
    for (est in unique(curves$estimator)) {
      base <- sub("_(G|p|pG)_[0-9.]+$", "", est)
      if (is.null(reference[[base]])) {
        reference[[base]] <- score_estimator(saved[saved$estimator == base, ], n, scopes, counts)
      }
      x <- curves[curves$estimator == est, ]
      this <- score_estimator(x, n, scopes, counts)
      score_rows[[length(score_rows) + 1]] <- cbind(run = run, setting = setting, estimator = est, this$rows,
                                                    median_target(x, n, counts)[, 3:4])
      pair_rows[[length(pair_rows) + 1]] <- cbind(
        run = run, paired_rows(setting, est, est, sprintf("%s reported %s", base, reference_setting[[setting]]),
                               this, reference[[base]], scopes))
      if (run == "C") {
        m <- paired_median_bias(setting, est, sprintf("%s reported %s", base, reference_setting[[setting]]),
                                x, saved[saved$estimator == base, ], n, counts)
        stopifnot(max(abs(m$value_a - this$rows$integrated_absolute_median_bias)) < 1e-10)
        pair_rows[[length(pair_rows) + 1]] <- cbind(run = run, m)
      }
    }
  }
}

if (length(controls)) {
  controls <- do.call(rbind, controls)
  write.csv(controls, file.path(tables, "15_controls.csv"), row.names = FALSE)
  options(width = 180)
  print(controls, row.names = FALSE)
  if (any(controls$largest_difference_estimate != 0 | controls$largest_difference_interval != 0 |
          controls$bandwidth_differs_in_hospitals != 0)) stop("A control differs from the saved rows.")
}
if (controls_only) quit(save = "no")
if (length(score_rows)) {
  scores <- do.call(rbind, score_rows)
  pairs <- do.call(rbind, pair_rows)
  for (run in unique(scores$run)) {
    write.csv(round_numeric(scores[scores$run == run, ]), file.path(tables, sprintf("15_run%s_performance.csv", run)), row.names = FALSE)
    write.csv(round_numeric(pairs[pairs$run == run, ]), file.path(tables, sprintf("15_run%s_paired.csv", run)), row.names = FALSE)
  }
  if ("C" %in% scores$run) {
    rule <- pairs[pairs$metric == "integrated_absolute_median_bias" & pairs$time_scope == "t = 5", ]
    predictions <- merge(predictions, rule[, c("setting", "estimator", "value_a", "value_b", "difference_a_minus_b",
                                               "difference_ci95_lower", "difference_ci95_upper")],
                         by = c("setting", "estimator"))
    predictions$result <- mapply(decide, predictions$expected, predictions$difference_ci95_lower,
                                 predictions$difference_ci95_upper)
    write.csv(round_numeric(predictions), file.path(tables, "15_runC_predictions.csv"), row.names = FALSE)
    print(predictions, row.names = FALSE, digits = 4)
  }
}
info <- do.call(rbind, info_rows)
runs <- aggregate(seconds ~ run + setting, info, median)
names(runs)[3] <- "median_seconds"
runs$n_hospitals <- aggregate(seed ~ run + setting, info, length)$seed
runs$commit <- aggregate(commit ~ run + setting, info, function(x) paste(unique(x), collapse = ","))$commit
write.csv(runs, file.path(tables, "15_runs.csv"), row.names = FALSE)
print(runs, row.names = FALSE)

if (length(dirs("B"))) {
  rows <- lapply(dirs("B"), function(setting) {
    i <- read_part(file.path(folder, "B", setting), "info")
    data.frame(setting = setting, n_hospitals = nrow(i), mean_share_dropped = mean(i$share_dropped),
               mean_share_g5_below_0.05_estimated = mean(i$share_g5_below_0.05_estimated),
               mean_share_g5_below_0.05_true = mean(i$share_g5_below_0.05_true),
               smallest_chance_of_staying = min(i$min_g), median_of_hospital_smallest_chance = median(i$min_g))
  })
  b <- do.call(rbind, rows)
  write.csv(round_numeric(b), file.path(tables, "15_runB_dropout_summary.csv"), row.names = FALSE)
  print(b, row.names = FALSE, digits = 4)
}

if (length(warning_rows)) {
  w <- do.call(rbind, warning_rows)
  w$message <- gsub("[0-9]+(\\.[0-9]+)?(e-?[0-9]+)?", "#", w$message)
  w$t[is.na(w$t)] <- -1
  w$arm[is.na(w$arm)] <- -1
  tally <- aggregate(seed ~ run + setting + fit_type + estimators + t + arm + message, w, length)
  names(tally)[names(tally) == "seed"] <- "n_warnings"
  tally$n_hospitals <- aggregate(seed ~ run + setting + fit_type + estimators + t + arm + message, w,
                                 function(s) length(unique(s)))$seed
  tally$t[tally$t == -1] <- NA
  tally$arm[tally$arm == -1] <- NA
  write.csv(tally, file.path(tables, "15_warnings_by_fit.csv"), row.names = FALSE)
  print(aggregate(n_warnings ~ run + setting + fit_type + estimators + message, tally, sum), row.names = FALSE)
}
