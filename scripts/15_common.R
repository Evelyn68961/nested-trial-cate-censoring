# Exploratory runs A, B and C (docs/exploratory_prespecification.md): settings, truncation schemes,
# and a record of every warning with its fit type and estimator. Source after the R/ files.
#
# The glm and survreg below sit in front of the real ones, so the code in R/ runs unchanged while
# each warning is recorded, including those that R/ suppresses, instead of only being counted.

right_censor <- ~ a + frailty + v + male
wrong_censor <- ~ a + v + male
right_outcome <- ~ frailty + v + I(v^2) + male
wrong_outcome <- ~ v + I(v^2) + male
right_join <- s ~ frailty + v + male
wrong_join <- s ~ v + male
floors <- c(0.01, 0.02, 0.05, 0.10)

no_frailty_join <- right_formulas
no_frailty_join$participation <- y ~ v + male
no_frailty_helpers <- no_frailty_join
no_frailty_helpers$outcome <- y ~ v + I(v^2) + male

base_spec <- list(censoring = "dependent", censor = right_censor, out = right_outcome,
                  join = right_join, formulas = right_formulas)
make_spec <- function(...) modifyList(base_spec, list(...), keep.null = TRUE)
exploratory_specs <- list(
  control = list(C2 = make_spec(), C4 = make_spec(out = wrong_outcome)),
  zero = list(C2 = make_spec(), C4 = make_spec(out = wrong_outcome)),
  A = list(C2 = make_spec(), C4 = make_spec(out = wrong_outcome)),
  B = list(C2m = make_spec(censoring = "mild"), C3m = make_spec(censoring = "mild", censor = wrong_censor)),
  C = list(C5a = make_spec(join = wrong_join, formulas = no_frailty_join),
           C5b = make_spec(join = wrong_join, formulas = no_frailty_helpers, out = wrong_outcome))
)

# Run B's dropout rates are kept here, so config/phase2.yaml is unchanged
exploratory_config <- function() {
  cfg <- load_config("config/phase2.yaml")
  cfg$censoring$mild <- list(base_rate = 0.06, frailty = 0.7, treated = 0.6)
  cfg
}

# Every patient's event and dropout quantities needed for the summaries of each hospital
hospital_info <- function(d, h, cfg, censoring) {
  trial <- d$s == 1
  cen <- cfg$censoring[[censoring]]
  rate <- cen$base_rate * exp(cen$frailty * d$frailty[trial] + cen$treated * d$a[trial])
  g5 <- weibull_surv(cfg$follow_up_end, h$cens_lp[trial], h$cens_scale[trial])
  data.frame(n_trial = sum(trial), share_dropped = mean(d$event[trial] == 0 & d$time[trial] < cfg$follow_up_end),
             min_p_join = min(h$p_join),
             min_g = min(weibull_surv(pmin(d$time[trial], cfg$follow_up_end), h$cens_lp[trial], h$cens_scale[trial])),
             share_g5_below_0.05_estimated = mean(g5 < 0.05),
             share_g5_below_0.05_true = mean(exp(-rate * cfg$follow_up_end) < 0.05))
}

# ---- Warnings ----

fit_log <- new.env()
reset_fit_log <- function() fit_log$rows <- list()
record_warning <- function(tag, message) {
  if (isTRUE(fit_log$paused)) return(invisible())
  fit_log$rows[[length(fit_log$rows) + 1]] <- cbind(tag, message = message)
}
logged_warnings <- function() {
  if (length(fit_log$rows)) do.call(rbind, fit_log$rows) else NULL
}
empty_tag <- function(fit_type, estimators, t = NA_real_, arm = NA_integer_, fold = NA_integer_) {
  data.frame(fit_type = fit_type, estimators = estimators, t = t, arm = arm, fold = fold)
}

frame_of <- function(calls, frames, name) {
  i <- which(sapply(calls, function(cl) identical(cl[[1]], as.name(name))))
  if (length(i)) list(call = calls[[max(i)]], frame = frames[[max(i)]])
}
local_value <- function(frame, name, default = NA) {
  if (exists(name, envir = frame, inherits = FALSE)) get(name, envir = frame) else default
}

