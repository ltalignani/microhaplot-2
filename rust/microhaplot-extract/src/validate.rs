//! `validate` subcommand core logic (wayfinder ticket #31) — replaces the
//! field prep wizard's two `samtools` shell-outs (`quickcheck`, `view -H`;
//! see `R/prep_validation.R`'s `.check_bam_integrity()`/`.bam_sq_names()`)
//! with one pass through `rust-htslib`, already linked into this binary.

use std::path::Path;

use rust_htslib::bam::{self, Read as _};

#[derive(Debug, thiserror::Error)]
pub enum ValidateError {
    #[error("opening {0}: {1}")]
    Open(std::path::PathBuf, rust_htslib::errors::Error),
    #[error("{0} appears truncated or corrupted: {1}")]
    Corrupt(std::path::PathBuf, rust_htslib::errors::Error),
}

/// Confirms `path` isn't truncated or corrupted, and returns its `@SQ`
/// reference names in header order.
///
/// A broken BAM fails either at [`bam::Reader::from_path`] (an unparsable
/// header) or partway through the record scan below (an I/O error reading
/// a broken BGZF block). Reading every record is more thorough than
/// `samtools quickcheck`'s own structural-only check (it deliberately
/// skips decoding records to stay fast) — but for what ticket #31 actually
/// asks to be verified against (a known-good BAM, and one truncated to a
/// handful of bytes), both approaches agree on pass/fail, which is the
/// acceptance bar here, not byte-for-byte algorithmic parity with
/// `quickcheck`'s own internals.
pub fn validate_bam(path: &Path) -> Result<Vec<String>, ValidateError> {
    let mut reader =
        bam::Reader::from_path(path).map_err(|e| ValidateError::Open(path.into(), e))?;

    let ref_names: Vec<String> = reader
        .header()
        .target_names()
        .iter()
        .map(|name| String::from_utf8_lossy(name).into_owned())
        .collect();

    let mut record = bam::Record::new();
    while let Some(result) = reader.read(&mut record) {
        result.map_err(|e| ValidateError::Corrupt(path.into(), e))?;
    }

    Ok(ref_names)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read as _, Write as _};
    use std::path::{Path, PathBuf};
    use std::process::Command;

    fn repo_root() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
    }

    fn extract_sebastes_bam(dest: &Path) -> PathBuf {
        let archive = repo_root().join("inst/extdata/sebastes_bam.tar.gz");
        let status = Command::new("tar")
            .args(["xzf"])
            .arg(&archive)
            .args(["-C"])
            .arg(dest)
            .status()
            .expect("failed to invoke `tar`");
        assert!(status.success());
        dest.join("s11.bam")
    }

    #[test]
    fn known_good_bam_passes_and_lists_its_references() {
        let dest = tempfile::tempdir().unwrap();
        let bam = extract_sebastes_bam(dest.path());

        let refs = validate_bam(&bam).unwrap();

        // Every read in the sebastes fixture lands on one of these 8 loci
        // (see tests/testthat/fixtures/hapture-golden/README.md); s11.bam's
        // own @SQ header carries this exact set, in this exact order.
        assert_eq!(
            refs,
            vec![
                "tag_id_2301",
                "tag_id_843",
                "tag_id_1836",
                "tag_id_1994",
                "tag_id_1999",
                "tag_id_879",
                "tag_id_55",
                "tag_id_2155",
            ]
        );
    }

    #[test]
    fn truncated_bam_fails() {
        let dest = tempfile::tempdir().unwrap();
        let good_bam = extract_sebastes_bam(dest.path());

        // Same idiom tests/testthat/test-validate-prep-inputs.R already
        // uses for its own "truncated BAM" fixture: truncate a real file
        // to its first 200 bytes.
        let mut buf = Vec::new();
        std::fs::File::open(&good_bam)
            .unwrap()
            .read_to_end(&mut buf)
            .unwrap();
        buf.truncate(200);

        let truncated_path = dest.path().join("truncated.bam");
        std::fs::File::create(&truncated_path)
            .unwrap()
            .write_all(&buf)
            .unwrap();

        let err = validate_bam(&truncated_path).unwrap_err();
        assert!(matches!(
            err,
            ValidateError::Open(_, _) | ValidateError::Corrupt(_, _)
        ));
    }

    #[test]
    fn missing_file_is_an_open_error() {
        let err = validate_bam(Path::new("/no/such/file.bam")).unwrap_err();
        assert!(matches!(err, ValidateError::Open(_, _)));
    }
}
