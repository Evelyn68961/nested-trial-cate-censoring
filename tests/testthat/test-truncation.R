truncation <- new.env()
truncation$right_formulas <- list()
source(file.path("..", "..", "scripts", "15_common.R"), local = truncation)
floored <- truncation$floored

test_that("the product floor gives 1 / (p_eff G_eff) = 1 / max(p G, f)", {
  set.seed(1)
  p <- runif(5000, 1e-4, 1)
  G <- exp(-rexp(5000, 0.3))
  f <- sample(c(0, 0.01, 0.02, 0.05, 0.1, runif(20, 0, 0.3)), 5000, replace = TRUE)
  w <- mapply(function(pi, fi) unlist(floored("pG", fi, pi)), p, f)
  p_eff <- w["p", ]
  G_eff <- pmax(G, w["g_floor", ])
  expect_equal(1 / (p_eff * G_eff), 1 / pmax(p * G, f), tolerance = 1e-12)
  expect_true(all(G_eff >= 0 & G_eff <= 1))
  # G_eff(0) = 1: the floor on G never exceeds 1
  expect_true(all(w["g_floor", ] <= 1))
})

test_that("floor 0 leaves p and G as they are in every scheme", {
  p <- c(0.001, 0.2, 0.9)
  for (scheme in c("G", "p", "pG")) {
    w <- floored(scheme, 0, p)
    expect_equal(w$p, p)
    expect_equal(w$g_floor, rep(0, 3))
  }
})
