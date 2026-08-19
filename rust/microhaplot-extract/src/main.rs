//! Rust replacement for microhaplot's `hapture.pl` extraction core.
//! See wayfinder map #18 and its child tickets for the decisions behind
//! this crate's shape.
//!
//! This binary does nothing real yet — ticket #28 (this scaffolding) only
//! has to prove the toolchain and the `rust-htslib` link work end to end.
//! Real extraction logic lands in ticket #29.

use std::ffi::CStr;

/// The htslib version this binary was linked against, read through
/// `rust-htslib`'s raw FFI bindings. Exists to prove the C library is
/// genuinely linked and callable, not just that `Cargo.toml` parses —
/// `hts_version()` is stable, public htslib API (`htslib/hts.h`).
fn htslib_version() -> String {
    // SAFETY: hts_version() takes no arguments and always returns a
    // non-null pointer to a static, NUL-terminated C string owned by
    // htslib itself — never freed, safe to read for the process lifetime.
    unsafe {
        let ptr = rust_htslib::htslib::hts_version();
        CStr::from_ptr(ptr).to_string_lossy().into_owned()
    }
}

fn main() {
    println!("microhaplot-extract {}", env!("CARGO_PKG_VERSION"));
    println!("linked against htslib {}", htslib_version());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn links_against_a_real_htslib() {
        // A placeholder in the sense that it asserts nothing about
        // microhaplot's own logic (none exists yet) — but it is a real
        // test: it fails if the FFI link is broken or returns garbage.
        let version = htslib_version();
        assert!(
            !version.is_empty(),
            "hts_version() returned an empty string"
        );
    }
}
