# Step 2a, check 4: how far are the outcome helpers from the true conditional risk at t = 5?
# The outcome models for CC, NE and IPCW are logistic while the generator has a complementary
# log-log form; the Weibull helper has the true form. No estimator is changed.
#
# RMSE: square root of the mean squared difference over all eligible patients of a hospital, then
# averaged over hospitals. Predictions are the cross-fitted ones the estimators use.
#
# Usage, from the repository root:  Rscript scripts/14_check_helpers.R <n_hospitals> <workers>
# Writes reports/tables/14_helper_specification.csv

args <- commandArgs(trailingOnly = TRUE)
n_hospitals <- as.integer(args[1])
workers <- as.integer(args[2])

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)
future::plan(future::multisession, workers = workers)

one_hospital <- function(seed, setting) {
  for (f in c("generate", "truth", "nuisance", "pseudo", "smooth", "phase2_generate", "phase2_truth",
              "phase2_estimators")) source(sprintf("R/%s.R", f))
  cfg <- load_config("config/phase2.yaml")
  b0 <- participation_intercept(cfg)
  censoring <- c(C0 = "none", C2 = "dependent")[[setting]]
  d <- simulate_cohort_surv(cfg, censoring, seed = seed, b0 = b0)$observed
  times <- unlist(cfg$times)
  t <- 5
  j <- match(t, times)
  warned <- 0
  rows <- tryCatch(withCallingHandlers({
    h <- fit_phase2_helpers(d, times, ~ a + frailty + v + male, cfg$follow_up_end, seed = seed)
    st <- status_at(d, t)
    keep <- d$s == 0 | st$known
    dcc <- d[keep, ]
    dcc$y <- st$y[keep]
    cc <- fit_nuisance(dcc, "glm", seed = seed)
    dne <- d
    dne$y <- ifelse(d$s == 1, st$y, NA)
    ne <- fit_nuisance(dne, "glm", seed = seed)
    do.call(rbind, lapply(1:0, function(arm) {
      truth <- event_risk(arm, t, d$frailty, d$v, d$male, cfg)
      rmse <- function(pred, who = rep(TRUE, nrow(d))) sqrt(mean((pred - truth[who])^2))
      bias <- function(pred, who = rep(TRUE, nrow(d))) mean(pred - truth[who])
      pick <- function(g1, g0) if (arm == 1) g1 else g0
      helpers <- list(
        logistic_CC = list(pick(cc$g1, cc$g0), keep),
        logistic_NE = list(pick(ne$g1, ne$g0), rep(TRUE, nrow(d))),
        logistic_IPCW = list(pick(h$ipcw_g1[, j], h$ipcw_g0[, j]), rep(TRUE, nrow(d))),
        logistic_IPCW_t = list(pick(h$ipcw_g1_t[, j], h$ipcw_g0_t[, j]), rep(TRUE, nrow(d))),
        weibull_AIPCW = list(1 - weibull_surv(t, pick(h$lp1, h$lp0), pick(h$scale1, h$scale0)), rep(TRUE, nrow(d))))
      do.call(rbind, lapply(names(helpers), function(n) {
        data.frame(seed = seed, setting = setting, arm = arm, helper = n,
                   rmse = rmse(helpers[[n]][[1]], helpers[[n]][[2]]),
                   mean_error = bias(helpers[[n]][[1]], helpers[[n]][[2]]))
      }))
    }))
  }, warning = function(w) {
    warned <<- warned + 1
    invokeRestart("muffleWarning")
  }), error = function(e) e)
  if (inherits(rows, "error")) return(data.frame(seed = seed, setting = setting, failed = conditionMessage(rows)))
  rows$n_warnings <- warned
  rows
}

all_rows <- list()
for (setting in c("C0", "C2")) {
  all_rows[[setting]] <- future.apply::future_lapply(seq_len(n_hospitals), one_hospital, setting = setting,
                                                     future.seed = TRUE)
}
rows <- do.call(rbind, unlist(all_rows, recursive = FALSE))
if ("failed" %in% names(rows)) {
  print(rows)
  stop("A helper fit failed.")
}
out <- aggregate(cbind(rmse, mean_error) ~ setting + arm + helper, rows, mean)
out$rmse_mcse <- aggregate(rmse ~ setting + arm + helper, rows, function(x) sd(x) / sqrt(length(x)))$rmse
out$n_hospitals <- n_hospitals
out$total_warnings <- aggregate(n_warnings ~ setting + arm + helper, rows, sum)$n_warnings
out$commit <- commit
names(out)[names(out) == "rmse"] <- "integrated_rmse"
out <- out[order(out$setting, -out$arm, out$helper), ]
options(width = 160)
print(out, row.names = FALSE, digits = 4)
write.csv(out, "reports/tables/14_helper_specification.csv", row.names = FALSE)

# Paired by hospital: logistic RMSE minus Weibull RMSE, with bootstrap intervals over hospitals
source("scripts/14_common.R")
set.seed(20261031)
counts <- resample_counts(n_hospitals)
pairs <- list()
for (setting in c("C0", "C2")) for (arm in 1:0) for (n in setdiff(unique(rows$helper), "weibull_AIPCW")) {
  this <- rows[rows$setting == setting & rows$arm == arm, ]
  logistic <- this[this$helper == n, ]
  weibull <- this[this$helper == "weibull_AIPCW", ]
  gap <- logistic$rmse - weibull$rmse[match(logistic$seed, weibull$seed)]
  boot <- as.vector(counts %*% gap) / n_hospitals
  pairs[[length(pairs) + 1]] <- data.frame(
    setting = setting, arm = arm, helper = n, n_hospitals = n_hospitals,
    mean_rmse_difference_logistic_minus_weibull = mean(gap),
    difference_ci95_lower = unname(quantile(boot, 0.025)),
    difference_ci95_upper = unname(quantile(boot, 0.975)),
    n_hospitals_logistic_worse = sum(gap > 0), commit = commit)
}
pairs <- do.call(rbind, pairs)
print(pairs, row.names = FALSE, digits = 4)
write.csv(round_numeric(pairs), "reports/tables/14_helper_specification_paired.csv", row.names = FALSE)
