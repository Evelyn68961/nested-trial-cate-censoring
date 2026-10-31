# Phase 2: four ways of handling dropout, each feeding the Phase 1 method (pseudo-outcome
# plus local linear curve) at each follow-up time t.
#
#   CC     complete case: trial patients whose status at t is unknown are removed
#   NE     no event: unknown status counted as "no event by t"
#   IPCW   inverse probability of censoring weighting: patients whose status at t is known are
#          weighted by 1 / (chance of still being followed); the outcome model is a weighted
#          logistic regression of status at t
#   AIPCW  augmented IPCW: as IPCW, plus a term for what dropouts would likely have done after
#          leaving, taken from a Weibull outcome model; the outcome model is that Weibull model.
#          Consistent if the Weibull outcome model is right, or if the participation and dropout
#          models are both right.
#   IPCW_t, AIPCW_t  the same with truncated weights: the estimated chance of still being
#          followed is never allowed below g_floor (0.05), so no patient's weight exceeds 20.
#          Added after the 200-hospital runs, where strong dependent dropout gave some
#          patients chances of staying near 0.0001 and weights above 10,000 (docs/LOG.md).
#   BJ     Buckley-James: no dropout weight at all. Each dropout's status at t is filled
#          in with the Weibull outcome model's chance of an event between leaving and t. It is
#          AIPCW with the chance of staying set to 1 for everyone (Steingrimsson & Morrison,
#          Stat Med 2020). Consistent only if the outcome model is right. Added 2026-10-23 to see
#          whether the large errors in C2 remain without the dropout weight.
#
# Needs R/generate.R, R/nuisance.R, R/pseudo.R, R/smooth.R, R/phase2_generate.R.

library(survival)

weibull_cumhaz <- function(u, lp, scale) (u / exp(lp))^(1 / scale)
weibull_surv <- function(u, lp, scale) exp(-weibull_cumhaz(u, lp, scale))

# Cross-fitted helpers for IPCW and AIPCW. Returns per-patient quantities for every time.
# out_formula is the analyst's outcome model, used for the Weibull models and the IPCW logistic
# models; setting C4 leaves frailty out of it.
fit_phase2_helpers <- function(d, times, censor_formula, follow_up_end, n_folds = 5, seed = 1,
                               g_floor = 0.05, out_formula = ~ frailty + v + I(v^2) + male,
                               join_formula = s ~ frailty + v + male) {
  folds <- make_folds(d$s, n_folds, seed)
  n <- nrow(d)
  empty <- function() matrix(NA_real_, n, length(times))
  out <- list(p_join = rep(NA_real_, n), p_treat = rep(NA_real_, n),
              cens_lp = rep(NA_real_, n), cens_scale = rep(NA_real_, n),
              lp1 = rep(NA_real_, n), scale1 = rep(NA_real_, n),
              lp0 = rep(NA_real_, n), scale0 = rep(NA_real_, n),
              ipcw_g1 = empty(), ipcw_g0 = empty(), ipcw_g1_t = empty(), ipcw_g0_t = empty())
  d$dropped <- as.integer(d$s == 1 & d$event == 0 & d$time < follow_up_end)
  any_dropout <- sum(d$dropped, na.rm = TRUE) > 0

  for (k in seq_len(n_folds)) {
    train <- folds != k
    test <- folds == k
    tr <- d[train & d$s == 1, ]
    newd <- d[test, ]

    out$p_join[test] <- predict(glm(join_formula, binomial(), data = d[train, ]),
                                newd, type = "response")
    out$p_treat[test] <- predict(glm(a ~ frailty + v + male, binomial(), data = tr),
                                 newd, type = "response")

    # Dropout model (trial patients); G(u) = chance of not having dropped out by u
    if (any_dropout) {
      cfit <- survreg(update(censor_formula, Surv(time, dropped) ~ .), data = tr, dist = "weibull")
      newd_a <- newd
      newd_a$a[is.na(newd_a$a)] <- 0
      out$cens_lp[test] <- predict(cfit, newd_a, type = "lp")
      out$cens_scale[test] <- cfit$scale
      tr_g_lp <- predict(cfit, tr, type = "lp")
      tr_g_scale <- cfit$scale
    } else {
      out$cens_lp[test] <- Inf
      out$cens_scale[test] <- 1
      tr_g_lp <- rep(Inf, nrow(tr))
      tr_g_scale <- 1
    }

    for (arm in 0:1) {
      tra <- tr$a == arm
      # Weibull outcome model in this arm, predicted for every test patient
      ofit <- survreg(update(out_formula, Surv(time, event) ~ .), data = tr[tra, ], dist = "weibull")
      if (arm == 1) {
        out$lp1[test] <- predict(ofit, newd, type = "lp")
        out$scale1[test] <- ofit$scale
      } else {
        out$lp0[test] <- predict(ofit, newd, type = "lp")
        out$scale0[test] <- ofit$scale
      }
      # IPCW-weighted logistic model of status at each time
      for (j in seq_along(times)) {
        st <- status_at(tr[tra, ], times[j])
        g_end <- weibull_surv(pmin(tr$time[tra], times[j]), tr_g_lp[tra], tr_g_scale)
        for (truncated in c(FALSE, TRUE)) {
          g_use <- if (truncated) pmax(g_end, g_floor) else g_end
          dat <- cbind(tr[tra, c("frailty", "v", "male")], y = st$y, w = 1 / g_use)[st$known, ]
          lfit <- suppressWarnings(glm(update(out_formula, y ~ .), quasibinomial(), data = dat, weights = w))
          pred <- predict(lfit, newd, type = "response")
          key <- paste0("ipcw_g", arm, if (truncated) "_t" else "")
          out[[key]][test, j] <- pred
        }
      }
    }
  }
  out
}

