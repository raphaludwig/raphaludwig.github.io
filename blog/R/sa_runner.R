# Rotina de ajuste sazonal usada no post 0002-ajuste-sazonal-credito.
#
# Três blocos: (1) leitura do snapshot do SGS, (2) escada de testes de
# sazonalidade + scorecard de escolha de método, (3) agregação bottom-up sobre
# a hierarquia de concessões, com contagem de folhas.
#
# Nenhuma função aqui devolve a série crua disfarçada de série ajustada. Quando
# o ajuste não acontece, `status` diz por quê.

# O motor é o JDemetra+ 3.x, via família `rjd3`, e não o `RJDemetra`, que está
# preso ao JDemetra+ 2.x e cujo runtime chega ao fim da vida em dezembro de 2026.
# Exige Java 21+ (aqui: OpenJDK 25). O `seastests` continua no degrau 3 de
# propósito, para ser um voto independente do motor que faz o ajuste.
suppressMessages({
  library(dplyr)
  library(purrr)
  library(stringr)
  library(rjd3toolkit)
  library(rjd3x13)
  library(rjd3tramoseats)
  library(seastests)
})

# Falha com echo, e cedo. Sob uma JVM velha os pacotes carregam sem reclamar e
# só quebram na primeira chamada, com um `UnsupportedClassVersionError` cru que
# não diz o que fazer. Acontece de verdade. Basta abrir o shell antes de apontar
# o JAVA_HOME para o JDK novo.
local({
  v <- rJava::.jcall("java/lang/System", "S", "getProperty", "java.version")
  maior <- as.integer(str_extract(v, "^\\d+"))
  if (!is.na(maior) && maior < 21) {
    stop(str_glue(
      "os pacotes rjd3 exigem Java 21+, mas a JVM desta sessão é a {v}. \\
       Aponte JAVA_HOME para o JDK 21+ e reinicie o processo do R."
    ))
  }
})

# ---------------------------------------------------------------------------
# 1. Coleta
# ---------------------------------------------------------------------------

#' Lê o snapshot congelado das séries do SGS
#'
#' O render lê CSV, não a API. Não é só conveniência de disponibilidade, embora
#' o SGS devolva 502 com frequência. O post inteiro é condicional à amostra: os
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

#' Regrava o snapshot a partir do SGS. Rodar À MÃO, nunca no render
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
#'
#' Devolve o pacote inteiro que o JDemetra+ 3.x precisa: as séries, o
#' `modelling_context` que as registra e os nomes qualificados (`grupo.nome`)
#' pelos quais a spec se refere a elas. No 2.x bastava passar uma matriz; no 3.x
#' as variáveis do usuário vivem num contexto separado da spec.
carregar_fatores <- function(path, grupo = "ibcbr") {
  bruto <- readr::read_tsv(
    path,
    col_names = c("year", "month", str_c("fator", 1:6)),
    col_types = "iidddddd"
  )
  nomes <- str_c("fator", 1:6)
  series <-
    nomes %>%
    map(~ ts(as.numeric(bruto[[.x]]), start = c(1990, 1), frequency = 12)) %>%
    set_names(nomes)

  list(
    grupo = grupo,
    nomes = nomes,
    series = series,
    uservars = str_c(grupo, ".", nomes),
    context = rjd3toolkit::modelling_context(
      variables = set_names(list(series), grupo)
    )
  )
}

# ---------------------------------------------------------------------------
# 2. Escada de testes
# ---------------------------------------------------------------------------

#' Degraus 2 a 4 da escada: QS, Friedman, Kruskal-Wallis, WO e sazonalidade
#' determinística (seasdum).
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
    seasdum_p = p(seastests::seasdum)
  )
}

# ---------------------------------------------------------------------------
# 3. Ajuste e diagnóstico
# ---------------------------------------------------------------------------

# Itens do dicionário do JDemetra+ que não vêm no objeto de resultado por
# padrão e precisam ser pedidos na chamada.
ITENS_DIC <- c(
  "diagnostics.seas-si-combined", # teste combinado sobre as razões SI
  "diagnostics.seas-sa-combined3" # o mesmo, restrito aos últimos 3 anos
)

