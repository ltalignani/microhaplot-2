#!/usr/bin/env bash
# Builds a deliberately large batch under ./microhaplot-data, by replicating
# the sebastes demo BAMs under fresh individual IDs.
#
# Its only purpose is the step 4 screenshot in the "Extracting haplotypes with
# Docker" vignette: on the 20-sample demo the extraction finishes before the
# progress bar (which polls every 300 ms) has rendered at all, so there is
# nothing to photograph. A few hundred samples make the bar observable, and
# also show what a real field campaign actually looks like on that screen.
#
# This is scratch data for documentation, not a fixture: it lives in the
# gitignored ./microhaplot-data and is not shipped with the package.
#
#   scripts/make-big-batch.sh [copies]     # default 10 -> 200 samples
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

copies=${1:-10}
src=microhaplot-data/sebastes-demo
dest=microhaplot-data/big-batch

if [ ! -d "$src" ]; then
  echo "unpack sebastes_bam.tar.gz into $src first" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest"
cp "$src/sebastes.vcf" "$dest/"

printf 'bam_file\tindividual_id\tgroup\tcolor\n' > "$dest/big_metadata.tsv"

for rep in $(seq 1 "$copies"); do
  while IFS=$'\t' read -r bam id group colour; do
    [ "$bam" = "bam_file" ] && continue
    new_bam="r${rep}_${bam}"
    cp "$src/$bam" "$dest/$new_bam"
    printf '%s\tr%s_%s\t%s\t%s\n' "$new_bam" "$rep" "$id" "$group" "$colour" \
      >> "$dest/big_metadata.tsv"
  done < "$src/sebastes_metadata.tsv"
done

n=$(($(wc -l < "$dest/big_metadata.tsv") - 1))
echo "wrote $dest with $n samples"
