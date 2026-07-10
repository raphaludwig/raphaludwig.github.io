suppressMessages(library(KFAS))

# KFAS builds models from a formula, and its exact diffuse initialization
# lets regression coefficients (beta/gamma, or theta in stage 2) be
# concentrated out of the likelihood entirely -- solved via GLS inside the
# same filter pass that estimates the NAIRU, rather than searched over by
# an outer optimizer. The only thing fitSSM()'s optimizer has to search is
# the single shared variance parameter, which is why this backend is the
# fastest of the three in the runtime comparison below.
fit_nairu_kfas <- function(reg, lambda, fixed = NULL) {
  if (is.null(fixed)) {
    xtilde <- reg$xtilde; u <- reg$u
    mod <- SSModel(reg$y2 ~ 0 + SSMregression(~ 0 + xtilde + u, Q = 0) +
      SSMtrend(1, Q = list(matrix(NA))), H = matrix(NA))
  } else {
    y3 <- reg$y2 - fixed$beta * reg$xtilde + fixed$gamma * reg$u
    ippcv <- reg$ippcv
    mod <- SSModel(y3 ~ 0 + SSMregression(~ 0 + ippcv, Q = 0) +
      SSMtrend(1, Q = list(matrix(NA))), H = matrix(NA))
  }
  # KFAS's SSMtrend() assumes a loading of 1 by default; override it to this
  # model's known 1/sqrt(lambda) for every time point (Z is time-varying
  # here because the regression component makes the whole Z array 3-D).
  level_col <- dim(mod$Z)[2]
  mod$Z[1, level_col, ] <- 1 / sqrt(lambda)

  m <- dim(mod$Q)[1]
  updatefn <- function(pars, model) {
    sigma2 <- exp(pars[1])
    model$H[1, 1, 1] <- sigma2
    model$Q[m, m, 1] <- sigma2 # tie Q to H: this model's "Q equals R"
    model
  }

  t0 <- Sys.time()
  fit <- fitSSM(mod, inits = log(1), updatefn = updatefn, method = "BFGS")
  runtime <- as.numeric(Sys.time() - t0, units = "secs")

  smooth <- KFS(fit$model, filtering = "state", smoothing = "state")
  cf <- coef(smooth)
  loglik <- -fit$optim.out$value

  if (is.null(fixed)) {
    beta <- as.numeric(cf[nrow(cf), "xtilde"])
    gamma <- -as.numeric(cf[nrow(cf), "u"])
    theta <- NA_real_
  } else {
    beta <- fixed$beta; gamma <- fixed$gamma
    theta <- as.numeric(cf[nrow(cf), "ippcv"])
  }
  s_t <- as.numeric(cf[, "level"])

  assemble_result(beta, gamma, theta, reg, s_t, lambda, loglik, runtime)
}
