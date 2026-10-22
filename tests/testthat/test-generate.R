source(file.path("..", "..", "R", "generate.R"))
source(file.path("..", "..", "R", "truth.R"))

cfg <- load_config(file.path("..", "..", "config", "phase1.yaml"))
b0 <- participation_intercept(cfg)

test_that("about 20% of patients join the trial", {
  sizes <- sapply(1:50, function(seed) sum(simulate_cohort(cfg, seed, b0)$observed$s))
  expect_equal(mean(sizes) / cfg$cohort_size, cfg$trial_fraction, tolerance = 0.02)
})

test_that("treatment and outcome exist only for trial patients", {
  d <- simulate_cohort(cfg, 1, b0)$observed
  expect_true(all(is.na(d$a[d$s == 0])))
  expect_true(all(is.na(d$y[d$s == 0])))
  expect_false(any(is.na(d$a[d$s == 1])))
  expect_false(any(is.na(d$y[d$s == 1])))
})

test_that("randomization gives about half treated in the trial", {
  a <- unlist(lapply(1:50, function(seed) {
    d <- simulate_cohort(cfg, seed, b0)$observed
    d$a[d$s == 1]
  }))
  expect_equal(mean(a), cfg$p_treat, tolerance = 0.01)
})

test_that("trial patients are less frail than all eligible patients", {
  d <- simulate_cohort(cfg, 1, b0)$observed
  expect_lt(mean(d$frailty[d$s == 1]), mean(d$frailty) - 0.2)
})

test_that("exact target curve agrees with a brute-force Monte Carlo average", {
  set.seed(99)
  n <- 2e6
  f <- rnorm(n)
  male <- rbinom(n, 1, 0.5)
  for (v in c(0.5, 2, 3.5)) {
    mc <- mean(outcome_risk(1, f, v, male, cfg) - outcome_risk(0, f, v, male, cfg))
    expect_equal(target_effect(v, cfg), mc, tolerance = 1e-3)
  }
})

test_that("exact trial curve agrees with the trial patients in a very large cohort", {
  big <- cfg
  big$cohort_size <- 2e6
  sim <- simulate_cohort(big, 7, b0)
  d <- merge(sim$observed, sim$hidden, by = "id")
  d <- d[d$s == 1 & abs(d$v - 2) < 0.05, ]
  expect_equal(trial_effect(2, cfg, b0), mean(d$p1 - d$p0), tolerance = 3e-3)
})

test_that("treatment lowers risk somewhere (negative effect = benefit)", {
  expect_true(any(target_effect(make_v_grid(cfg), cfg) < 0))
})
