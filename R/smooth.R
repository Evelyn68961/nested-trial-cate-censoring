# Drawing the effect curve through the pseudo-outcomes: local linear (kernel) regression.
# Paper section 5, step 2, and section 5.1 for the intervals.
#
# At each grid value v0, fit a straight line to the pseudo-outcomes of patients whose v is
# within h of v0, giving more weight to those closer to v0 (Epanechnikov kernel). The height
# of that line at v0 is the estimated effect for profile v0. The bandwidth h sets how wide
# the window is: small h follows the data closely but is noisy; large h is smooth but can
# flatten real bends.

epanechnikov <- function(u) 0.75 * (1 - u^2) * (abs(u) <= 1)

# Estimates and pointwise 95% intervals on v_grid.
# Interval: theta_hat +/- 1.96 * sigma / sqrt(n), with sigma^2 the (1,1) element of the
# sandwich P_n[phi phi'], phi = D^-1 g(V) K_h(V - v0) {xi - g(V)' beta}, g(V) = (1, V - v0)',
# D = P_n[g(V) K_h(V - v0) g(V)'] (paper section 5.1).
local_linear <- function(v, xi, v_grid, h) {
  n <- length(v)
  res <- t(sapply(v_grid, function(v0) {
    d <- v - v0
    w <- epanechnikov(d / h) / h
    D <- matrix(c(mean(w), mean(w * d), mean(w * d), mean(w * d^2)), 2, 2)
    if (sum(w > 0) < 3 || abs(det(D)) < 1e-12) return(c(NA, NA))
    Dinv <- solve(D)
    beta <- Dinv %*% c(mean(w * xi), mean(w * d * xi))
    r <- xi - beta[1] - beta[2] * d
    phi1 <- (Dinv[1, 1] + Dinv[1, 2] * d) * w * r
    c(beta[1], sqrt(mean(phi1^2) / n))
  }))
  data.frame(v = v_grid, estimate = res[, 1], se = res[, 2],
             lower = res[, 1] - 1.96 * res[, 2], upper = res[, 1] + 1.96 * res[, 2])
}

# Leave-one-out cross-validation score for each bandwidth, using the closed form for
# linear smoothers: residual_i / (1 - H_ii), where H_ii is patient i's weight on their own fit.
cv_scores <- function(v, xi, bandwidths) {
  d <- outer(v, v, function(vi, vj) vj - vi)   # d[i, j] = v_j - v_i
  sapply(bandwidths, function(h) {
    w <- epanechnikov(d / h) / h
    s0 <- rowSums(w)
    s1 <- rowSums(w * d)
    s2 <- rowSums(w * d^2)
    t0 <- as.numeric(w %*% xi)
    t1 <- as.numeric((w * d) %*% xi)
    den <- s0 * s2 - s1^2
    fit <- (s2 * t0 - s1 * t1) / den
    hii <- (epanechnikov(0) / h) * s2 / den
    mean(((xi - fit) / (1 - hii))^2)
  })
}

# which.min skips a bandwidth whose score is NaN (for example a window too narrow to fit a line,
# where den is 0), so such a bandwidth is never chosen.
choose_bandwidth <- function(v, xi, bandwidths = seq(0.3, 2.0, by = 0.1)) {
  bandwidths[which.min(cv_scores(v, xi, bandwidths))]
}

# The smoothed target theta*(v0): the same local linear fit applied to the true curve itself,
# with patients' v spread according to density_u. The paper's intervals are centred on this
# smoothed curve rather than on the exact curve (section 5.1).
smoothed_curve <- function(u, curve_u, density_u, v_grid, h) {
  sapply(v_grid, function(v0) {
    d <- u - v0
    w <- epanechnikov(d / h) * density_u
    fit <- lm.wfit(cbind(1, d)[w > 0, , drop = FALSE], curve_u[w > 0], w[w > 0])
    fit$coefficients[1]
  })
}
