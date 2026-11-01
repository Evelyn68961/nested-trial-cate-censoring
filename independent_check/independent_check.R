# independent_check.R: independent second method for the nested-trial CATE simulation.
# Usage: Rscript independent_check.R <output_folder> [n_modeB=500000] [reps_modeA=200]
# Needs: survival, future, future.apply. Shares no code with the repo.
#
# ASSUMPTIONS the brief left open (both are reported, or stated, so they can be matched):
#  - Target population: the whole eligible cohort, S ignored: theta(v) = E[Y^1 - Y^0 | V=v].
#  - Scale of theta_5(v): both are reported, treated minus untreated:
#    estimand "surv": P(T^1>5) - P(T^0>5); estimand "rmst": E[min(T^1,5)] - E[min(T^0,5)].
#  - No truncation of 1/G or 1/p(S|X): G has only a 1e-12 floor, to avoid Inf.

suppressPackageStartupMessages({library(survival); library(future); library(future.apply)})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript independent_check.R <output_folder> [n_modeB] [reps_modeA]")
OUT <- args[1]
N_B <- if (length(args) >= 2) as.numeric(args[2]) else 5e5
R_A <- if (length(args) >= 3) as.integer(args[3]) else 200L
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# Design: values from config/phase2.yaml, censoring scenario "dependent".
N <- 2500; TAU <- 5; VS <- c(1, 2, 3); H <- 1.0; SEED <- 20261031L
MAX_GRID <- 800     # the sum runs over every jump unless more than this (mode B only)
expit <- function(x) 1 / (1 + exp(-x))
lp0 <- function(f, v, m) -3.0 + 0.6 * f + 0.3 * v + 0.3 * m
eff <- function(f, v) 0.8 - 1.4 * v + 0.35 * v^2 + 0.8 * f
K0 <- 1.3; K1 <- 1.0                    # Weibull shapes for a=0 and a=1

# Intercept for a 20% trial share, by deterministic quadrature on (frailty, v, male).
s_int <- local({
  fq <- qnorm((1:400 - 0.5) / 400); vq <- (1:400 - 0.5) / 100
  g <- expand.grid(f = fq, v = vq, m = 0:1)
  uniroot(function(a) mean(expit(a - 0.8 * g$f + 0.4 * g$v + 0.2 * g$m)) - 0.20,
          c(-10, 5), tol = 1e-8)$root
})

# Generator. A, T, dropout exist only for trial patients (outcomes unseen outside the trial).
gen <- function(n) {
  f <- rnorm(n); v <- runif(n, 0, 4); m <- rbinom(n, 1, 0.5)
  S <- rbinom(n, 1, expit(s_int - 0.8 * f + 0.4 * v + 0.2 * m))
  d <- data.frame(frailty = f, v = v, male = m, S = S, A = NA_real_, Y = NA_real_,
                  ev = NA_real_, cens = NA_real_)
  i <- which(S == 1); nt <- length(i)
  A <- rbinom(nt, 1, 0.5)
  rate <- exp(lp0(f[i], v[i], m[i]) + A * eff(f[i], v[i]))
  shp <- ifelse(A == 1, K1, K0)
  Tt <- (rexp(nt) / rate)^(1 / shp)                  # inverse of the cumulative hazard
  Cc <- rexp(nt, 0.10 * exp(1.5 * f[i] + 1.0 * A))   # dropout
  Y <- pmin(Tt, Cc, TAU)
  d$A[i] <- A; d$Y[i] <- Y
  d$ev[i] <- as.numeric(Tt <= pmin(Cc, TAU))
  d$cens[i] <- as.numeric(Cc < pmin(Tt, TAU))        # the end of follow-up is not a dropout event
  d
}