# Augmented status at time t for trial patients (AIPCW). For others the value is unused.
# With use_dropout_model = FALSE the chance of staying is 1 for everyone: the IPCW part becomes
# the observed status, the compensator vanishes, and each dropout gets the outcome model's
# chance of an event between leaving and t (the Buckley-James status).
augmented_status <- function(d, t, h, n_steps = 30, g_floor = 0, use_dropout_model = TRUE) {
  st <- status_at(d, t)
  trial <- which(d$s == 1)
  res <- rep(0, nrow(d))
  a <- d$a[trial]
  lp <- ifelse(a == 1, h$lp1[trial], h$lp0[trial])
  sc <- ifelse(a == 1, h$scale1[trial], h$scale0[trial])
  G <- if (use_dropout_model) {
    function(u) pmax(weibull_surv(u, h$cens_lp[trial], h$cens_scale[trial]), g_floor)
  } else {
    function(u) rep(1, length(trial))
  }
  H <- function(u) weibull_cumhaz(u, lp, sc)
  # Chance of the event by t, given event-free at u; written with cumulative hazards so that
  # very high-risk patients do not give 0 / 0
  F_cond <- function(u) 1 - exp(-(H(t) - H(u)))

  end <- pmin(d$time[trial], t)
  ipcw_part <- st$known[trial] * st$y[trial] / G(end)
  dropped_before_t <- d$event[trial] == 0 & d$time[trial] < t
  jump <- ifelse(dropped_before_t, F_cond(d$time[trial]) / G(d$time[trial]), 0)
  # Compensator: integral over [0, end] of F_cond(u) d(1/G(u)), midpoint rule
  comp <- 0
  for (k in seq_len(n_steps)) {
    u_lo <- end * (k - 1) / n_steps
    u_hi <- end * k / n_steps
    comp <- comp + F_cond((u_lo + u_hi) / 2) * (1 / G(u_hi) - 1 / G(u_lo))
  }
  res[trial] <- ipcw_part + jump - comp
  res
}

# Pseudo-outcome with a transformed status (IPCW or AIPCW) in place of y
pseudo_from_status <- function(d, ystar, p_join, p_treat, g1, g0) {
  a <- ifelse(is.na(d$a), 0, d$a)
  p_arm <- ifelse(a == 1, p_treat, 1 - p_treat)
  g_a <- ifelse(a == 1, g1, g0)
  d$s * (2 * a - 1) / (p_join * p_arm) * (ystar - g_a) + (g1 - g0)
}

