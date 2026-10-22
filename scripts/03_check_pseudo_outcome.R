# Step 3 check: the pseudo-outcome repairs one wrong helper model, but not two.
# 200 hospitals; logistic helper models with the right terms or with a term left out on purpose.
# The quantity checked is the average effect over all eligible patients (the mean of the
# pseudo-outcomes), compared with the outcome model alone (the mean of g1 - g0).
# Run from the repository root:  Rscript scripts/03_check_pseudo_outcome.R

source("R/generate.R")
source("R/truth.R")
source("R/nuisance.R")
source("R/pseudo.R")

cfg <- load_config("config/phase1.yaml")
b0 <- participation_intercept(cfg)
true_average <- mean(target_effect(seq(0, 4, length.out = 401), cfg))

wrong <- list(participation = y ~ 1, outcome = y ~ v + I(v^2) + male)
settings <- list(
  "Both right" = right_formulas,
  "Outcome model wrong" = modifyList(right_formulas, list(outcome = wrong$outcome)),
  "Participation model wrong" = modifyList(right_formulas, list(participation = wrong$participation)),
  "Both wrong" = modifyList(right_formulas, wrong)
)

n_hospitals <- 200
rows <- list()
for (name in names(settings)) {
  est <- t(sapply(seq_len(n_hospitals), function(seed) {
    d <- simulate_cohort(cfg, seed = seed, b0 = b0)$observed
    nu <- fit_nuisance(d, "glm", n_folds = 5, seed = seed, formulas = settings[[name]])
    c(model_only = mean(nu$g1 - nu$g0), pseudo = mean(pseudo_outcome(d, nu)))
  }))
  rows[[name]] <- data.frame(
    helpers = name,
    outcome_model_alone = round(mean(est[, "model_only"]) - true_average, 4),
    with_correction = round(mean(est[, "pseudo"]) - true_average, 4),
    with_correction_mcse = round(sd(est[, "pseudo"]) / sqrt(n_hospitals), 4),
    with_correction_sd = round(sd(est[, "pseudo"]), 4)
  )
}
result <- do.call(rbind, rows)
cat(sprintf("True average effect over all eligible patients: %.4f\n", true_average))
cat(sprintf("Error (estimate minus truth), mean of %d hospitals:\n", n_hospitals))
print(result, row.names = FALSE)
write.csv(result, "reports/tables/03_double_robustness.csv", row.names = FALSE)
