# Standard deviation across hospitals at t = 5, averaged over the v grid, from saved rows, for the
# corrected report. Run from the repository root:  Rscript scripts/15_sd_table.R
# Writes reports/tables/15_sd_at_t5.csv

source("scripts/14_common.R")
rows <- list()
for (setting in paste0("C", 0:4)) {
  x <- read_chunks(file.path("results", "phase2", setting))
  x <- x[x$t == 5, ]
  for (est in unique(x$estimator)) {
    y <- x[x$estimator == est, ]
    rows[[length(rows) + 1]] <- data.frame(setting = setting, estimator = est, sd_integrated = mean(tapply(y$estimate, y$v, sd)))
  }
}
write.csv(round_numeric(do.call(rbind, rows)), "reports/tables/15_sd_at_t5.csv", row.names = FALSE)
