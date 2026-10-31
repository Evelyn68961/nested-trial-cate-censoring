# Step 2a follow-ups asked for in the check of the first report. R/ is not changed.
#
# Usage, from the repository root:
#   Rscript scripts/14_followups.R warnings <setting> <workers>
#     setting C2 or C4. Reruns, at 30 steps, the hospitals with a warning in the compensator run plus
#     seed 145, through the same path as scripts/14_check_compensator.R, keeping each warning's text
#     and comparing every estimate with the saved row.
#     Writes reports/tables/14_warnings_<setting>.csv and 14_control_30_steps_<setting>.csv
#   Rscript scripts/14_followups.R warnings_cc <setting> <workers>
#     setting C1 or C2. The same for the CC_fullp run. Writes reports/tables/14_warnings_cc_<setting>.csv
#   Rscript scripts/14_followups.R slope
#     For seeds 145, 156, 16, 37: the patient with the largest 30-step error in C2 and in C4, and
#     the slope of F_cond over the last step for those patients in both settings.
#     Writes reports/tables/14_compensator_slope.csv

args <- commandArgs(trailingOnly = TRUE)
mode <- args[1]

if (length(system("git status --porcelain -- R config scripts", intern = TRUE)) > 0) {
  stop("Uncommitted changes in R/, config/ or scripts/. Commit first so results can be traced.")
}
commit <- system("git rev-parse --short HEAD", intern = TRUE)
source("scripts/14_common.R")

phase2_files <- c("generate", "truth", "nuisance", "pseudo", "smooth",
                  "phase2_generate", "phase2_truth", "phase2_estimators")
right_formula <- ~ a + frailty + v + male
right_outcome <- ~ frailty + v + I(v^2) + male
wrong_outcome <- ~ v + I(v^2) + male
out_formulas <- list(C2 = right_outcome, C4 = wrong_outcome)

use_n_steps <- function(n_steps) {
  f <- get("augmented_status", envir = globalenv())
  formals(f)$n_steps <- n_steps
  assign("augmented_status", f, envir = globalenv())
}

