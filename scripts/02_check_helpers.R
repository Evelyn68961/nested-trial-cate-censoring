# Step 2 check: fit the three helper models on one hospital and compare them with the truth.
# Run from the repository root:  Rscript scripts/02_check_helpers.R

source("R/generate.R")
source("R/truth.R")
source("R/nuisance.R")
library(ggplot2)

cfg <- load_config("config/phase1.yaml")
b0 <- participation_intercept(cfg)
sim <- simulate_cohort(cfg, seed = 1, b0 = b0)
d <- sim$observed
h <- sim$hidden

summarise_fit <- function(nu, learner, seconds) {
  data.frame(
    learner = learner,
    seconds = round(seconds, 1),
    join_error = round(mean(abs(nu$p_join - h$p_join)), 3),
    risk_treated_error = round(mean(abs(nu$g1 - h$p1)), 3),
    risk_untreated_error = round(mean(abs(nu$g0 - h$p0)), 3),
    effect_error = round(mean(abs((nu$g1 - nu$g0) - (h$p1 - h$p0))), 3),
    smallest_p_join = signif(min(nu$p_join), 2)
  )
}

fits <- list()
rows <- list()
for (learner in c("glm", "sl")) {
  t0 <- Sys.time()
  fits[[learner]] <- fit_nuisance(d, learner, n_folds = 5, seed = 1)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  rows[[learner]] <- summarise_fit(fits[[learner]], learner, secs)
}
table_fit <- do.call(rbind, rows)
cat("Average absolute error of each helper prediction against the truth (one hospital):\n")
print(table_fit, row.names = FALSE)
write.csv(table_fit, "reports/tables/02_helper_errors.csv", row.names = FALSE)

# Preview of why the 2,000 non-trial patients matter: average the outcome model's predicted
# effect over patients with v near 2, once among everyone and once among trial patients only.
# One hospital is noisy, so this is repeated over 200 hospitals (20 were too few: chance made both look biased).
preview <- t(sapply(1:200, function(seed) {
  di <- simulate_cohort(cfg, seed = seed, b0 = b0)$observed
  nui <- fit_nuisance(di, "glm", n_folds = 5, seed = seed)
  near2 <- abs(di$v - 2) < 0.2
  effect <- nui$g1 - nui$g0
  c(all = mean(effect[near2]), trial = mean(effect[near2 & di$s == 1]))
}))
cat("\nOutcome model's predicted effect for patients with v between 1.8 and 2.2, 200 hospitals:\n")
cat(sprintf("  Averaged over all eligible patients: mean %.3f (hospitals ranged %.3f to %.3f); true target %.3f\n",
            mean(preview[, "all"]), min(preview[, "all"]), max(preview[, "all"]), target_effect(2, cfg)))
cat(sprintf("  Averaged over trial patients only:   mean %.3f (hospitals ranged %.3f to %.3f); true trial value %.3f\n",
            mean(preview[, "trial"]), min(preview[, "trial"]), max(preview[, "trial"]), trial_effect(2, cfg, b0)))

plot_data <- rbind(
  data.frame(learner = "glm (told the right terms)", truth = h$p1 - h$p0,
             predicted = fits$glm$g1 - fits$glm$g0, s = d$s),
  data.frame(learner = "Super Learner (not told)", truth = h$p1 - h$p0,
             predicted = fits$sl$g1 - fits$sl$g0, s = d$s)
)
p <- ggplot(plot_data, aes(truth, predicted, colour = factor(s, labels = c("Not in trial", "In trial")))) +
  geom_abline(colour = "grey50") +
  geom_point(alpha = 0.25, size = 0.6) +
  facet_wrap(~learner) +
  coord_cartesian(xlim = c(-0.25, 0.25), ylim = c(-0.5, 0.6)) +
  labs(x = "True effect for this patient (risk difference)",
       y = "Effect predicted by the outcome model",
       colour = NULL,
       title = "Outcome model: predicted vs true effect, one hospital of 2,500 patients",
       subtitle = "Grey line = exact prediction. The model learns from trial patients and is applied to everyone.") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom") +
  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))
ggsave("reports/figures/02_outcome_model_vs_truth.png", p, width = 8.5, height = 4.8, dpi = 150)
cat("\nFigure written to reports/figures/02_outcome_model_vs_truth.png\n")
