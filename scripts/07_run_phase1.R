# Step 7: run the four estimators on many simulated hospitals.
#
# Usage, from the repository root:
#   Rscript scripts/07_run_phase1.R <learner> <trial_fraction> <n_hospitals> <workers>
#   e.g. Rscript scripts/07_run_phase1.R sl 0.20 500 3
#
# Results go to results/phase1/<learner>_trial<percent>/chunk_<k>.rds, 25 hospitals per chunk.
# Finished chunks are skipped, so an interrupted run continues where it stopped.
# Each row records the git commit, and the script refuses to run on uncommitted code.

args <- commandArgs(trailingOnly = TRUE)
learner <- args[1]
trial_fraction <- as.numeric(args[2])
n_hospitals <- as.integer(args[3])
workers <- as.integer(args[4])

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)

setting <- sprintf("%s_trial%02d", learner, round(100 * trial_fraction))
out_dir <- file.path("results", "phase1", setting)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

chunk_size <- 25
chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / chunk_size))

future::plan(future::multisession, workers = workers)

one_hospital <- function(seed, learner, trial_fraction, commit) {
  source("R/generate.R")
  source("R/truth.R")
  source("R/nuisance.R")
  source("R/pseudo.R")
  source("R/smooth.R")
  source("R/estimators.R")
  cfg <- load_config("config/phase1.yaml")
  cfg$trial_fraction <- trial_fraction
  b0 <- participation_intercept(cfg)
  d <- simulate_cohort(cfg, seed = seed, b0 = b0)$observed
  t0 <- Sys.time()
  res <- suppressWarnings(run_estimators(d, learner, seed, make_v_grid(cfg)))
  seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(curves = cbind(seed = seed, res$curves),
       info = cbind(seed = seed, res$info, seconds = seconds, commit = commit))
}

for (k in seq_along(chunks)) {
  path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
  if (file.exists(path)) next
  t0 <- Sys.time()
  res <- future.apply::future_lapply(chunks[[k]], one_hospital, learner = learner,
                                     trial_fraction = trial_fraction, commit = commit,
                                     future.seed = TRUE)
  saveRDS(list(curves = do.call(rbind, lapply(res, `[[`, "curves")),
               info = do.call(rbind, lapply(res, `[[`, "info"))), path)
  cat(sprintf("%s  %s chunk %d of %d done (%.1f min)\n", format(Sys.time(), "%H:%M"), setting, k,
              length(chunks), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
cat("All chunks done.\n")
