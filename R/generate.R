# Simulated hospitals: every trial-eligible patient, some of whom join a randomized trial.
#
# Patient characteristics (the paper's X):
#   frailty  standard normal; affects joining the trial, the outcome and the size of the benefit
#   v        uniform on 0 to 4; the profile variable (the paper's V) along which the effect is drawn
#   male     0 or 1, half each
# Only trial patients (s = 1) have a treatment (a) and an observed outcome (y).

expit <- function(x) 1 / (1 + exp(-x))

load_config <- function(path) yaml::read_yaml(path)

# Log-odds of joining the trial, without the intercept
participation_lp <- function(frailty, v, male, cfg) {
  p <- cfg$participation
  p$frailty * frailty + p$v * (v - 2) + p$male * male
}

# Risk of the bad outcome under treatment a (0 or 1)
outcome_risk <- function(a, frailty, v, male, cfg) {
  b <- cfg$baseline
  e <- cfg$effect
  lp0 <- b$intercept + b$frailty * frailty + b$v * v + b$male * male
  effect <- e$intercept + e$v * v + e$v_squared * v^2 + e$frailty * frailty
  expit(lp0 + a * effect)
}

# Intercept of the participation model that gives the target trial fraction.
# Solved once on a large fixed sample, so it does not change from run to run.
participation_intercept <- function(cfg, n_mc = 1e6, seed = 1) {
  set.seed(seed)
  frailty <- rnorm(n_mc)
  v <- runif(n_mc, 0, 4)
  male <- rbinom(n_mc, 1, 0.5)
  lp <- participation_lp(frailty, v, male, cfg)
  uniroot(function(b0) mean(expit(b0 + lp)) - cfg$trial_fraction,
          interval = c(-10, 10), tol = 1e-10)$root
}

# One simulated hospital.
# Returns a list:
#   observed  what an analyst would have (a and y are NA outside the trial)
#   hidden    each patient's true chance of joining and true risks under both treatments;
#             for checking only, never for estimating
simulate_cohort <- function(cfg, seed, b0 = participation_intercept(cfg)) {
  set.seed(seed)
  n <- cfg$cohort_size
  frailty <- rnorm(n)
  v <- runif(n, 0, 4)
  male <- rbinom(n, 1, 0.5)

  p_join <- expit(b0 + participation_lp(frailty, v, male, cfg))
  s <- rbinom(n, 1, p_join)
  a <- ifelse(s == 1, rbinom(n, 1, cfg$p_treat), NA_integer_)

  p0 <- outcome_risk(0, frailty, v, male, cfg)
  p1 <- outcome_risk(1, frailty, v, male, cfg)
  y <- rep(NA_integer_, n)
  in_trial <- s == 1
  y[in_trial] <- rbinom(sum(in_trial), 1, ifelse(a[in_trial] == 1, p1[in_trial], p0[in_trial]))

  list(
    observed = data.frame(id = seq_len(n), frailty, v, male, s, a, y),
    hidden = data.frame(id = seq_len(n), p_join, p0, p1)
  )
}
