# The post's qmd sources this file with cwd = blog/ (so "R/" lives under
# "0001-kalman-filter-nairu-pt1/"); tests/testthat.R sources it with cwd =
# the post's own directory (so "R/" is directly underneath). Try both.
.fit_nairu_dir <- if (file.exists("0001-kalman-filter-nairu-pt1/R/shared.R")) {
  "0001-kalman-filter-nairu-pt1/R"
} else {
  "R"
}

source(file.path(.fit_nairu_dir, "shared.R"))
source(file.path(.fit_nairu_dir, "fit_nairu_marss.R"))
source(file.path(.fit_nairu_dir, "fit_nairu_kfas.R"))
source(file.path(.fit_nairu_dir, "fit_nairu_kalmanfilter.R"))

#' fit_nairu: the one seam every backend is built against.
#'
#' @param data data.frame slice of the frozen snapshot (already windowed to
#'   the desired sample by the caller).
#' @param lambda signal-to-noise ratio (calibrated smoothness).
#' @param package one of "marss", "kfas", "kalmanfilter".
#' @param alpha calibrated level gap (see calibrate_alpha()).
#' @param fixed NULL for stage 1 (beta, gamma estimated, no IPPCV term); or
#'   list(beta=, gamma=) for stage 2 (theta estimated, IPPCV term included).
#' @return list(beta, gamma, theta, nairu, loglik, runtime_secs)
fit_nairu <- function(data, lambda, package, alpha, fixed = NULL) {
  reg <- build_regressors(data, alpha)
  backend <- switch(package,
    marss = fit_nairu_marss,
    kfas = fit_nairu_kfas,
    kalmanfilter = fit_nairu_kalmanfilter,
    stop("unknown package: ", package)
  )
  backend(reg, lambda, fixed)
}
