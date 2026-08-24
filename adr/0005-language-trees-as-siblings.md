# Both languages under a path prefix, with a dispatcher at the root

## The decision

English moves from the site root to `/en/`. Portuguese stays at `/pt/`. The root
holds no page at all — just a generated `index.html` that sends a bare visit to
`/pt/`, plus redirect stubs standing on the old English addresses.

## Why not just redirect the root and leave the layout alone

That was built first and thrown away. Keeping English at the root while making
Portuguese the default forces the root to answer a question it cannot see the
answer to: this visitor typed the address, versus this visitor just clicked `EN`
from the Portuguese side. Same URL either way. Telling them apart meant carrying a
signal — `localStorage`, plus `?lang=en` on the URL for the browsers where storage
is unavailable — and the whole apparatus existed to patch one asymmetry.

Making the trees siblings deletes the question. A visitor is inside `/en/` or
inside `/pt/`, Quarto resolves every in-tree link relative to the page, so "Home"
from an English page is the English home by construction. No state, no query
string, no script. The root is left with one unconditional job.

## What it costs, and what it does not

The English URLs change: `/blog/x.html` becomes `/en/blog/x.html`. The Portuguese
ones — the links actually shared with people — do not move at all.

Nothing 404s regardless. Every English page keeps a redirect stub at its old
address, generated in `build.ps1` by walking `docs/en` and mirroring the tree.
Hrefs in the stubs are relative, matching the reasoning in
`assets/html/lang-switch.html`: the site should not have to be served from a domain
root. The CV PDFs are copied rather than redirected, because a redirect stub is
HTML and the old link promises a PDF.

The one address that genuinely changes meaning is the bare root. It was the English
home; it is the dispatcher now, and the English home is `/en/`.

## Consequence for the language switch

`assets/html/lang-switch.html` derived the two site roots by stripping `pt/` off
the declared href, which assumed English sat one level above Portuguese. With the
trees as siblings the declared href always points at the other tree's home, and the
pair follows by swapping the last segment. Everything downstream — the
`.pt`-optional slug matching, the language-aware candidate order, the `hreflang`
alternates — is written in terms of those two roots and needed no change.

## Cost accepted

An English-first reader arriving at the bare root lands in Portuguese and has to
click `EN` — deliberate: the audience is mostly Brazilian. Crawlers that execute
JavaScript follow the bounce, so the root will likely consolidate onto `/pt/`; the
root carries `noindex` and a canonical to `/pt/` to say so plainly, and the legacy
stubs carry the same toward `/en/`.
