# Site

A bilingual personal site: an English version at the root and a Portuguese version
under `/pt/`, both generated from one set of source files.

## Language

**Profile**:
One of the two Quarto profiles, `en` or `pt`, each declared in its own
`_quarto-<profile>.yml`. A profile is the unit that decides everything that differs
between the two versions of the site — output directory, `lang`, navbar, footer,
site description. Neither is the default: a render without an explicit profile is
always a mistake.
_Avoid_: "locale", "translation" (a profile is the configuration, not the text).

**Native version**:
The English version. It lives at the site root and is the one a visitor with no
prior choice lands on. Portuguese is reached only by an explicit act — clicking the
language switch — never by auto-detection.
_Avoid_: "default language" (Quarto uses `lang` for something narrower).

**Language switch**:
The navbar control that moves a visitor to the same page in the other version. It
names its *destination*, not the current version — `PT` on the English site, `EN`
on the Portuguese one.
_Avoid_: "language toggle", "locale picker".

**Counterpart**:
The other version of the page a visitor is currently on — what the language switch
navigates to. A page's counterpart is found by slug, treating the `.pt` suffix as
optional, so it survives a post being translated (which changes the filename).
Where no counterpart exists, the blog index of the other version stands in.
_Avoid_: "mirror", "alternate" (the latter is the HTML `rel`, not the concept).

## Posts

**Language marker**:
A front-matter key on a post saying that its counterpart in the other language now
exists, so the listing on that side should stop showing this file: `en-version:
true` on a Portuguese post, `pt-version: true` on an English one. An unmarked post
appears in *both* listings — which is the intended state for a post that has not
been translated yet.
_Avoid_: "language flag", "hidden" (a marked post is still rendered and reachable;
only the listing drops it).

**Placeholder**:
A Portuguese post standing in for its untranslated English counterpart. It is not a
separate file — the same `.pt.qmd` is rendered into both versions of the site, so a
placeholder is a *situation*, not an artifact. It stops being one the moment the
English file is written and the language markers are added.
_Avoid_: "stub", "draft" (`draft:` is a real and different Quarto key).
