# Rotina de ajuste sazonal usada no post 0002-ajuste-sazonal-credito.
#
# Três blocos: (1) leitura do snapshot do SGS, (2) escada de testes de
# sazonalidade + scorecard de escolha de método, (3) agregação bottom-up sobre
# a hierarquia de concessões, com contagem de folhas.
#
# Nenhuma função aqui devolve a série crua disfarçada de série ajustada: quando
# o ajuste não acontece, `status` diz por quê.

suppressMessages({
  library(dplyr)
  library(purrr)
  library(stringr)
  library(RJDemetra)
  library(seastests)
})

# ---------------------------------------------------------------------------
# 1. Coleta
# ---------------------------------------------------------------------------

#' Lê o snapshot congelado das séries do SGS
#'
#' O render lê CSV, não a API. Não é só conveniência de disponibilidade (o SGS
#' devolve 502 com frequência): o post inteiro é condicional à amostra como os
#' p-valores dos testes, a escolha X-11 vs SEATS série a série e os gaps de
#' reconciliação mudariam a cada revisão publicada.
carregar_series <- function(codigos, cache_path) {
  codigos <- as.character(unique(codigos))
  db <- readr::read_csv(cache_path, col_types = "cDd")

  # Falha com echo
  faltando <- setdiff(codigos, unique(db$codigo))
  if (length(faltando) > 0) {
    stop(str_glue("snapshot não tem: {str_flatten_comma(faltando)}"))
  }
  filter(db, codigo %in% codigos)
}

#' Regrava o snapshot a partir do SGS — rodar À MÃO, nunca no render
baixar_snapshot <- function(
  codigos,
  cache_path,
  inicio = as.Date("2011-01-01")
) {
  codigos <- as.character(unique(codigos))

  novo <-
    GetBCBData::gbcbd_get_series(
      id = as.numeric(codigos),
      first.date = inicio,
      last.date = Sys.Date(),
      format.data = "long",
      use.memoise = FALSE
    ) %>%
    transmute(codigo = as.character(id.num), date = ref.date, value = value) %>%
    arrange(codigo, date)

  faltando <- setdiff(codigos, unique(novo$codigo))
  if (length(faltando) > 0) {
    stop(str_glue(
      "faltaram {length(faltando)} códigos; snapshot NÃO reescrito: \\
       {str_flatten_comma(faltando)}"
    ))
  }
  readr::write_csv(novo, cache_path)
  message(str_glue(
    "snapshot regravado: {n_distinct(novo$codigo)} séries até {max(novo$date)}"
  ))
  invisible(novo)
}

#' Converte o recorte de uma série para `ts` mensal
as_ts_mensal <- function(db, codigo) {
  d <-
    db %>%
    filter(codigo == .env$codigo, !is.na(value)) %>%
    arrange(date)
  ts(
    d$value,
    start = c(
      as.integer(format(min(d$date), "%Y")),
      as.integer(format(min(d$date), "%m"))
    ),
    frequency = 12
  )
}

#' Fatores de calendário do IBC-BR (6 regressores mensais desde 1990)
carregar_fatores <- function(path) {
  bruto <- readr::read_tsv(
    path,
    col_names = c("year", "month", str_c("fator", 1:6)),
    col_types = "iidddddd"
  )
  fatores <-
    str_c("fator", 1:6) %>%
    map(~ ts(as.numeric(bruto[[.x]]), start = c(1990, 1), frequency = 12)) %>%
    reduce(cbind)
  colnames(fatores) <- str_c("fator", 1:6)
  fatores
}

# ---------------------------------------------------------------------------
# 2. Escada de testes
# ---------------------------------------------------------------------------

#' Degraus 2 a 4 da escada: QS, Friedman, Kruskal-Wallis, WO, sazonalidade
#' determinística (seasdum) e raiz unitária sazonal (OCSB).
#'
#' O degrau 1 (subseries plot) é visual e vive no post, não aqui.
testes_sazonalidade <- function(x) {
  p <- function(f) tryCatch(as.numeric(f(x)$Pval), error = function(e) NA_real_)
  tibble(
    qs_p = p(seastests::qs),
    fried_p = p(seastests::fried),
    kw_p = p(seastests::kw),
    wo = tryCatch(seastests::isSeasonal(x, test = "wo"), error = function(e) {
      NA
    }),
    seasdum_p = p(seastests::seasdum),
    ocsb_stat = tryCatch(
      as.numeric(seastests::ocsb(x)$stat),
      error = function(e) NA_real_
    )
  )
}

# ---------------------------------------------------------------------------
# 3. Ajuste e diagnóstico
# ---------------------------------------------------------------------------

