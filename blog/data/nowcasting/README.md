# CSV congelado do nowcasting do PIB

Saída da esteira em `Nowcasting/code/` (ADR 0003). O post lê estes CSVs e nada mais:
não reestima, não lê draw, não chama o lake. Uma rodada só; os números abaixo dizem qual.

## Rodada

- Snapshot do painel: **2026-09-02**. Dados finais nesta data; o exercício é pseudo real-time sobre eles.
- Séries no painel: **11** no core, **59** no estendido, **9** no core longo (fora o alvo `pib`).
- Grade em execução: 2015Q1 a 2026Q3, quatro timings por trimestre (M1, M2, M3, véspera).
- Manchete: 2019Q1 a 2026Q2. Estimação desde 2011-01-01, janela expansiva; amostra de ajuste do X-13 desde 2003-01-01.

## MF-BAVART

O MF-BAVART (Huber, Koop, Onorante, Pfarrhofer & Schreiner, JoE 2023) saiu do lineup (ADR 0008). O código publicado (`mpfarrho/mf-bavart`) quebra em toda véspera de 2020: a linearização do BART por VAR (`ginv(X) %*% fit_BART`), usada como transição do simulation smoother, é explosiva em toda célula, e sem o PIB de 2020Q2 os meses latentes divergem. Quebra também no dado do próprio artigo. Os dois consertos possíveis mudam o algoritmo do paper e os números onde ele rodava, então a réplica não entra na tabela. No lugar entrou o sg-LASSO-FAMIDAS de Beyhum & Striaukas, e a tabela de densidade fica com três densos + SARIMA.

## Monitor do PIB

O Monitor do PIB é da FGV IBRE, e os termos de uso vedam a redistribuição do dado. Por isso `caminho_mensal.csv` só tem os três modelos, e a comparação com o Monitor atravessa como figura pronta, `caminho_mensal.png`, gravada na esteira por `figura_caminho_congelada()` com o tema do blog. É a única figura do post que o `.qmd` não desenha a partir de CSV.

## Tempos de execução

`tempos.csv` vem do `tar_meta()` do store. Máquina: AMD Ryzen 7 9800X3D (8 núcleos), 32 GB de RAM, Windows 11; o store foi construído com 6 workers do `crew`, e os segundos por ramo foram medidos com eles dividindo a máquina. `parede_min` só existe onde um ticket mediu o tempo de parede, e cada medição é de uma rodada diferente: `parede_de` diz a grade e os workers de cada uma. `painel` e `trilha` saem do nome do alvo e ficam `NA` onde o nome não os traz (o SARIMA sem painel é o do core).

## Tabelas

| Arquivo | Linhas | Colunas | O que é |
| --- | --- | --- | --- |
| `nowcasts.csv` | 9719 | 16 | Nowcasts de ponto, uma linha por (modelo, painel, trilha, variante, trimestre, timing): os modelos mais o combo de ponto e o combo-peneira, sem o core longo |
| `nowcasts_core_longo.csv` | 1367 | 16 | Nowcasts de ponto do core longo, com o SARIMA do core e o FOCUS como linhas de referência |
| `realizado.csv` | 94 | 6 | Gabaritos da série final do snapshot: Realizado SA (SA própria, spec do X-13 recursivo) e Realizado a/a, mais o QoQ da SA oficial do IBGE (`qoq_sa_oficial`), que é régua da SA própria e nunca gabarito |
| `avaliacao_qoq.csv` | 408 | 13 | RMSE, RMSE relativo ao SARIMA e DM-HLN contra SARIMA e FOCUS, métrica QoQ SA, manchete |
| `avaliacao_aa.csv` | 424 | 13 | A mesma tabela na métrica a/a |
| `avaliacao_densidade.csv` | 80 | 14 | CRPS, CRPS relativo ao SARIMA, log score, cobertura 68/90 e DM-HLN sobre diferenciais de CRPS |
| `quantis.csv` | 1200 | 11 | Quantis reduzidos (5/16/50/84/95) por célula: o que o fan chart do post lê no lugar dos draws |
| `avaliacao_densidade_aa.csv` | 80 | 14 | A tabela de densidade na métrica a/a: cada draw de QoQ SA levado a a/a pelo nível da célula de ponto, gabarito Realizado a/a |
| `quantis_aa.csv` | 1200 | 11 | Os quantis reduzidos na métrica a/a |
| `robustez_qoq.csv` | 1224 | 14 | A tabela QoQ SA nos três cortes de robustez 2015+ (cheia, pre_covid, pos) |
| `robustez_aa.csv` | 1272 | 14 | A tabela a/a nos mesmos três cortes |
| `core_longo_qoq.csv` | 160 | 14 | A tabela QoQ SA do core longo (cortes manchete e pos) |
| `core_longo_aa.csv` | 160 | 14 | A tabela a/a do core longo |
| `diagnostico_combos.csv` | 1310 | 9 | Por célula do combo de ponto e do combo-peneira: quantos modelos pesaram, quantos sobreviveram à peneira e se ela caiu no FOCUS |
| `news_4a_bloco.csv` | 1577 | 13 | News do DFM 4a agregada por bloco do catálogo: o gráfico principal do post |
| `estabilidade_timings.csv` | 60 | 3 | Revisão média absoluta da última observação SA entre timings consecutivos, por série |
| `status_x13.csv` | 11280 | 16 | Status do X-13 por (célula, série): estado, transform escolhido, queda pickmdl para automdl, erro |
| `caminho_mensal.csv` | 279 | 8 | Caminho mensal do PIB na véspera (dlog m/m SA) nos três MF do core, sem o Monitor do PIB |
| `tempos.csv` | 39 | 9 | Tempo de execução por etapa da esteira, lido do `tar_meta()` do store: ramos, segundos por ramo (mediana) e soma, mais o tempo de parede onde um ticket o mediu |

A coluna `erro` de `status_x13.csv` vem com os espaços em branco colapsados — é o log do
binário do X-13, com quebras de linha dentro, e nenhum campo aqui atravessa o limite da linha.
Valores ausentes são `NA`; separador `,`, decimal `.`, fim de linha `\n`, codificação UTF-8.

