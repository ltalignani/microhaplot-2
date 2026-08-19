//! The per-read extraction algorithm itself — a direct port of
//! `hapture.pl`'s SAM-processing loop (see `inst/perl/hapture.pl` in this
//! repo), reading through `rust-htslib`'s `bam::Reader`.
//!
//! BAM only, deliberately: `hapture.pl` itself just tab-splits SAM text and
//! never needs a header (it reads `RNAME` as opaque text off column 3), but
//! rust-htslib's SAM reader refuses input with no `@SQ` header lines at all
//! — which real production SAM/BAM both have, but hand-built pathological
//! fixtures don't always. Rather than hand-roll a second, header-tolerant
//! text parser to preserve input `hapture.pl` accepted only as an accident
//! of its own lack of validation, `microhaplot-extract` reads BAM
//! exclusively — the format `prepHaplotFiles()`'s wizard already requires
//! upstream (see `scripts/make-bam-fixture.sh`'s own header) and the one
//! rust-htslib decodes natively, without a `samtools view -h |` shell pipe.

use std::collections::BTreeMap;
use std::path::Path;

use rust_htslib::bam::{self, Read as _};

use crate::cigar::{reference_length, rpos_to_qpos};
use crate::vcf::load_snp_sites;

/// Placeholder Phred quality `hapture.pl` uses for a position it marks `N`
/// or `X` — the ASCII character `_` (`ord('_') == 95`), giving a quality
/// score of `95 - 33 == 62`. Not a real base call; a quirk of the original
/// script kept intentionally, not "fixed", for exact output parity.
const PLACEHOLDER_QUALITY: f64 = 62.0;

#[derive(Debug, thiserror::Error)]
pub enum ExtractError {
    #[error("reading VCF {0}: {1}")]
    Vcf(std::path::PathBuf, std::io::Error),
    #[error("opening alignment file {0}: {1}")]
    OpenAlignment(std::path::PathBuf, rust_htslib::errors::Error),
    #[error("reading a record from {0}: {1}")]
    ReadRecord(std::path::PathBuf, rust_htslib::errors::Error),
}

/// One (locus, haplotype) row of output — the same grain of aggregation
/// `hapture.pl` produces, minus the group/individual labels, which the
/// caller already knows and which this pure extraction step has no need
/// to carry.
#[derive(Debug, Clone, PartialEq)]
pub struct HaplotypeSummary {
    pub locus: String,
    pub haplotype: String,
    pub count: u32,
    /// Sum, across every read with this exact haplotype, of `1 - error_prob`
    /// at each variant position (in the same order as the VCF's positions
    /// for this locus). `hapture.pl`'s `sC`.
    pub sum_prob: Vec<f64>,
    /// The maximum `1 - error_prob` seen at each position, across the same
    /// reads. `hapture.pl`'s `maxC`.
    pub max_prob: Vec<f64>,
}

#[derive(Default)]
struct Aggregate {
    count: u32,
    sum_prob: Vec<f64>,
    max_prob: Vec<f64>,
}

