//! Golden-fixture regression tests — `microhaplot_extract::extract_sample`'s
//! output, canonicalized (sorted), must match the recorded output of
//! `inst/perl/hapture` in `tests/testthat/fixtures/hapture-golden/` (see
//! that directory's own README.md for how the fixtures were captured and
//! why row order isn't part of the behavior being pinned).
//!
//! `extract_sample` only reads BAM (see `extract.rs`'s doc comment for
//! why), so these tests run against the BAM fixtures — `sebastes_bam.tar.gz`
//! and `edge-cases.bam` — even though the golden `.summary` files were
//! captured against `hapture`'s SAM input; `hapture.pl`'s own per-read
//! logic doesn't care which format fed it (SAM/BAM parity was verified by
//! hand while resolving wayfinder ticket #29), so the `.summary` files
//! remain a valid oracle for BAM input too.
//!
//! These tests extract the repo's bundled tarballs at run time via the
//! `tar` binary rather than adding a tar-handling crate dependency — this
//! crate only ever needs to *read* BAM/VCF, never archives.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use microhaplot_extract::{extract_sample, to_tsv_line};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn extract_tar_gz(archive: &Path, dest: &Path) {
    let status = Command::new("tar")
        .args(["xzf"])
        .arg(archive)
        .args(["-C"])
        .arg(dest)
        .status()
        .expect("failed to invoke `tar` — required to unpack test fixtures");
    assert!(status.success(), "tar extraction of {archive:?} failed");
}

/// Sorted, non-empty lines — the same canonicalization
/// `capture-golden-fixtures.sh` applies before writing each fixture.
fn sorted_lines(path: &Path) -> Vec<String> {
    let contents = fs::read_to_string(path).unwrap_or_else(|e| panic!("reading {path:?}: {e}"));
    let mut lines: Vec<String> = contents.lines().map(str::to_string).collect();
    lines.sort();
    lines
}

/// Parses `sebastes_metadata.tsv` (the BAM tarball's own label file) into
/// `sample_id -> group`, ignoring the file-name and color columns this
/// test doesn't need.
fn read_group_map(path: &Path) -> HashMap<String, String> {
    let contents = fs::read_to_string(path).unwrap_or_else(|e| panic!("reading {path:?}: {e}"));
    contents
        .lines()
        .skip(1) // header row
        .filter(|l| !l.is_empty())
        .map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            (fields[1].to_string(), fields[2].to_string())
        })
        .collect()
}

fn extract_and_render(vcf: &Path, bam: &Path, group: &str, id: &str) -> Vec<String> {
    let rows = extract_sample(vcf, bam)
        .unwrap_or_else(|e| panic!("extract_sample({vcf:?}, {bam:?}): {e}"));
    let mut lines: Vec<String> = rows.iter().map(|r| to_tsv_line(group, id, r)).collect();
    lines.sort();
    lines
}

#[test]
fn sebastes_per_sample_matches_golden_fixtures() {
    let dest = tempfile::tempdir().unwrap();
    extract_tar_gz(
        &repo_root().join("inst/extdata/sebastes_bam.tar.gz"),
        dest.path(),
    );

    let vcf = dest.path().join("sebastes.vcf");
    let groups = read_group_map(&dest.path().join("sebastes_metadata.tsv"));
    assert_eq!(groups.len(), 20, "expected all 20 sebastes samples");

    for (id, group) in &groups {
        let bam = dest.path().join(format!("{id}.bam"));
        let actual = extract_and_render(&vcf, &bam, group, id);

        let golden = repo_root().join(format!(
            "tests/testthat/fixtures/hapture-golden/sebastes-per-sample/{id}.summary"
        ));
        let expected = sorted_lines(&golden);

        assert_eq!(
            actual, expected,
            "sample {id} diverges from its golden fixture"
        );
    }
}

#[test]
fn sebastes_combined_matches_golden_fixture() {
    let dest = tempfile::tempdir().unwrap();
    extract_tar_gz(
        &repo_root().join("inst/extdata/sebastes_bam.tar.gz"),
        dest.path(),
    );

    let vcf = dest.path().join("sebastes.vcf");
    let groups = read_group_map(&dest.path().join("sebastes_metadata.tsv"));

    let mut actual: Vec<String> = groups
        .iter()
        .flat_map(|(id, group)| {
            let bam = dest.path().join(format!("{id}.bam"));
            extract_and_render(&vcf, &bam, group, id)
        })
        .collect();
    actual.sort();

    let expected = sorted_lines(
        &repo_root().join("tests/testthat/fixtures/hapture-golden/sebastes-all.summary"),
    );
    assert_eq!(actual, expected);
}

#[test]
fn edge_cases_produce_no_output() {
    let dest = tempfile::tempdir().unwrap();
    extract_tar_gz(
        &repo_root().join("inst/extdata/sebastes_bam.tar.gz"),
        dest.path(),
    );
    let vcf = dest.path().join("sebastes.vcf");
    let edge_bam = repo_root().join("tests/testthat/fixtures/hapture-golden/edge-cases.bam");

    // A secondary-alignment read (SAM flag 256) and a 1-base query read —
    // both must be filtered outright before contributing a haplotype.
    let actual = extract_and_render(&vcf, &edge_bam, "edge", "edge");
    let expected = sorted_lines(
        &repo_root().join("tests/testthat/fixtures/hapture-golden/edge-cases.summary"),
    );
    assert!(expected.is_empty(), "golden fixture itself should be empty");
    assert_eq!(actual, expected);
}
