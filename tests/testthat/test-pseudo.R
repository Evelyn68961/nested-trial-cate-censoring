source(file.path("..", "..", "R", "generate.R"))
source(file.path("..", "..", "R", "truth.R"))
source(file.path("..", "..", "R", "nuisance.R"))
source(file.path("..", "..", "R", "pseudo.R"))

cfg <- load_config(file.path("..", "..", "config", "phase1.yaml"))
b0 <- participation_intercept(cfg)

# The true helper values, for checks that should hold exactly in expectation
oracle <- function(sim) {
  h <- sim$hidden
  data.frame(id = h$id, p_join = h$p_join, p_treat = cfg$p_treat, g1 = h$p1, g0 = h$p0)
}

test_that("patients outside the trial get exactly the predicted effect", {
  sim <- simulate_cohort(cfg, 1, b0)
  nu <- fit_nuisance(sim$observed, "glm")
  xi <- pseudo_outcome(sim$observed, nu)
  out <- sim$observed$s == 0
  expect_equal(xi[out], (nu$g1 - nu$g0)[out])
})

test_that("treated and untreated trial patients get the correction with opposite signs", {
  d <- data.frame(s = c(1, 1), a = c(1, 0), y = c(1, 1))
  nu <- data.frame(p_join = 0.2, p_treat = 0.5, g1 = 0.3, g0 = 0.4)
  # treated:   10 * (1 - 0.3) - 0.1 =  6.9
  # untreated: -10 * (1 - 0.4) - 0.1 = -6.1
  expect_equal(pseudo_outcome(d, nu), c(6.9, -6.1))
})

# Checks on the average over all eligible patients (v is uniform on 0 to 4), where a cohort
# of one million keeps Monte Carlo noise near 0.003. Limits are absolute differences.
big <- cfg
big$cohort_size <- 1e6
sim_big <- simulate_cohort(big, 11, b0)
true_average <- mean(target_effect(seq(0, 4, length.out = 401), cfg))
true_trial_average <- mean((sim_big$hidden$p1 - sim_big$hidden$p0)[sim_big$observed$s == 1])

test_that("with the true helper values, pseudo-outcomes average to the true target effect", {
  xi <- pseudo_outcome(sim_big$observed, oracle(sim_big))
  expect_lt(abs(mean(xi) - true_average), 0.01)
})

test_that("a wrong outcome model is repaired when the participation model is right", {
  nu <- oracle(sim_big)
  nu$g1 <- 0.3
  nu$g0 <- 0.3
  xi <- pseudo_outcome(sim_big$observed, nu)
  expect_lt(abs(mean(xi) - true_average), 0.01)
})

test_that("a wrong participation model does no harm when the outcome model is right", {
  nu <- oracle(sim_big)
  nu$p_join <- mean(sim_big$observed$s)
  xi <- pseudo_outcome(sim_big$observed, nu)
  expect_lt(abs(mean(xi) - true_average), 0.01)
})

test_that("with both helpers wrong, the estimate drifts to the trial's value", {
  nu <- oracle(sim_big)
  nu$g1 <- 0.3
  nu$g0 <- 0.3
  nu$p_join <- mean(sim_big$observed$s)
  xi <- pseudo_outcome(sim_big$observed, nu)
  expect_gt(abs(mean(xi) - true_average), 0.02)
  expect_lt(abs(mean(xi) - true_trial_average), 0.01)
})
