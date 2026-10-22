# Step 4 check: the paper's estimator (P) drawn on one hospital, against the true curve.
# Run from the repository root:  Rscript scripts/04_check_curve.R

source("R/generate.R")
source("R/truth.R")
source("R/nuisance.R")
source("R/pseudo.R")
source("R/smooth.R")
library(ggplot2)

cfg <- load_config("config/phase1.yaml")
b0 <- participation_intercept(cfg)
v_grid <- make_v_grid(cfg)
u <- seq(0, 4, length.out = 801)
truth_u <- target_effect(u, cfg)

d <- simulate_cohort(cfg, seed = 1, b0 = b0)$observed
nu <- fit_nuisance(d, "sl", n_folds = 5, seed = 1)
xi <- pseudo_outcome(d, nu)

bandwidths <- seq(0.3, 2.0, by = 0.1)
scores <- cv_scores(d$v, xi, bandwidths)
h <- bandwidths[which.min(scores)]
fit <- local_linear(d$v, xi, v_grid, h)
fit$truth <- target_effect(v_grid, cfg)
fit$smoothed_truth <- smoothed_curve(u, truth_u, rep(1, length(u)), v_grid, h)

cat(sprintf("Pseudo-outcomes: %d patients; range %.1f to %.1f; middle 90%% from %.2f to %.2f\n",
            length(xi), min(xi), max(xi), quantile(xi, 0.05), quantile(xi, 0.95)))
cat(sprintf("Bandwidth chosen by cross-validation: %.1f\n", h))
cat(sprintf("Intervals containing the true curve: %d of %d grid points\n",
            sum(fit$lower <= fit$truth & fit$truth <= fit$upper), nrow(fit)))
print(round(fit[c(1, 10, 19, 28, 37), c("v", "estimate", "lower", "upper", "truth", "smoothed_truth")], 3),
      row.names = FALSE)

p <- ggplot(fit, aes(v)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "steelblue", alpha = 0.2) +
  geom_line(aes(y = estimate, colour = "Estimate (one hospital)"), linewidth = 0.8) +
  geom_line(aes(y = truth, colour = "True curve"), linewidth = 0.8, linetype = "dashed") +
  scale_colour_manual(values = c("Estimate (one hospital)" = "steelblue", "True curve" = "black")) +
  labs(x = "Profile value v", y = "Risk difference (treated minus untreated)", colour = NULL,
       title = "The paper's estimator in one simulated hospital",
       subtitle = sprintf("Super Learner helpers; bandwidth %.1f (cross-validated); band: 95%% intervals", h)) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave("reports/figures/04_one_hospital_curve.png", p, width = 7, height = 4.5, dpi = 150)
cat("Figure written to reports/figures/04_one_hospital_curve.png\n")
