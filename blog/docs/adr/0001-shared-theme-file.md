# Shared, sourced theme file instead of per-post inline styling

Every blog post's data-collection code is deliberately kept self-contained — no dependency
on the author's private infra — so a reader can copy a `.qmd` and reproduce it standalone
(see the note in `0001-kalman-filter-pt1-nairu.qmd` about `datalake.utils`). Chart styling
breaks that pattern on purpose: `R/theme_blog.R` lives once in `blog/R/` and every post
`source()`s it, rather than pasting the same `theme_blog()`/palette code into each `.qmd`.
The trade-off was made explicitly: consistency across posts (and one place to evolve the
palette) was judged more valuable than each post being trivially copy-paste-runnable in
isolation. A reader who wants only the data/model code, not the exact visual styling, can
skip the `source()` line and use `theme_minimal()` instead — the charts will render, just
without the blog's house style.
