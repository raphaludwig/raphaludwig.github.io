# Congela os resultados do motor antigo (RJDemetra 0.2.8 / JDemetra+ 2.2.5).
#
# Rodar À MÃO, e obrigatoriamente ANTES de trocar o Java da máquina para a
# versão 21+ que a família rjd3 exige: os jars 2.2.5 foram compilados para
# Java 8 e não há garantia de que sigam carregando depois. Este script é a
# config "A" do teste controlado da migração — sem ele não há contra o quê
# comparar o motor novo.
#
# HISTÓRICO, NÃO RODA MAIS. Ficou aqui como procedência dos CSVs
# `baseline_rjdemetra_2x_*` que estão em data/seasonal-adjustment/, e não como
# script executável. O `R/sa_runner.R` que ele carrega migrou para a família
# rjd3: aborta em Java < 21 (o que este script exige que NÃO aconteça),
# `carregar_fatores()` devolve o pacote do 3.x em vez de uma matriz e
# `rodar_lote()` ganhou o argumento `calendario`. Reproduzir o baseline exigiria
# o `sa_runner.R` na revisão fe26c8d, RJDemetra 0.2.8 e Java 8.

setwd("C:/dev/raphaludwig.github.io/blog")
suppressMessages(source("R/sa_runner.R"))

dir_dados <- "data/seasonal-adjustment"

hierarquia <- readr::read_csv(
  file.path(dir_dados, "hierarquia_concessoes.csv"),
  show_col_types = FALSE
) %>%
  mutate(codigo = as.character(codigo))

codigos_oficiais <- as.character(na.omit(hierarquia$dessaz_oficial))

db <- carregar_series(
  c(hierarquia$codigo, codigos_oficiais),
  cache_path = file.path(dir_dados, "sgs_concessoes.csv")
)
fatores <- carregar_fatores(file.path(dir_dados, "dessaz_ibc_br.txt"))

message("rodando o lote nas ", nrow(hierarquia), " séries...")
resultado <- rodar_lote(db, hierarquia$codigo, fatores, verbose = FALSE)

readr::write_csv(
  resultado$status,
  file.path(dir_dados, "baseline_rjdemetra_2x_status.csv")
)
readr::write_csv(
  resultado$sa,
  file.path(dir_dados, "baseline_rjdemetra_2x_sa.csv")
)

# Procedência: sem isto o CSV é um monte de número sem dizer de onde veio.
jars <- basename(list.files(system.file("java", package = "RJDemetra")))
writeLines(
  c(
    paste("gerado em            :", Sys.time()),
    paste("R                    :", R.version.string),
    paste("RJDemetra            :", as.character(packageVersion("RJDemetra"))),
    paste("seastests            :", as.character(packageVersion("seastests"))),
    paste("JVM                  :", rJava::.jcall("java/lang/System", "S", "getProperty", "java.version")),
    paste("jars                 :", paste(jars, collapse = ", ")),
    paste("spec x13             : default do x13_spec() = RSA5c"),
    paste("spec tramoseats      : default do tramoseats_spec() = RSAfull"),
    paste("usrdef.varType       : default = Undefined"),
    paste("séries               :", nrow(resultado$status))
  ),
  file.path(dir_dados, "baseline_rjdemetra_2x_meta.txt")
)

# `count` qualificado: o `seastests` carregado pelo sa_runner.R mascara o do dplyr.
cat("\n=== resumo do baseline ===\n")
print(resultado$status %>% dplyr::count(status, metodo))
cat("\nvereditos do teste combinado:\n")
print(resultado$status %>% dplyr::count(combined))
cat("\nSEATS escolhido por qual razão:\n")
print(resultado$status %>% filter(metodo == "seats") %>% dplyr::count(razao))
cat("\nbaseline gravado em", dir_dados, "\n")
