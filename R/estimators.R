# The four estimators of the effect curve compared in Phase 1.
#
#   P  the paper's: pseudo-outcomes for all eligible patients, local linear curve,
#      bandwidth by cross-validation, sandwich intervals
#   L  the paper's comparison: same pseudo-outcomes, a straight line in v instead of a curve
#   T  trial only: the same method using trial patients alone; it estimates the effect curve
#      of the trial population, which is not the target
#   G  outcome model alone: local linear curve through g1 - g0 for all eligible patients,
#      no correction term; no interval (none is justified for it)

linear_fit <- function(v, xi, v_grid) {
  X <- cbind(1, v)
  bread <- solve(crossprod(X))
  beta <- bread %*% crossprod(X, xi)
  r <- as.numeric(xi - X %*% beta)
  vcov <- bread %*% crossprod(X * r) %*% bread   # robust (sandwich) variance
  G <- cbind(1, v_grid)
  est <- as.numeric(G %*% beta)
  se <- sqrt(rowSums((G %*% vcov) * G))
  data.frame(v = v_grid, estimate = est, se = se, lower = est - 1.96 * se, upper = est + 1.96 * se)
}

run_estimators <- function(d, learner, seed, v_grid, bandwidths = seq(0.3, 2.0, by = 0.1),
                           n_folds = 5) {
  nu <- fit_nuisance(d, learner, n_folds = n_folds, seed = seed)
  xi <- pseudo_outcome(d, nu)

  h_P <- choose_bandwidth(d$v, xi, bandwidths)
  P <- local_linear(d$v, xi, v_grid, h_P)
  L <- linear_fit(d$v, xi, v_grid)

  g_effect <- nu$g1 - nu$g0
  h_G <- choose_bandwidth(d$v, g_effect, bandwidths)
  G <- local_linear(d$v, g_effect, v_grid, h_G)
  G$se <- NA_real_
  G$lower <- NA_real_
  G$upper <- NA_real_

  dt <- d[d$s == 1, ]
  nut <- fit_nuisance(dt, learner, n_folds = n_folds, seed = seed, trial_only = TRUE)
  xit <- pseudo_outcome(dt, nut)
  h_T <- choose_bandwidth(dt$v, xit, bandwidths)
  T_ <- local_linear(dt$v, xit, v_grid, h_T)

  curves <- rbind(
    cbind(estimator = "P", h = h_P, P),
    cbind(estimator = "L", h = NA_real_, L),
    cbind(estimator = "T", h = h_T, T_),
    cbind(estimator = "G", h = h_G, G)
  )
  list(curves = curves,
       info = data.frame(n_trial = sum(d$s), min_p_join = min(nu$p_join),
                         max_weight = max(d$s / (nu$p_join * 0.5)), h_P = h_P, h_T = h_T, h_G = h_G))
}
