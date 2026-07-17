# Chunk-level knitr defaults (device, fig-width) live in theme_blog.R

`theme_blog.R` registers a "Segoe UI Semibold" font variant via `systemfonts::register_variant()`
so `theme_blog()` can reference a semibold weight that isn't its own family in Windows'
font database. That registration is only honored by graphics devices that consult
systemfonts (`ragg`, `svglite`) — Quarto's default `grDevices::png` device doesn't know
about it, and warns "font family not found in Windows font database" on every text draw.

The fix — `knitr::opts_chunk$set(dev = "ragg_png", fig.width = 9)` — is a document-level
knitr option, not a ggplot theme setting, and could instead have lived in the project
`_quarto.yml` under `execute`/`knitr` defaults, decoupled from the R code entirely. We put
it in `theme_blog.R` anyway: every post already `source()`s this file as its one required
step for blog chart styling (see `0001-shared-theme-file.md`), so bundling the device fix
and the wider default `fig.width` (7in → 9in, closer to the 900px `grid.body-width`) here
means a post gets correct rendering automatically from that same `source()` line, with no
second place to remember to configure. The trade-off: `theme_blog.R` is no longer "just
ggplot theme functions" — sourcing it now has document-wide side effects on chunk
defaults, which a reader skimming only the function definitions could miss.
