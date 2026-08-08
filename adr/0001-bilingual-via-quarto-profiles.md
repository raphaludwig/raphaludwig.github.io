# Bilingual site via two Quarto profiles, assembled by build.ps1

ADRs live in `adr/` rather than the conventional `docs/adr/` because `docs/` is
Quarto's published output directory and is wiped on every build.

## The decision

The site is built twice — once per language profile — and the two outputs are
assembled into `docs/` by `build.ps1`. The alternative was a single build plus
client-side JavaScript swapping marked-up strings. Profiles won because most of the
translatable text is chrome Quarto generates itself (search widget, TOC title, date
formats), which `lang: pt` translates for free and which a DOM-rewriting script
handles worst. The cost is a build step and a doubled `docs/`.

## Why there is an `en` profile and not just a base config

Quarto profile merging **concatenates** arrays rather than replacing them: a
`navbar.left` declared in both `_quarto.yml` and `_quarto-pt.yml` renders as
`Home, Blog, Início, Blog`. So every list that differs by language has to live in a
profile and *only* in a profile — which means English needs one too. Consequence:
a bare `quarto render` produces a site with no navbar at all, and `build.ps1` always
passes an explicit `--profile`.

## Why the profiles stage into `_site-en` / `_site-pt` first

Rendering English directly into `docs/` and Portuguese into `docs/pt/` does not
work: the English render deletes `docs/pt/`. Verified, not assumed.

## Why the blog index is two files but the home page is one

`listing:` is front matter, and front matter is not profile-aware, so a page whose
listing must differ by language has to either carry two listings or exist twice.

Two listings on one page is the cheaper option, but it has two traps. First, a
listing whose target div is removed by the `when-profile` filter is *not* dropped —
Quarto appends it to the end of the page instead. So the divs must survive and be
hidden with CSS (`.lang-en-only` / `.lang-pt-only`, keyed off `lang`), never removed.
Second, and fatally for the blog index: two listings on a page share a single
category filter widget, whose counts then aggregate across both — "All (4)" above two
visible posts. There is no way to scope the widget to one listing.

So the blog index exists twice (`index.qmd` / `index-pt.qmd`, the latter with
`output-file: index.html`), selected by each profile's `render:` list. The home page
has no category widget, so it keeps the cheaper two-listing form.

## Two Quarto behaviours build.ps1 has to compensate for

Both were found by `quarto preview` failing where `quarto render` succeeded.

A `.qmd` excluded from a profile's `render:` list is not ignored — Quarto reclassifies
it as a **resource** and copies the *source file* into that profile's output. Moved
into `docs/`, it becomes a stray input on the next run, and its `../assets/` includes
no longer resolve from that depth, killing the build with `unable to open file
../assets/html/particles-embed.html`. `build.ps1` deletes any `.qmd` from `docs/`.

`quarto preview` **ignores those `!` exclusions** and renders both twins. That is
harmless on its own, but fatal if both declare the same `output-file` — they collide
on rename. So `index-pt.qmd` keeps its own output name and `build.ps1` renames it,
rewriting the references baked into `search.json`, `sitemap.xml`, `listings.json` and
the canonical links. For the same reason the Portuguese navbar and "Ver mais" link
point at `blog/index-pt.qmd`: Quarto only rewrites `.qmd` → `.html` for files it
renders in the active profile, and would otherwise emit the raw source path.

## Why the language switch resolves counterparts in JavaScript

The switch ships as an ordinary navbar link with a static href to the other
version's home, so it works without JavaScript. A script then upgrades it to the
current page's counterpart by reading the other version's `search.json`. The
matching is on the slug with `.pt` optional — deliberately *not* on the numeric
prefix, which is a series number here and is shared by every part of a multi-post
series.

Both profiles render every post, so each tree contains both language files and a
counterpart lookup that merely checks existence would find the wrong one. The
candidate order is therefore language-aware: going to Portuguese prefers `.pt.html`,
going to English prefers `.html`, and the other is the untranslated placeholder.

The same script emits the `hreflang` alternates, since it is what knows the mapping.
They are therefore JavaScript-injected, not static — Googlebot renders and will see
them, but crawlers that do not execute JavaScript will not. Making them static would
mean computing each page's counterpart at build time, which no Quarto hook offers
cheaply.