# Which fit is this: from the formula and from the function that called glm or survreg
describe_fit <- function(cl, caller, calls, frames) {
  own <- local_value(caller, "fit_tag", NULL)
  if (!is.null(own)) return(own)
  nuisance <- frame_of(calls, frames, "fit_nuisance")
  if (!is.null(nuisance)) {
    binary <- frame_of(calls, frames, "fit_binary")
    data_name <- deparse(nuisance$call[[2]])[1]
    estimator <- c(dcc = "CC", dne = "NE")[data_name]
    runner <- frame_of(calls, frames, "run_phase2_estimators")
    return(empty_tag(sub("formulas\\$", "logistic ", deparse(binary$call[[6]])[1]), unname(estimator),
                     if (is.null(runner)) NA_real_ else local_value(runner$frame, "t"),
                     local_value(nuisance$frame, "arm", NA_integer_), local_value(nuisance$frame, "k", NA_integer_)))
  }
  f <- eval(cl$formula, caller)
  lhs <- paste(deparse(f[[2]]), collapse = "")
  fold <- local_value(caller, "k", NA_integer_)
  arm <- local_value(caller, "arm", NA_integer_)
  if (lhs == "s") return(empty_tag("logistic participation", "IPCW AIPCW IPCW_t AIPCW_t BJ", fold = fold))
  if (lhs == "a") return(empty_tag("logistic treatment", "IPCW AIPCW IPCW_t AIPCW_t BJ", fold = fold))
  if (grepl("dropped", lhs)) return(empty_tag("weibull dropout", "IPCW AIPCW IPCW_t AIPCW_t", fold = fold))
  if (grepl("event", lhs)) return(empty_tag("weibull outcome", "AIPCW AIPCW_t BJ", arm = arm, fold = fold))
  truncated <- local_value(caller, "truncated", FALSE)
  empty_tag("logistic IPCW outcome", if (truncated) "IPCW_t" else "IPCW",
            local_value(caller, "times")[local_value(caller, "j")], arm, fold)
}

logged_fit <- function(cl, caller, calls, frames) {
  withCallingHandlers(eval(cl, caller), warning = function(w) {
    record_warning(describe_fit(cl, caller, calls, frames), conditionMessage(w))
    invokeRestart("muffleWarning")
  })
}
glm <- function(formula, ...) {
  cl <- match.call()
  cl[[1]] <- quote(stats::glm)
  logged_fit(cl, parent.frame(), sys.calls(), sys.frames())
}
survreg <- function(formula, ...) {
  cl <- match.call()
  cl[[1]] <- quote(survival::survreg)
  logged_fit(cl, parent.frame(), sys.calls(), sys.frames())
}

# ---- Run A: truncation ----

# scheme G:  chance of staying floored at f
# scheme p:  chance of joining floored at f
# scheme pG: lower bound f on the product p G. With p_eff = max(p, f) and G floored at f / p_eff,
#            1 / (p_eff G_eff) = 1 / max(p G, f), and G_eff stays in [0, 1] with G_eff(0) = 1.
floored <- function(scheme, f, p_join) {
  switch(scheme,
         G = list(p = p_join, g_floor = rep(f, length(p_join))),
         p = list(p = pmax(p_join, f), g_floor = rep(0, length(p_join))),
         pG = list(p = pmax(p_join, f), g_floor = f / pmax(p_join, f)))
}

# IPCW's logistic models for schemes G and pG, whose weights use the floored G. As the loop in
# fit_phase2_helpers. The joining and dropout models are refits of those already recorded there,
# so stats::glm and survival::survreg are called directly and their warnings are not counted twice.
fit_floor_gamma <- function(d, times, censor_formula, follow_up_end, seed, out_formula, join_formula,
                            floor_values = floors, n_folds = 5) {
  folds <- make_folds(d$s, n_folds, seed)
  d$dropped <- as.integer(d$s == 1 & d$event == 0 & d$time < follow_up_end)
  out <- list()
  for (scheme in c("G", "pG")) for (f in floor_values) for (arm in 0:1) {
    out[[paste(scheme, f, arm)]] <- matrix(NA_real_, nrow(d), length(times))
  }
  for (k in seq_len(n_folds)) {
    train <- folds != k
    test <- folds == k
    tr <- d[train & d$s == 1, ]
    newd <- d[test, ]
    join <- suppressWarnings(stats::glm(join_formula, binomial(), data = d[train, ]))
    p_tr <- predict(join, tr, type = "response")
    cfit <- suppressWarnings(survival::survreg(update(censor_formula, Surv(time, dropped) ~ .), data = tr, dist = "weibull"))
    tr_lp <- predict(cfit, tr, type = "lp")
    for (arm in 0:1) {
      tra <- tr$a == arm
      for (j in seq_along(times)) {
        st <- status_at(tr[tra, ], times[j])
        g_end <- weibull_surv(pmin(tr$time[tra], times[j]), tr_lp[tra], cfit$scale)
        for (scheme in c("G", "pG")) for (f in floor_values) {
          fit_tag <- empty_tag("logistic IPCW outcome", sprintf("IPCW_%s_%g", scheme, f), times[j], arm, k)
          g_use <- pmax(g_end, floored(scheme, f, p_tr[tra])$g_floor)
          dat <- cbind(tr[tra, c("frailty", "v", "male")], y = st$y, w = 1 / g_use)[st$known, ]
          lfit <- glm(update(out_formula, y ~ .), quasibinomial(), data = dat, weights = w)
          key <- paste(scheme, f, arm)
          out[[key]][test, j] <- predict(lfit, newd, type = "response")
        }
      }
    }
  }
  out
}