ajustar_x13 <- function(x, fatores) {
  RJDemetra::x13(
    x,
    RJDemetra::x13_spec(
      usrdef.varEnabled = TRUE,
      usrdef.var = fatores,
      transform.function = "Auto"
    )
  )
}

ajustar_seats <- function(x, fatores) {
  RJDemetra::tramoseats(
    x,
    RJDemetra::tramoseats_spec(
      usrdef.varEnabled = TRUE,
      usrdef.var = fatores,
      transform.function = "Auto"
    )
  )
}

#' Diagnósticos pós-ajuste, do próprio motor que fez o ajuste
#'
#' `qs_sa` e `f_sa` medem sazonalidade residual na série ajustada; `l3` faz o
#' mesmo restrito aos últimos 3 anos, que é onde a sazonalidade residual
#' costuma aparecer primeiro. p-valor baixo = sobrou sazonalidade = ruim.
diagnosticos <- function(fit) {
  g <- function(linha) {
    tryCatch(
      as.numeric(fit$diagnostics$residuals_test[linha, "P.value"]),
      error = function(e) NA_real_
    )
  }
  tibble(
    qs_sa = g("qs test on sa"),
    f_sa = g("f-test on sa (seasonal dummies)"),
    l3 = g("Residual seasonality (last 3 years)")
  )
}

#' Qualidade da decomposição X-11 (só existe para o X-13)
#'
#' Q < 1 é o critério clássico de decomposição aceitável; M7 < 1 indica
#' sazonalidade identificável.
qualidade_x11 <- function(fit) {
  g <- function(m) {
    tryCatch(as.numeric(fit$decomposition$mstats[m, 1]), error = function(e) {
      NA_real_
    })
  }
  tibble(Q = g("Q"), M7 = g("M(7)"))
}

veredito_combinado <- function(fit) {
  tryCatch(
    as.character(fit$diagnostics$combined_test$combined_seasonality_test),
    error = function(e) NA_character_
  )
}

# ---------------------------------------------------------------------------
# 4. Scorecard
# ---------------------------------------------------------------------------

#' Escolhe entre X-11 e SEATS, ou decide não ajustar
#'
#' Não existe teste formal de "X-11 vs SEATS". O que existe é diagnóstico
#' comparativo, e a ordem abaixo é a hierarquia de critérios: primeiro
#' presença de sazonalidade, depois sazonalidade residual (o pecado capital de
#' um ajuste), depois o recorte recente, e só então qualidade da decomposição.
escolher_metodo <- function(combined, dx13, dseats, qx11, limiar = 0.05) {
  falha <- function(p) !is.na(p) && p < limiar

  case_when(
    combined %in% c("None", "ProbablyNone") ~ "nenhum",
    falha(dx13$qs_sa) & falha(dseats$qs_sa) ~ "nenhum",
    falha(dseats$qs_sa) & !falha(dx13$qs_sa) ~ "x11",
    falha(dx13$qs_sa) & !falha(dseats$qs_sa) ~ "seats",
    falha(dseats$l3) & !falha(dx13$l3) ~ "x11",
    falha(dx13$l3) & !falha(dseats$l3) ~ "seats",
    !is.na(qx11$Q) & qx11$Q > 1 ~ "seats",
    .default = "x11"
  )
}

razao_metodo <- function(combined, dx13, dseats, qx11, limiar = 0.05) {
  falha <- function(p) !is.na(p) && p < limiar

  case_when(
    combined %in% c("None", "ProbablyNone") ~ str_glue(
      "teste combinado: {combined}"
    ),
    falha(dx13$qs_sa) &
      falha(dseats$qs_sa) ~ "sazonalidade residual nos dois métodos",
    falha(dseats$qs_sa) &
      !falha(dx13$qs_sa) ~ "SEATS deixa sazonalidade residual (QS)",
    falha(dx13$qs_sa) &
      !falha(dseats$qs_sa) ~ "X-11 deixa sazonalidade residual (QS)",
    falha(dseats$l3) & !falha(dx13$l3) ~ "SEATS falha nos últimos 3 anos",
    falha(dx13$l3) & !falha(dseats$l3) ~ "X-11 falha nos últimos 3 anos",
    !is.na(qx11$Q) & qx11$Q > 1 ~ str_glue(
      "Q = {round(qx11$Q, 2)} > 1, decomposição X-11 fraca"
    ),
    .default = "empate nos diagnósticos, X-11 por robustez"
  ) %>%
    as.character()
}

# ---------------------------------------------------------------------------
# 5. Runner
# ---------------------------------------------------------------------------

