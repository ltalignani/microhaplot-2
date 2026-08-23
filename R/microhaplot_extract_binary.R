#' GitHub repo this fork publishes microhaplot-extract release binaries to
#' (wayfinder ticket #32's release-binaries.yml workflow).
#' @keywords internal
#' @noRd
MICROHAPLOT_EXTRACT_RELEASE_REPO <- "ltalignani/microhaplot-2"

#' This package's own version, robust to an unrelated "microhaplot" package
#' shadowing this source tree in \code{.libPaths()}
#'
#' \code{utils::packageVersion("microhaplot")} is correct once this package
#' is properly installed or loaded via \code{devtools::load_all()} -- but
#' under the lightweight CI harness (wayfinder ticket #35,
#' \code{scripts/run-prep-extraction-integration-test.R}), which sources a
#' few R files directly rather than installing/loading the package, it
#' silently resolves to whatever unrelated package happens to be installed
#' under that name (or errors, on a runner where nothing is installed at
#' all) -- not this source tree's own \code{DESCRIPTION}.
#'
#' Checked in order: the \code{MICROHAPLOT_EXPECTED_VERSION} environment
#' variable (the harness sets this once, at its own top level, before
#' \code{testthat::test_file()} changes the working directory to
#' \code{tests/testthat/} for the duration of the run -- a \code{DESCRIPTION}
#' lookup relative to the working directory can't be relied on once that's
#' happened); then a \code{DESCRIPTION} at the current working directory,
#' for any other script run from the repo root that hasn't set the env var;
#' then \code{packageVersion()}, correct for every real installed-package
#' scenario (a bioinformatician's local R install, or the Docker image),
#' where neither of the above apply.
#'
#' @keywords internal
#' @noRd
this_microhaplot_version <- function() {
  env_version <- Sys.getenv("MICROHAPLOT_EXPECTED_VERSION", unset = NA)
  if (!is.na(env_version) && nzchar(env_version)) return(env_version)

  if (file.exists("DESCRIPTION")) {
    version <- tryCatch(
      as.character(read.dcf("DESCRIPTION", fields = "Version")[1, "Version"]),
      error = function(e) NA_character_
    )
    if (!is.na(version) && nzchar(version)) return(version)
  }
  as.character(utils::packageVersion("microhaplot"))
}

#' Locate a locally-built microhaplot-extract binary
#'
#' Checks, in order: the \code{MICROHAPLOT_EXTRACT_BIN} environment
#' variable, then a release build, then a debug build, under
#' \code{rust/microhaplot-extract/target/} relative to the package's own
#' root. Two candidate roots are tried, since \code{system.file(package =
#' "microhaplot")} points at different places depending on how the package
#' was loaded: one directory up under \code{devtools::load_all()} (which
#' resolves to the installed-package layout's \code{inst/}), or the same
#' directory for a real install.
#'
#' This is the development-only half of binary acquisition -- it never
#' downloads anything. \code{\link{resolve_microhaplot_extract_bin}()} is
#' the production counterpart: it checks here first (so a local checkout's
#' own build always wins), then falls back to a cached or freshly
#' downloaded release binary.
#'
#' @return string path to the binary, or \code{NA_character_} if none was found.
#' @keywords internal
#' @noRd
find_microhaplot_extract_bin <- function() {
  env_bin <- Sys.getenv("MICROHAPLOT_EXTRACT_BIN", unset = NA)
  if (!is.na(env_bin) && nzchar(env_bin) && file.exists(env_bin)) {
    return(env_bin)
  }

  pkg_dir <- system.file(package = "microhaplot")
  candidate_roots <- c(dirname(pkg_dir), pkg_dir)
  exe_name <- if (.Platform$OS.type == "windows") {
    "microhaplot-extract.exe"
  } else {
    "microhaplot-extract"
  }

  for (root in candidate_roots) {
    for (profile in c("release", "debug")) {
      candidate <- file.path(
        root, "rust", "microhaplot-extract", "target", profile, exe_name
      )
      if (file.exists(candidate)) return(candidate)
    }
  }

  NA_character_
}

