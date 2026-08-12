#!/usr/bin/env bash
# Builds the pkgdown site, then removes the pages that should never be
# published.
#
# Use this instead of calling pkgdown::build_site() directly. pkgdown renders
# every Markdown file it finds in the package root, including CLAUDE.md —
# agent instructions that are deliberately kept out of the repository
# (.gitignore) and have no business on a public documentation site. There is
# no pkgdown setting to exclude them, and .Rbuildignore does not apply, so
# they are stripped here afterwards.
#
#   scripts/build-site.sh
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

# Root-level Markdown that pkgdown will render but which must not ship.
private_pages=("CLAUDE")

Rscript -e 'pkgdown::build_site(preview = FALSE, install = TRUE)'

for page in "${private_pages[@]}"; do
  if [ -f "docs/${page}.html" ]; then
    rm -f "docs/${page}.html"
    echo "removed docs/${page}.html"
  fi
  # ...and its sitemap entry, so the published sitemap doesn't advertise a 404.
  if [ -f docs/sitemap.xml ]; then
    tmp=$(mktemp)
    grep -v "/${page}\.html</loc>" docs/sitemap.xml > "$tmp"
    mv "$tmp" docs/sitemap.xml
  fi
done

echo
echo "site built in docs/"
if grep -rl "CLAUDE" docs/ >/dev/null 2>&1; then
  echo "warning: 'CLAUDE' still appears somewhere under docs/" >&2
  grep -rl "CLAUDE" docs/ >&2
else
  echo "no trace of CLAUDE.md in the output"
fi
