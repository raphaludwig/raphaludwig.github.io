# Tema e paleta padrão pros gráficos ggplot2 do blog. Ancorado no verde-slate
# do site (assets/css/theme.scss: --pal-accent #52796f, --pal-text #2f3e46).
# Ver blog/CONTEXT.md para o glossário dos tiers/accent.

suppressMessages(library(ggplot2))
suppressMessages(library(scales))

# "Segoe UI Semibold" não é uma família separada no Windows -- é o peso
# "semibold" dentro da família "Segoe UI". Registra a variante pra poder
# referenciá-la por esse nome em element_text(family = ...).
if (requireNamespace("systemfonts", quietly = TRUE)) {
  try(
    systemfonts::register_variant(
      name = "Segoe UI Semibold",
      family = "Segoe UI",
      weight = "semibold"
    ),
    silent = TRUE
  )
}

# A variante acima só é reconhecida por dispositivos gráficos que consultam o
# registro do systemfonts (ragg, svglite) -- o dispositivo padrão do knitr
# (grDevices::png) não a encontra e gera warnings "font family not found".
# fig.width maior que o padrão (7) pra aproveitar melhor os 900px do container
# do post (grid.body-width no _quarto.yml). Ver blog/docs/adr/0002.
knitr::opts_chunk$set(dev = "ragg_png", fig.width = 9)

pal_blog_colors <- c(
  slate_darkest = "#2f3e46",
  slate_dark    = "#3f5f56",
  slate_mid     = "#52796f",
  sage_light    = "#84a98c",
  sage_pale     = "#cad2c5"
)

pal_blog_accent <- c(
  cool = "#7a3b4a", # ameixa/vinho -- default
  warm = "#b5654a"  # terracota -- alternativa
)

#' Paleta verde-slate do blog
#'
#' @param tier "main" (1-2 séries, tons próximos), "contrast" (2-3 tons bem
#'   distintos, para destacar uma série contra outra) ou "extended" (rampa
#'   completa, para 3+ séries).
#' @param n Número de cores desejado. Se menor que o tamanho do tier, os tons
#'   são reamostrados igualmente espaçados na rampa para maximizar contraste
#'   (em vez de truncar do início).
pal_blog <- function(tier = c("main", "contrast", "extended"), n = NULL) {
  tier <- match.arg(tier)
  base <- switch(tier,
    main     = unname(pal_blog_colors[c("slate_mid", "sage_light")]),
    contrast = unname(pal_blog_colors[c("slate_darkest", "sage_light")]),
    extended = unname(pal_blog_colors)
  )
  if (is.null(n) || n >= length(base)) {
    return(base)
  }
  # Caso especial: o resampling genérico pra n=3 em "extended" cairia em
  # sage_pale (índice 5), claro demais pra contrastar contra fundo branco
  # numa linha. Troca por sage_light (índice 4).
  if (tier == "extended" && n == 3) {
    return(base[c(1, 3, 4)])
  }
  base[round(seq(1, length(base), length.out = n))]
}

#' Cor de destaque fora do verde-slate, para barras/saldo/elementos secundários
#'
#' @param tone "cool" (ameixa, default) ou "warm" (terracota, alternativa).
accent_blog <- function(tone = c("cool", "warm")) {
  tone <- match.arg(tone)
  unname(pal_blog_accent[tone])
}

scale_color_blog <- function(tier = c("main", "contrast", "extended"), n = NULL, ...) {
  scale_color_manual(values = pal_blog(match.arg(tier), n), ...)
}

scale_fill_blog <- function(tier = c("main", "contrast", "extended"), n = NULL, ...) {
  scale_fill_manual(values = pal_blog(match.arg(tier), n), ...)
}

#' Tema padrão dos gráficos do blog
#'
#' Legenda no canto superior direito, fora da área do plot, horizontal, sem
#' título; só linhas de grade horizontais; eixo Y sem título (a unidade vai
#' no subtítulo, não no eixo); título em negrito; eixo X rotacionado 90°
#' (garante que o último label, sempre a última data, não vaze pra fora do
#' plot -- ver blog/docs/adr/0003).
theme_blog <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      text = element_text(family = "Segoe UI Semibold", colour = pal_blog_colors[["slate_darkest"]]),
      plot.title = element_text(face = "bold", vjust = 1.5),
      plot.subtitle = element_text(colour = pal_blog_colors[["slate_mid"]], vjust = 3.75),
      # sem colour aqui de propósito -- herda slate_darkest de `text`, igual
      # ao título (plot.title também não sobrescreve colour).
      plot.caption = element_text(face = "italic", size = rel(0.75), hjust = 1),
      axis.title.y = element_blank(),
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.minor.y = element_blank(),
      panel.grid.major.y = element_line(colour = "lightgray", linewidth = 0.1),
      legend.title = element_blank(),
      legend.position = c(1, 1),
      legend.justification = "right",
      legend.direction = "horizontal",
      legend.box = "horizontal"
    )
}

#' Quebras/formato padrão pro eixo X quando é uma série de datas
scale_x_date_blog <- function(date_col, n_breaks = 13, ...) {
  scale_x_date(
    labels = date_format("%b %y"),
    breaks = seq.Date(from = min(date_col), to = max(date_col), length.out = n_breaks),
    expand = expansion(mult = c(0.01, 0.01)),
    ...
  )
}

#' Caption padrão: fontes oficiais primeiro, "RL" sempre por último
caption_blog <- function(sources) {
  all <- c(sources, "RL")
  if (length(all) == 1) {
    joined <- all
  } else {
    joined <- paste0(paste(all[-length(all)], collapse = ", "), " e ", all[length(all)])
  }
  paste0("Fonte: ", joined)
}