#' Roda a escada inteira numa série e devolve status + série ajustada
#'
#' Devolve sempre duas coisas: uma linha de `status` (o que foi testado, o que
#' foi decidido, por quê) e a série em `sa`. Quando `status != "ajustada"`, a
#' coluna `value_sa` repete a série crua — mas isso está declarado, não
#' escondido.
ajustar_serie <- function(db, codigo, fatores, min_obs = 48) {
  d <-
    db %>%
    filter(codigo == .env$codigo, !is.na(value)) %>%
    arrange(date)

  vazio <- function(status) {
    list(
      status = tibble(codigo = codigo, n_obs = nrow(d), status = status),
      sa = tibble(codigo = codigo, date = d$date, value_sa = d$value)
    )
  }

  if (nrow(d) < min_obs) {
    return(vazio("serie_curta"))
  }

  x <- as_ts_mensal(db, codigo)
  fx13 <- tryCatch(ajustar_x13(x, fatores), error = function(e) NULL)
  fseat <- tryCatch(ajustar_seats(x, fatores), error = function(e) NULL)

  if (is.null(fx13) && is.null(fseat)) {
    return(vazio("falha_ajuste"))
  }

  testes <- testes_sazonalidade(x)
  combined <- veredito_combinado(fx13)
  dx13 <- if (is.null(fx13)) {
    tibble(qs_sa = NA_real_, f_sa = NA_real_, l3 = NA_real_)
  } else {
    diagnosticos(fx13)
  }
  dseats <- if (is.null(fseat)) {
    tibble(qs_sa = NA_real_, f_sa = NA_real_, l3 = NA_real_)
  } else {
    diagnosticos(fseat)
  }
  qx11 <- if (is.null(fx13)) {
    tibble(Q = NA_real_, M7 = NA_real_)
  } else {
    qualidade_x11(fx13)
  }

  metodo <- escolher_metodo(combined, dx13, dseats, qx11)
  razao <- razao_metodo(combined, dx13, dseats, qx11)

  serie_sa <- switch(
    metodo,
    x11 = as.numeric(fx13$final$series[, "sa"]),
    seats = as.numeric(fseat$final$series[, "sa"]),
    d$value
  )

  status <- if (metodo == "nenhum") {
    if (combined %in% c("None", "ProbablyNone")) {
      "sem_sazonalidade"
    } else {
      "nenhum_metodo_valido"
    }
  } else {
    "ajustada"
  }

  list(
    status = tibble(
      codigo = codigo,
      n_obs = nrow(d),
      combined = combined,
      testes,
      Q = qx11$Q,
      M7 = qx11$M7,
      qs_sa_x11 = dx13$qs_sa,
      qs_sa_seats = dseats$qs_sa,
      l3_x11 = dx13$l3,
      l3_seats = dseats$l3,
      metodo = metodo,
      razao = razao,
      status = status
    ),
    sa = tibble(codigo = codigo, date = d$date, value_sa = serie_sa)
  )
}

#' Aplica `ajustar_serie()` a um vetor de códigos
rodar_lote <- function(db, codigos, fatores, verbose = TRUE) {
  res <-
    unique(codigos) %>%
    map(function(cd) {
      if (verbose) {
        message("  ", cd)
      }
      tryCatch(
        ajustar_serie(db, cd, fatores),
        error = function(e) {
          list(
            status = tibble(
              codigo = cd,
              status = "erro",
              razao = conditionMessage(e)
            ),
            sa = tibble(
              codigo = cd,
              date = as.Date(character()),
              value_sa = numeric()
            )
          )
        }
      )
    })

  list(
    status = res %>% map("status") %>% list_rbind(),
    sa = res %>% map("sa") %>% list_rbind()
  )
}

# ---------------------------------------------------------------------------
# 6. Hierarquia e agregação
# ---------------------------------------------------------------------------

#' Folhas de um nó da hierarquia (walker recursivo)
folhas_de <- function(codigo, h) {
  linha <- h %>% filter(codigo == .env$codigo)
  if (nrow(linha) == 0 || linha$agg[1] == "F") {
    return(codigo)
  }
  linha$agg[1] %>%
    str_remove_all(" ") %>%
    str_split_1(",") %>%
    map(~ folhas_de(.x, h)) %>%
    unlist() %>%
    unique()
}

#' Soma bottom-up das folhas dessazonalizadas
#'
#' `na.rm = FALSE` de propósito: se uma folha falta num mês, o agregado daquele
#' mês tem que ser NA e não um número que parece completo. As colunas
#' `n_folhas_*` existem para que isso seja diagnosticável em vez de misterioso.
bottom_up <- function(codigo, h, sa) {
  folhas <- folhas_de(codigo, h)
  sa %>%
    filter(codigo %in% folhas) %>%
    reframe(
      value_sa = sum(value_sa, na.rm = FALSE),
      n_folhas_presentes = n(),
      .by = date
    ) %>%
    mutate(
      codigo = .env$codigo,
      n_folhas_esperadas = length(folhas)
    )
}
