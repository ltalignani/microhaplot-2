#!/usr/bin/env bash
# Regenerates this directory's golden fixtures — the recorded output of
# TODAY's inst/perl/hapture (the fatpacked binary prepHaplotFiles() actually
# invokes, not the raw hapture.pl source) on known inputs.
#
# These files are the regression oracle for the Perl->Rust portage
# (wayfinder map #18): microhaplot-extract's output, canonicalized the same
# way, must match them exactly. Do NOT re-run this script to "refresh" the
# fixtures after changing hapture.pl's behavior — that would defeat their
# purpose. It exists for provenance: to show exactly how they were produced,
# and to let someone regenerate them from scratch if they're ever lost.
#
# Perl's hash key iteration order is randomized per-process (confirmed:
# running hapture twice on the same input gives the same set of rows in a
# different order each time), so hapture's output order is NOT part of its
# behavior worth pinning — only its content is. Every fixture here is sorted
# before being written, and any future comparison must sort its own output
# the same way before diffing against these files. (group, individual,
# locus, haplotype) was confirmed unique across the full sebastes fixture,
# so a plain whole-line `sort` is a well-defined canonicalization.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
fixture_dir="$repo_root/tests/testthat/fixtures/hapture-golden"
hapture="$repo_root/inst/perl/hapture"

command -v perl >/dev/null || { echo "perl is required" >&2; exit 1; }
[ -x "$hapture" ] || [ -f "$hapture" ] || { echo "missing $hapture" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/hapture-golden.XXXXXX")
trap 'rm -rf "$work"' EXIT

echo "perl: $(perl -e 'print $];')"

# ---- sebastes: the bundled 20-sample fixture, full coverage -----------------
# Chosen because it already exercises, with no synthetic input needed:
#   - plain SNP resolution (the bulk of the output)
#   - N marking: a variant position beyond a read's aligned reference span
#   - X marking: a deletion overlapping a variant site
#   - VCF filtering of the 2 multi-allelic and 2 indel sites out of 56 total
# Confirmed by inspection before writing this script; see the ticket's
# resolution comment for the exact counts.
tar xzf "$repo_root/inst/extdata/sebastes_sam.tar.gz" -C "$work"
mkdir -p "$fixture_dir/sebastes-per-sample"
: > "$fixture_dir/sebastes-all.summary"

while IFS=$'\t' read -r sam id group; do
  [ -z "$sam" ] && continue
  out="$fixture_dir/sebastes-per-sample/${id}.summary"
  perl "$hapture" -v "$work/sebastes.vcf" -s "$work/$sam" -i "$id" -g "$group" \
    | sort > "$out"
  cat "$out" >> "$fixture_dir/sebastes-all.summary.tmp"
done < "$work/label.txt"

sort "$fixture_dir/sebastes-all.summary.tmp" > "$fixture_dir/sebastes-all.summary"
rm -f "$fixture_dir/sebastes-all.summary.tmp"

# ---- edge-cases: pathological input real sequencing data doesn't produce ---
# edge-cases.sam is hand-built, not generated here — see its own contents:
#   - a secondary-alignment read (flag 256, SAM bit 0x100), which must be
#     skipped outright (hapture.pl: `next if $lines[1] >= 256`)
#   - a 1-base query read, which must be skipped outright
#     (hapture.pl: `next if $#qseq < 1`)
# Expected output: empty. Both reads are filtered before either could
# contribute a haplotype.
perl "$hapture" -v "$work/sebastes.vcf" -s "$fixture_dir/edge-cases.sam" \
  -i edge -g edge | sort > "$fixture_dir/edge-cases.summary"

echo "wrote sebastes-all.summary ($(wc -l < "$fixture_dir/sebastes-all.summary") rows)"
echo "wrote sebastes-per-sample/ (20 files)"
echo "wrote edge-cases.summary ($(wc -l < "$fixture_dir/edge-cases.summary") rows, expect 0)"
