# Step 2a, check 1: is the 30-step midpoint rule for the AIPCW compensator accurate enough?
# R/ is not changed: only the default n_steps of augmented_status is overridden.
#
# Usage, from the repository root:
#   Rscript scripts/14_check_compensator.R integrate
#     about 20 trial patients with the largest 1/G, in the C2 hospital with the smallest chance of
#     staying, against stats::integrate. The same hospital is also compared with its saved row.
#   Rscript scripts/14_check_compensator.R run <setting> <n_steps> <n_hospitals> <workers>
#     setting C2 or C4, same seeds and same future_lapply route as scripts/10_run_phase2.R.
#     Results go to results/check_step2/compensator/n<n_steps>/<setting>/chunk_<k>.rds

args <- commandArgs(trailingOnly = TRUE)
mode <- args[1]

phase2_files <- c("generate", "truth", "nuisance", "pseudo", "smooth",
                  "phase2_generate", "phase2_truth", "phase2_estimators")
right_formula <- ~ a + frailty + v + male
right_outcome <- ~ frailty + v + I(v^2) + male

use_n_steps <- function(n_steps) {
  f <- get("augmented_status", envir = globalenv())
  formals(f)$n_steps <- n_steps
  assign("augmented_status", f, envir = globalenv())
}

if (mode == "integrate") {
  for (f in phase2_files) source(sprintf("R/%s.R", f))
  source("scripts/14_common.R")
  cfg <- load_config("config/phase2.yaml")
  b0 <- participation_intercept(cfg)
  times <- unlist(cfg$times)
  t <- 5

  info <- read_chunks("results/phase2/C2", "info")
  seed <- info$seed[which.min(info$min_g)]
  cat(sprintf("Hospital seed %d, smallest chance of staying %.6f\n", seed, min(info$min_g)))

  # The saved runs drew under L'Ecuyer-CMRG, set by future.seed = TRUE
  RNGkind("L'Ecuyer-CMRG")
  d <- simulate_cohort_surv(cfg, "dependent", seed = seed, b0 = b0)$observed
  res <- suppressWarnings(run_phase2_estimators(d, cfg, right_formula, seed, make_v_grid(cfg),
                                                out_formula = right_outcome))
  saved <- read_chunks("results/phase2/C2")
  saved <- saved[saved$seed == seed, ]
  m <- merge(res$curves, saved, by = c("estimator", "t", "v"), suffixes = c(".n", ".o"))
  control <- max(abs(m$estimate.n - m$estimate.o))
  cat(sprintf("Control: %d rows, largest difference from the saved row %.3g\n", nrow(m), control))
  if (control != 0) stop("The 30-step rerun does not reproduce the saved hospital.")

  h <- fit_phase2_helpers(d, times, right_formula, cfg$follow_up_end, seed = seed, out_formula = right_outcome)
  trial <- which(d$s == 1)
  st <- status_at(d, t)
  end <- pmin(d$time[trial], t)
  a <- d$a[trial]
  lp <- ifelse(a == 1, h$lp1[trial], h$lp0[trial])
  sc <- ifelse(a == 1, h$scale1[trial], h$scale0[trial])
  cl <- h$cens_lp[trial]
  cs <- h$cens_scale[trial]
  G_end <- weibull_surv(end, cl, cs)
  dropped <- d$event[trial] == 0 & d$time[trial] < t
  jump <- ifelse(dropped, (1 - exp(-(weibull_cumhaz(t, lp, sc) - weibull_cumhaz(d$time[trial], lp, sc)))) /
                   weibull_surv(d$time[trial], cl, cs), 0)
  base <- st$known[trial] * st$y[trial] / G_end + jump

  # Exact compensator: substitute x = cumulative dropout hazard, so d(1/G) = exp(x) dx. Second
  # route: substitute y = 1/G directly.
  exact_x <- function(i) {
    F_x <- function(x) {
      u <- exp(cl[i]) * x^cs[i]
      (1 - exp(-(weibull_cumhaz(t, lp[i], sc[i]) - weibull_cumhaz(u, lp[i], sc[i])))) * exp(x)
    }
    integrate(F_x, 0, weibull_cumhaz(end[i], cl[i], cs[i]), rel.tol = 1e-11, subdivisions = 5000L)$value
  }
  exact_y <- function(i) {
    F_y <- function(y) {
      u <- exp(cl[i]) * log(y)^cs[i]
      1 - exp(-(weibull_cumhaz(t, lp[i], sc[i]) - weibull_cumhaz(u, lp[i], sc[i])))
    }
    integrate(F_y, 1, 1 / G_end[i], rel.tol = 1e-11, subdivisions = 5000L)$value
  }

  comp_at <- function(n_steps) {
    use_n_steps(n_steps)
    base - augmented_status(d, t, h)[trial]
  }
  comp30 <- comp_at(30)
  comp300 <- comp_at(300)
  comp3000 <- comp_at(3000)
  use_n_steps(30)

  top <- order(G_end)[1:20]
  x <- sapply(top, exact_x)
  y <- sapply(top, exact_y)
  out <- data.frame(seed = seed, id = d$id[trial][top], arm = a[top], dropped = dropped[top],
                    one_over_G = 1 / G_end[top], exact_integrate = x, exact_second_route = y,
                    comp_30 = comp30[top], comp_300 = comp300[top], comp_3000 = comp3000[top],
                    error_30 = comp30[top] - x, error_300 = comp300[top] - x, error_3000 = comp3000[top] - x)
  options(width = 200)
  print(out, row.names = FALSE, digits = 6)
  cat(sprintf("\nLargest |routes differ| %.3g\n", max(abs(x - y))))
  cat(sprintf("Largest |error|: 30 steps %.4g, 300 steps %.4g, 3000 steps %.4g\n",
              max(abs(out$error_30)), max(abs(out$error_300)), max(abs(out$error_3000))))
  cat(sprintf("All trial patients, mean Y* change (3000 minus 30 steps): %.6f; trial patients %d\n",
              mean(comp30 - comp3000), length(trial)))
  write.csv(round_numeric(out), "reports/tables/14_compensator_integrate_check.csv", row.names = FALSE)
  if (max(abs(out$error_300)) >= 5e-4 && max(abs(out$error_3000)) >= 5e-4) {
    stop("Neither 300 nor 3000 steps agrees with stats::integrate to 3 decimals.")
  }
} else if (mode == "run") {
  setting <- args[2]
  n_steps <- as.integer(args[3])
  n_hospitals <- as.integer(args[4])
  workers <- as.integer(args[5])

  if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
    stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
  }
  commit <- system("git rev-parse --short HEAD", intern = TRUE)

  spec <- list(C2 = list(censoring = "dependent", out_formula = right_outcome),
               C4 = list(censoring = "dependent", out_formula = ~ v + I(v^2) + male))[[setting]]
  out_dir <- file.path("results", "check_step2", "compensator", paste0("n", n_steps), setting)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / 25))
  future::plan(future::multisession, workers = workers)

  one_hospital <- function(seed, spec, n_steps, commit) {
    for (f in phase2_files) source(sprintf("R/%s.R", f))
    use_n_steps(n_steps)
    cfg <- load_config("config/phase2.yaml")
    b0 <- participation_intercept(cfg)
    d <- simulate_cohort_surv(cfg, spec$censoring, seed = seed, b0 = b0)$observed
    t0 <- Sys.time()
    warned <- character()
    res <- tryCatch(withCallingHandlers(
      run_phase2_estimators(d, cfg, right_formula, seed, make_v_grid(cfg), out_formula = spec$out_formula),
      warning = function(w) {
        warned <<- c(warned, conditionMessage(w))
        invokeRestart("muffleWarning")
      }), error = function(e) e)
    if (inherits(res, "error")) {
      return(list(curves = NULL, info = data.frame(seed = seed, seconds = NA, n_warnings = length(warned),
                                                   failed = conditionMessage(res), commit = commit)))
    }
    seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    list(curves = cbind(seed = seed, res$curves),
         info = data.frame(seed = seed, seconds = seconds, n_warnings = length(warned),
                           failed = "", commit = commit))
  }

  for (k in seq_along(chunks)) {
    path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
    if (file.exists(path)) next
    t0 <- Sys.time()
    res <- future.apply::future_lapply(chunks[[k]], one_hospital, spec = spec, n_steps = n_steps,
                                       commit = commit, future.seed = TRUE)
    saveRDS(list(curves = do.call(rbind, lapply(res, `[[`, "curves")),
                 info = do.call(rbind, lapply(res, `[[`, "info"))), path)
    cat(sprintf("%s  %s n%d chunk %d of %d done (%.1f min)\n", format(Sys.time(), "%H:%M"), setting, n_steps,
                k, length(chunks), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  }
  cat("All chunks done.\n")
} else if (mode == "patients") {
  # Per hospital at t = 5: the largest 30-step compensator error relative to 3000 steps, and how
  # much of AIPCW's curve change comes from one patient. The curve is linear in the pseudo-outcome
  # for a fixed bandwidth, so each patient's part of the change is known exactly; the hospital's
  # saved AIPCW bandwidth is used.
  # Usage: Rscript scripts/14_check_compensator.R patients <setting> <n_hospitals> <workers>
  # Results go to results/check_step2/compensator/patients/<setting>/chunk_<k>.rds
  setting <- args[2]
  n_hospitals <- as.integer(args[3])
  workers <- as.integer(args[4])
  if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
    stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
  }
  commit <- system("git rev-parse --short HEAD", intern = TRUE)
  out_formula <- list(C2 = right_outcome, C4 = ~ v + I(v^2) + male)[[setting]]
  source("scripts/14_common.R")
  saved <- read_chunks(file.path("results", "phase2", setting))
  saved <- saved[saved$estimator == "AIPCW" & saved$t == 5 & abs(saved$v - saved$v[1]) < 1e-9, ]
  bandwidth <- setNames(saved$h, saved$seed)
  out_dir <- file.path("results", "check_step2", "compensator", "patients", setting)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  chunks <- split(seq_len(n_hospitals), ceiling(seq_len(n_hospitals) / 25))
  future::plan(future::multisession, workers = workers)

  one_hospital <- function(seed, bw, out_formula, commit) {
    for (f in phase2_files) source(sprintf("R/%s.R", f))
    cfg <- load_config("config/phase2.yaml")
    b0 <- participation_intercept(cfg)
    d <- simulate_cohort_surv(cfg, "dependent", seed = seed, b0 = b0)$observed
    t <- 5
    times <- unlist(cfg$times)
    h <- suppressWarnings(fit_phase2_helpers(d, times, right_formula, cfg$follow_up_end, seed = seed,
                                             out_formula = out_formula))
    use_n_steps(30)
    y30 <- augmented_status(d, t, h)
    use_n_steps(3000)
    y3000 <- augmented_status(d, t, h)
    g1 <- 1 - weibull_surv(t, h$lp1, h$scale1)
    g0 <- 1 - weibull_surv(t, h$lp0, h$scale0)
    xi30 <- pseudo_from_status(d, y30, h$p_join, h$p_treat, g1, g0)
    xi3000 <- pseudo_from_status(d, y3000, h$p_join, h$p_treat, g1, g0)
    v_grid <- make_v_grid(cfg)
    fit30 <- local_linear(d$v, xi30, v_grid, bw)$estimate
    fit3000 <- local_linear(d$v, xi3000, v_grid, bw)$estimate
    dxi <- xi3000 - xi30
    # parts[k, i]: patient i's part of the curve change at v_grid[k]
    parts <- t(sapply(v_grid, function(v0) {
      dv <- d$v - v0
      w <- epanechnikov(dv / bw) / bw
      Dinv <- solve(matrix(c(mean(w), mean(w * dv), mean(w * dv), mean(w * dv^2)), 2, 2))
      (Dinv[1, 1] + Dinv[1, 2] * dv) * w * dxi / length(dv)
    }))
    change <- fit3000 - fit30
    stopifnot(max(abs(rowSums(parts) - change)) < 1e-8)
    per_patient <- colSums(abs(parts))
    top <- which.max(per_patient)
    y_error <- y3000 - y30    # the compensator error, 30 minus 3000 steps
    worst <- which.max(abs(y_error))
    i <- d$s == 1
    data.frame(seed = seed, bandwidth = bw,
               largest_compensator_error_30_vs_3000 = y_error[worst],
               one_over_G_of_that_patient = 1 / weibull_surv(pmin(d$time[worst], t), h$cens_lp[worst], h$cens_scale[worst]),
               n_patients_error_above_0.01 = sum(abs(y_error[i]) > 0.01),
               integrated_absolute_curve_change = mean(abs(change)),
               largest_absolute_curve_change = max(abs(change)),
               top_patient_share_of_absolute_parts = per_patient[top] / sum(per_patient),
               integrated_absolute_change_without_top_patient = mean(abs(change - parts[, top])),
               commit = commit)
  }

  for (k in seq_along(chunks)) {
    path <- file.path(out_dir, sprintf("chunk_%03d.rds", k))
    if (file.exists(path)) next
    res <- future.apply::future_lapply(chunks[[k]], function(s) {
      one_hospital(s, bandwidth[[as.character(s)]], out_formula, commit)
    }, future.seed = TRUE)
    saveRDS(list(patients = do.call(rbind, res)), path)
    cat(sprintf("%s  %s patients chunk %d of %d done\n", format(Sys.time(), "%H:%M"), setting, k, length(chunks)))
  }
  all_rows <- read_chunks(out_dir, "patients")
  all_rows <- cbind(setting = setting, all_rows)
  write.csv(round_numeric(all_rows), sprintf("reports/tables/14_compensator_patients_%s.csv", setting), row.names = FALSE)
  cat("All chunks done.\n")
}
