//! Golden-fixture regression test for the batch entry point
//! (`run_batch`, ticket #30) — the whole bundled 20-sample sebastes fixture,
//! run through one call, must produce a combined output matching
//! `sebastes-all.summary` once canonicalized (sorted), and a completion
//! marker per sample. Complements `tests/golden.rs`, which exercises the
//! single-sample `extract_sample` this batch orchestration is built on.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use microhaplot_extract::run_batch;

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

fn sorted_lines(path: &Path) -> Vec<String> {
    let contents = fs::read_to_string(path).unwrap_or_else(|e| panic!("reading {path:?}: {e}"));
    let mut lines: Vec<String> = contents.lines().map(str::to_string).collect();
    lines.sort();
    lines
}

/// Converts the BAM tarball's own `sebastes_metadata.tsv` (headered,
/// 4-column: bam_file, individual_id, group, color) into the headerless
/// 3-column label file `run_batch` actually expects — the same shape
/// `build_prep_label_file()` produces in R.
fn write_label_file(metadata_tsv: &Path, dest: &Path) {
    let contents = fs::read_to_string(metadata_tsv).unwrap();
    let label: String = contents
        .lines()
        .skip(1) // header row
        .filter(|l| !l.is_empty())
        .map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            format!("{}\t{}\t{}\n", fields[0], fields[1], fields[2])
        })
        .collect();
    fs::write(dest, label).unwrap();
}

#[test]
fn batch_run_matches_combined_golden_fixture_and_writes_markers() {
    let dest = tempfile::tempdir().unwrap();
    extract_tar_gz(
        &repo_root().join("inst/extdata/sebastes_bam.tar.gz"),
        dest.path(),
    );

    let label_path = dest.path().join("label.txt");
    write_label_file(&dest.path().join("sebastes_metadata.tsv"), &label_path);

    let vcf = dest.path().join("sebastes.vcf");
    let output_dir = dest.path().join("intermed");

    let n = run_batch(&label_path, dest.path(), &vcf, &output_dir, 4)
        .unwrap_or_else(|e| panic!("run_batch failed: {e}"));
    assert_eq!(n, 20, "expected all 20 sebastes samples to be processed");

    let actual = sorted_lines(&output_dir.join("all.summary"));
    let expected = sorted_lines(
        &repo_root().join("tests/testthat/fixtures/hapture-golden/sebastes-all.summary"),
    );
    assert_eq!(actual, expected);

    // One completion marker per sample, alongside the combined output —
    // exactly what the field prep wizard's file-counting poller expects.
    let markers: Vec<String> = fs::read_dir(&output_dir)
        .unwrap()
        .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
        .filter(|name| name.ends_with(".summary") && name != "all.summary")
        .collect();
    assert_eq!(markers.len(), 20, "expected one marker per sample");
}

#[test]
fn batch_run_fails_loudly_on_a_missing_alignment_file() {
    let dest = tempfile::tempdir().unwrap();
    extract_tar_gz(
        &repo_root().join("inst/extdata/sebastes_bam.tar.gz"),
        dest.path(),
    );

    let label_path = dest.path().join("label.txt");
    fs::write(&label_path, "does-not-exist.bam\tghost\tgr\n").unwrap();

    let vcf = dest.path().join("sebastes.vcf");
    let output_dir = dest.path().join("intermed");

    let err = run_batch(&label_path, dest.path(), &vcf, &output_dir, 1).unwrap_err();
    let message = err.to_string();
    assert!(
        message.contains("ghost"),
        "error should name the failing sample: {message}"
    );

    // No combined output should exist for a run that didn't fully succeed.
    assert!(!output_dir.join("all.summary").exists());
}
