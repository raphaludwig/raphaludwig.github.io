suppressMessages({
  library(dplyr)
})

# Diffuse initial-state variance: large enough that the first few
# observations, not this arbitrary prior, determine where the filter starts.
DIFFUSE_VAR <- 1e6

# Penalty returned for a parameter draw the optimizer should reject
# (non-convergent filter, non-finite likelihood).
LOGLIK_PENALTY <- 1e10

#' alpha: the calibrated level gap between services-core and headline IPCA.
#' Always computed on the stage-1 (pre-pandemic) window, per the original
#' post's own calibration convention, and reused unchanged in stage 2.
calibrate_alpha <- function(data) {
  mean(data$ipca_ssubj - data$ipca_full)
}

#' Build the model's regressors from a frozen-snapshot slice.
#'   y2     = pi_ss - E_t(pi^LP) - alpha
#'   xtilde = pi_{t-1}^12m - E_t(pi^LP)   (dissolves the (1-beta) constraint)
#'   u      = u_rate
#'   ippcv  = ippcv
build_regressors <- function(data, alpha) {
  list(
    date = data$date,
    y2 = data$ipca_ssubj - data$focus - alpha,
    xtilde = data$pi_12m_lag - data$focus,
    u = data$u_rate,
    ippcv = data$ippcv
  )
}

#' The observation equation's state s_t = sqrt(lambda)*gamma*nairu_t has
#' loading 1/sqrt(lambda) and Q = R exactly (see the post's derivation): this
#' is what lets lambda enter every backend as a plain known constant instead
#' of a free parameter tangled up with gamma.
recover_nairu <- function(s_t, gamma, lambda) {
  s_t / (sqrt(lambda) * gamma)
}

#' Assemble a fit_nairu() return value from what every backend computes the
#' same way, once smoothed states and coefficients are in hand.
assemble_result <- function(beta, gamma, theta, reg, s_t, lambda, loglik, runtime_secs) {
  list(
    beta = beta, gamma = gamma, theta = theta,
    nairu = data.frame(date = reg$date, nairu = recover_nairu(s_t, gamma, lambda)),
    loglik = loglik, runtime_secs = runtime_secs
  )
}
