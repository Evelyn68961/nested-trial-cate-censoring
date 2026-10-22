# The pseudo-outcome: Wen, Dahabreh and Chiu, equation 1.
#
#   xi = S (2A - 1) / [ p(S=1|X) p(A|X,S=1) ] * { Y - g_A(X) }  +  g1(X) - g0(X)
#        \_____________ weight ______________/   \_ residual _/     \ predicted effect /
#
# Every patient gets the predicted effect from the outcome model. Trial patients also get a
# correction: how far their actual outcome was from the prediction, multiplied by a weight.
# The weight is large when a patient had a small chance of being in the trial, so that
# patient stands in for the many similar people who did not join. The sign (2A - 1) is
# +1 for treated and -1 for untreated patients, because the effect is treated minus untreated.
# For patients outside the trial S = 0, so only the predicted effect remains.

pseudo_outcome <- function(d, nu) {
  a <- ifelse(is.na(d$a), 0, d$a)   # values outside the trial are multiplied by S = 0
  y <- ifelse(is.na(d$y), 0, d$y)
  p_arm <- ifelse(a == 1, nu$p_treat, 1 - nu$p_treat)
  g_a <- ifelse(a == 1, nu$g1, nu$g0)
  weight <- d$s * (2 * a - 1) / (nu$p_join * p_arm)
  weight * (y - g_a) + (nu$g1 - nu$g0)
}
