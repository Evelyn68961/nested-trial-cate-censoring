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

test_that("AIPCW status averages to the true risk with both helpers right", {
  ystar <- augmented_status(sim$observed, t, oracle_helpers(sim, "dependent"))
  expect_lt(abs(mean(ystar[treated]) - truth_treated), 0.01)
})

test_that("AIPCW status is still right with a wrong outcome model", {
  h <- oracle_helpers(sim, "dependent")
  h$lp1 <- rep(mean(h$lp1[treated]), length(h$lp1))   # ignores every patient characteristic
  ystar <- augmented_status(sim$observed, t, h)
  expect_lt(abs(mean(ystar[treated]) - truth_treated), 0.01)
})

test_that("AIPCW status is still right with a wrong dropout model", {
  h <- oracle_helpers(sim, "dependent")
  h$cens_lp <- rep(mean(h$cens_lp[treated]), length(h$cens_lp))   # same dropout rate for all
  ystar <- augmented_status(sim$observed, t, h)
  expect_lt(abs(mean(ystar[treated]) - truth_treated), 0.01)
})

test_that("with both wrong, AIPCW status is off; so is counting dropouts as event-free", {
  h <- oracle_helpers(sim, "dependent")
  h$lp1 <- rep(mean(h$lp1[treated]), length(h$lp1))
  h$cens_lp <- rep(Inf, length(h$cens_lp))   # pretends nobody drops out
  ystar <- augmented_status(sim$observed, t, h)
  expect_gt(abs(mean(ystar[treated]) - truth_treated), 0.01)
  st <- status_at(sim$observed[treated, ], t)
  expect_lt(mean(st$y), truth_treated - 0.01)
})
