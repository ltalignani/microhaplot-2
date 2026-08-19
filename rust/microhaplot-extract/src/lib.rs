//! Library crate for `microhaplot-extract` — the Rust replacement for
//! `hapture.pl` (wayfinder map #18). Exposes the extraction algorithm and
//! the multi-sample batch orchestration built on it as a reusable library;
//! `main.rs` wires a CLI on top (ticket #30).

pub mod batch;
pub mod cigar;
pub mod extract;
pub mod format;
pub mod label;
pub mod validate;
pub mod vcf;

pub use batch::{run_batch, BatchError};
pub use extract::{extract_sample, to_tsv_line, ExtractError, HaplotypeSummary};
pub use label::{read_label_file, LabelError, LabelRow};
pub use validate::{validate_bam, ValidateError};
