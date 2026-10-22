source(file.path("..", "..", "R", "smooth.R"))

test_that("a straight line without noise is recovered exactly", {
  v <- seq(0, 4, length.out = 500)
  xi <- 0.3 - 0.1 * v
  fit <- local_linear(v, xi, c(0.5, 2, 3.5), h = 0.5)
  expect_equal(fit$estimate, 0.3 - 0.1 * c(0.5, 2, 3.5), tolerance = 1e-10)
})

test_that("a smooth curve with noise is recovered closely in a large sample", {
  set.seed(1)
  v <- runif(20000, 0, 4)
  curve <- function(x) -0.1 * sin(x)
  xi <- curve(v) + rnorm(20000, sd = 1)
  fit <- local_linear(v, xi, c(1, 2, 3), h = 0.4)
  expect_lt(max(abs(fit$estimate - curve(c(1, 2, 3)))), 0.05)
  expect_true(all(fit$se > 0))
})

test_that("intervals cover the smoothed curve about 95% of the time", {
  set.seed(2)
  hit <- replicate(300, {
    v <- runif(2000, 0, 4)
    xi <- -0.1 * sin(v) + rnorm(2000, sd = 1)
    fit <- local_linear(v, xi, 2, h = 0.6)
    u <- seq(0, 4, length.out = 801)
    target <- smoothed_curve(u, -0.1 * sin(u), rep(1, 801), 2, 0.6)
    fit$lower <= target && target <= fit$upper
  })
  expect_gt(mean(hit), 0.91)
  expect_lt(mean(hit), 0.99)
})

test_that("the closed-form leave-one-out score equals refitting without each patient", {
  set.seed(3)
  v <- runif(60, 0, 4)
  xi <- sin(v) + rnorm(60, sd = 0.3)
  h <- 0.9
  brute <- mean(sapply(seq_along(v), function(i) {
    (xi[i] - local_linear(v[-i], xi[-i], v[i], h)$estimate)^2
  }))
  expect_equal(cv_scores(v, xi, h), brute, tolerance = 1e-8)
})

test_that("cross-validation picks a narrow window for a wiggly curve and a wide one for a flat one", {
  set.seed(4)
  v <- runif(1500, 0, 4)
  wiggly <- sin(4 * v) + rnorm(1500, sd = 0.3)
  flat <- rnorm(1500, sd = 0.3)
  expect_lt(choose_bandwidth(v, wiggly), 0.6)
  expect_gt(choose_bandwidth(v, flat), 1.2)
})
