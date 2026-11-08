source(file.path("..", "..", "R", "generate.R"))
source(file.path("..", "..", "R", "nuisance.R"))
source(file.path("..", "..", "R", "pseudo.R"))
source(file.path("..", "..", "R", "smooth.R"))
source(file.path("..", "..", "R", "phase2_generate.R"))
source(file.path("..", "..", "R", "phase2_truth.R"))
source(file.path("..", "..", "R", "phase2_estimators.R"))

cfg <- load_config(file.path("..", "..", "config", "phase2.yaml"))
b0 <- participation_intercept(cfg)

test_that("dropout happens only when it should, and more among treated when dependent", {
  none <- simulate_cohort_surv(cfg, "none", 1, b0)$observed
  tr <- none[none$s == 1, ]
  expect_true(all(tr$event == 1 | tr$time == cfg$follow_up_end))

  dep <- simulate_cohort_surv(cfg, "dependent", 1, b0)$observed
  tr <- dep[dep$s == 1, ]
  dropped <- tr$event == 0 & tr$time < cfg$follow_up_end
  expect_gt(mean(dropped[tr$a == 1]), mean(dropped[tr$a == 0]))
  expect_gt(mean(dropped), 0.1)
})

test_that("exact effect curve over time agrees with true event times in a large cohort", {
  big <- cfg
  big$cohort_size <- 1e6
  h <- simulate_cohort_surv(big, "none", 3, b0)
  near <- abs(h$observed$v - 2) < 0.05
  for (t in c(1, 3, 5)) {
    mc <- mean(h$hidden$t1[near] <= t) - mean(h$hidden$t0[near] <= t)
    expect_lt(abs(target_effect_t(2, t, cfg) - mc), 0.01)
  }
})

test_that("time to benefit is the first time the effect reaches -delta", {
  eff <- rbind(c(0.1, -0.02, -0.06, -0.1), c(0.1, 0.05, 0.02, 0))
  expect_equal(time_to_benefit(eff, c(1, 2, 3, 4), 0.05), c(3, NA))
})

# True helper values for the AIPCW check, in survreg's Weibull form:
# S(u) = exp(-(u / exp(lp))^(1 / scale))
oracle_helpers <- function(sim, censoring) {
  o <- sim$observed
  b <- cfg$baseline
  e <- cfg$effect
  lp0 <- b$intercept + b$frailty * o$frailty + b$v * o$v + b$male * o$male
  eff <- e$intercept + e$v * o$v + e$v_squared * o$v^2 + e$frailty * o$frailty
  cen <- cfg$censoring[[censoring]]
  a0 <- ifelse(is.na(o$a), 0, o$a)
  rate <- cen$base_rate * exp(cen$frailty * o$frailty + cen$treated * a0)
  n <- nrow(o)   # one value per patient, as the fitted helpers store them
  list(lp1 = -(lp0 + eff) / cfg$shape_treated, scale1 = rep(1 / cfg$shape_treated, n),
       lp0 = -lp0 / cfg$shape_untreated, scale0 = rep(1 / cfg$shape_untreated, n),
       cens_lp = -log(rate), cens_scale = rep(1, n))
}

big <- cfg
big$cohort_size <- 600000
sim <- simulate_cohort_surv(big, "dependent", 5, b0)
tr <- sim$observed$s == 1
treated <- tr & sim$observed$a == 1
t <- 3
truth_treated <- mean(sim$hidden$t1[treated] <= t)
# Limit: 3 Monte Carlo standard errors plus 0.002. Strong dependent dropout gives some
# patients very large weights, so a fixed limit would fail on noise alone (docs/LOG.md).
within <- function(ystar) 3 * sd(ystar[treated]) / sqrt(sum(treated)) + 0.002

test_that("AIPCW status averages to the true risk with both helpers right", {
  ystar <- augmented_status(sim$observed, t, oracle_helpers(sim, "dependent"))
  expect_lt(abs(mean(ystar[treated]) - truth_treated), within(ystar))
})

test_that("AIPCW status is still right with a wrong outcome model", {
  h <- oracle_helpers(sim, "dependent")
  h$lp1 <- rep(mean(h$lp1[treated]), length(h$lp1))   # ignores every patient characteristic
  ystar <- augmented_status(sim$observed, t, h)
  expect_lt(abs(mean(ystar[treated]) - truth_treated), within(ystar))
})

