# Architecture decision records

One numbered series for the whole repo — site infrastructure and blog conventions
alike. They used to be two series (`adr/` and `blog/docs/adr/`), which produced two
different documents both called "ADR 0001"; merged on 2026-08-11.

| # | escopo | assunto |
|---|---|---|
| [0001](0001-bilingual-via-quarto-profiles.md) | site | site bilíngue via dois perfis do Quarto, montado pelo `build.ps1` |
| [0002](0002-shared-theme-file.md) | blog | `theme_blog.R` compartilhado em vez de estilo inline por post |
| [0003](0003-ragg-png-device-and-fig-width-defaults.md) | blog | defaults de chunk (`dev = "ragg_png"`, `fig.width`) moram no `theme_blog.R` |
| [0004](0004-rotated-x-axis-labels.md) | blog | eixo X de data rotacionado 90° |

ADRs ficam em `adr/` e não no convencional `docs/adr/` porque `docs/` é o diretório
de saída publicado do Quarto e é apagado a cada build — ver 0001.

## O que vai aqui e o que vai em `blog/notes/`

Aqui: decisão **perene, que vale para mais de um post** — infra do site ou convenção
do blog, sempre com razão e trade-off.

Em `blog/notes/`, **uma pasta por post**: tudo que é daquele post só. Dentro dela
convivem duas coisas de vidas diferentes e, desde 17/08/2026, em arquivos
separados — porque só uma das duas merece ser versionada:

| arquivo | o que é | versionado? |
|---|---|---|
| `nota.md` | nota de trabalho: estado, como retomar, pendências. Morre quando o post é publicado. | **não** (`.gitignore`) |
| `adr-NNNN-*.md` | decisão de **modelagem**, que não morre: justifica código que está no ar. | **sim** |

O ADR precisa ser legível por terceiros — é o gênero dele —, enquanto a nota de
trabalho é rascunho endereçado à próxima sessão e envelhece mal em público.

**A numeração dos ADRs de post recomeça em `0001` dentro de cada pasta** e é
independente da série da raiz. `adr/0001` (site bilíngue) e
`blog/notes/0002-ajuste-sazonal-credito/adr-0001` (usar `rjd3` em vez de
`RJDemetra`) são documentos diferentes, e isso é intencional: a série da raiz é do
repositório, a de cada pasta é do post.

Existentes:

| post | ADR |
|---|---|
| 0001 (Kalman / NAIRU) | [decisões de modelagem](../blog/notes/0001-kalman-filter/adr-0001-decisoes-de-modelagem.md) — bssm nativo em vez de `as_bssm()`, estimação em estágio único, fonte pública do EX3 Serviços |
| 0002 (ajuste sazonal / crédito) | [usar a família `rjd3`](../blog/notes/0002-ajuste-sazonal-credito/adr-0001-rjd3-sobre-rjdemetra.md) — EOL do JDemetra+ 2.x em dez/2026 |

Material que o autor **não** escreveu (papers, PDFs, código de referência) e
exploração descartável não entram no repo — ficam na pasta do tema em
`G:\My Drive\knowledge\`.
