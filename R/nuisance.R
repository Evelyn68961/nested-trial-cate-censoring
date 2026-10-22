# The three helper models (the paper calls them nuisance functions), fitted with cross-fitting.
#
#   p_join   P(S = 1 | X)          chance of joining the trial; fitted on all patients
#   p_treat  P(A = 1 | X, S = 1)   chance of treatment in the trial; fitted on trial patients
#   g1, g0   E(Y | A = a, X, S = 1) risk with and without treatment; fitted on trial patients
#            in each arm, then predicted for every patient
#
# Cross-fitting (paper section 5, step 1): patients are split into L folds. Each fold's
# predictions come from models fitted on the other folds only, so no patient's own outcome
# is used to make that patient's predictions.
#
# Two learner settings:
#   "glm"  logistic regressions with the right terms (the outcome model includes v squared)
#   "sl"   Super Learner choosing a blend of logistic regression, a generalized additive model
#          and a random forest, without being told the right terms

covariate_names <- c("frailty", "v", "male")

# Folds that each hold about the same share of trial patients
make_folds <- function(s, n_folds, seed) {
  set.seed(seed)
  folds <- integer(length(s))
  for (group in 0:1) {
    idx <- which(s == group)
    folds[idx] <- sample(rep(seq_len(n_folds), length.out = length(idx)))
  }
  folds
}

fit_binary <- function(y, x, newx, learner, glm_formula) {
  if (learner == "glm") {
    fit <- glm(glm_formula, data = cbind(y = y, x), family = binomial())
    return(as.numeric(predict(fit, newdata = newx, type = "response")))
  }
  if (learner == "sl") {
    fit <- SuperLearner::SuperLearner(
      Y = y, X = x, newX = newx, family = binomial(),
      SL.library = c("SL.glm", "SL.gam", "SL.ranger"),
      cvControl = list(V = 5),
      env = asNamespace("SuperLearner")
    )
    return(as.numeric(fit$SL.predict))
  }
  stop("learner must be 'glm' or 'sl'")
}

# Formulas used when learner = "glm". The defaults contain the right terms.
# Lesson 3 replaces one or both with a wrong formula on purpose:
#   participation = y ~ 1                  (everyone given the same chance of joining)
#   outcome       = y ~ v + I(v^2) + male  (frailty left out)
right_formulas <- list(
  participation = y ~ frailty + v + male,
  treatment = y ~ frailty + v + male,
  outcome = y ~ frailty + v + I(v^2) + male
)

# trial_only = TRUE: d holds trial patients only; no participation model is fitted and
# p_join is set to 1, so the pseudo-outcome targets the trial population (estimator T).
fit_nuisance <- function(d, learner = "glm", n_folds = 5, seed = 1,
                         formulas = right_formulas, trial_only = FALSE) {
  folds <- make_folds(d$s, n_folds, seed)
  out <- data.frame(id = d$id, fold = folds,
                    p_join = NA_real_, p_treat = NA_real_, g1 = NA_real_, g0 = NA_real_)
  x_all <- d[, covariate_names]

  for (k in seq_len(n_folds)) {
    train <- folds != k
    test <- folds == k
    trial <- train & d$s == 1
    newx <- x_all[test, , drop = FALSE]

    if (trial_only) {
      out$p_join[test] <- 1
    } else {
      out$p_join[test] <- fit_binary(d$s[train], x_all[train, , drop = FALSE], newx, learner,
                                     formulas$participation)
    }

    # Treatment was randomized, so a simple logistic model is enough here whatever the learner
    out$p_treat[test] <- fit_binary(d$a[trial], x_all[trial, , drop = FALSE], newx, "glm",
                                    formulas$treatment)

    for (arm in 0:1) {
      in_arm <- trial & d$a == arm
      pred <- fit_binary(d$y[in_arm], x_all[in_arm, , drop = FALSE], newx, learner,
                         formulas$outcome)
      if (arm == 1) out$g1[test] <- pred else out$g0[test] <- pred
    }
  }
  out
}