test_that("AIPCW status is still right with a wrong dropout model", {
  h <- oracle_helpers(sim, "dependent")
  h$cens_lp <- rep(mean(h$cens_lp[treated]), length(h$cens_lp))   # same dropout rate for all
  ystar <- augmented_status(sim$observed, t, h)
  expect_lt(abs(mean(ystar[treated]) - truth_treated), within(ystar))
})

test_that("with both wrong, AIPCW status is off; so is counting dropouts as event-free", {
  h <- oracle_helpers(sim, "dependent")
  h$lp1 <- rep(mean(h$lp1[treated]), length(h$lp1))
  h$cens_lp <- rep(Inf, length(h$cens_lp))   # pretends nobody drops out
  ystar <- augmented_status(sim$observed, t, h)
  expect_gt(abs(mean(ystar[treated]) - truth_treated), within(ystar))
  st <- status_at(sim$observed[treated, ], t)
  expect_lt(mean(st$y), truth_treated - 0.01)
})

test_that("BJ equals AIPCW when G = 1 (does not test AIPCW's dropout terms)", {
  h <- oracle_helpers(sim, "dependent")
  bj <- augmented_status(sim$observed, t, h, use_dropout_model = FALSE)
  h_off <- h
  h_off$cens_lp <- rep(Inf, length(h$cens_lp))   # chance of staying = 1 for everyone
  expect_equal(bj, augmented_status(sim$observed, t, h_off))
})

test_that("Buckley-James status is right with the right outcome model, wrong with a wrong one", {
  h <- oracle_helpers(sim, "dependent")
  bj <- augmented_status(sim$observed, t, h, use_dropout_model = FALSE)
  expect_lt(abs(mean(bj[treated]) - truth_treated), within(bj))
  h$lp1 <- rep(mean(h$lp1[treated]), length(h$lp1))
  bj_wrong <- augmented_status(sim$observed, t, h, use_dropout_model = FALSE)
  expect_gt(abs(mean(bj_wrong[treated]) - truth_treated), within(bj_wrong))
})

test_that("with no dropout (G = 1), BJ gives the same curve as AIPCW, and the weight checks are near 1", {
  d0 <- simulate_cohort_surv(cfg, "none", 11, b0)$observed
  small <- cfg
  small$times <- list(1, 5)
  res <- suppressWarnings(run_phase2_estimators(d0, small, ~ a + frailty + v + male, 11,
                                                c(1, 2, 3), bandwidths = 1))
  cv <- res$curves
  expect_equal(cv$estimate[cv$estimator == "BJ"], cv$estimate[cv$estimator == "AIPCW"])
  w <- res$info
  for (k in c("mean_w_join", "mean_w_arm1", "mean_w_arm0", "mean_wc_arm1", "mean_wc_arm0")) {
    expect_lt(abs(w[[k]] - 1), 0.3)
  }
  expect_equal(w$mean_wc_arm1, w$mean_w_arm1)   # nobody drops out, so status is always known
})

# Tests added after the 8 November 2026 recheck: paths the tests above do not reach.

test_that("pseudo_from_status with the observed status equals the Phase 1 pseudo-outcome", {
  d <- simulate_cohort(load_config(file.path("..", "..", "config", "phase1.yaml")), seed = 3, b0 = b0)$observed
  set.seed(3)
  n <- nrow(d)
  nu <- data.frame(p_join = runif(n, 0.05, 0.9), p_treat = runif(n, 0.3, 0.7), g1 = runif(n), g0 = runif(n))
  y0 <- ifelse(is.na(d$y), 0, d$y)
  expect_equal(pseudo_from_status(d, y0, nu$p_join, nu$p_treat, nu$g1, nu$g0), pseudo_outcome(d, nu))
})

test_that("cross-fitted helpers for a fold do not use that fold's patients", {
  d <- simulate_cohort_surv(cfg, "dependent", 11, b0)$observed
  folds <- make_folds(d$s, 5, 11)
  fit <- function(x) suppressWarnings(fit_phase2_helpers(x, c(1, 5), ~ a + frailty + v + male, cfg$follow_up_end, seed = 11))
  h <- fit(d)
  # Change the follow-up of fold 1's trial patients only; their own predictions must not move
  d2 <- d
  k <- which(folds == 1 & d$s == 1)
  d2$event[k] <- 1L - d2$event[k]
  d2$time[k] <- d2$time[k] * 0.7
  h2 <- fit(d2)
  same <- folds == 1
  for (key in c("p_join", "p_treat", "cens_lp", "lp1", "lp0")) expect_equal(h2[[key]][same], h[[key]][same])
  for (key in c("ipcw_g1", "ipcw_g0", "ipcw_g1_t", "ipcw_g0_t")) expect_equal(h2[[key]][same, ], h[[key]][same, ])
  # The change does reach the other folds, so the test can fail
  for (key in c("cens_lp", "lp1", "lp0")) expect_gt(max(abs(h2[[key]][!same] - h[[key]][!same])), 1e-6)
})

