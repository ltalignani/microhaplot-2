//! Library crate for `microhaplot-extract` — the Rust replacement for
//! `hapture.pl` (wayfinder map #18). Exposes the extraction algorithm as a
//! reusable library; the `main.rs` binary target wires a CLI on top (see
//! ticket #30 for the multi-sample batch orchestration that will drive it).

pub mod cigar;
pub mod extract;
pub mod format;
pub mod vcf;

pub use extract::{extract_sample, to_tsv_line, ExtractError, HaplotypeSummary};
