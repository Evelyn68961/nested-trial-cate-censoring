# Phase 2 runs: the four dropout estimators on many hospitals, for each dropout setting.
#
# Usage, from the repository root:
#   Rscript scripts/10_run_phase2.R <setting> <n_hospitals> <workers>
#   setting: C0 (no dropout), C1 (random), C2 (dependent), C3 (dependent, dropout model leaves
#   out frailty). C2 and C3 use the same hospitals (same seeds); only the analysis differs.
#
# Results go to results/phase2/<setting>/chunk_<k>.rds, 25 hospitals per chunk; finished chunks
# are skipped. Refuses to run on uncommitted code and records the commit in every row.

args <- commandArgs(trailingOnly = TRUE)
setting <- args[1]
n_hospitals <- as.integer(args[2])
workers <- as.integer(args[3])

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)

spec <- list(
  C0 = list(censoring = "none", formula = "~ a + frailty + v + male"),
  C1 = list(censoring = "random", formula = "~ a + frailty + v + male"),
  C2 = list(censoring = "dependent", formula = "~ a + frailty + v + male"),
  C3 = list(censoring = "dependent", formula = "~ a + v + male")
)[[setting]]

out_dir <- file.path("results", "phase2", setting)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
chunk_size <- 25
chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / chunk_size))
future::plan(future::multisession, workers = workers)

one_hospital <- function(seed, spec, commit) {
  for (f in c("generate", "truth", "nuisance", "pseudo", "smooth",
              "phase2_generate", "phase2_truth", "phase2_estimators")) source(sprintf("R/%s.R", f))
  cfg <- load_config("config/phase2.yaml")
  b0 <- participation_intercept(cfg)
  d <- simulate_cohort_surv(cfg, spec$censoring, seed = seed, b0 = b0)$observed
  t0 <- Sys.time()
  res <- suppressWarnings(run_phase2_estimators(d, cfg, as.formula(spec$formula), seed, make_v_grid(cfg)))
  seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(curves = cbind(seed = seed, res$curves),
       info = cbind(seed = seed, res$info, seconds = seconds, commit = commit))
}

for (k in seq_along(chunks)) {
  path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
  if (file.exists(path)) next
  t0 <- Sys.time()
  res <- future.apply::future_lapply(chunks[[k]], one_hospital, spec = spec, commit = commit,
                                     future.seed = TRUE)
  saveRDS(list(curves = do.call(rbind, lapply(res, `[[`, "curves")),
               info = do.call(rbind, lapply(res, `[[`, "info"))), path)
  cat(sprintf("%s  %s chunk %d of %d done (%.1f min)\n", format(Sys.time(), "%H:%M"), setting, k,
              length(chunks), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
cat("All chunks done.\n")
