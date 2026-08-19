//! VCF loading, ported from `hapture.pl`'s own inline VCF scan. Keeps only
//! SNP sites — a REF allele of exactly one base, and every comma-separated
//! ALT allele also exactly one base (so a bi- or multi-allelic SNP site
//! passes; any site with an indel-length allele, REF or ALT, does not).
//!
//! Positions are kept in the order they're encountered in the file, per
//! locus (CHROM) — not sorted by this code. `hapture.pl` relies on the VCF
//! itself being position-sorted (its own comment: "!! assumed the position
//! is sorted") and this port preserves that same assumption rather than
//! silently fixing it, since the output's per-position column order is
//! defined by this file order.

use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::Path;

/// SNP-only variant positions, one ordered list per locus (VCF CHROM),
/// in file order.
pub type VariantSites = HashMap<String, Vec<i64>>;

pub fn load_snp_sites(path: &Path) -> io::Result<VariantSites> {
    let reader = BufReader::new(File::open(path)?);
    let mut sites: VariantSites = HashMap::new();

    for line in reader.lines() {
        let line = line?;
        if line.starts_with('#') {
            continue;
        }

        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() < 5 {
            continue; // not a well-formed data line
        }

        let chrom = fields[0].trim();
        let pos = fields[1].trim();
        let reference = fields[3].trim();
        let alt = fields[4].trim();

        if reference.len() > 1 {
            continue; // indel (or larger) REF allele
        }
        let max_alt_len = alt.split(',').map(str::len).max().unwrap_or(0);
        if max_alt_len > 1 {
            continue; // at least one ALT allele is an indel
        }

        let Ok(pos) = pos.parse::<i64>() else {
            continue; // malformed POS; hapture.pl would have pushed a
                      // non-numeric string here too, but nothing downstream
                      // could ever have matched a read against it either
        };

        sites.entry(chrom.to_string()).or_default().push(pos);
    }

    Ok(sites)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_vcf(contents: &str) -> tempfile::NamedTempFile {
        let mut f = tempfile::NamedTempFile::new().unwrap();
        f.write_all(contents.as_bytes()).unwrap();
        f
    }

    #[test]
    fn keeps_snp_only_sites_in_file_order() {
        let vcf = write_vcf(concat!(
            "##fileformat=VCFv4.2\n",
            "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n",
            "locusA\t10\t.\tA\tT\t.\t.\t.\n",
            "locusA\t5\t.\tA\tG,C\t.\t.\t.\n", // multi-allelic SNP: kept
            "locusA\t7\t.\tAT\tA\t.\t.\t.\n",  // REF indel: dropped
            "locusA\t8\t.\tA\tATT\t.\t.\t.\n", // ALT indel: dropped
            "locusB\t1\t.\tG\tA\t.\t.\t.\n",
        ));

        let sites = load_snp_sites(vcf.path()).unwrap();
        assert_eq!(sites["locusA"], vec![10, 5]); // file order, not sorted
        assert_eq!(sites["locusB"], vec![1]);
        assert_eq!(sites.len(), 2);
    }

    #[test]
    fn ignores_header_lines() {
        let vcf = write_vcf("##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\n");
        let sites = load_snp_sites(vcf.path()).unwrap();
        assert!(sites.is_empty());
    }
}
