# Same-metric comparison: saved repo AIPCW against the independent script's aipcw, survival
# difference, repo signs flipped, setting C2, t = 5, v = 1, 2, 3. From saved rows, no refitting.
# Bootstrap intervals over hospitals (repo) or replicates (script).
#
# Run from the repository root:  Rscript independent_check/compare_with_repo.R
# Writes independent_check/comparison_C2_t5.csv

source("scripts/14_common.R")
set.seed(20261031)

curves <- read_chunks("results/phase2/C2")
repo <- curves[curves$estimator == "AIPCW" & curves$t == 5, ]
stopifnot(all(sapply(1:3, function(v) any(abs(repo$v - v) < 1e-9))))
truth <- read.csv("independent_check/output/truth.csv")
truth <- truth[truth$estimand == "surv", ]
script <- read.csv("independent_check/output/modeA_replicates.csv")
script <- script[script$estimand == "surv" & script$estimator == "aipcw", ]

summarise <- function(est, truth_v) {
  err <- est - truth_v
  n <- length(err)
  boots <- sapply(seq_len(n_boot), function(b) {
    e <- err[sample.int(n, n, replace = TRUE)]
    c(mean(e), median(e), sum(abs(e) > threshold))
  })
  q <- apply(boots, 1, quantile, c(0.025, 0.975))
  data.frame(n = n, mean_bias = mean(err), mean_bias_ci95_lower = q[1, 1], mean_bias_ci95_upper = q[2, 1],
             median_bias = median(err), median_bias_ci95_lower = q[1, 2], median_bias_ci95_upper = q[2, 2],
             empirical_sd = sd(est), mcse = sd(est) / sqrt(n), largest_absolute_error = max(abs(err)),
             count_abs_error_gt_0.5 = sum(abs(err) > threshold),
             count_ci95_lower = q[1, 3], count_ci95_upper = q[2, 3])
}

rows <- list()
for (v in 1:3) {
  truth_v <- truth$truth[truth$v == v]
  # The repo curve is a risk difference, so its sign is flipped to a survival difference
  rows[[length(rows) + 1]] <- cbind(source = "repo AIPCW", v = v, truth = truth_v,
                                    summarise(-repo$estimate[abs(repo$v - v) < 1e-9], truth_v))
  rows[[length(rows) + 1]] <- cbind(source = "script aipcw", v = v, truth = truth_v,
                                    summarise(script$est[script$v == v], truth_v))
}
out <- do.call(rbind, rows)
write.csv(round_numeric(out), "independent_check/comparison_C2_t5.csv", row.names = FALSE)
options(width = 200)
print(t(out), digits = 4)
