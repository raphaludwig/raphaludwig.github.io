suppressMessages(library(kalmanfilter))

# kalmanfilter is the most bare-bones of the three: one function,
# kalman_filter(ssm, yt), that runs the filter and hands back the
# log-likelihood -- no built-in estimator at all. Every parameter, structural
# or variance, goes into a vector optimized by hand (with optim() here);
# every state-space matrix is rebuilt from that vector on every likelihood
# evaluation.
fit_nairu_kalmanfilter <- function(reg, lambda, fixed = NULL) {
  n <- length(reg$y2)
  yt <- matrix(reg$y2, nrow = 1)

  build_ssm <- function(par) {
    if (is.null(fixed)) {
      beta <- par[["beta"]]; gamma <- par[["gamma"]]
      ippcv_term <- 0
    } else {
      beta <- fixed$beta; gamma <- fixed$gamma
      ippcv_term <- par[["theta"]] * reg$ippcv
    }
    sigma2 <- exp(par[["logsigma2"]])
    Am_t <- beta * reg$xtilde - gamma * reg$u + ippcv_term
    list(
      Fm = array(1, dim = c(1, 1, n)),
      Dm = array(0, dim = c(1, 1, n)),
      Qm = array(sigma2, dim = c(1, 1, n)),
      Hm = array(1 / sqrt(lambda), dim = c(1, 1, n)),
      Am = array(Am_t, dim = c(1, 1, n)),
      Rm = array(sigma2, dim = c(1, 1, n)), # Q equals R: this model's signal-to-noise tie
      B0 = matrix(0), P0 = matrix(DIFFUSE_VAR)
    )
  }
  negloglik <- function(par) {
    f <- tryCatch(kalman_filter(build_ssm(par), yt), error = function(e) NULL)
    if (is.null(f) || !is.finite(f$lnl)) return(LOGLIK_PENALTY)
    -f$lnl
  }

  start <- if (is.null(fixed)) {
    c(beta = 0.3, gamma = 0.6, logsigma2 = log(2))
  } else {
    c(theta = 1, logsigma2 = log(2))
  }

  t0 <- Sys.time()
  opt <- optim(start, negloglik, method = "BFGS")
  runtime <- as.numeric(Sys.time() - t0, units = "secs")

  if (is.null(fixed)) {
    beta <- opt$par[["beta"]]; gamma <- opt$par[["gamma"]]; theta <- NA_real_
  } else {
    beta <- fixed$beta; gamma <- fixed$gamma; theta <- opt$par[["theta"]]
  }
  filt <- kalman_filter(build_ssm(opt$par), yt, smooth = TRUE)
  s_t <- as.numeric(filt$B_tt)

  assemble_result(beta, gamma, theta, reg, s_t, lambda, -opt$value, runtime)
}
