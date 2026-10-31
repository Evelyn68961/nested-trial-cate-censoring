# Exploratory runs, as fixed in docs/exploratory_prespecification.md.
#
# Usage, from the repository root:
#   Rscript scripts/15_run_exploratory.R <run> <setting> <n_hospitals> <workers> [folder]
#   run A: truncation range, settings C2 C4
#   run B: mild dropout, settings C2m C3m
#   run C: wrong participation model, settings C5a C5b
#   run control: the reported analysis through this path, settings C2 C4
#   run zero: every truncation scheme at floor 0, settings C2 C4, 3 hospitals
#
# Same seeds as the reported runs, 30 compensator steps. Results go to
# results/exploratory/<run>/<setting>/chunk_<k>.rds, 25 hospitals per chunk; finished chunks are
# skipped. folder replaces results/exploratory, so a smoke test stays apart from the full runs.
# Refuses to run on uncommitted code and records the commit in every row.

args <- commandArgs(trailingOnly = TRUE)
run <- args[1]
setting <- args[2]
n_hospitals <- as.integer(args[3])
workers <- as.integer(args[4])
folder <- if (length(args) >= 5) args[5] else file.path("results", "exploratory")

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)

out_dir <- file.path(folder, run, setting)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
chunk_size <- 25
chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / chunk_size))
future::plan(future::multisession, workers = workers)

one_hospital <- function(seed, run, setting, commit) {
  for (f in c("generate", "truth", "nuisance", "pseudo", "smooth",
              "phase2_generate", "phase2_truth", "phase2_estimators")) source(sprintf("R/%s.R", f))
  source("scripts/15_common.R")
  spec <- exploratory_specs[[run]][[setting]]
  cfg <- exploratory_config()
  b0 <- participation_intercept(cfg)
  d <- simulate_cohort_surv(cfg, spec$censoring, seed = seed, b0 = b0)$observed
  reset_fit_log()
  t0 <- Sys.time()
  analyse <- switch(run, A = run_truncation, zero = run_zero_floor, run_seven)
  res <- tryCatch(withCallingHandlers(
    analyse(d, cfg, spec, seed, make_v_grid(cfg)),
    warning = function(w) {
      record_warning(empty_tag("not in a fit", "not attributed"), conditionMessage(w))
      invokeRestart("muffleWarning")
    }), error = function(e) e)
  warnings_seen <- logged_warnings()
  if (!is.null(warnings_seen)) warnings_seen <- cbind(seed = seed, warnings_seen)
  if (inherits(res, "error")) {
    return(list(curves = NULL, warnings = warnings_seen,
                info = data.frame(seed = seed, seconds = NA, failed = conditionMessage(res), commit = commit)))
  }
  list(curves = cbind(seed = seed, res$curves), warnings = warnings_seen,
       info = cbind(seed = seed, res$info, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")),
                    failed = "", commit = commit))
}

for (k in seq_along(chunks)) {
  path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
  if (file.exists(path)) next
  t0 <- Sys.time()
  res <- future.apply::future_lapply(chunks[[k]], one_hospital, run = run, setting = setting, commit = commit,
                                     future.seed = TRUE)
  saveRDS(list(curves = do.call(rbind, lapply(res, `[[`, "curves")),
               info = Reduce(function(a, b) merge(a, b, all = TRUE), lapply(res, `[[`, "info")),
               warnings = do.call(rbind, lapply(res, `[[`, "warnings"))), path)
  cat(sprintf("%s  %s %s chunk %d of %d done (%.1f min)\n", format(Sys.time(), "%H:%M"), run, setting, k,
              length(chunks), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
cat("All chunks done.\n")
