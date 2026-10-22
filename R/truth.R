# The true effect curves, computed exactly from the simulation rules.
#
# target_effect(v): risk if treated minus risk if not, averaged over ALL trial-eligible
#                   patients with profile value v. This is what the estimators try to recover.
# trial_effect(v):  the same, averaged over TRIAL patients only. It differs from the target
#                   because trial patients are less frail. The gap is the reason the method exists.
#
# frailty and male are independent of v, so each average is an integral over frailty
# (standard normal) and a sum over male (0 or 1, half each).

target_effect <- function(v_grid, cfg) {
  sapply(v_grid, function(v) {
    sum(sapply(0:1, function(male) {
      0.5 * integrate(function(f) {
        dnorm(f) * (outcome_risk(1, f, v, male, cfg) - outcome_risk(0, f, v, male, cfg))
      }, -Inf, Inf, rel.tol = 1e-10)$value
    }))
  })
}

trial_effect <- function(v_grid, cfg, b0) {
  sapply(v_grid, function(v) {
    num <- 0
    den <- 0
    for (male in 0:1) {
      p_join <- function(f) expit(b0 + participation_lp(f, v, male, cfg))
      num <- num + 0.5 * integrate(function(f) {
        dnorm(f) * p_join(f) * (outcome_risk(1, f, v, male, cfg) - outcome_risk(0, f, v, male, cfg))
      }, -Inf, Inf, rel.tol = 1e-10)$value
      den <- den + 0.5 * integrate(function(f) dnorm(f) * p_join(f), -Inf, Inf, rel.tol = 1e-10)$value
    }
    num / den
  })
}

make_v_grid <- function(cfg) {
  seq(cfg$v_grid$from, cfg$v_grid$to, length.out = cfg$v_grid$length)
}
