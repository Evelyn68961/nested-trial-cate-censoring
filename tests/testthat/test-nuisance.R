source(file.path("..", "..", "R", "generate.R"))
source(file.path("..", "..", "R", "nuisance.R"))

cfg <- load_config(file.path("..", "..", "config", "phase1.yaml"))
b0 <- participation_intercept(cfg)

test_that("every patient gets four predictions between 0 and 1", {
  d <- simulate_cohort(cfg, 1, b0)$observed
  nu <- fit_nuisance(d, "glm")
  expect_equal(nrow(nu), nrow(d))
  for (col in c("p_join", "p_treat", "g1", "g0")) {
    expect_false(any(is.na(nu[[col]])))
    expect_true(all(nu[[col]] > 0 & nu[[col]] < 1))
  }
})

test_that("folds each hold a share of the trial patients", {
  d <- simulate_cohort(cfg, 1, b0)$observed
  folds <- make_folds(d$s, 5, 1)
  per_fold <- tapply(d$s, folds, sum)
  expect_true(all(abs(per_fold - sum(d$s) / 5) <= 1))
})

test_that("a patient's own outcome never affects that patient's predictions", {
  d <- simulate_cohort(cfg, 1, b0)$observed
  nu <- fit_nuisance(d, "glm", seed = 3)
  changed <- d
  in_fold1 <- nu$fold == 1 & d$s == 1
  changed$y[in_fold1] <- 1 - changed$y[in_fold1]
  nu2 <- fit_nuisance(changed, "glm", seed = 3)
  expect_equal(nu2$g1[nu$fold == 1], nu$g1[nu$fold == 1])
  expect_equal(nu2$g0[nu$fold == 1], nu$g0[nu$fold == 1])
  expect_false(isTRUE(all.equal(nu2$g1[nu$fold != 1], nu$g1[nu$fold != 1])))
})

test_that("with the right terms and many patients, the helpers recover the true values", {
  big <- cfg
  big$cohort_size <- 50000
  sim <- simulate_cohort(big, 5, b0)
  nu <- fit_nuisance(sim$observed, "glm", n_folds = 2)
  h <- sim$hidden
  expect_lt(mean(abs(nu$p_join - h$p_join)), 0.01)
  expect_lt(mean(abs(nu$g1 - h$p1)), 0.02)
  expect_lt(mean(abs(nu$g0 - h$p0)), 0.02)
  expect_lt(mean(abs(nu$p_treat - 0.5)), 0.02)
})