# ---- (a) Truth ----
# Closed form: integral of exp(-c t^k) from 0 to tau, through the regularised incomplete gamma.
rmst_w <- function(c, k, tau) c^(-1 / k) / k * gamma(1 / k) * pgamma(c * tau^k, 1 / k)
theta_true <- function(v, est, tau = TAU) {
  g <- function(f, m) {
    c0 <- exp(lp0(f, v, m)); c1 <- exp(lp0(f, v, m) + eff(f, v))
    y <- if (est == "surv") exp(-c1 * tau^K1) - exp(-c0 * tau^K0)
         else rmst_w(c1, K1, tau) - rmst_w(c0, K0, tau)
    y * dnorm(f)
  }
  mean(sapply(0:1, function(m)
    integrate(g, -9, 9, m = m, subdivisions = 1000L, rel.tol = 1e-9)$value))
}
# The curve as seen through a kernel of bandwidth H: splits smoothing bias from the rest.
epan <- function(u) 0.75 * (1 - u^2) * (abs(u) <= 1)
theta_smooth <- function(v0, est) {
  vv <- seq(max(0, v0 - H), min(4, v0 + H), length.out = 201)
  w <- epan((vv - v0) / H)
  sum(w * sapply(vv, theta_true, est = est)) / sum(w)
}
truth_mc <- function(v, nmc = 2e6) {        # large Monte Carlo check, potential outcomes at v
  f <- rnorm(nmc); m <- rbinom(nmc, 1, 0.5)
  T0 <- (rexp(nmc) / exp(lp0(f, v, m)))^(1 / K0)
  T1 <- (rexp(nmc) / exp(lp0(f, v, m) + eff(f, v)))^(1 / K1)
  ds <- (T1 > TAU) - (T0 > TAU); dr <- pmin(T1, TAU) - pmin(T0, TAU)
  data.frame(v = v, estimand = c("surv", "rmst"), truth_mc = c(mean(ds), mean(dr)),
             truth_mc_se = c(sd(ds), sd(dr)) / sqrt(nmc))
}

# ---- Nuisance helpers ----
Xo <- function(d) cbind(frailty = d$frailty, v = d$v, v2 = d$v^2, male = d$male)  # outcome
Xc <- function(d) cbind(frailty = d$frailty, v = d$v, male = d$male, A = d$A)     # dropout
breslow <- function(time, status, eta) {    # hand Breslow; tied times occur only at tau (no events)
  o <- order(time); keep <- status[o] == 1
  risk <- rev(cumsum(rev(exp(eta[o]))))
  list(t = time[o][keep], H = cumsum(1 / risk[keep]))
}
fit_cox <- function(time, status, X) {
  b <- coef(coxph(Surv(time, status) ~ X, ties = "breslow"))
  b[is.na(b)] <- 0
  list(b = b, br = breslow(time, status, drop(X %*% b)))
}
Hat <- function(br, tt) c(0, br$H)[findInterval(tt, br$t) + 1]    # step-function cumulative hazard
chunks <- function(n, size = 5000) split(seq_len(n), ceiling(seq_len(n) / size))

# Outcome-model predictions m_a(X) at tau on both scales, for any set of people.
pred_m <- function(fo, X, tg0) {
  e <- exp(drop(X %*% fo$b)); Ho <- Hat(fo$br, tg0); w <- diff(tg0); nk <- length(tg0)
  out <- matrix(NA_real_, nrow(X), 2)
  for (ix in chunks(nrow(X))) {
    S <- exp(-outer(e[ix], Ho))
    out[ix, 1] <- S[, nk]
    out[ix, 2] <- drop(((S[, -1, drop = FALSE] + S[, -nk, drop = FALSE]) / 2) %*% w)
  }
  out
}

