# Phase 2 true curves: risk by time t if treated minus risk by time t if not, averaged over
# all trial-eligible patients with profile value v (exact integrals over frailty and sex).

target_effect_t <- function(v_grid, t, cfg) {
  sapply(v_grid, function(v) {
    sum(sapply(0:1, function(male) {
      0.5 * integrate(function(f) {
        dnorm(f) * (event_risk(1, t, f, v, male, cfg) - event_risk(0, t, f, v, male, cfg))
      }, -Inf, Inf, rel.tol = 1e-10)$value
    }))
  })
}

# Matrix of true effects: rows = v_grid, columns = times
target_effect_grid <- function(v_grid, times, cfg) {
  m <- sapply(times, function(t) target_effect_t(v_grid, t, cfg))
  dimnames(m) <- list(NULL, paste0("t", times))
  m
}

# Time to benefit for each profile: the first time on the grid at which the effect is at or
# below -delta (risk lowered by at least delta). NA if never reached by the last time.
time_to_benefit <- function(effects, times, delta) {
  apply(effects, 1, function(row) {
    hit <- which(row <= -delta)
    if (length(hit)) times[min(hit)] else NA_real_
  })
}