#' Detect this platform's microhaplot-extract release asset name
#'
#' Maps the running R session's OS/architecture to the asset-naming
#' convention \code{release-binaries.yml} uses (wayfinder ticket #32): one
#' of \code{"linux-x86_64"}, \code{"linux-arm64"}, \code{"macos-arm64"},
#' \code{"macos-x86_64"}. Stops immediately, without attempting any
#' download, on Windows (no native build exists -- wayfinder ticket #24)
#' or any other unrecognized platform.
#'
#' @param sysname string. Override for testing; defaults to the real
#'   \code{Sys.info()[["sysname"]]}.
#' @param arch string. Override for testing; defaults to the real
#'   \code{R.version$arch}.
#' @param os_type string. Override for testing; defaults to the real
#'   \code{.Platform$OS.type}.
#' @return string, one of the four asset-name platform tags.
#' @keywords internal
#' @noRd
detect_microhaplot_extract_platform <- function(sysname = Sys.info()[["sysname"]],
                                                 arch = R.version$arch,
                                                 os_type = .Platform$OS.type) {
  if (identical(os_type, "windows")) {
    stop(
      "microhaplot-extract has no native Windows build (wayfinder ticket ",
      "#24). Use the Docker distribution instead: ",
      "https://github.com/", MICROHAPLOT_EXTRACT_RELEASE_REPO, "#docker"
    )
  }

  is_arm <- arch %in% c("aarch64", "arm64")
  is_x86_64 <- arch %in% c("x86_64", "x86-64")

  if (identical(sysname, "Darwin") && is_arm) return("macos-arm64")
  if (identical(sysname, "Darwin") && is_x86_64) return("macos-x86_64")
  if (identical(sysname, "Linux") && is_x86_64) return("linux-x86_64")
  if (identical(sysname, "Linux") && is_arm) return("linux-arm64")

  stop(
    "microhaplot-extract has no prebuilt binary for this platform (",
    sysname, "/", arch, "). Supported: macOS (arm64/x86_64) and Linux ",
    "(x86_64/arm64). Use the Docker distribution instead: ",
    "https://github.com/", MICROHAPLOT_EXTRACT_RELEASE_REPO, "#docker"
  )
}

#' Build the GitHub Release download URL for one platform's binary
#' @keywords internal
#' @noRd
microhaplot_extract_release_url <- function(version, platform) {
  sprintf(
    "https://github.com/%s/releases/download/v%s/microhaplot-extract-%s",
    MICROHAPLOT_EXTRACT_RELEASE_REPO, version, platform
  )
}

#' Local cache path for one version+platform's downloaded binary
#'
#' Namespaced by version so upgrading the R package (and thus the release
#' it should fetch) never reuses a stale cached binary.
#'
#' @keywords internal
#' @noRd
microhaplot_extract_cache_path <- function(version, platform, cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("microhaplot", which = "cache")
  }
  exe_name <- if (.Platform$OS.type == "windows") {
    "microhaplot-extract.exe"
  } else {
    "microhaplot-extract"
  }
  file.path(cache_dir, paste0("microhaplot-extract-", version), platform, exe_name)
}

#' Obtain a working microhaplot-extract binary, downloading and caching a
#' release build if a local development build isn't already available
#'
#' The production counterpart to \code{\link{find_microhaplot_extract_bin}()}
#' (wayfinder tickets #32/#33): tries that first (so a local source
#' checkout's own \code{cargo build} always wins, unchanged from before this
#' ticket), then a previously-cached download, and only then downloads the
#' release binary matching this platform and the installed package's
#' version from GitHub, caching it under
#' \code{tools::R_user_dir("microhaplot", "cache")} so later calls reuse it
#' without re-downloading. Fails immediately with a clear, Docker-pointing
#' message on Windows or any other unsupported platform, without attempting
#' a download that could never succeed.
#'
#' @param version string. Package version to fetch a matching release for.
#'   Defaults to \code{\link{this_microhaplot_version}()} -- the release tag
#'   convention \code{release-binaries.yml} enforces (wayfinder ticket #32)
#'   is \code{vX.Y.Z} for \code{DESCRIPTION}'s \code{Version: X.Y.Z}.
#' @param platform string. Override for testing; defaults to
#'   \code{\link{detect_microhaplot_extract_platform}()}'s autodetection.
#' @param cache_dir string. Override for testing; defaults to
#'   \code{tools::R_user_dir("microhaplot", "cache")}.
#' @param dev_lookup_fn function. Override for testing; defaults to
#'   \code{\link{find_microhaplot_extract_bin}}.
#' @param download_fn function. Override for testing; defaults to
#'   \code{utils::download.file}. Called as
#'   \code{download_fn(url, destfile, mode = "wb", quiet = TRUE)} and
#'   expected to return \code{0L} on success, matching
#'   \code{utils::download.file()}'s own contract.
#' @return string path to a usable microhaplot-extract binary.
#' @keywords internal
#' @noRd
resolve_microhaplot_extract_bin <- function(version = this_microhaplot_version(),
                                             platform = NULL,
                                             cache_dir = NULL,
                                             dev_lookup_fn = find_microhaplot_extract_bin,
                                             download_fn = utils::download.file) {
  dev_bin <- dev_lookup_fn()
  if (!is.na(dev_bin) && nzchar(dev_bin) && file.exists(dev_bin)) {
    return(dev_bin)
  }

  if (is.null(platform)) platform <- detect_microhaplot_extract_platform()

  cache_path <- microhaplot_extract_cache_path(version, platform, cache_dir)
  if (file.exists(cache_path)) {
    return(cache_path)
  }

  url <- microhaplot_extract_release_url(version, platform)
  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(cache_path, ".download")
  on.exit(unlink(tmp), add = TRUE)

  download_failed_msg <- paste0(
    "failed to download microhaplot-extract from ", url,
    ". Check your network connection, or download it manually from ",
    "https://github.com/", MICROHAPLOT_EXTRACT_RELEASE_REPO, "/releases"
  )

  status <- tryCatch(
    download_fn(url, tmp, mode = "wb", quiet = TRUE),
    error = function(e) {
      stop(download_failed_msg, " (", conditionMessage(e), ")", call. = FALSE)
    }
  )
  if (!identical(status, 0L) || !file.exists(tmp) || file.info(tmp)$size == 0) {
    stop(download_failed_msg, call. = FALSE)
  }

  file.copy(tmp, cache_path, overwrite = TRUE)
  Sys.chmod(cache_path, "0755")
  cache_path
}

