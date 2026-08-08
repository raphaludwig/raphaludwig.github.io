# Builds both language versions of the site into docs/.
#
# Run this instead of `quarto render`. A bare `quarto render` has no profile and
# would produce a site with no navbar at all — every navbar/footer key lives in
# _quarto-en.yml / _quarto-pt.yml, because Quarto profiles CONCATENATE arrays
# rather than replacing them, so those keys cannot sit in the shared base.
#
# Layout produced:
#   docs/         English (the native version)
#   docs/pt/      Portuguese
#
# docs/ is wiped and rebuilt each time so that files deleted from the source do
# not linger in the published site. The staging dirs (_site-en, _site-pt) are
# gitignored.

Set-Location $PSScriptRoot

foreach ($d in "_site-en", "_site-pt", "docs") {
    if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction Stop }
}

# Deliberately NOT $ErrorActionPreference = "Stop" around the quarto calls. In
# Windows PowerShell 5.1 that turns anything a native executable writes to stderr
# into a terminating error — so a harmless Quarto warning would abort the build
# even though quarto exited 0. The exit code is the only reliable signal.
Write-Host "==> Rendering English" -ForegroundColor Cyan
quarto render --profile en
if ($LASTEXITCODE -ne 0) { throw "English render failed (exit $LASTEXITCODE)" }

Write-Host "==> Rendering Portuguese" -ForegroundColor Cyan
quarto render --profile pt
if ($LASTEXITCODE -ne 0) { throw "Portuguese render failed (exit $LASTEXITCODE)" }

Write-Host "==> Assembling docs/" -ForegroundColor Cyan

# blog/index-pt.qmd is the Portuguese twin of blog/index.qmd and renders to
# blog/index-pt.html. It cannot declare `output-file: index.html` — two sources
# aiming at one output crashes `quarto preview` (see the note in that file) — so
# it is moved into place here.
if (Test-Path _site-pt\blog\index-pt.html) {
    Move-Item _site-pt\blog\index-pt.html _site-pt\blog\index.html -Force -ErrorAction Stop
    # The name is baked into the generated metadata (search index, sitemap,
    # listings) and into each page's canonical link, so those have to follow the
    # rename or PT search sends people to a 404.
    Get-ChildItem _site-pt -Recurse -Include *.html, *.json, *.xml |
        ForEach-Object {
            $t = [IO.File]::ReadAllText($_.FullName)
            if ($t.Contains("index-pt.html")) {
                [IO.File]::WriteAllText($_.FullName, $t.Replace("index-pt.html", "index.html"))
            }
        }
}
# Defensive: under `preview` (not `render`) Quarto ignores the profile's render
# exclusions, so the wrong language's twin can appear in a tree.
Remove-Item _site-en\blog\index-pt.html -ErrorAction SilentlyContinue

Move-Item _site-en docs -ErrorAction Stop
Move-Item _site-pt docs\pt -ErrorAction Stop

# Quarto treats a .qmd excluded from a profile's `render:` list as a *resource*
# and copies the source file into that profile's output — so blog/index.qmd lands
# in the pt tree and blog/index-pt.qmd in the en one. Left in place they end up
# inside docs/, where the next render/preview discovers them as stray inputs whose
# ../assets/ includes no longer resolve from that depth, and the build dies with
# "unable to open file ../assets/html/particles-embed.html". Drop them here: docs/
# is published HTML, no .qmd belongs in it either way.
$strays = Get-ChildItem docs -Recurse -Filter *.qmd -ErrorAction SilentlyContinue
if ($strays) {
    $strays | Remove-Item -Force
    Write-Host "    removed $($strays.Count) stray .qmd from docs/" -ForegroundColor DarkGray
}

# .nojekyll tells GitHub Pages to serve site_libs/ (directories starting with an
# underscore are otherwise dropped). It is listed under resources: so Quarto
# copies it, but only the root copy matters.
if (-not (Test-Path docs\.nojekyll)) { New-Item -ItemType File docs\.nojekyll | Out-Null }

Write-Host "==> Done. docs/ rebuilt (en at root, pt under docs/pt)." -ForegroundColor Green
