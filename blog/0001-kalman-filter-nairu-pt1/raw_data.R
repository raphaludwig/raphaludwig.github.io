suppressMessages({
  library(here)
  library(jsonlite)
  library(datalake.utils)
})
Sys.setenv(TZ = "America/Sao_Paulo")
post_dir <- here("blog", "0001-kalman-filter-nairu-pt1")

# IPCA -----
dataset_id <- paste(
  c(c("latam", "brasil"), "ipca"),
  collapse = "-"
)

ipca_ssubj <-
  read_vintage(dataset_id, table = "db_infdeg_des") %>%
  filter(Ssubj == T) %>%
  unique() %>%
  select(date, inf7, weight7) %>%
  reframe(ipca_ssubj = weighted.mean(inf7, weight7), .by = date) %>%
  mutate(ipca_ssubj = 100 * ((1 + ipca_ssubj / 100)^12 - 1))

ipca_full <-
  read_vintage(dataset_id, table = "db/ag") %>%
  filter(
    `Variável` ==
      "IPCA - Número-índice (base: dezembro de 1993 = 100) (Número-índice)"
  ) %>%
  select(date, Valor) %>%
  reframe(date, ipca_full = 100 * (Valor / lag(Valor, 12) - 1)) %>%
  na.trim("left")

# PNAD -----
monthly <- FALSE
u_rate_file <- if (monthly) "pnad_desemprego_monthly.csv" else "pnad_desemprego_retropolada.csv"

u_rate <-
  read_csv(file.path(post_dir, "data", u_rate_file)) %>%
  reframe(
    date,
    u_rate = 100 * seas_dplyr(
      u_rate,
      year(first(date)),
      month(first(date)),
      12,
      "x13"
    )
  )

# FOCUS -----
dataset_id <- paste(
  c(c("latam", "brasil"), "focus"),
  collapse = "-"
)

focus <-
  read_vintage(dataset_id, table = "db_focus_annual") %>%
  filter(Indicador == "IPCA") %>%
  reframe(date = Data, DataReferencia, focus = Media) %>%
  mutate(ym = as.yearmon(date)) %>%
  group_by(ym) %>%
  filter(date == max(date)) %>%
  slice_max(DataReferencia, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(-ym, -DataReferencia) %>%
  mutate(date = date %>% as.yearmon() %>% as_date())

# IPPCV -----
ippcv <-
  read_excel(file.path(post_dir, "data", "ippcv.xlsx")) %>%
  reframe(date = as_date(`Mês`), ippcv)

# joining -----
# pi_12m_lag is pi_{t-1}^12m in the Phillips curve: the *previous* month's
# 12-month IPCA reading, not the contemporaneous one (see CONTEXT.md / the
# original BCB post's observation equation).
ipca_full_lag <- ipca_full %>%
  mutate(date = date %m+% months(1), pi_12m_lag = ipca_full) %>%
  select(date, pi_12m_lag)

db <-
  reduce(
    list(ipca_ssubj, ipca_full, ipca_full_lag, u_rate, focus, ippcv),
    left_join,
    by = "date"
  ) %>%
  na.trim("left") %>%
  mutate(ippcv = ifelse(is.na(ippcv), 0, ippcv))

write_csv(db, file.path(post_dir, "data", "frozen_snapshot.csv"))