# Censoring-unbiased transformation for one arm, as a sum on the time grid:
#   Gamma = Delta f(Y) / G(Y-) + sum_u Q(u) / G(u) dM_C(u),
# with Q(u) = E[f(T) | T>u, X, a]; dM_C = dN_C - at-risk * dLambda_C.
gamma_arm <- function(te, fo, fc, tg0) {
  Xoa <- Xo(te); Xca <- Xc(te)
  eo <- exp(drop(Xoa %*% fo$b)); ec <- exp(drop(Xca %*% fc$b))
  Ho <- Hat(fo$br, tg0); Hc <- Hat(fc$br, tg0)
  dL <- c(0, diff(Hc)); w <- diff(tg0); nk <- length(tg0)
  iL <- findInterval(te$Y, tg0)                        # last grid point <= Y
  iM <- findInterval(te$Y, tg0, left.open = TRUE)      # last grid point <  Y, for G(Y-)
  nt <- nrow(te)
  out <- matrix(NA_real_, nt, 5, dimnames = list(NULL, c("g_s", "g_r", "ip_s", "ip_r", "G5")))
  for (ix in chunks(nt)) {
    nc <- length(ix)
    G <- pmax(exp(-outer(ec[ix], Hc)), 1e-12)
    S <- pmax(exp(-outer(eo[ix], Ho)), 1e-300)
    inc <- (S[, -1, drop = FALSE] + S[, -nk, drop = FALSE]) / 2 * rep(w, each = nc)
    R <- matrix(0, nc, nk)                             # R(u) = integral of S from u to tau
    for (j in (nk - 1):1) R[, j] <- R[, j + 1] + inc[, j]
    Qs <- S[, nk] / S                                  # surv: P(T>tau | T>u)
    Qr <- rep(tg0, each = nc) + R / S                  # rmst: E[min(T,tau) | T>u]
    obs <- te$cens[ix] == 0
    ip_s <- obs * (te$Y[ix] >= TAU) / G[cbind(1:nc, iM[ix])]
    ip_r <- obs * pmin(te$Y[ix], TAU) / G[cbind(1:nc, iM[ix])]
    dLm <- outer(ec[ix], dL) * outer(iL[ix], seq_len(nk), ">=")
    aug <- function(Q) te$cens[ix] * Q[cbind(1:nc, iL[ix])] / G[cbind(1:nc, iL[ix])] -
      rowSums(Q / G * dLm)
    out[ix, ] <- cbind(ip_s + aug(Qs), ip_r + aug(Qr), ip_s, ip_r, G[, nk])
  }
  out
}

# One training/held-out split: nuisances from tr, predictions for te.
fold_fit <- function(tr, te) {
  trT <- tr[tr$S == 1, ]
  ps <- glm(S ~ frailty + v + male, binomial, data = tr)
  fc <- fit_cox(trT$Y, trT$cens, Xc(trT))
  fo <- lapply(0:1, function(a) {
    x <- trT[trT$A == a, ]; fit_cox(x$Y, x$ev, Xo(x))
  })
  tg <- sort(unique(c(fc$br$t, fo[[1]]$br$t, fo[[2]]$br$t, TAU)))   # the observed jumps
  if (length(tg) > MAX_GRID)                 # mode B only: thin, cumulative hazards stay exact
    tg <- sort(unique(c(unname(quantile(tg, (1:MAX_GRID) / MAX_GRID, type = 1)), TAU)))
  tg0 <- c(0, tg[tg <= TAU])
  X <- Xo(te)
  m0 <- pred_m(fo[[1]], X, tg0); m1 <- pred_m(fo[[2]], X, tg0)
  res <- matrix(NA_real_, nrow(te), 5, dimnames = list(NULL, c("g_s", "g_r", "ip_s", "ip_r", "G5")))
  for (a in 0:1) {
    i <- which(te$S == 1 & te$A == a)
    if (length(i)) res[i, ] <- gamma_arm(te[i, ], fo[[a + 1]], fc, tg0)
  }
  cbind(pi = predict(ps, te, type = "response"), m0s = m0[, 1], m0r = m0[, 2],
        m1s = m1[, 1], m1r = m1[, 2], res)
}