run_phase2_estimators <- function(d, cfg, censor_formula, seed, v_grid,
                                  bandwidths = c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0),
                                  g_floor = 0.05, out_formula = ~ frailty + v + I(v^2) + male,
                                  join_formula = s ~ frailty + v + male, nuisance_formulas = right_formulas) {
  times <- unlist(cfg$times)
  h <- fit_phase2_helpers(d, times, censor_formula, cfg$follow_up_end, seed = seed, g_floor = g_floor,
                          out_formula = out_formula, join_formula = join_formula)

  xi <- list(CC = list(), NE = list(), IPCW = list(), AIPCW = list(), IPCW_t = list(), AIPCW_t = list(),
             BJ = list())
  keep_cc <- list()
  for (j in seq_along(times)) {
    t <- times[j]
    st <- status_at(d, t)

    # CC: remove trial patients with unknown status, then the Phase 1 method on status at t
    keep <- d$s == 0 | st$known
    dcc <- d[keep, ]
    dcc$y <- st$y[keep]
    xi$CC[[j]] <- pseudo_outcome(dcc, fit_nuisance(dcc, "glm", seed = seed, formulas = nuisance_formulas))
    keep_cc[[j]] <- keep

    # NE: unknown status counted as no event
    dne <- d
    dne$y <- ifelse(d$s == 1, st$y, NA)
    xi$NE[[j]] <- pseudo_outcome(dne, fit_nuisance(dne, "glm", seed = seed, formulas = nuisance_formulas))

    # IPCW
    g_end <- weibull_surv(pmin(d$time, t), h$cens_lp, h$cens_scale)
    ystar <- ifelse(d$s == 1, st$known * st$y / g_end, 0)
    xi$IPCW[[j]] <- pseudo_from_status(d, ystar, h$p_join, h$p_treat, h$ipcw_g1[, j], h$ipcw_g0[, j])

    # AIPCW, with the Weibull outcome model
    g1 <- 1 - weibull_surv(t, h$lp1, h$scale1)
    g0 <- 1 - weibull_surv(t, h$lp0, h$scale0)
    xi$AIPCW[[j]] <- pseudo_from_status(d, augmented_status(d, t, h), h$p_join, h$p_treat, g1, g0)

    # Truncated versions: chance of staying never below g_floor
    ystar_t <- ifelse(d$s == 1, st$known * st$y / pmax(g_end, g_floor), 0)
    xi$IPCW_t[[j]] <- pseudo_from_status(d, ystar_t, h$p_join, h$p_treat, h$ipcw_g1_t[, j], h$ipcw_g0_t[, j])
    xi$AIPCW_t[[j]] <- pseudo_from_status(d, augmented_status(d, t, h, g_floor = g_floor),
                                          h$p_join, h$p_treat, g1, g0)

    # Buckley-James: no dropout weight, dropouts filled in by the outcome model
    xi$BJ[[j]] <- pseudo_from_status(d, augmented_status(d, t, h, use_dropout_model = FALSE),
                                     h$p_join, h$p_treat, g1, g0)
  }

  # One bandwidth per estimator, chosen by cross-validation at the last time, used at every time
  last <- length(times)
  rows <- list()
  for (est in names(xi)) {
    v_last <- if (est == "CC") d$v[keep_cc[[last]]] else d$v
    bw <- choose_bandwidth(v_last, xi[[est]][[last]], bandwidths)
    for (j in seq_along(times)) {
      v_j <- if (est == "CC") d$v[keep_cc[[j]]] else d$v
      fit <- local_linear(v_j, xi[[est]][[j]], v_grid, bw)
      rows[[length(rows) + 1]] <- cbind(estimator = est, t = times[j], h = bw, fit)
    }
  }
  curves <- do.call(rbind, rows)
  dropped <- with(d[d$s == 1, ], mean(event == 0 & time < cfg$follow_up_end))
  list(curves = curves,
       info = cbind(data.frame(n_trial = sum(d$s), share_dropped = dropped,
                               min_p_join = min(h$p_join), min_g = min(weibull_surv(pmin(d$time[d$s == 1], 5),
                                                                                    h$cens_lp[d$s == 1], h$cens_scale[d$s == 1]))),
                    weight_checks(d, h, times[last])))
}

# Weight checks recommended by Dahabreh et al. (Stat Med 2020, p. 16), at time t, computed
# over all eligible patients. Each mean should be close to 1:
#   mean_w_join        S / P(trial)
#   mean_w_arm1, _arm0 S * [A = a] / (P(trial) * P(arm a))
#   mean_wc_arm1, _arm0  the same times [status known at t] / P(still followed)  (untruncated)
# Also, for the combined weight in each arm: the largest weight, the share of the arm's total
# weight carried by the single largest one, and the effective sample size (sum w)^2 / sum w^2.
weight_checks <- function(d, h, t) {
  st <- status_at(d, t)
  a <- ifelse(is.na(d$a), 0, d$a)
  known <- ifelse(d$s == 1, st$known, 0)
  g_end <- weibull_surv(pmin(d$time, t), h$cens_lp, h$cens_scale)
  w_join <- d$s / h$p_join
  out <- data.frame(mean_w_join = mean(w_join))
  for (arm in 1:0) {
    p_arm <- if (arm == 1) h$p_treat else 1 - h$p_treat
    w <- w_join * (a == arm) / p_arm
    wc <- ifelse(d$s == 1, w * known / g_end, 0)
    out[[paste0("mean_w_arm", arm)]] <- mean(w)
    out[[paste0("mean_wc_arm", arm)]] <- mean(wc)
    out[[paste0("max_wc_arm", arm)]] <- max(wc)
    out[[paste0("top_share_wc_arm", arm)]] <- max(wc) / sum(wc)
    out[[paste0("ess_wc_arm", arm)]] <- sum(wc)^2 / sum(wc^2)
  }
  out
}
