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

Em `blog/notes/`, um arquivo por post: tudo que é **daquele post só**. Isso inclui
duas coisas de vidas diferentes, e está tudo bem que dividam o arquivo —

- nota de trabalho, que morre quando o post é publicado (estado, como retomar,
  pendências);
- decisão de **modelagem**, que não morre: justifica código que está no ar, como
  o post de Kalman construir o modelo bssm nativamente em vez de usar `as_bssm()`.

Material que o autor **não** escreveu (papers, PDFs, código de referência) e
exploração descartável não entram no repo — ficam na pasta do tema em
`G:\My Drive\knowledge\`.
