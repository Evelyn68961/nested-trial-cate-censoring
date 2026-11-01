# Step 2a, check 3: CC refits p_join and p_treat on the reduced data, so p_join becomes
# P(S = 1, status known | X). CC_fullp takes both from the full cohort and keeps CC's reduced data
# for the outcome model and residuals. CC is recomputed beside it as a control. R/ is not changed.
#
# Usage, from the repository root:
#   Rscript scripts/14_check_cc_propensity.R <setting> <n_hospitals> <workers>
#   setting C1 or C2. Results go to results/check_step2/cc_fullp/<setting>/chunk_<k>.rds

args <- commandArgs(trailingOnly = TRUE)
setting <- args[1]
n_hospitals <- as.integer(args[2])
workers <- as.integer(args[3])

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)

censoring <- c(C1 = "random", C2 = "dependent")[[setting]]
out_dir <- file.path("results", "check_step2", "cc_fullp", setting)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / 25))
future::plan(future::multisession, workers = workers)

# As the CC part of run_phase2_estimators, with CC_fullp beside it
run_cc_variants <- function(d, cfg, seed, v_grid, bandwidths = c(0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0)) {
  times <- unlist(cfg$times)
  xi <- list(CC = list(), CC_fullp = list())
  keep_cc <- list()
  dfull <- d
  dfull$y <- ifelse(d$s == 1, 0L, NA)   # y is not used for p_join or p_treat
  full <- suppressWarnings(fit_nuisance(dfull, "glm", seed = seed))
  for (j in seq_along(times)) {
    st <- status_at(d, times[j])
    keep <- d$s == 0 | st$known
    dcc <- d[keep, ]
    dcc$y <- st$y[keep]
    nu <- fit_nuisance(dcc, "glm", seed = seed)
    xi$CC[[j]] <- pseudo_outcome(dcc, nu)
    nu$p_join <- full$p_join[keep]
    nu$p_treat <- full$p_treat[keep]
    xi$CC_fullp[[j]] <- pseudo_outcome(dcc, nu)
    keep_cc[[j]] <- keep
  }
  last <- length(times)
  rows <- list()
  for (est in names(xi)) {
    bw <- choose_bandwidth(d$v[keep_cc[[last]]], xi[[est]][[last]], bandwidths)
    for (j in seq_along(times)) {
      fit <- local_linear(d$v[keep_cc[[j]]], xi[[est]][[j]], v_grid, bw)
      rows[[length(rows) + 1]] <- cbind(estimator = est, t = times[j], h = bw, fit)
    }
  }
  do.call(rbind, rows)
}

one_hospital <- function(seed, censoring, commit) {
  for (f in c("generate", "truth", "nuisance", "pseudo", "smooth", "phase2_generate")) source(sprintf("R/%s.R", f))
  cfg <- load_config("config/phase2.yaml")
  b0 <- participation_intercept(cfg)
  d <- simulate_cohort_surv(cfg, censoring, seed = seed, b0 = b0)$observed
  t0 <- Sys.time()
  warned <- character()
  res <- tryCatch(withCallingHandlers(
    run_cc_variants(d, cfg, seed, make_v_grid(cfg)),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }), error = function(e) e)
  if (inherits(res, "error")) {
    return(list(curves = NULL, info = data.frame(seed = seed, seconds = NA, n_warnings = length(warned),
                                                 failed = conditionMessage(res), commit = commit)))
  }
  list(curves = cbind(seed = seed, res),
       info = data.frame(seed = seed, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")),
                         n_warnings = length(warned), failed = "", commit = commit))
}

for (k in seq_along(chunks)) {
  path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
  if (file.exists(path)) next
  t0 <- Sys.time()
  res <- future.apply::future_lapply(chunks[[k]], one_hospital, censoring = censoring, commit = commit,
                                     future.seed = TRUE)
  saveRDS(list(curves = do.call(rbind, lapply(res, `[[`, "curves")),
               info = do.call(rbind, lapply(res, `[[`, "info"))), path)
  cat(sprintf("%s  %s chunk %d of %d done (%.1f min)\n", format(Sys.time(), "%H:%M"), setting, k,
              length(chunks), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
cat("All chunks done.\n")