#' Specs pinadas, nunca o default
#'
#' Os defaults divergem entre as gerações: `RJDemetra::x13_spec()` entregava
#' RSA5c, `rjd3x13::x13_spec()` entrega rsa4. Depender do default trocaria o
#' tratamento de calendário em silêncio, então as duas specs são explícitas.
#'
#' `calendario = TRUE` põe os seis fatores do IBC-BR **no lugar** do bloco de
#' dias úteis do JDemetra+, em vez de empilhar um sobre o outro. É o que
#' `set_tradingdays(option = "UserDefined")` faz. O `add_usrdefvar()` não serve
#' aqui, porque a própria documentação exclui o componente de calendário do que
#' ela sabe alocar.
spec_x13 <- function(fatores, calendario = TRUE) {
  spec <- rjd3x13::x13_spec("rsa5c")
  aplicar_fatores(spec, fatores, calendario)
}

spec_seats <- function(fatores, calendario = TRUE) {
  spec <- rjd3tramoseats::tramoseats_spec("rsafull")
  aplicar_fatores(spec, fatores, calendario)
}

aplicar_fatores <- function(spec, fatores, calendario) {
  if (calendario) {
    return(rjd3toolkit::set_tradingdays(
      spec,
      option = "UserDefined",
      uservariable = fatores$uservars,
      test = "None"
    ))
  }
  # Ramo de comparação: replica o 2.x, onde os fatores entravam como regressores
  # indefinidos e conviviam com os dias úteis próprios do JDemetra+.
  reduce(
    fatores$nomes,
    function(s, v) {
      rjd3toolkit::add_usrdefvar(
        s,
        group = fatores$grupo,
        name = v,
        regeffect = "Undefined"
      )
    },
    .init = spec
  )
}

ajustar_x13 <- function(x, fatores, calendario = TRUE) {
  rjd3x13::x13(
    x,
    spec_x13(fatores, calendario),
    context = fatores$context,
    userdefined = ITENS_DIC
  )
}

ajustar_seats <- function(x, fatores, calendario = TRUE) {
  rjd3tramoseats::tramoseats(
    x,
    spec_seats(fatores, calendario),
    context = fatores$context,
    userdefined = ITENS_DIC
  )
}

#' Contrafactual "sem calendário nenhum", via RSA3
#'
#' Não confundir com `calendario = FALSE`, que ainda deixa o bloco de dias úteis
#' do próprio JDemetra+ ligado (é a réplica do 2.x, onde os fatores entravam por
#' fora como regressores indefinidos). O RSA3 desliga o tratamento de calendário
#' inteiro, e é ele que responde "quanto muda por causa do calendário?".
ajustar_x13_rsa3 <- function(x) {
  rjd3x13::x13(x, rjd3x13::x13_spec("rsa3"), userdefined = ITENS_DIC)
}

#' Série dessazonalizada, seja qual for o motor
#'
#' As duas saídas não têm a mesma forma. O X-13 devolve séries diretas com a
#' nomenclatura das tabelas do X-11 (`d11final` = série ajustada, `d12final` =
#' tendência, `d16` = fatores sazonais, `d13final` = irregular, `e1` = original).
#' O TRAMO-SEATS devolve nomes semânticos (`sa`, `t`, `s`, `i`, `series`), mas
#' cada um embrulhado numa lista com `$data` (amostra) e `$fcasts` (previsão).
#' Só o `$data` interessa aqui.
dados_de <- function(x) as.numeric(if (is.list(x)) x$data else x)

serie_sa_ts <- function(fit) {
  final <- fit$result$final
  x <- if (!is.null(final$d11final)) final$d11final else final$sa
  if (is.list(x)) x$data else x
}

serie_sa <- function(fit) as.numeric(serie_sa_ts(fit))

#' Componentes da decomposição, para o gráfico das quatro peças
componentes <- function(fit) {
  final <- fit$result$final
  if (!is.null(final$d11final)) {
    list(
      y = dados_de(final$e1),
      t = dados_de(final$d12final),
      s = dados_de(final$d16),
      i = dados_de(final$d13final)
    )
  } else {
    list(
      y = dados_de(final$series),
      t = dados_de(final$t),
      s = dados_de(final$s),
      i = dados_de(final$i)
    )
  }
}