run_truncation <- function(d, cfg, spec, seed, v_grid, floor_values = floors,
                           bandwidths = c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0)) {
  times <- unlist(cfg$times)
  h <- fit_phase2_helpers(d, times, spec$censor, cfg$follow_up_end, seed = seed, out_formula = spec$out,
                          join_formula = spec$join)
  gamma <- fit_floor_gamma(d, times, spec$censor, cfg$follow_up_end, seed, spec$out, spec$join, floor_values)
  trial <- d$s == 1
  xi <- list()
  for (scheme in c("G", "p", "pG")) for (f in floor_values) {
    w <- floored(scheme, f, h$p_join)
    ipcw <- paste0("IPCW_", scheme, "_", f)
    aipcw <- paste0("AIPCW_", scheme, "_", f)
    xi[[ipcw]] <- xi[[aipcw]] <- list()
    for (j in seq_along(times)) {
      t <- times[j]
      st <- status_at(d, t)
      g_end <- weibull_surv(pmin(d$time, t), h$cens_lp, h$cens_scale)
      ystar <- ifelse(trial, st$known * st$y / pmax(g_end, w$g_floor), 0)
      if (scheme == "p") {
        g1 <- h$ipcw_g1[, j]
        g0 <- h$ipcw_g0[, j]
      } else {
        g1 <- gamma[[paste(scheme, f, 1)]][, j]
        g0 <- gamma[[paste(scheme, f, 0)]][, j]
      }
      xi[[ipcw]][[j]] <- pseudo_from_status(d, ystar, w$p, h$p_treat, g1, g0)
      wg1 <- 1 - weibull_surv(t, h$lp1, h$scale1)
      wg0 <- 1 - weibull_surv(t, h$lp0, h$scale0)
      xi[[aipcw]][[j]] <- pseudo_from_status(d, augmented_status(d, t, h, g_floor = w$g_floor[trial]),
                                             w$p, h$p_treat, wg1, wg0)
    }
  }
  last <- length(times)
  rows <- list()
  for (est in names(xi)) {
    bw <- choose_bandwidth(d$v, xi[[est]][[last]], bandwidths)
    for (j in seq_along(times)) {
      rows[[length(rows) + 1]] <- cbind(estimator = est, t = times[j], h = bw, local_linear(d$v, xi[[est]][[j]], v_grid, bw))
    }
  }
  list(curves = do.call(rbind, rows), info = hospital_info(d, h, cfg, spec$censoring))
}

# Control only: at floor 0 every scheme must reproduce the reported IPCW and AIPCW
run_zero_floor <- function(d, cfg, spec, seed, v_grid) {
  run_truncation(d, cfg, spec, seed, v_grid, floor_values = 0)
}

run_seven <- function(d, cfg, spec, seed, v_grid) {
  res <- run_phase2_estimators(d, cfg, spec$censor, seed, v_grid, out_formula = spec$out,
                               join_formula = spec$join, nuisance_formulas = spec$formulas)
  # The same fits again, at one time only, for the summaries; their warnings are already recorded
  fit_log$paused <- TRUE
  h <- fit_phase2_helpers(d, 5, spec$censor, cfg$follow_up_end, seed = seed, out_formula = spec$out,
                          join_formula = spec$join)
  fit_log$paused <- FALSE
  list(curves = res$curves, info = hospital_info(d, h, cfg, spec$censoring))
}
