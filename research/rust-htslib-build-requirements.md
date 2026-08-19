# What rust-htslib needs to build

Research for [wayfinder map #18](https://github.com/ltalignani/microhaplot-2/issues/18)
— ticket [#20](https://github.com/ltalignani/microhaplot-2/issues/20).

Tested against `rust-htslib = "0.47"` (resolved to 0.47.1, `hts-sys` 2.2.1)
with a minimal probe crate (`Cargo.toml` depending on nothing but
`rust-htslib`, a `main.rs` that just links and prints). Two environments:

1. **Locally**, macOS arm64 (this dev machine).
2. **In a probe Dockerfile**, `FROM rocker/r-ver:4.5.0` plus the exact `apt`
   package list already in this repo's real `Dockerfile` — nothing added
   for Rust except what step 3 below found missing.

## 1. Toolchain age matters more than anything htslib-specific

The very first build attempt, locally, failed before touching any C code:

```
this version of Cargo is older than the `2024` edition, and only supports
`2015`, `2018`, and `2021` editions.
```

This dev machine's Rust toolchain was 1.74.1 (December 2023). A transitive
dependency several layers under `rust-htslib` (`idna_adapter`, pulled in via
URL-parsing support) requires the 2024 edition, stabilized in Rust 1.85
(February 2025). Updating to current stable (1.97.1, via `rustup update
stable`) fixed it immediately — this is a toolchain-age problem, not an
htslib problem, but it's a hard floor: whatever builds microhaplot-extract
(a developer's machine, CI, a Docker build stage) needs a **recent** stable
Rust, not merely "a Rust."

## 2. Local build (macOS arm64, current stable): clean

Once the toolchain was current, `cargo build --release` succeeded with
**no manual setup beyond what was already on this machine**: Xcode
command-line tools (`cc`/`clang`), Homebrew's `cmake`, system `perl`.

- Debug build: 1m 01s wall clock.
- Release build: 51.4s wall clock (both from a cold `cargo` registry
  cache — crates.io downloads counted).
- Release binary: 421 KB.

## 3. Docker build (Ubuntu 24.04, the exact apt list already in our Dockerfile): one missing package

Same probe crate, same `Cargo.toml`, built inside a container from
`rocker/r-ver:4.5.0` with today's Dockerfile's apt packages plus `curl`
(to fetch `rustup`) and a `rustup`-installed current stable toolchain.

First attempt failed:

```
thread 'main' panicked at bindgen-0.72.1/lib.rs:616:27:
Unable to find libclang: "couldn't find any valid shared libraries
matching: ['libclang.so', ...]"
```

`hts-sys` uses `bindgen` to generate Rust bindings from htslib's C headers,
and `bindgen` needs `libclang` at build time. `build-essential` provides
`gcc`/`g++`/`make`, not `clang`/`libclang` — that's a separate package. This
went unnoticed locally only because this Mac already has LLVM's `libclang`
on it (from an unrelated Homebrew install), not because it's optional.

**Fix**: add `libclang-dev` to the apt package list. One line. Rebuild
succeeded.

## 4. There is no "link against system htslib" option

Ubuntu 24.04 ships `libhts-dev` (1.19+ds-1.1build3 — the same htslib version
already pulled in as `samtools`'s own dependency), which raised the
question: could `rust-htslib` link against that instead of compiling its
own copy, skipping most of the build time?

No. Read `hts-sys` 2.2.1's `build.rs` directly (via the local `cargo`
registry cache): there is no `pkg-config` lookup, no `HTS_LIB_DIR`/`HTS_DIR`
escape hatch, nothing that consults an already-installed htslib. The crate
embeds a full copy of htslib's C source (15 MB, vendored under
`hts-sys-2.2.1/htslib/`) and *always* compiles it from scratch via the `cc`
crate. The `static` feature / `HTS_STATIC` env var only chooses static vs.
dynamic linking of the *result* — not whether to build it at all.

Installing `libhts-dev` would be dead weight for `rust-htslib`'s own build.
It's already installed anyway, transitively, as part of `samtools` — no
action needed either way.

## 5. Where the build time actually goes

The full Docker build (apt install + `rustup` install + `cargo build
--release`, from a cold layer) was **4m 16s** wall clock; `cargo build
--release` alone accounted for **3m 20s** of that — much slower than the
51s seen locally with a warm registry cache. Cargo's own "Finished ... in
45.19s" line under-reports the true cost: `hts-sys`'s build script runs
htslib's own C build (effectively a `configure`+`make` of the vendored
source, via the `cc`/`cmake` crates) *before* cargo's per-crate progress
lines for `hts-sys` even appear, and that step is the bulk of the 3m20s,
not `rustc` itself.

This is a one-time-per-dependency-change cost, not a per-source-edit one:
a Dockerfile that copies `Cargo.toml`/`Cargo.lock` and runs `cargo build`
for dependencies *before* copying the actual source — the same
cache-ordering principle already used in this repo's real `Dockerfile` for
R's `install_deps()` — would only pay it again when the dependency graph
changes, not on every source edit. Confirmed by cargo's own incremental
behavior on the two local builds (debug then release, same deps): the
second build only recompiled the workspace crate itself, seconds not
minutes.

## 6. Release binary size

455 KB (Docker/Linux release build) — comparable to the 421 KB seen
locally on macOS. Trivial next to the multi-gigabyte R/Shiny image this
already ships inside.

## 7. Cross-arch: inferred, not independently tested here

Not tested directly in this ticket (would need a second, amd64 probe run).
Given this repo's Docker publish workflow already builds `linux/amd64` and
`linux/arm64` **natively**, one job per architecture, on GitHub's own
runners (no QEMU — established separately, after the `v1.0.3` publish
attempt was cancelled two hours in under QEMU emulation), a Rust build step
added to that same Dockerfile would build natively on both, with no
emulation penalty either. This should be confirmed the first time
microhaplot-extract is actually added to the real Dockerfile, not assumed
indefinitely.

## Bottom line for the distribution & build strategy ticket (#22)

- Building `microhaplot-extract` inside the Docker image is straightforward:
  a current Rust toolchain (`rustup`, not a stale distro package) plus one
  additional apt package (`libclang-dev`) beyond what's already installed.
  Everything else `hts-sys` needs, it vendors and compiles itself.
- No system-htslib linking option exists to shortcut that — the build-time
  cost of compiling htslib's C source is unavoidable with this crate, but
  it's a dependency-graph-cache-hit cost (paid once, not per source edit)
  if the Dockerfile orders its layers the way this repo's R dependency
  install already does.
- Compiling at install time for a **local, non-Docker** R install would
  ask the same of the end user: a recent Rust toolchain (not whatever
  distro package might be stale) plus a C compiler and `libclang`. That's a
  materially heavier ask than today's "install a Perl interpreter" — worth
  weighing directly against shipping prebuilt binaries in ticket #22.
