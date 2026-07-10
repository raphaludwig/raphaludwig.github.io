suppressMessages(library(MARSS))

# MARSS wants a fully-specified list of matrices, where any cell is either a
# fixed number or a character label naming a free parameter. It has no way
# to tie a free parameter across two *different* top-level matrices, though
# — which is exactly what this model's "Q equals R" reparametrization needs.
# So the shared variance is profiled in an outer 1-D search, and MARSS's own
# estimator handles beta/gamma (or just theta, in stage 2) conditional on
# each candidate variance. That's also why this backend is the slowest of
# the three in the runtime comparison below.
fit_nairu_marss <- function(reg, lambda, fixed = NULL) {
  Zt <- matrix(1 / sqrt(lambda))
  y <- matrix(reg$y2, nrow = 1)

  if (is.null(fixed)) {
    d <- t(cbind(reg$xtilde, -reg$u))
    D_labels <- list("beta", "gamma")
  } else {
    d <- t(cbind(reg$xtilde, -reg$u, reg$ippcv))
    D_labels <- list(fixed$beta, fixed$gamma, "theta")
  }
  D <- matrix(D_labels, nrow = 1)

  fit_given_sigma2 <- function(sigma2) {
    mod <- list(
      B = matrix(1), U = matrix(0), Q = matrix(sigma2),
      Z = Zt, A = matrix(0), R = matrix(sigma2),
      D = D, d = d,
      x0 = matrix(0), tinitx = 0, V0 = matrix(DIFFUSE_VAR)
    )
    MARSS(y, model = mod, silent = TRUE, control = list(maxit = 1000))
  }
  negloglik <- function(log_sigma2) {
    fit <- tryCatch(fit_given_sigma2(exp(log_sigma2)), error = function(e) NULL)
    if (is.null(fit) || !is.finite(fit$logLik)) return(LOGLIK_PENALTY)
    -fit$logLik
  }

  t0 <- Sys.time()
  opt <- optimize(negloglik, interval = log(c(1e-3, 100)), tol = 1e-4)
  fit <- fit_given_sigma2(exp(opt$minimum))
  runtime <- as.numeric(Sys.time() - t0, units = "secs")

  cf <- coef(fit)$D
  if (is.null(fixed)) {
    beta <- cf[1]; gamma <- cf[2]; theta <- NA_real_
  } else {
    beta <- fixed$beta; gamma <- fixed$gamma; theta <- cf[1]
  }
  s_t <- as.numeric(MARSSkfss(fit)$xtT)

  assemble_result(beta, gamma, theta, reg, s_t, lambda, fit$logLik, runtime)
}
