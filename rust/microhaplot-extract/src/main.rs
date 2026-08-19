//! Rust replacement for microhaplot's `hapture.pl` extraction core, and the
//! per-sample shell-script/process-spawning `R/runHaplot.R` currently
//! generates around it. See wayfinder map #18 and its child tickets for the
//! decisions behind this crate's shape; the `extract` subcommand's contract
//! is ticket #23's decision (batch behavior: ticket #30's), `validate` is
//! ticket #31's.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};

use microhaplot_extract::batch::run_batch;
use microhaplot_extract::validate::validate_bam;

#[derive(Parser)]
#[command(name = "microhaplot-extract", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Extracts haplotypes for every sample in a label file, in parallel,
    /// against one VCF's variant sites — replacing R's current per-sample
    /// invocation loop with a single call.
    Extract {
        /// Headerless, tab-separated label file: alignment filename,
        /// individual id, group (the same format `build_prep_label_file()`
        /// already produces in R — no new manifest).
        #[arg(short = 'l', long = "label-file")]
        label_file: PathBuf,

        /// Directory containing the alignment (BAM) files named in the
        /// label file's first column.
        #[arg(short = 's', long = "sample-dir")]
        sample_dir: PathBuf,

        /// VCF listing this run's variant sites.
        #[arg(short = 'v', long = "vcf")]
        vcf: PathBuf,

        /// Directory to write the combined `all.summary` output and each
        /// sample's `<individual id>.summary` completion marker into
        /// (matches `prepHaplotFiles()`'s existing `intermed/` directory,
        /// so its progress poller needs no changes).
        #[arg(short = 'o', long = "output-dir")]
        output_dir: PathBuf,

        /// Number of samples to process concurrently.
        #[arg(short = 't', long = "threads", default_value_t = 1)]
        threads: usize,
    },

    /// Confirms a BAM isn't truncated or corrupted, and prints its `@SQ`
    /// reference names (one per line) to stdout — replacing the field prep
    /// wizard's `samtools quickcheck` + `samtools view -H` shell-outs.
    Validate {
        /// Path to the BAM file to check.
        #[arg(short = 'b', long = "bam")]
        bam: PathBuf,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Command::Extract {
            label_file,
            sample_dir,
            vcf,
            output_dir,
            threads,
        } => match run_batch(&label_file, &sample_dir, &vcf, &output_dir, threads) {
            Ok(n) => {
                eprintln!("microhaplot-extract: processed {n} sample(s)");
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("microhaplot-extract: error: {e}");
                ExitCode::FAILURE
            }
        },

        Command::Validate { bam } => match validate_bam(&bam) {
            Ok(ref_names) => {
                for name in ref_names {
                    println!("{name}");
                }
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("microhaplot-extract: error: {e}");
                ExitCode::FAILURE
            }
        },
    }
}