dep <- simulate_cohort_surv(cfg, "dependent", 12, b0)$observed
small2 <- cfg
small2$times <- list(1, 5)
run_dep <- function(g_floor) suppressWarnings(run_phase2_estimators(dep, small2, ~ a + frailty + v + male, 12,
                                                                    c(1, 2, 3), bandwidths = 1, g_floor = g_floor)$curves)

test_that("with no floor, the truncated estimators equal the untruncated ones", {
  cv <- run_dep(0)
  expect_equal(cv$estimate[cv$estimator == "IPCW_t"], cv$estimate[cv$estimator == "IPCW"])
  expect_equal(cv$estimate[cv$estimator == "AIPCW_t"], cv$estimate[cv$estimator == "AIPCW"])
})

test_that("a floor that binds changes the truncated estimators and leaves the others", {
  cv0 <- run_dep(0)
  cv <- run_dep(0.5)
  for (e in c("CC", "NE", "IPCW", "AIPCW", "BJ")) {
    expect_equal(cv$estimate[cv$estimator == e], cv0$estimate[cv0$estimator == e])
  }
  for (e in c("IPCW_t", "AIPCW_t")) {
    expect_gt(max(abs(cv$estimate[cv$estimator == e] - cv0$estimate[cv0$estimator == e])), 1e-6)
  }
})

test_that("with no dropout, IPCW gives the same curve as NE and CC", {
  d0 <- simulate_cohort_surv(cfg, "none", 11, b0)$observed
  cv <- suppressWarnings(run_phase2_estimators(d0, small2, ~ a + frailty + v + male, 11, c(1, 2, 3), bandwidths = 1)$curves)
  expect_equal(cv$estimate[cv$estimator == "IPCW"], cv$estimate[cv$estimator == "NE"], tolerance = 1e-8)
  expect_equal(cv$estimate[cv$estimator == "IPCW"], cv$estimate[cv$estimator == "CC"], tolerance = 1e-8)
})

test_that("the floor on G reaches IPCW's weighted outcome models only in the truncated version", {
  fit <- function(f) suppressWarnings(fit_phase2_helpers(dep, c(1, 5), ~ a + frailty + v + male, cfg$follow_up_end,
                                                         seed = 12, g_floor = f))
  h0 <- fit(0)
  h <- fit(0.5)
  expect_equal(h0$ipcw_g1_t, h0$ipcw_g1)
  expect_equal(h$ipcw_g1, h0$ipcw_g1)
  expect_gt(max(abs(h$ipcw_g1_t - h$ipcw_g1)), 1e-6)
})

test_that("IPCW and truncated IPCW curves follow their definitions", {
  f <- 0.5
  h <- suppressWarnings(fit_phase2_helpers(dep, c(1, 5), ~ a + frailty + v + male, cfg$follow_up_end, seed = 12, g_floor = f))
  cv <- run_dep(f)
  for (j in 1:2) {
    t <- unlist(small2$times)[j]
    st <- status_at(dep, t)
    g_end <- weibull_surv(pmin(dep$time, t), h$cens_lp, h$cens_scale)
    ystar <- ifelse(dep$s == 1, st$known * st$y / g_end, 0)
    ystar_t <- ifelse(dep$s == 1, st$known * st$y / pmax(g_end, f), 0)
    by_hand <- function(y, g1, g0) local_linear(dep$v, pseudo_from_status(dep, y, h$p_join, h$p_treat, g1, g0), c(1, 2, 3), 1)$estimate
    expect_equal(cv$estimate[cv$estimator == "IPCW" & cv$t == t], by_hand(ystar, h$ipcw_g1[, j], h$ipcw_g0[, j]))
    expect_equal(cv$estimate[cv$estimator == "IPCW_t" & cv$t == t], by_hand(ystar_t, h$ipcw_g1_t[, j], h$ipcw_g0_t[, j]))
  }
})