/// Extracts haplotypes for a single sample: one VCF, one BAM alignment
/// file. Returns rows sorted by `(locus, haplotype)` — deterministic,
/// unlike `hapture.pl`'s own hash-iteration-order output (confirmed
/// non-deterministic per-process while building the golden fixtures this
/// is tested against; sorting here costs nothing and removes that surprise
/// for downstream callers).
pub fn extract_sample(
    vcf_path: &Path,
    alignment_path: &Path,
) -> Result<Vec<HaplotypeSummary>, ExtractError> {
    let sites = load_snp_sites(vcf_path).map_err(|e| ExtractError::Vcf(vcf_path.into(), e))?;

    let mut reader = bam::Reader::from_path(alignment_path)
        .map_err(|e| ExtractError::OpenAlignment(alignment_path.into(), e))?;
    let header = reader.header().clone();

    // Keyed by (locus, haplotype) — a BTreeMap gives sorted output for free
    // and needs no separate sort step.
    let mut aggregates: BTreeMap<(String, String), Aggregate> = BTreeMap::new();

    let mut record = bam::Record::new();
    while let Some(result) = reader.read(&mut record) {
        result.map_err(|e| ExtractError::ReadRecord(alignment_path.into(), e))?;

        // Order matches hapture.pl's own checks exactly (inst/perl/hapture.pl):
        // flags, then locus membership, then CIGAR presence, then query length.

        if record.flags() >= 256 {
            continue; // secondary/supplementary/QC-fail/duplicate
        }

        if record.tid() < 0 {
            continue; // unmapped, no reference assigned at all
        }
        let locus = String::from_utf8_lossy(header.tid2name(record.tid() as u32)).into_owned();
        let Some(positions) = sites.get(&locus) else {
            continue; // no SNP sites on this locus
        };

        let cigar = record.cigar();
        if cigar.is_empty() {
            continue; // CIGAR == "*"
        }

        let seq = record.seq().as_bytes();
        let qual = record.qual(); // raw Phred scores, not ASCII-offset
        if seq.len() < 2 {
            continue; // hapture.pl: next if $#qseq < 1
        }

        let cigar_ops: Vec<_> = cigar.iter().copied().collect();
        let ref_span = reference_length(&cigar_ops);
        // rust-htslib's pos() is 0-based; SAM POS (what hapture.pl reads
        // straight off the text line) is 1-based. Converting here keeps
        // rpos_adj's arithmetic identical to the Perl source.
        let start_qpos = record.pos() + 1;

        let mut haplotype = String::with_capacity(positions.len());
        let mut read_quality = Vec::with_capacity(positions.len());

        for &rpos in positions {
            let rpos_adj = rpos - start_qpos + 1;

            if ref_span < rpos_adj || rpos_adj < 1 {
                haplotype.push('N');
                read_quality.push(PLACEHOLDER_QUALITY);
                continue;
            }

            match rpos_to_qpos(&cigar_ops, rpos_adj) {
                None => {
                    haplotype.push('X');
                    read_quality.push(PLACEHOLDER_QUALITY);
                }
                Some(qpos) => {
                    let idx = (qpos - 1) as usize;
                    haplotype.push(seq[idx] as char);
                    read_quality.push(qual[idx] as f64);
                }
            }
        }

        let key = (locus, haplotype);
        let entry = aggregates.entry(key).or_default();
        entry.count += 1;
        if entry.sum_prob.is_empty() {
            entry.sum_prob = vec![0.0; read_quality.len()];
            entry.max_prob = vec![0.0; read_quality.len()];
        }
        for (i, &q) in read_quality.iter().enumerate() {
            let correct_prob = 1.0 - 10f64.powf(-q / 10.0);
            entry.sum_prob[i] += correct_prob;
            entry.max_prob[i] = entry.max_prob[i].max(correct_prob);
        }
    }

    Ok(aggregates
        .into_iter()
        .map(|((locus, haplotype), agg)| HaplotypeSummary {
            locus,
            haplotype,
            count: agg.count,
            sum_prob: agg.sum_prob,
            max_prob: agg.max_prob,
        })
        .collect())
}

/// Renders one row exactly as `hapture.pl` prints it: group, individual,
/// locus, haplotype, count, comma-joined `sum_prob`, comma-joined
/// `max_prob` — tab-separated, no trailing newline.
pub fn to_tsv_line(group: &str, individual: &str, row: &HaplotypeSummary) -> String {
    let sum_prob = row
        .sum_prob
        .iter()
        .map(|v| crate::format::perl_g(*v))
        .collect::<Vec<_>>()
        .join(",");
    let max_prob = row
        .max_prob
        .iter()
        .map(|v| crate::format::perl_g(*v))
        .collect::<Vec<_>>()
        .join(",");
    format!(
        "{group}\t{individual}\t{}\t{}\t{}\t{sum_prob}\t{max_prob}",
        row.locus, row.haplotype, row.count
    )
}