# Hand-written local linear (Epanechnikov) at v0, with a sandwich-style approximate SE.
loclin <- function(y, v, v0, h = H) {
  u <- v - v0; w <- epan(u / h)
  s0 <- sum(w); s1 <- sum(w * u); s2 <- sum(w * u^2)
  l <- w * (s2 - s1 * u) / (s0 * s2 - s1^2)          # linear smoother weights
  est <- sum(l * y)
  c(est = est, se = sqrt(sum((l * (y - est))^2)))
}

# (d) Per-arm Weibull g-computation, averaged with kernel weights around each target v.
gcomp <- function(d) {
  tr <- d[d$S == 1, ]; d$v2 <- d$v^2; tr$v2 <- tr$v^2
  pr <- lapply(0:1, function(a) {
    fit <- survreg(Surv(Y, ev) ~ frailty + v + v2 + male, data = tr[tr$A == a, ], dist = "weibull")
    k <- 1 / fit$scale; c <- exp(-k * predict(fit, newdata = d, type = "lp"))
    cbind(exp(-c * TAU^k), rmst_w(c, k, TAU))
  })
  do.call(rbind, lapply(VS, function(v0) {
    w <- epan((d$v - v0) / H)
    data.frame(estimand = c("surv", "rmst"), estimator = "gcomp_weibull", v = v0,
               est = c(sum(w * (pr[[2]][, 1] - pr[[1]][, 1])),
                       sum(w * (pr[[2]][, 2] - pr[[1]][, 2]))) / sum(w), se_approx = NA_real_)
  }))
}

# All estimators on one dataset.
estimate <- function(d) {
  n <- nrow(d); fold <- sample(rep(1:5, length.out = n))
  ncv <- NULL
  for (k in 1:5) {
    p <- fold_fit(d[fold != k, ], d[fold == k, ])
    if (is.null(ncv)) ncv <- matrix(NA_real_, n, ncol(p), dimnames = list(NULL, colnames(p)))
    ncv[fold == k, ] <- p
  }
  A <- d$A; S <- d$S == 1; ncv <- as.data.frame(ncv)
  # Wen pseudo-outcome for the eligible population, with p(A)=0.5.
  wen <- function(m0, m1, g) {
    phi <- m1 - m0
    phi[S] <- phi[S] + (2 * A[S] - 1) / 0.5 / ncv$pi[S] * (g[S] - ifelse(A[S] == 1, m1[S], m0[S]))
    phi
  }
  ipw <- function(ip) {
    phi <- numeric(n)
    phi[S] <- (2 * A[S] - 1) / 0.5 / ncv$pi[S] * ip[S]
    phi
  }
  phis <- list(list("surv", "aipcw", wen(ncv$m0s, ncv$m1s, ncv$g_s)),
               list("rmst", "aipcw", wen(ncv$m0r, ncv$m1r, ncv$g_r)),
               list("surv", "ipcw", ipw(ncv$ip_s)), list("rmst", "ipcw", ipw(ncv$ip_r)))
  est <- do.call(rbind, lapply(phis, function(p) do.call(rbind, lapply(VS, function(v0) {
    r <- loclin(p[[3]], d$v, v0)
    data.frame(estimand = p[[1]], estimator = p[[2]], v = v0, est = r[["est"]], se_approx = r[["se"]])
  }))))
  G_true <- exp(-0.10 * exp(1.5 * d$frailty[S] + A[S]) * TAU)
  list(est = rbind(est, gcomp(d)),
       g = data.frame(share_G5_lt05_est = mean(ncv$G5[S] < 0.05),
                      share_G5_lt05_true = mean(G_true < 0.05), n_trial = sum(S)))
}

# ---- Run ----
t_all <- Sys.time()
truth <- expand.grid(v = VS, estimand = c("surv", "rmst"), stringsAsFactors = FALSE)
truth$truth <- mapply(theta_true, truth$v, truth$estimand)
truth$truth_smoothed <- mapply(theta_smooth, truth$v, truth$estimand)
set.seed(SEED)
truth <- merge(truth, do.call(rbind, lapply(VS, truth_mc)), by = c("v", "estimand"))
truth$z_int_vs_mc <- (truth$truth - truth$truth_mc) / truth$truth_mc_se
write.csv(truth, file.path(OUT, "truth.csv"), row.names = FALSE)
print(truth)
cat(sprintf("Trial intercept %.5f; truth took %.1f s\n", s_int, difftime(Sys.time(), t_all, units = "secs")))

