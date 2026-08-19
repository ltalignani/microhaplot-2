//! Reads the label file `prepHaplotFiles()` already builds and validates in
//! R (`build_prep_label_file()`) — a headerless, 3-column, tab-separated
//! file: alignment filename, individual id, group. This is the same format
//! `hapture.pl`'s caller (`R/runHaplot.R`) has always looped over one row at
//! a time; `microhaplot-extract` reads it directly instead, per the CLI
//! contract decided in wayfinder ticket #23 — no new manifest format.

use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::Path;

/// One row of the label file: which alignment file, whose individual id,
/// and which group it belongs to.
#[derive(Debug, Clone, PartialEq)]
pub struct LabelRow {
    pub filename: String,
    pub individual_id: String,
    pub group: String,
}

#[derive(Debug, thiserror::Error)]
pub enum LabelError {
    #[error(transparent)]
    Io(#[from] io::Error),
    #[error(
        "line {line}: expected at least 3 tab-separated columns (filename, individual id, group), found {found}"
    )]
    TooFewColumns { line: usize, found: usize },
}

/// Parses every non-empty line into a [`LabelRow`], in file order — the
/// same order `hapture.pl`'s R caller has always processed rows in.
/// Extra columns beyond the first three (e.g. the wizard's `color` column)
/// are ignored, matching R's own `dim(read.label)[2] < 3` check rather than
/// an exact-3 requirement.
pub fn read_label_file(path: &Path) -> Result<Vec<LabelRow>, LabelError> {
    let reader = BufReader::new(File::open(path)?);
    let mut rows = Vec::new();

    for (i, line) in reader.lines().enumerate() {
        let line = line?;
        if line.is_empty() {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() < 3 {
            return Err(LabelError::TooFewColumns {
                line: i + 1,
                found: fields.len(),
            });
        }
        rows.push(LabelRow {
            filename: fields[0].to_string(),
            individual_id: fields[1].to_string(),
            group: fields[2].to_string(),
        });
    }

    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_label(contents: &str) -> tempfile::NamedTempFile {
        let mut f = tempfile::NamedTempFile::new().unwrap();
        f.write_all(contents.as_bytes()).unwrap();
        f
    }

    #[test]
    fn parses_rows_in_file_order() {
        let label = write_label("s6.bam\ts6\tgr\ns11.bam\ts11\tcu\n");
        let rows = read_label_file(label.path()).unwrap();
        assert_eq!(
            rows,
            vec![
                LabelRow {
                    filename: "s6.bam".into(),
                    individual_id: "s6".into(),
                    group: "gr".into()
                },
                LabelRow {
                    filename: "s11.bam".into(),
                    individual_id: "s11".into(),
                    group: "cu".into()
                },
            ]
        );
    }

    #[test]
    fn ignores_extra_columns() {
        let label = write_label("s6.bam\ts6\tgr\t#1f77b4\n");
        let rows = read_label_file(label.path()).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].group, "gr");
    }

    #[test]
    fn skips_blank_lines() {
        let label = write_label("s6.bam\ts6\tgr\n\ns11.bam\ts11\tcu\n");
        let rows = read_label_file(label.path()).unwrap();
        assert_eq!(rows.len(), 2);
    }

    #[test]
    fn rejects_too_few_columns() {
        let label = write_label("s6.bam\ts6\n");
        let err = read_label_file(label.path()).unwrap_err();
        assert!(matches!(
            err,
            LabelError::TooFewColumns { line: 1, found: 2 }
        ));
    }
}
