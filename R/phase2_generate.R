# Phase 2 hospitals: the same patients and trial as Phase 1, but each trial patient has an
# event time instead of a yes/no outcome, and may drop out before the end of follow-up.
# Uses expit(), load_config(), participation_lp() and participation_intercept() from R/generate.R.

# Cumulative risk of the event by time t under treatment a
event_risk <- function(a, t, frailty, v, male, cfg) {
  b <- cfg$baseline
  e <- cfg$effect
  lp0 <- b$intercept + b$frailty * frailty + b$v * v + b$male * male
  effect <- e$intercept + e$v * v + e$v_squared * v^2 + e$frailty * frailty
  shape <- if (a == 1) cfg$shape_treated else cfg$shape_untreated
  1 - exp(-exp(lp0 + a * effect) * t^shape)
}

# Returns a list:
#   observed  id, frailty, v, male, s, a, time, event (time and event only for trial patients;
#             time = min(event time, dropout time, end of follow-up); event = 1 if the event was seen)
#   hidden    true event times under both treatments, dropout time, and chance of joining
simulate_cohort_surv <- function(cfg, censoring, seed, b0 = participation_intercept(cfg)) {
  set.seed(seed)
  n <- cfg$cohort_size
  frailty <- rnorm(n)
  v <- runif(n, 0, 4)
  male <- rbinom(n, 1, 0.5)

  p_join <- expit(b0 + participation_lp(frailty, v, male, cfg))
  s <- rbinom(n, 1, p_join)
  a <- ifelse(s == 1, rbinom(n, 1, cfg$p_treat), NA_integer_)

  # Event times under each treatment, from one uniform draw per patient (inverse transform)
  b <- cfg$baseline
  e <- cfg$effect
  lp0 <- b$intercept + b$frailty * frailty + b$v * v + b$male * male
  effect <- e$intercept + e$v * v + e$v_squared * v^2 + e$frailty * frailty
  minus_log_u <- -log(runif(n))
  t0 <- (minus_log_u / exp(lp0))^(1 / cfg$shape_untreated)
  t1 <- (minus_log_u / exp(lp0 + effect))^(1 / cfg$shape_treated)

  cen <- cfg$censoring[[censoring]]
  a0 <- ifelse(is.na(a), 0, a)
  rate <- cen$base_rate * exp(cen$frailty * frailty + cen$treated * a0)
  dropout <- ifelse(rate > 0, rexp(n, pmax(rate, 1e-300)), Inf)

  t_actual <- ifelse(a0 == 1, t1, t0)
  end <- pmin(dropout, cfg$follow_up_end)
  time <- ifelse(s == 1, pmin(t_actual, end), NA_real_)
  event <- ifelse(s == 1, as.integer(t_actual <= end), NA_integer_)

  list(
    observed = data.frame(id = seq_len(n), frailty, v, male, s, a, time, event),
    hidden = data.frame(id = seq_len(n), p_join, t0, t1, dropout)
  )
}

# Event status by time t, and whether it is known.
# Known if the event was seen by t, or the patient was followed event-free through t.
status_at <- function(d, t) {
  y <- as.integer(d$event == 1 & d$time <= t)
  known <- (d$event == 1 & d$time <= t) | d$time >= t
  data.frame(y = y, known = known)
}