# Mode A: replicates of n=2500. A failed fit drops that replicate, counted in n_ok.
t_a <- Sys.time()
plan(multisession, workers = 4)
runs <- future_lapply(seq_len(R_A), function(i) {
  r <- tryCatch(suppressWarnings(estimate(gen(N))), error = function(e) NULL)
  if (is.null(r)) return(NULL)
  r$est$rep <- i; r$g$rep <- i; r
}, future.seed = SEED, future.packages = "survival")
plan(sequential)
runs <- runs[!vapply(runs, is.null, logical(1))]
raw <- do.call(rbind, lapply(runs, `[[`, "est"))
gsh <- do.call(rbind, lapply(runs, `[[`, "g"))
raw <- merge(raw, truth[, c("v", "estimand", "truth", "truth_smoothed")], by = c("v", "estimand"))
raw$err <- raw$est - raw$truth
sumA <- do.call(rbind, lapply(split(raw, list(raw$estimand, raw$estimator, raw$v), drop = TRUE),
  function(x) {
    n <- nrow(x); s <- sd(x$est)
    data.frame(estimand = x$estimand[1], estimator = x$estimator[1], v = x$v[1],
               truth = x$truth[1], truth_smoothed = x$truth_smoothed[1], n_ok = n,
               bias = mean(x$err), bias_vs_smoothed = mean(x$est - x$truth_smoothed),
               emp_sd = s, mcse = s / sqrt(n), n_abs_err_gt_0.5 = sum(abs(x$err) > 0.5))
  }))
sumA <- sumA[order(sumA$estimand, sumA$estimator, sumA$v), ]; rownames(sumA) <- NULL
gA <- data.frame(n_ok = nrow(gsh), share_G5_lt05_est = mean(gsh$share_G5_lt05_est),
                 share_G5_lt05_true = mean(gsh$share_G5_lt05_true),
                 mean_n_trial = mean(gsh$n_trial))
write.csv(raw, file.path(OUT, "modeA_replicates.csv"), row.names = FALSE)
write.csv(sumA, file.path(OUT, "modeA_summary.csv"), row.names = FALSE)
write.csv(gA, file.path(OUT, "modeA_G_share.csv"), row.names = FALSE)
print(sumA, digits = 3); print(gA, digits = 3)
cat(sprintf("Mode A: %d of %d replicates in %.1f min\n", nrow(gsh), R_A,
            difftime(Sys.time(), t_a, units = "mins")))

# Mode B: one very large cohort, sequential. Lower n_modeB (argument 2) if memory runs short.
t_b <- Sys.time()
set.seed(SEED + 1L)
rB <- suppressWarnings(estimate(gen(N_B)))
b <- merge(rB$est, truth[, c("v", "estimand", "truth", "truth_smoothed")], by = c("v", "estimand"))
b$bias <- b$est - b$truth
b$bias_vs_smoothed <- b$est - b$truth_smoothed
b <- b[order(b$estimand, b$estimator, b$v), ]; rownames(b) <- NULL
write.csv(b, file.path(OUT, "modeB_large_cohort.csv"), row.names = FALSE)
write.csv(rB$g, file.path(OUT, "modeB_G_share.csv"), row.names = FALSE)
print(b, digits = 4); print(rB$g, digits = 3)
cat(sprintf("Mode B: n=%d in %.1f min\n", N_B, difftime(Sys.time(), t_b, units = "mins")))
cat(sprintf("Total %.1f min. Outputs in %s\n", difftime(Sys.time(), t_all, units = "mins"), OUT))