#' Read the version a microhaplot-extract binary reports via `--version`
#'
#' clap's auto-generated \code{--version} prints \code{"microhaplot-extract
#' X.Y.Z"} to stdout (from the crate's own \code{Cargo.toml} version, kept
#' in lockstep with \code{DESCRIPTION}'s \code{Version:} -- wayfinder ticket
#' #38's decision). Used by \code{\link{resolve_bin_or_stop}()} to catch a
#' binary that predates the R package it's paired with.
#'
#' @param bin string. Path to the binary to query.
#' @return string version (e.g. \code{"2.1.0"}), or \code{NA_character_} if
#'   the binary couldn't be run or its output didn't look like a version.
#' @keywords internal
#' @noRd
get_microhaplot_extract_bin_version <- function(bin) {
  out <- withCallingHandlers(
    tryCatch(
      system2(bin, "--version", stdout = TRUE, stderr = TRUE),
      error = function(e) NA_character_
    ),
    warning = function(w) invokeRestart("muffleWarning")
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) return(NA_character_)
  if (length(out) == 0 || is.na(out[1])) return(NA_character_)

  m <- regmatches(out[1], regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", out[1]))
  if (length(m) == 0) NA_character_ else m
}

#' Resolve which microhaplot-extract binary to use, or stop with a clear message
#'
#' Shared entry point for every \code{microhaplot-extract} caller
#' (\code{run_microhaplot_extract()}, \code{check_bam_integrity_rust()}):
#' an explicit \code{bin.path} always wins; otherwise resolves one via
#' \code{\link{resolve_microhaplot_extract_bin}()} (local dev build, cached
#' download, or a fresh download -- wayfinder tickets #30-#33).
#'
#' Once a binary is in hand, its \code{--version} is checked against this
#' package's own \code{DESCRIPTION} version (wayfinder ticket #38's
#' decision, implemented in #40) and a mismatch is a hard stop, not a
#' warning -- a downloaded release can't drift (its cache path and release
#' tag are both already namespaced by version), but a local dev build
#' (\code{MICROHAPLOT_EXTRACT_BIN} or a stale \code{cargo build} output) or
#' an explicit \code{bin.path} can. The check re-runs on every call rather
#' than caching its result; an extra subprocess spawn is negligible next to
#' the extraction work every caller here goes on to do.
#'
#' @param bin.path string or \code{NULL}.
#' @param resolve_fn function. Override for testing; defaults to
#'   \code{\link{resolve_microhaplot_extract_bin}}. Only called when
#'   \code{bin.path} is \code{NULL}.
#' @param version_check_fn function. Override for testing; defaults to
#'   \code{\link{get_microhaplot_extract_bin_version}}.
#' @param expected_version string. Override for testing; defaults to
#'   \code{\link{this_microhaplot_version}()}.
#' @return string path to a usable binary.
#' @keywords internal
#' @noRd
resolve_bin_or_stop <- function(
    bin.path,
    resolve_fn = resolve_microhaplot_extract_bin,
    version_check_fn = get_microhaplot_extract_bin_version,
    expected_version = this_microhaplot_version()) {
  bin <- bin.path
  if (is.null(bin)) {
    bin <- tryCatch(
      resolve_fn(),
      error = function(e) stop(conditionMessage(e), call. = FALSE)
    )
  }
  if (is.na(bin) || !nzchar(bin) || !file.exists(bin)) {
    stop(
      "microhaplot-extract binary not found. Build it with `cargo build",
      " --release` in rust/microhaplot-extract/, or pass bin.path explicitly."
    )
  }

  actual_version <- version_check_fn(bin)
  if (!identical(actual_version, expected_version)) {
    reported <- if (is.na(actual_version)) {
      "an unreadable version"
    } else {
      paste0("version ", actual_version)
    }
    if (is.null(bin.path)) {
      stop(
        "microhaplot-extract version mismatch: the resolved binary (", bin,
        ") reports ", reported, ", but this package expects version ",
        expected_version, ". If this is a local development build, rebuild",
        " it with `cargo build --release` in rust/microhaplot-extract/. If",
        " it was downloaded automatically, delete the cached copy under ",
        tools::R_user_dir("microhaplot", which = "cache"),
        " and let the package fetch it again."
      )
    } else {
      stop(
        "microhaplot-extract version mismatch: the binary at '", bin,
        "' reports ", reported, ", but this package expects version ",
        expected_version, ". Pass a matching binary via bin.path, or omit",
        " bin.path to let the package resolve one automatically."
      )
    }
  }

  bin
}
