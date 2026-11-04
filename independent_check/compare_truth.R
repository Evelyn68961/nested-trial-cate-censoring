# True values: repository (R/phase2_truth.R) against the independent script's truth.csv.
# The script reports only t = 5 at v = 1, 2, 3. Its "surv" estimand is a survival difference,
# treated minus untreated; the repository's curve is a risk difference, so its sign is flipped.
# Run from the repository root:  Rscript independent_check/compare_truth.R
# Prints the comparison; writes no file.
for (f in c("generate", "truth", "smooth", "phase2_generate", "phase2_truth")) source(sprintf("R/%s.R", f))
cfg <- load_config("config/phase2.yaml")
script <- read.csv("independent_check/output/truth.csv")
script <- script[script$estimand == "surv", ]
v_grid <- make_v_grid(cfg)
times <- unlist(cfg$times)
grid <- target_effect_grid(v_grid, times, cfg)
rows <- sapply(script$v, function(p) which(abs(v_grid - p) < 1e-9))
repo <- -grid[rows, which(times == 5)]
out <- data.frame(v = script$v, t = 5, repo_survival_difference = repo, script_truth = script$truth,
                  difference = repo - script$truth)
print(format(out, digits = 17), row.names = FALSE)
cat(sprintf("largest absolute difference: %.3g\n", max(abs(out$difference))))
direct <- -target_effect_t(script$v, 5, cfg)
cat(sprintf("target_effect_t at v = 1, 2, 3 directly, largest absolute difference: %.3g\n", max(abs(direct - script$truth))))
cat(sprintf("v grid: %d values, %g to %g; times: %s\n", length(v_grid), min(v_grid), max(v_grid), paste(times, collapse = " ")))
