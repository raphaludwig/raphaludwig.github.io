# Post 0001 (filtro de Kalman / NAIRU) — decisões de modelagem

Decisões que explicam o código publicado nos posts
`blog/0001-kalman-filter-pt1-nairu.pt.qmd` e `blog/0001-kalman-filter-pt2-bssm.pt.qmd`.
As três são da Parte 2.

Vieram de `G:\My Drive\knowledge\Kalman Filter\BCB blog example\docs\adr\` em
2026-08-11, texto preservado. Estavam órfãs fora do repo: justificam código que
está publicado, mas quem clonasse o repositório não chegava nelas.

Duas ressalvas de leitura:

- Elas foram escritas **antes** da publicação — "a Pt 2 (ainda não publicada)" no
  primeiro parágrafo da segunda. Os três desenhos que elas decidem foram todos
  para o ar como descrito (`bsm_lg` com `P1 = matrix(1e6)`, estimação em estágio
  único, SGS 29683 via `GetBCBData` com Focus/IPPCV ainda internos), conferido
  contra o `.qmd` publicado.
- As referências a "este `CONTEXT.md`" apontam para o arquivo de ~32KB que continua
  na pasta de pesquisa no Drive, não para `blog/CONTEXT.md` (que é o glossário de
  cores/tiers dos gráficos). Não confundir os dois.

Não confundir também com `adr/` na raiz do repo: aquilo é convenção **perene de
site e de blog**, que vale para todo post. Isto aqui é modelagem de um post só.

---

## 1. bssm constrói o modelo nativamente (bsm_lg), não via as_bssm(model_kfas_*)

**Status**: accepted

`bssm` (ao contrário do KFAS) não oferece inicialização difusa exata — `P1`
precisa ser uma matriz finita, sem equivalente ao `P1inf` do KFAS. Existe uma
alternativa: `as_bssm(model_kfas_1, kappa=...)` converte o `SSModel` do KFAS
(já com difuso exato) direto pro formato bssm, herdando a inicialização
correta e evitando qualquer divergência numérica no 1º estágio.

Decidimos NÃO usar essa ponte e construir o modelo nativamente com `bsm_lg` e
`P1=1e6` (grande-mas-finito), aceitando a divergência esperada em γ no 1º
estágio — pelo mesmo motivo já documentado no `CONTEXT.md` pro pacote
`kalmanfilter` (que tem a mesma limitação). Razão: a seção bssm existe pra
demonstrar o pacote como ferramenta independente (MLE vs. MCMC dado o MESMO
modelo), não como pós-processamento de um modelo KFAS já validado — misturar
os dois enfraqueceria esse ponto pedagógico e faria "bssm" parecer um wrapper
do KFAS em vez de uma 4ª implementação de verdade.

**Consequência esperada (hipótese pré-execução)**: γ̂ do 1º estágio via bssm
ficaria mais perto do `kalmanfilter` (~0.85) do que de MARSS/KFAS (~0.69).

**Resultado observado e verificado (rodado em 2026-07-16, após corrigir dois
bugs de instrumentação — ver nota abaixo)**: a hipótese estava ERRADA, e da
forma mais forte possível. `bssm-MLE` (β=0.2193, γ=0.6933, θ=1.525) e
`bssm-MCMC` (β≈0.219, γ≈0.69, θ≈1.50) reproduzem MARSS/KFAS até a 3ª–4ª casa
decimal — tanto no PONTO quanto na LARGURA da banda de IC 95% (verificado
numericamente, não só visualmente: larguras de banda em datas de checagem
batem entre os 4 pacotes; só o `kalmanfilter` diverge, como já documentado).
`P1=1e6` (grande-mas-finito) se revelou, na prática, numericamente
equivalente à inicialização difusa exata para ESSE modelo — a limitação
formal de bssm (sem `P1inf`) não se traduziu em nenhum viés mensurável aqui.

Isso reforça, em vez de contradizer, o que o `CONTEXT.md` já registrava sobre
o `kalmanfilter`: sua divergência nunca foi explicada por "P0 pequeno demais"
(não desaparece nem com P0=1e14) — bssm ser numericamente correto com
P1=1e6 é evidência adicional de que o problema é específico da recursão do
`kalmanfilter`, não uma limitação genérica de "P0 grande-mas-finito vs.
difuso exato".

**Nota sobre o processo**: as duas primeiras tentativas de interpretar esse
resultado (registradas e descartadas nesta mesma revisão do documento) vieram
de bugs de instrumentação, não do modelo: (1) a inovação usada pra recuperar
`sigma2_hat` no `bssm-MLE` esqueceu de subtrair o termo `D=θ·IPPCV_t` antes de
comparar com a previsão do filtro; (2) o `SD` que `summary(run_mcmc(...),
variable="states")` devolve está na mesma escala NÃO-normalizada de
`sd_y=1`/`sd_level=sqrt(1/λ)` que os outros pacotes usam — precisa do MESMO
`sigma2_hat` de reescala que o `bssm-MLE` já aplicava, e essa reescala tinha
sido esquecida no `bssm-MCMC`, fazendo a banda sair ~2x mais estreita que a
real. Fica como lembrete de checar SEMPRE a largura da banda numericamente
(não só a inspeção visual do gráfico) antes de tirar conclusão sobre
incerteza em qualquer novo pacote adicionado aqui.

---

## 2. Pt 2 migra para estimação em estágio único, abandonando os dois estágios da Pt 1

A Pt 1 (e o post nº29 do BC Blog que ela replica) estima o modelo em dois
estágios — dez/01-dez/19 fixa β e γ (θ=0 nessa janela); dez/01-[fim] fixa β,γ
e estima θ e a NAIRU — para evitar que a pandemia distorça os parâmetros
estruturais. O post nº46 do BC Blog (atualização oficial do exercício,
publicada em resposta à própria Pt 1) abandona essa separação: estima β, γ,
θ, as variâncias dos termos de erro (portanto λ deixa de ser calibrado e
passa a ser estimado) e a NAIRU conjuntamente, por máxima verossimilhança, na
amostra completa.

Decisão: a Pt 2 (`bssm-MLE` + `bssm-MCMC`, ainda não publicada) migra para
estágio único, seguindo o post nº46, mesmo que isso divirja do desenho de
dois estágios que a Pt 1 usa e que está documentado em detalhe neste
CONTEXT.md (seção "y_t efetivo do BCB — o ponto mais sutil"). Motivo:
prioriza fidelidade à metodologia atual do BCB (o que a Pt 2 está replicando
agora) sobre consistência de desenho com a Pt 1 — a Pt 1 fica intocada como
registro do exercício original.

### Consequências

- A restrição de parâmetro compartilhado γ (mesmo valor como coeficiente de
  `u_t` e como `Z_t` do estado) continua valendo, mas não há mais uma
  transição de "γ livre no 1º estágio" para "γ fixo no 2º estágio" — γ é
  parâmetro livre do início ao fim da amostra, junto com β, θ e as variâncias.
- λ deixa de ser um valor calibrado testado em três cenários de robustez
  (60/120/240) e passa a ser estimado — no `bssm-MLE` via a mesma
  otimização que já produz os demais parâmetros; no `bssm-MCMC`, vira
  parâmetro com prior (em vez de `sd_level=sqrt(1/120)` fixo).
- Como consequência, os ICs da NAIRU passam a ser nativos por método:
  bootstrap paramétrico no `bssm-MLE` (replicando o procedimento do post
  nº46), intervalo de credibilidade por quantis da posterior no
  `bssm-MCMC` — isso substitui a aproximação normal ±1.96×sd que a Pt 2
  usava antes só para manter comparabilidade visual com as 5 vozes da Pt 1
  (ver CONTEXT.md, seção "Decisões de grilling: adicionando bssm").

---

## 3. Na Pt 2, só o núcleo EX3 Serviços migra para fonte pública (SGS 29683); o resto continua no datalake.utils

O `raw_data.R` da Pt 1 monta a série de inflação subjacente de serviços
(`ipca_ssubj`) recalculando-a a partir de tabelas internas do
`datalake.utils` (`db_infdeg_des`/`db_difex_des`), com a estrutura de pesos
atual do IPCA aplicada retroativamente. O post nº46 usa em vez disso a série
já publicada pelo BC no Sistema Gerenciador de Séries Temporais (SGS), código
29683 ("núcleo EX3 Serviços") — sem recálculo.

Decisão: na Pt 2, a série de inflação passa a ser puxada do SGS 29683 via
pacote `GetBCBData` (público), substituindo o recálculo via `datalake.utils`.
As demais séries (desemprego retropolado, Focus, IPPCV) continuam vindo de
`datalake.utils`/CSVs locais, exatamente como no `raw_data.R` da Pt 1 —
decisão explícita de NÃO estender essa migração ao resto do pipeline nesta
rodada (desemprego retropolado e IPPCV são séries próprias, sem publicação em
SGS; Focus teria alternativa pública via Sistema de Expectativas de Mercado,
mas manter a mesma fonte que a Pt 1 já usa evita reescrever partes do
pipeline que não precisam mudar).

### Consequências

- A Pt 2 passa a ter proveniência de dados mista dentro do mesmo
  `raw_data.R`: uma série pública (via `GetBCBData`), três internas
  (`datalake.utils`/CSVs). Isso é intencional — não um descuido — e reflete
  que só essa série tem equivalente público exato (mesma definição, mesmo
  código SGS) usado pelo próprio post nº46.
- Introduz `GetBCBData` como nova dependência do projeto (pacote R para
  download de séries do SGS).