catch_warnings <- function(expr) {
  texts <- character()
  sources <- character()
  value <- withCallingHandlers(expr, warning = function(w) {
    texts <<- c(texts, conditionMessage(w))
    sources <<- c(sources, paste(deparse(conditionCall(w))[1], collapse = ""))
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = data.frame(message = texts, call = sources))
}

tally <- function(found, setting, run) {
  w <- do.call(rbind, lapply(found, function(x) if (nrow(x$warnings)) cbind(seed = x$seed, x$warnings)))
  w$message <- gsub("[0-9]+(\\.[0-9]+)?(e-?[0-9]+)?", "#", w$message)
  w$call <- substr(w$call, 1, 60)
  out <- aggregate(seed ~ message + call, w, length)
  names(out)[3] <- "n_warnings"
  out$n_hospitals <- aggregate(seed ~ message + call, w, function(s) length(unique(s)))$seed
  cbind(setting = setting, run = run, out[order(-out$n_warnings), ], commit = commit)
}

if (mode == "warnings") {
  setting <- args[2]
  workers <- as.integer(args[3])
  info <- read_chunks(file.path("results", "check_step2", "compensator", "n3000", setting), "info")
  seeds <- sort(unique(c(info$seed[info$n_warnings > 0], 145)))
  future::plan(future::multisession, workers = workers)
  one_hospital <- function(seed, setting, out_formula) {
    for (f in phase2_files) source(sprintf("R/%s.R", f))
    use_n_steps(30)
    cfg <- load_config("config/phase2.yaml")
    b0 <- participation_intercept(cfg)
    d <- simulate_cohort_surv(cfg, "dependent", seed = seed, b0 = b0)$observed
    res <- catch_warnings(run_phase2_estimators(d, cfg, right_formula, seed, make_v_grid(cfg),
                                                out_formula = out_formula))
    list(seed = seed, curves = cbind(seed = seed, res$value$curves), warnings = res$warnings)
  }
  found <- future.apply::future_lapply(seeds, one_hospital, setting = setting,
                                       out_formula = out_formulas[[setting]], future.seed = TRUE)
  counts <- sapply(found, function(x) nrow(x$warnings))
  stopifnot(identical(as.numeric(counts[seeds != 145 | seeds %in% info$seed[info$n_warnings > 0]]),
                      as.numeric(info$n_warnings[match(seeds, info$seed)][seeds != 145 | seeds %in% info$seed[info$n_warnings > 0]])))
  out <- tally(found, setting, "compensator")
  write.csv(out, sprintf("reports/tables/14_warnings_%s.csv", setting), row.names = FALSE)

  saved <- read_chunks(file.path("results", "phase2", setting))
  new <- do.call(rbind, lapply(found, `[[`, "curves"))
  m <- merge(new, saved, by = c("seed", "estimator", "t", "v"), suffixes = c(".new", ".saved"))
  stopifnot(nrow(m) == nrow(new))
  m$difference <- abs(m$estimate.new - m$estimate.saved)
  control <- aggregate(difference ~ estimator, m, max)
  names(control)[2] <- "largest_difference_all_rerun_hospitals"
  control$largest_difference_seed_145 <- aggregate(difference ~ estimator, m[m$seed == 145, ], max)$difference
  control$n_hospitals <- length(seeds)
  control$n_rows <- aggregate(difference ~ estimator, m, length)$difference
  control <- cbind(setting = setting, control, commit = commit)
  write.csv(control, sprintf("reports/tables/14_control_30_steps_%s.csv", setting), row.names = FALSE)
  options(width = 180)
  print(out, row.names = FALSE)
  print(control, row.names = FALSE)
} else if (mode == "warnings_cc") {
  setting <- args[2]
  workers <- as.integer(args[3])
  censoring <- c(C1 = "random", C2 = "dependent")[[setting]]
  info <- read_chunks(file.path("results", "check_step2", "cc_fullp", setting), "info")
  seeds <- info$seed[info$n_warnings > 0]
  future::plan(future::multisession, workers = workers)
  # The CC part of the fits in scripts/14_check_cc_propensity.R, which are where its warnings arise
  one_hospital <- function(seed, censoring) {
    for (f in c("generate", "truth", "nuisance", "pseudo", "smooth", "phase2_generate")) source(sprintf("R/%s.R", f))
    cfg <- load_config("config/phase2.yaml")
    b0 <- participation_intercept(cfg)
    d <- simulate_cohort_surv(cfg, censoring, seed = seed, b0 = b0)$observed
    res <- catch_warnings(for (t in unlist(cfg$times)) {
      st <- status_at(d, t)
      keep <- d$s == 0 | st$known
      dcc <- d[keep, ]
      dcc$y <- st$y[keep]
      fit_nuisance(dcc, "glm", seed = seed)
    })
    list(seed = seed, warnings = res$warnings)
  }
  found <- future.apply::future_lapply(seeds, one_hospital, censoring = censoring, future.seed = TRUE)
  stopifnot(identical(as.numeric(sapply(found, function(x) nrow(x$warnings))), as.numeric(info$n_warnings[info$n_warnings > 0])))
  out <- tally(found, setting, "cc_fullp")
  write.csv(out, sprintf("reports/tables/14_warnings_cc_%s.csv", setting), row.names = FALSE)
  options(width = 180)
  print(out, row.names = FALSE)
} else if (mode == "slope") {
  for (f in phase2_files) source(sprintf("R/%s.R", f))
  RNGkind("L'Ecuyer-CMRG")
  cfg <- load_config("config/phase2.yaml")
  b0 <- participation_intercept(cfg)
  times <- unlist(cfg$times)
  t <- 5
  rows <- list()
  for (seed in c(145, 156, 16, 37)) {
    d <- simulate_cohort_surv(cfg, "dependent", seed = seed, b0 = b0)$observed
    trial <- which(d$s == 1)
    end <- pmin(d$time[trial], t)
    fits <- lapply(c(C2 = "C2", C4 = "C4"), function(s) {
      h <- suppressWarnings(fit_phase2_helpers(d, times, right_formula, cfg$follow_up_end, seed = seed,
                                               out_formula = out_formulas[[s]]))
      use_n_steps(30)
      y30 <- augmented_status(d, t, h)[trial]
      use_n_steps(3000)
      y3000 <- augmented_status(d, t, h)[trial]
      list(h = h, error = y3000 - y30)
    })
    worst <- sapply(fits, function(x) which.max(abs(x$error)))
    for (s in names(fits)) for (i in unique(worst)) {
      h <- fits[[s]]$h
      who <- trial[i]
      lp <- if (d$a[who] == 1) h$lp1[who] else h$lp0[who]
      sc <- if (d$a[who] == 1) h$scale1[who] else h$scale0[who]
      F_cond <- function(u) 1 - exp(-(weibull_cumhaz(t, lp, sc) - weibull_cumhaz(u, lp, sc)))
      one_over_G <- function(u) 1 / weibull_surv(u, h$cens_lp[who], h$cens_scale[who])
      step <- end[i] / 30
      rows[[length(rows) + 1]] <- data.frame(
        seed = seed, setting = s, id = d$id[who], largest_error_patient_in = paste(names(worst)[worst == i], collapse = " "),
        arm = d$a[who], end = end[i], one_over_G = one_over_G(end[i]), last_step_width = step,
        last_step_rise_in_one_over_G = one_over_G(end[i]) - one_over_G(end[i] - step),
        F_cond_start_of_last_step = F_cond(end[i] - step), F_cond_end_of_last_step = F_cond(end[i]),
        F_cond_slope_last_step = (F_cond(end[i]) - F_cond(end[i] - step)) / step,
        error_30_vs_3000 = fits[[s]]$error[i], commit = commit)
    }
  }
  out <- do.call(rbind, rows)
  write.csv(round_numeric(out), "reports/tables/14_compensator_slope.csv", row.names = FALSE)
  options(width = 220)
  print(out[, setdiff(names(out), "commit")], row.names = FALSE, digits = 5)
}