#' Diagnósticos pós-ajuste da série ajustada
#'
#' `qs_sa` e `f_sa` medem sazonalidade residual na série ajustada; `combined3`
#' faz o mesmo restrito aos últimos 3 anos, que é onde a sazonalidade residual
#' costuma aparecer primeiro. Nos p-valores, baixo = sobrou sazonalidade = ruim;
#' no `combined3`, que é categórico, o valor ruim é `Present`.
#'
#' Sobre o recorte de 3 anos, que mudou na tradução do 2.x para o 3.x. O 2.x
#' publicava uma linha "Residual seasonality (last 3 years)" com p-valor pronto.
#' O dicionário do 3.x não tem esse p-valor, só o `seas-sa-combined3`, que
#' devolve veredito (`Present`/`None`) e não número. A primeira tradução aqui
#' recalculou um QS à mão sobre os últimos 36 meses, para o scorecard seguir
#' comparando p-valor com p-valor. Não funcionou: ~36 observações já
#' diferenciadas, num teste unilateral, colapsam a estatística a zero, e o
#' p-valor saía **exatamente 1 nas 73 séries, nos dois motores**. O critério
#' nunca separava nada. Por isso o scorecard passou a ler o veredito categórico
#' do próprio motor, que é o que este campo devolve.
#'
#' Sobre a primeira diferença. O `rjd3toolkit` aplica o QS à série como ela
#' chega, e uma série ajustada em nível ainda tem tendência. A autocorrelação da
#' tendência domina e o p-valor vai a zero em toda série, sazonal ou não.
#' Diferenciar antes é o que o próprio motor faz internamente.
#' `qs_sa` e `l3` saem os dois dessa receita, sobre a mesma transformação, para
#' que o número do X-11 e o do SEATS sejam comparáveis. O veredito `combined3`
#' vai junto no status, como conferência independente.
diagnosticos <- function(fit) {
  p <- function(no) {
    tryCatch(as.numeric(no$pvalue), error = function(e) NA_real_)
  }
  d <- fit$result$diagnostics
  sa <- tryCatch(serie_sa_ts(fit), error = function(e) NULL)

  # QS sobre a mesma transformação nos dois motores. O `seas.qstest.sa` do
  # relatório não serve para comparar X-11 com SEATS. O motor diferencia a SA
  # conforme o (d, bd) do modelo ARIMA que ele próprio escolheu, e quando o
  # TRAMO escolhe bd = 0 e o RegARIMA do X-13 escolhe bd = 1, o QS do SEATS sai
  # de uma série que ainda tem tendência e o do X-11 não. Aqui os dois números
  # vêm do mesmo objeto: primeira diferença da SA, sobre a amostra inteira.
  qs <- function() {
    if (is.null(sa)) {
      return(NA_real_)
    }
    tryCatch(
      as.numeric(
        rjd3toolkit::seasonality_qs(diff(sa), period = 12)$pvalue
      ),
      error = function(e) NA_real_
    )
  }

  tibble(
    qs_sa = qs(),
    f_sa = p(d$seas.ftest.sa),
    combined3 = tryCatch(
      as.character(fit$user_defined[["diagnostics.seas-sa-combined3"]]),
      error = function(e) NA_character_
    )
  )
}

#' Qualidade da decomposição X-11 (só existe para o X-13)
#'
#' Q < 1 é o critério clássico de decomposição aceitável; M7 < 1 indica
#' sazonalidade identificável.
qualidade_x11 <- function(fit) {
  g <- function(m) {
    tryCatch(as.numeric(fit$result$mstats[[m]]), error = function(e) NA_real_)
  }
  tibble(Q = g("q"), M7 = g("m7"))
}

#' Veredito do teste combinado (Ladiray & Quenneville)
#'
#' É o mesmo teste que o 2.x expunha como `combined_test`, a variante calculada
#' sobre as razões SI, `seas-si-combined`. O dicionário do 3.x oferece outras
#' variantes (`-sa-`, `-lin-`, `-res-`) que respondem perguntas diferentes e
#' **não** são substitutas.
veredito_combinado <- function(fit) {
  v <- tryCatch(
    as.character(fit$user_defined[["diagnostics.seas-si-combined"]]),
    error = function(e) NA_character_
  )
  # `NULL[["chave"]]` devolve NULL em vez de dar erro, então o tryCatch acima não
  # dispara quando o ajuste falhou e `fit` é NULL: o veredito sairia como
  # `character(0)`, que se propaga em silêncio. `case_when()` recicla todas as
  # condições para tamanho 0, `escolher_metodo()` devolve `character(0)` e o
  # `switch()` do runner quebra com "EXPR must be a length 1 vector" — a série
  # vira `erro` em vez de cair no outro motor.
  if (length(v) != 1) NA_character_ else v
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
  # O recorte de 3 anos é categórico, não p-valor: `Present` = sobrou
  # sazonalidade nos últimos 3 anos = o método falhou ali.
  falha3 <- function(v) !is.na(v) && v == "Present"

  case_when(
    combined %in% c("None", "ProbablyNone") ~ "nenhum",
    falha(dx13$qs_sa) & falha(dseats$qs_sa) ~ "nenhum",
    falha(dseats$qs_sa) & !falha(dx13$qs_sa) ~ "x11",
    falha(dx13$qs_sa) & !falha(dseats$qs_sa) ~ "seats",
    falha3(dseats$combined3) & !falha3(dx13$combined3) ~ "x11",
    falha3(dx13$combined3) & !falha3(dseats$combined3) ~ "seats",
    !is.na(qx11$Q) & qx11$Q > 1 ~ "seats",
    .default = "x11"
  )
}

