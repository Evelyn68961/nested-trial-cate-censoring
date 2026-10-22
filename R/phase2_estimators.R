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
#          Correct if either the dropout model or the Weibull outcome model is right.
#
# Needs R/generate.R, R/nuisance.R, R/pseudo.R, R/smooth.R, R/phase2_generate.R.

library(survival)

weibull_cumhaz <- function(u, lp, scale) (u / exp(lp))^(1 / scale)
weibull_surv <- function(u, lp, scale) exp(-weibull_cumhaz(u, lp, scale))

# Cross-fitted helpers for IPCW and AIPCW. Returns per-patient quantities for every time.
fit_phase2_helpers <- function(d, times, censor_formula, follow_up_end, n_folds = 5, seed = 1) {
  folds <- make_folds(d$s, n_folds, seed)
  n <- nrow(d)
  out <- list(p_join = rep(NA_real_, n), p_treat = rep(NA_real_, n),
              cens_lp = rep(NA_real_, n), cens_scale = rep(NA_real_, n),
              lp1 = rep(NA_real_, n), scale1 = rep(NA_real_, n),
              lp0 = rep(NA_real_, n), scale0 = rep(NA_real_, n),
              ipcw_g1 = matrix(NA_real_, n, length(times)), ipcw_g0 = matrix(NA_real_, n, length(times)))
  d$dropped <- as.integer(d$s == 1 & d$event == 0 & d$time < follow_up_end)
  any_dropout <- sum(d$dropped, na.rm = TRUE) > 0
  out_formula <- ~ frailty + v + I(v^2) + male

  for (k in seq_len(n_folds)) {
    train <- folds != k
    test <- folds == k
    tr <- d[train & d$s == 1, ]
    newd <- d[test, ]

    out$p_join[test] <- predict(glm(s ~ frailty + v + male, binomial(), data = d[train, ]),
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
        dat <- cbind(tr[tra, c("frailty", "v", "male")], y = st$y, w = 1 / g_end)[st$known, ]
        lfit <- suppressWarnings(glm(update(out_formula, y ~ .), quasibinomial(), data = dat, weights = w))
        pred <- predict(lfit, newd, type = "response")
        if (arm == 1) out$ipcw_g1[test, j] <- pred else out$ipcw_g0[test, j] <- pred
      }
    }
  }
  out
}

# Augmented status at time t for trial patients (AIPCW). For others the value is unused.
augmented_status <- function(d, t, h, n_steps = 30) {
  st <- status_at(d, t)
  trial <- which(d$s == 1)
  res <- rep(0, nrow(d))
  a <- d$a[trial]
  lp <- ifelse(a == 1, h$lp1[trial], h$lp0[trial])
  sc <- ifelse(a == 1, h$scale1[trial], h$scale0[trial])
  G <- function(u) weibull_surv(u, h$cens_lp[trial], h$cens_scale[trial])
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
                                  bandwidths = c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0)) {
  times <- unlist(cfg$times)
  h <- fit_phase2_helpers(d, times, censor_formula, cfg$follow_up_end, seed = seed)

  xi <- list(CC = list(), NE = list(), IPCW = list(), AIPCW = list())
  keep_cc <- list()
  for (j in seq_along(times)) {
    t <- times[j]
    st <- status_at(d, t)

    # CC: remove trial patients with unknown status, then the Phase 1 method on status at t
    keep <- d$s == 0 | st$known
    dcc <- d[keep, ]
    dcc$y <- st$y[keep]
    xi$CC[[j]] <- pseudo_outcome(dcc, fit_nuisance(dcc, "glm", seed = seed))
    keep_cc[[j]] <- keep

    # NE: unknown status counted as no event
    dne <- d
    dne$y <- ifelse(d$s == 1, st$y, NA)
    xi$NE[[j]] <- pseudo_outcome(dne, fit_nuisance(dne, "glm", seed = seed))

    # IPCW
    g_end <- weibull_surv(pmin(d$time, t), h$cens_lp, h$cens_scale)
    ystar <- ifelse(d$s == 1, st$known * st$y / g_end, 0)
    xi$IPCW[[j]] <- pseudo_from_status(d, ystar, h$p_join, h$p_treat, h$ipcw_g1[, j], h$ipcw_g0[, j])

    # AIPCW, with the Weibull outcome model
    g1 <- 1 - weibull_surv(t, h$lp1, h$scale1)
    g0 <- 1 - weibull_surv(t, h$lp0, h$scale0)
    xi$AIPCW[[j]] <- pseudo_from_status(d, augmented_status(d, t, h), h$p_join, h$p_treat, g1, g0)
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
       info = data.frame(n_trial = sum(d$s), share_dropped = dropped,
                         min_p_join = min(h$p_join), min_g = min(weibull_surv(pmin(d$time[d$s == 1], 5),
                                                                              h$cens_lp[d$s == 1], h$cens_scale[d$s == 1]))))
}
