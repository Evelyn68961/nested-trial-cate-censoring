# Check that the six estimators that existed on 22 October reproduce the archived 200-hospital
# results exactly after the 23 October additions (BJ, C4, weight checks).
# Run from the repository root:  Rscript scripts/12_check_reproduction.R

read_setting <- function(dir) {
  files <- list.files(dir, pattern = "^chunk_.*rds$", full.names = TRUE)
  do.call(rbind, lapply(files, function(f) readRDS(f)$curves))
}
old_estimators <- c("CC", "NE", "IPCW", "AIPCW", "IPCW_t", "AIPCW_t")
for (s in c("C0", "C1", "C2", "C3")) {
  old <- read_setting(file.path("results", "archive", "phase2_200_before_bj", s))
  new <- read_setting(file.path("results", "phase2", s))
  new <- new[new$estimator %in% old_estimators, ]
  key <- function(x) paste(x$seed, x$estimator, x$t, round(x$v, 8))
  new <- new[match(key(old), key(new)), ]
  diff <- max(abs(c(old$estimate - new$estimate, old$se - new$se, old$h - new$h)))
  cat(sprintf("%s: %d rows compared, largest difference %.3g\n", s, nrow(old), diff))
}
