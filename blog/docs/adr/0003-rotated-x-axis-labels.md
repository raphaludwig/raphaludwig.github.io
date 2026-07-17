# Blog time-series charts rotate x-axis labels 90°

`scale_x_date_blog()` always places its last break at `max(date_col)`, so the rightmost
tick is the most recent data point available — matching the convention already used in
the private macro-pipelines graphs this blog's chart style is based on. With horizontal
axis text (theme_minimal's default, inherited by `theme_blog()` until now), that last
label's text runs past the tick itself and can bleed past the panel's right edge, since
`scale_x_date_blog()`'s expansion is deliberately tight (`mult = 0.01`) and nothing
reserved extra margin for it. This showed up concretely in the NAIRU chart
(`0001-kalman-filter-pt1-nairu.qmd`): the "Nov 24" label clipped against the plot boundary.

The alternative was to keep labels horizontal and instead widen the right expansion
and/or plot margin to leave room for the last label's width. That fix is fragile: the
margin needed depends on the label's text length and the plot's rendered width, both of
which vary per chart and per `fig.width`, so a value tuned for one post could reintroduce
clipping in another.

We instead set `axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)` in
`theme_blog()`, matching the reference pipeline's own convention. A rotated label's
horizontal footprint is just its font size, not its string length, so it structurally
cannot overflow the panel horizontally regardless of break count, label date format, or
plot width. This applies to every time-series chart on the blog, not just this one — the
trade-off is rotated date labels are marginally less readable at a glance than horizontal
ones, accepted for the guarantee against edge clipping.
