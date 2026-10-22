# Step 5: cross-check our pseudo-outcomes against independent published code.
#
# Robertson, Steingrimsson and Dahabreh (Eur J Epidemiol 2023) released R code whose function
# DGM_Sim computes the same pseudo-outcome as Wen, Dahabreh and Chiu's equation 1. That code
# fits CASS-specific helper models inside fit_models(), so here fit_models() is replaced by
# one that returns our helper predictions. Everything else in DGM_Sim runs unchanged.
# Their file has no licence, so it is downloaded at run time to results/ (not committed).
#
# Run from the repository root:  Rscript scripts/05_reference_check.R

source("R/generate.R")
source("R/nuisance.R")
source("R/pseudo.R")

commit <- "0bace88a7cd695dca72eb35f59d81dbafe1a942a"
url <- sprintf("https://raw.githubusercontent.com/serobertson/GeneralizabilityCATE/%s/00_cate_fxns_source.R", commit)
dir.create("results/reference", recursive = TRUE, showWarnings = FALSE)
local_copy <- "results/reference/00_cate_fxns_source.R"
if (!file.exists(local_copy)) download.file(url, local_copy, quiet = TRUE)

reference <- new.env()
sys.source(local_copy, envir = reference)

cfg <- load_config("config/phase1.yaml")
b0 <- participation_intercept(cfg)

compare_one <- function(seed, learner) {
  d <- simulate_cohort(cfg, seed = seed, b0 = b0)$observed
  nu <- fit_nuisance(d, learner, n_folds = 5, seed = seed)
  ours <- pseudo_outcome(d, nu)

  # Their code expects columns Y, A, S; outside the trial A and Y are multiplied by S = 0,
  # so any finite placeholder works.
  DF <- data.frame(id = d$id, frailty = d$frailty, v = d$v, male = d$male, S = d$s,
                   A = ifelse(is.na(d$a), 0, d$a), Y = ifelse(is.na(d$y), 0, d$y))
  reference$fit_models <- function(DF, regtype) {
    m <- nu[match(DF$id, nu$id), ]
    data.frame(pahat = m$p_treat, pshat = m$p_join, mu1hat = m$g1, mu0hat = m$g0)
  }
  theirs <- reference$DGM_Sim(DF, regtype = "mock", estimator = "phi")$pseudo_est_all

  data.frame(seed = seed, learner = learner, patients = length(ours),
             max_abs_difference = max(abs(ours - theirs)),
             mean_ours = mean(ours), mean_theirs = mean(theirs))
}

result <- do.call(rbind, c(lapply(1:5, compare_one, learner = "glm"),
                           lapply(1:2, compare_one, learner = "sl")))
print(result, row.names = FALSE)
write.csv(result, "reports/tables/05_reference_check.csv", row.names = FALSE)
cat(if (all(result$max_abs_difference < 1e-10)) "MATCH: identical to machine precision\n" else "MISMATCH\n")
