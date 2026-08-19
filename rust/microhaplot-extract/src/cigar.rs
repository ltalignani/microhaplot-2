//! CIGAR-walking, ported from `hapture.pl`'s use of Perl's `Bio::Cigar`
//! (`reference_length` and `rpos_to_qpos`). Pure functions, independent of
//! `rust-htslib`'s own `Cigar` type only insofar as that type is the input —
//! no I/O, no state, easy to unit-test directly.

use rust_htslib::bam::record::Cigar;

/// Total reference bases the CIGAR consumes — the operations that "use up"
/// reference coordinate space: `M`, `D`, `N`, `=`, `X`. Matches
/// `Bio::Cigar::reference_length`.
pub fn reference_length(cigar: &[Cigar]) -> i64 {
    cigar
        .iter()
        .map(|op| match op {
            Cigar::Match(n)
            | Cigar::Del(n)
            | Cigar::RefSkip(n)
            | Cigar::Equal(n)
            | Cigar::Diff(n) => *n as i64,
            Cigar::Ins(_) | Cigar::SoftClip(_) | Cigar::HardClip(_) | Cigar::Pad(_) => 0,
        })
        .sum()
}

/// Maps a 1-based reference position — relative to the read's own alignment
/// start, i.e. `rpos_adj = 1` is the CIGAR's first reference-consuming base —
/// to a 1-based query (read) position. Returns `None` when that reference
/// position falls inside a deletion or reference-skip, where no query base
/// exists. Ported from `Bio::Cigar::rpos_to_qpos`.
///
/// Callers are expected to have already checked `rpos_adj` against
/// [`reference_length`] and rejected `rpos_adj < 1` — this function assumes
/// the position is somewhere within the CIGAR's reference span, matching
/// `hapture.pl`'s own control flow (its N-marking pre-check runs before
/// calling the equivalent of this function, not inside it).
pub fn rpos_to_qpos(cigar: &[Cigar], rpos_adj: i64) -> Option<i64> {
    let mut ref_pos: i64 = 0; // 0-based, reference bases consumed so far
    let mut query_pos: i64 = 0; // 0-based, query bases consumed so far (incl. soft clips)

    for op in cigar {
        let (consumes_ref, consumes_query, len) = match op {
            Cigar::Match(n) | Cigar::Equal(n) | Cigar::Diff(n) => (true, true, *n as i64),
            Cigar::Ins(n) | Cigar::SoftClip(n) => (false, true, *n as i64),
            Cigar::Del(n) | Cigar::RefSkip(n) => (true, false, *n as i64),
            Cigar::HardClip(_) | Cigar::Pad(_) => (false, false, 0),
        };

        if consumes_ref {
            if ref_pos < rpos_adj && rpos_adj <= ref_pos + len {
                return if consumes_query {
                    let offset_into_op = rpos_adj - ref_pos - 1;
                    Some(query_pos + offset_into_op + 1)
                } else {
                    None // deletion / refskip: no corresponding query base
                };
            }
            ref_pos += len;
        }
        if consumes_query {
            query_pos += len;
        }
    }

    None // rpos_adj beyond the CIGAR's reference span
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reference_length_sums_only_ref_consuming_ops() {
        // 2H10M5X3=2H: hard clips don't count, everything else does.
        let cigar = vec![
            Cigar::HardClip(2),
            Cigar::Match(10),
            Cigar::Diff(5),
            Cigar::Equal(3),
            Cigar::HardClip(2),
        ];
        assert_eq!(reference_length(&cigar), 18);
    }

    #[test]
    fn simple_match_maps_1to1() {
        let cigar = vec![Cigar::Match(10)];
        assert_eq!(rpos_to_qpos(&cigar, 1), Some(1));
        assert_eq!(rpos_to_qpos(&cigar, 10), Some(10));
    }

    #[test]
    fn leading_softclip_shifts_query_position() {
        // 5S10M: reference position 1 (the first M base) is query position 6.
        let cigar = vec![Cigar::SoftClip(5), Cigar::Match(10)];
        assert_eq!(rpos_to_qpos(&cigar, 1), Some(6));
        assert_eq!(rpos_to_qpos(&cigar, 10), Some(15));
    }

    #[test]
    fn deletion_returns_none() {
        // 5M3D5M: ref positions 6-8 fall inside the deletion.
        let cigar = vec![Cigar::Match(5), Cigar::Del(3), Cigar::Match(5)];
        assert_eq!(rpos_to_qpos(&cigar, 5), Some(5));
        assert_eq!(rpos_to_qpos(&cigar, 6), None);
        assert_eq!(rpos_to_qpos(&cigar, 7), None);
        assert_eq!(rpos_to_qpos(&cigar, 8), None);
        // Query position doesn't advance for the deleted bases: the next
        // matched base right after the deletion is still query position 6.
        assert_eq!(rpos_to_qpos(&cigar, 9), Some(6));
    }

    #[test]
    fn insertion_is_skipped_over_for_reference_positions() {
        // 5M3I5M: the insertion consumes query but no reference position
        // ever "lands" inside it.
        let cigar = vec![Cigar::Match(5), Cigar::Ins(3), Cigar::Match(5)];
        assert_eq!(rpos_to_qpos(&cigar, 5), Some(5));
        // Ref position 6 is the first base of the second M run, but 3
        // inserted query bases sit between it and ref position 5.
        assert_eq!(rpos_to_qpos(&cigar, 6), Some(9));
    }

    #[test]
    fn beyond_reference_span_returns_none() {
        let cigar = vec![Cigar::Match(10)];
        assert_eq!(rpos_to_qpos(&cigar, 11), None);
    }
}