razao_metodo <- function(combined, dx13, dseats, qx11, limiar = 0.05) {
  falha <- function(p) !is.na(p) && p < limiar
  # O recorte de 3 anos é categórico, não p-valor: `Present` = sobrou
  # sazonalidade nos últimos 3 anos = o método falhou ali.
  falha3 <- function(v) !is.na(v) && v == "Present"

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
    falha3(dseats$combined3) &
      !falha3(dx13$combined3) ~ "SEATS deixa sazonalidade residual nos últimos 3 anos",
    falha3(dx13$combined3) &
      !falha3(dseats$combined3) ~ "X-11 deixa sazonalidade residual nos últimos 3 anos",
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
#' coluna `value_sa` repete a série crua, e isso está declarado, não escondido.
ajustar_serie <- function(db, codigo, fatores, min_obs = 48, calendario = TRUE) {
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
  fx13 <- tryCatch(ajustar_x13(x, fatores, calendario), error = function(e) NULL)
  fseat <- tryCatch(ajustar_seats(x, fatores, calendario), error = function(e) NULL)

  if (is.null(fx13) && is.null(fseat)) {
    return(vazio("falha_ajuste"))
  }

  sem_diag <- tibble(
    qs_sa = NA_real_, f_sa = NA_real_, combined3 = NA_character_
  )
  testes <- testes_sazonalidade(x)
  combined <- veredito_combinado(fx13)
  dx13 <- if (is.null(fx13)) sem_diag else diagnosticos(fx13)
  dseats <- if (is.null(fseat)) sem_diag else diagnosticos(fseat)
  qx11 <- if (is.null(fx13)) {
    tibble(Q = NA_real_, M7 = NA_real_)
  } else {
    qualidade_x11(fx13)
  }

  metodo <- escolher_metodo(combined, dx13, dseats, qx11)
  razao <- razao_metodo(combined, dx13, dseats, qx11)

  # O scorecard decide olhando diagnósticos, e um motor que falhou entrega
  # diagnósticos NA — que `falha()` lê como "não falhou". Sem esta guarda, os
  # critérios 4 e 5 podem mandar para o SEATS uma série cujo `fseat` é NULL, e
  # `serie_sa(NULL)` devolveria `numeric(0)`.
  existe <- c(x11 = !is.null(fx13), seats = !is.null(fseat))
  if (metodo %in% names(existe) && !existe[[metodo]]) {
    alternativa <- setdiff(names(existe)[existe], metodo)
    if (length(alternativa) == 1) {
      razao <- str_glue("{razao}; {metodo} não ajustou, caiu para {alternativa}")
      metodo <- alternativa
    } else {
      razao <- str_glue("{razao}; {metodo} não ajustou e não há alternativa")
      metodo <- "nenhum"
    }
    razao <- as.character(razao)
  }

  valores_sa <- switch(
    metodo,
    x11 = serie_sa(fx13),
    seats = serie_sa(fseat),
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
      combined3_x11 = dx13$combined3,
      combined3_seats = dseats$combined3,
      metodo = metodo,
      razao = razao,
      status = status
    ),
    sa = tibble(codigo = codigo, date = d$date, value_sa = valores_sa)
  )
}

#' Aplica `ajustar_serie()` a um vetor de códigos
rodar_lote <- function(db, codigos, fatores, verbose = TRUE, calendario = TRUE) {
  res <-
    unique(codigos) %>%
    map(function(cd) {
      if (verbose) {
        message("  ", cd)
      }
      tryCatch(
        ajustar_serie(db, cd, fatores, calendario = calendario),
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
#' `na.rm = FALSE` de propósito. Se uma folha falta num mês, o agregado daquele
#' mês tem que ser NA, e não um número que parece completo. As colunas
#' `n_folhas_*` estão ali para que isso apareça em vez de virar mistério.
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
      n_folhas_esperadas = length(folhas),
      # `na.rm = FALSE` protege contra valor NA, não contra linha ausente. Uma
      # folha que terminou como `erro` não contribui linha nenhuma, e a soma
      # sairia menor — sem NA e sem aviso. Aqui ela vira NA, como manda a regra
      # declarada acima.
      value_sa = if_else(
        n_folhas_presentes < n_folhas_esperadas,
        NA_real_,
        value_sa
      )
    )
}
