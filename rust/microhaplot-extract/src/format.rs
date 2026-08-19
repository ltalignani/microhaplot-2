//! Replicates Perl's default number-to-string stringification for the
//! quality-aggregate columns (`sum.Phred.C`, `max.Phred.C`), so
//! `microhaplot-extract`'s output is byte-identical to `hapture.pl`'s once
//! canonicalized — not just numerically equal.
//!
//! Perl stringifies a floating-point value the way the C standard library's
//! `%.15g` does: 15 significant digits, switching between fixed and
//! scientific notation by magnitude, with trailing zeros (and a bare
//! trailing decimal point) stripped. Rust's own `f64` `Display` uses a
//! different algorithm (shortest round-tripping representation), which
//! disagrees with `%.15g` often enough in the last couple of digits that
//! golden-fixture comparisons would fail on formatting alone, not on the
//! underlying arithmetic. Verified against the golden fixtures themselves
//! while writing this: e.g. `0.920567176527572` and `23.9876926097562` are
//! both exactly what `%.15g` produces for those values, not what Rust's
//! default formatter would.

const SIGNIFICANT_DIGITS: i32 = 15;

/// Formats `value` exactly as Perl's default number stringification would.
pub fn perl_g(value: f64) -> String {
    if value == 0.0 {
        return "0".to_string();
    }
    if !value.is_finite() {
        // hapture.pl never produces these (its inputs are Phred-derived
        // probabilities in (0, 1]), but don't silently mangle them if
        // something upstream is wrong.
        return value.to_string();
    }

    let exponent = value.abs().log10().floor() as i32;

    // %g's own rule for choosing fixed vs. scientific notation.
    if (-4..SIGNIFICANT_DIGITS).contains(&exponent) {
        let decimals = (SIGNIFICANT_DIGITS - 1 - exponent).max(0) as usize;
        strip_trailing(&format!("{value:.decimals$}"))
    } else {
        let decimals = (SIGNIFICANT_DIGITS - 1).max(0) as usize;
        let formatted = format!("{value:.decimals$e}");
        normalize_exponent(&strip_trailing_scientific(&formatted))
    }
}

/// Strips trailing zeros from a fixed-notation string, and the decimal
/// point itself if nothing is left after it — `%g`'s behavior without the
/// `#` flag, which Perl's stringification doesn't set.
fn strip_trailing(s: &str) -> String {
    if !s.contains('.') {
        return s.to_string();
    }
    let trimmed = s.trim_end_matches('0');
    trimmed.trim_end_matches('.').to_string()
}

/// Same trailing-zero stripping, but only on the mantissa of a
/// `{value:.N$e}`-formatted string (before the `e...` suffix).
fn strip_trailing_scientific(s: &str) -> String {
    let Some(e_pos) = s.find('e') else {
        return s.to_string();
    };
    let (mantissa, exp) = s.split_at(e_pos);
    format!("{}{}", strip_trailing(mantissa), exp)
}

/// Rust's `{:e}` formats the exponent as e.g. `e5` / `e-5`; C's `%g` (and
/// Perl) format it zero-padded to at least two digits with an explicit
/// sign, e.g. `e+05` / `e-05`.
fn normalize_exponent(s: &str) -> String {
    let Some(e_pos) = s.find('e') else {
        return s.to_string();
    };
    let (mantissa, exp) = s.split_at(e_pos);
    let exp_digits = &exp[1..]; // drop the 'e'
    let (sign, digits) = match exp_digits.strip_prefix('-') {
        Some(rest) => ('-', rest),
        None => ('+', exp_digits),
    };
    format!("{mantissa}e{sign}{digits:0>2}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_known_golden_fixture_values() {
        // Pulled directly from tests/testthat/fixtures/hapture-golden/.
        assert_eq!(perl_g(0.920567176527572), "0.920567176527572");
        assert_eq!(perl_g(23.9876926097562), "23.9876926097562");
        assert_eq!(perl_g(0.999841510680754), "0.999841510680754");
    }

    #[test]
    fn strips_trailing_zeros() {
        assert_eq!(perl_g(1.5), "1.5");
        assert_eq!(perl_g(1.0), "1");
        assert_eq!(perl_g(0.5), "0.5");
    }

    #[test]
    fn zero_is_bare() {
        assert_eq!(perl_g(0.0), "0");
    }
}
