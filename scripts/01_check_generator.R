# Step 1 check: what one simulated hospital looks like, and the two true effect curves.
# Run from the repository root:  Rscript scripts/01_check_generator.R

source("R/generate.R")
source("R/truth.R")
library(ggplot2)

cfg <- load_config("config/phase1.yaml")
b0 <- participation_intercept(cfg)
d <- simulate_cohort(cfg, seed = 1, b0 = b0)$observed

cat(sprintf("Participation intercept: %.4f\n", b0))
cat(sprintf("Eligible patients: %d   in the trial: %d   not in the trial: %d\n",
            nrow(d), sum(d$s), sum(1 - d$s)))
cat(sprintf("Mean frailty   all: %.2f   trial: %.2f   not in trial: %.2f\n",
            mean(d$frailty), mean(d$frailty[d$s == 1]), mean(d$frailty[d$s == 0])))
cat(sprintf("Trial: %d treated, %d control; outcome rate %.1f%% treated, %.1f%% control\n",
            sum(d$a == 1, na.rm = TRUE), sum(d$a == 0, na.rm = TRUE),
            100 * mean(d$y[d$s == 1 & d$a == 1]), 100 * mean(d$y[d$s == 1 & d$a == 0])))

v_grid <- make_v_grid(cfg)
curves <- rbind(
  data.frame(v = v_grid, effect = target_effect(v_grid, cfg), who = "All eligible patients (target)"),
  data.frame(v = v_grid, effect = trial_effect(v_grid, cfg, b0), who = "Trial patients only")
)
write.csv(curves, "reports/tables/01_true_curves.csv", row.names = FALSE)

idx <- c(1, 10, 19, 28, 37)
print(data.frame(v = v_grid[idx],
                 target = round(curves$effect[idx], 3),
                 trial = round(curves$effect[length(v_grid) + idx], 3)))

p1 <- ggplot(curves, aes(v, effect, linetype = who)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.8) +
  labs(x = "Profile value v", y = "True risk difference (treated minus untreated)",
       linetype = NULL,
       title = "The true effect curve differs between the trial and all eligible patients",
       subtitle = "Below zero = treatment lowers the risk. Trial patients are less frail, so they benefit more.") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave("reports/figures/01_true_curves.png", p1, width = 7, height = 4.5, dpi = 150, type = "cairo")

p2 <- ggplot(d, aes(frailty, fill = factor(s, labels = c("Not in trial", "In trial")))) +
  geom_density(alpha = 0.5) +
  labs(x = "Frailty", y = "Density", fill = NULL,
       title = "Trial patients are less frail than those who did not join") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave("reports/figures/01_frailty_by_trial.png", p2, width = 7, height = 4, dpi = 150, type = "cairo")

cat("Figures written to reports/figures/\n")
