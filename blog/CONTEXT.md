# Blog graphics

Conventions for every ggplot2 chart published on the blog, implemented in `R/theme_blog.R`
and applied via `theme_blog()`, `pal_blog()`, `accent_blog()`, `scale_color_blog()`,
`scale_fill_blog()`, `scale_x_date_blog()`, `caption_blog()`.

## Language

**Tier**:
One of the three named slices of the green-slate palette (`pal_blog(tier = ...)`):
`main` (1-2 series, close tones), `contrast` (2-3 series, maximally distinct within the
green-slate family), `extended` (3+ series, full 5-tone ramp).
_Avoid_: "palette" alone (ambiguous between a tier and the whole green-slate family).

**Accent**:
The single highlight hue reserved for elements *outside* the green-slate family —
bars, saldo/balance series, a prior-vs-posterior reference line, anything meant to read as
"not one of the main series." Not a tier. Has two tones, chosen via `accent_blog(tone = ...)`:
`cool` (plum/wine, `#7a3b4a`, default) and `warm` (terracotta, `#b5654a`, deliberate
alternative — e.g. when cool is already in use elsewhere in the same chart).
_Avoid_: "contrast" (that name is taken by the tier above; accent is a separate concept).

**Green-slate family**:
The five anchor tones every tier is built from — `slate_darkest` (`#2f3e46`), `slate_dark`
(`#3f5f56`), `slate_mid` (`#52796f`), `sage_light` (`#84a98c`), `sage_pale` (`#cad2c5`).
Sourced from the site's own palette (`assets/css/theme.scss` — `--pal-text`, `--pal-accent`).
