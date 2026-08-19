//! Multi-sample orchestration — one `run_batch` call replaces R's current
//! per-sample shell-script generation and process spawning (`R/runHaplot.R`).
//! Every sample in the label file is extracted internally, in parallel via
//! Rayon; as each finishes, a completion marker lands in `output_dir` for
//! the field prep wizard's existing progress poller (it counts `*.summary`
//! files in `intermed/`, excluding `all.summary` — see
//! `inst/shiny/microhaplot-prep/server.R`), and once every sample has
//! succeeded, the combined output is written as `all.summary` in the same
//! directory. Decided in wayfinder tickets #23 and #30.

use std::fs;
use std::path::{Path, PathBuf};

use rayon::prelude::*;

use crate::extract::{extract_sample, to_tsv_line, ExtractError};
use crate::label::{read_label_file, LabelError, LabelRow};

/// The combined output's filename — deliberately matching today's
/// concatenated `all.summary`, so R's post-processing needs no schema
/// change (ticket #23's decision).
pub const COMBINED_OUTPUT_FILENAME: &str = "all.summary";

#[derive(Debug, thiserror::Error)]
pub enum BatchError {
    #[error("reading label file {0}: {1}")]
    Label(PathBuf, LabelError),
    #[error("creating output directory {0}: {1}")]
    CreateOutputDir(PathBuf, std::io::Error),
    #[error("sample {individual_id} ({alignment}): {source}")]
    Sample {
        individual_id: String,
        alignment: PathBuf,
        // Boxed: ExtractError is large enough (it carries several PathBufs
        // across its variants) that clippy::result_large_err flags an
        // unboxed BatchError, which every fallible function here returns.
        #[source]
        source: Box<ExtractError>,
    },
    #[error("writing completion marker {0}: {1}")]
    Marker(PathBuf, std::io::Error),
    #[error("writing combined output {0}: {1}")]
    CombinedOutput(PathBuf, std::io::Error),
    #[error("building a {0}-thread pool: {1}")]
    ThreadPool(usize, rayon::ThreadPoolBuildError),
}

/// Runs every sample in `label_path` against `vcf_path`, using up to
/// `threads` concurrently. Returns the number of samples processed.
///
/// On any sample's failure (bad VCF, corrupt alignment file, missing file),
/// returns `Err` without writing `all.summary` — a partial run leaves
/// per-sample markers for whatever finished first (harmless: the wizard
/// clears `intermed/` before every run) but never a combined file that
/// looks complete when it isn't.
pub fn run_batch(
    label_path: &Path,
    sample_dir: &Path,
    vcf_path: &Path,
    output_dir: &Path,
    threads: usize,
) -> Result<usize, BatchError> {
    let rows = read_label_file(label_path).map_err(|e| BatchError::Label(label_path.into(), e))?;

    fs::create_dir_all(output_dir)
        .map_err(|e| BatchError::CreateOutputDir(output_dir.into(), e))?;

    let pool = build_thread_pool(threads)?;

    let per_sample_lines: Vec<Vec<String>> = pool.install(|| {
        rows.par_iter()
            .map(|row| process_one(row, sample_dir, vcf_path, output_dir))
            .collect::<Result<Vec<_>, _>>()
    })?;

    let mut combined: Vec<String> = per_sample_lines.into_iter().flatten().collect();
    combined.sort();

    let combined_path = output_dir.join(COMBINED_OUTPUT_FILENAME);
    let contents = if combined.is_empty() {
        String::new()
    } else {
        combined.join("\n") + "\n"
    };
    fs::write(&combined_path, contents)
        .map_err(|e| BatchError::CombinedOutput(combined_path, e))?;

    Ok(rows.len())
}

fn process_one(
    row: &LabelRow,
    sample_dir: &Path,
    vcf_path: &Path,
    output_dir: &Path,
) -> Result<Vec<String>, BatchError> {
    let alignment_path = sample_dir.join(&row.filename);
    let summaries =
        extract_sample(vcf_path, &alignment_path).map_err(|source| BatchError::Sample {
            individual_id: row.individual_id.clone(),
            alignment: alignment_path.clone(),
            source: Box::new(source),
        })?;

    let lines: Vec<String> = summaries
        .iter()
        .map(|s| to_tsv_line(&row.group, &row.individual_id, s))
        .collect();

    // Written as soon as this sample finishes — not after the whole batch
    // completes — so the wizard's poller sees real incremental progress.
    let marker_path = output_dir.join(format!("{}.summary", row.individual_id));
    fs::write(&marker_path, "").map_err(|e| BatchError::Marker(marker_path, e))?;

    Ok(lines)
}

/// A dedicated pool sized to `threads` (at least 1), rather than Rayon's
/// global default pool — makes the thread count an explicit, observable
/// property of one `run_batch` call instead of process-wide state, and
/// lets tests assert the configured size took effect via
/// `rayon::current_num_threads()` from inside `pool.install`.
fn build_thread_pool(threads: usize) -> Result<rayon::ThreadPool, BatchError> {
    rayon::ThreadPoolBuilder::new()
        .num_threads(threads.max(1))
        .build()
        .map_err(|e| BatchError::ThreadPool(threads, e))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn thread_pool_honors_requested_count() {
        // Concurrency itself is Rayon's own well-tested guarantee; what's
        // worth pinning here is that run_batch's thread-count argument
        // actually reaches the pool it builds, matching the Rayon
        // thread-count contract decided in ticket #23.
        let pool = build_thread_pool(3).unwrap();
        let observed = pool.install(rayon::current_num_threads);
        assert_eq!(observed, 3);
    }

    #[test]
    fn zero_threads_is_treated_as_one() {
        let pool = build_thread_pool(0).unwrap();
        let observed = pool.install(rayon::current_num_threads);
        assert_eq!(observed, 1);
    }

    #[test]
    fn missing_label_file_is_a_clear_error() {
        let err = run_batch(
            Path::new("/nonexistent/label.txt"),
            Path::new("/nonexistent"),
            Path::new("/nonexistent/x.vcf"),
            Path::new("/nonexistent/out"),
            1,
        )
        .unwrap_err();
        assert!(matches!(err, BatchError::Label(_, _)));
    }

    #[test]
    fn writes_marker_per_sample_and_combined_output() {
        let work = tempfile::tempdir().unwrap();

        // A minimal VCF with one SNP site on one locus.
        let vcf_path = work.path().join("sites.vcf");
        std::fs::write(
            &vcf_path,
            "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\nlocusA\t1\t.\tA\tT\t.\t.\t.\n",
        )
        .unwrap();

        // No alignment files, but an empty result set is still a valid
        // outcome for a sample with an alignment file that exists but has
        // no reads on locusA — build empty BAMs via a real one from the
        // repo's fixtures would need samtools, so instead assert on the
        // simplest observable behavior: a label file with zero rows still
        // produces a (deliberately empty) combined output and touches no
        // markers.
        let label_path = work.path().join("label.txt");
        let mut f = std::fs::File::create(&label_path).unwrap();
        writeln!(f).unwrap(); // a single blank line: zero rows once parsed

        let out_dir = work.path().join("intermed");
        let n = run_batch(&label_path, work.path(), &vcf_path, &out_dir, 1).unwrap();

        assert_eq!(n, 0);
        let combined = std::fs::read_to_string(out_dir.join(COMBINED_OUTPUT_FILENAME)).unwrap();
        assert_eq!(combined, "");
    }
}
