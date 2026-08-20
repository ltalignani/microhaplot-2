test_that("detect_microhaplot_extract_platform() maps known platforms correctly", {
  expect_equal(
    detect_microhaplot_extract_platform(sysname = "Darwin", arch = "aarch64", os_type = "unix"),
    "macos-arm64"
  )
  expect_equal(
    detect_microhaplot_extract_platform(sysname = "Darwin", arch = "arm64", os_type = "unix"),
    "macos-arm64"
  )
  expect_equal(
    detect_microhaplot_extract_platform(sysname = "Darwin", arch = "x86_64", os_type = "unix"),
    "macos-x86_64"
  )
  expect_equal(
    detect_microhaplot_extract_platform(sysname = "Linux", arch = "x86_64", os_type = "unix"),
    "linux-x86_64"
  )
  expect_equal(
    detect_microhaplot_extract_platform(sysname = "Linux", arch = "aarch64", os_type = "unix"),
    "linux-arm64"
  )
})

test_that("detect_microhaplot_extract_platform() fails immediately on Windows, pointing to Docker", {
  expect_error(
    detect_microhaplot_extract_platform(sysname = "Windows", arch = "x86_64", os_type = "windows"),
    "no native Windows build.*Docker"
  )
})

test_that("detect_microhaplot_extract_platform() fails clearly on an unsupported platform", {
  expect_error(
    detect_microhaplot_extract_platform(sysname = "SunOS", arch = "sparc", os_type = "unix"),
    "no prebuilt binary for this platform"
  )
})

test_that("microhaplot_extract_release_url() builds the expected GitHub Release URL", {
  expect_equal(
    microhaplot_extract_release_url("2.0.1", "linux-x86_64"),
    "https://github.com/ltalignani/microhaplot-2/releases/download/v2.0.1/microhaplot-extract-linux-x86_64"
  )
})

test_that("microhaplot_extract_cache_path() is namespaced by version and platform", {
  cache_dir <- withr::local_tempdir()
  p1 <- microhaplot_extract_cache_path("2.0.1", "linux-x86_64", cache_dir)
  p2 <- microhaplot_extract_cache_path("2.0.2", "linux-x86_64", cache_dir)
  p3 <- microhaplot_extract_cache_path("2.0.1", "macos-arm64", cache_dir)

  expect_true(all(startsWith(c(p1, p2, p3), cache_dir)))
  expect_false(p1 == p2)
  expect_false(p1 == p3)
  expect_true(grepl("2\\.0\\.1", p1))
  expect_true(grepl("linux-x86_64", p1))
})

test_that("resolve_microhaplot_extract_bin() returns the dev build without downloading", {
  called <- FALSE
  fake_download <- function(...) {
    called <<- TRUE
    0L
  }

  dev_bin <- withr::local_tempfile()
  writeLines("#!/bin/sh", dev_bin)

  result <- resolve_microhaplot_extract_bin(
    dev_lookup_fn = function() dev_bin,
    download_fn = fake_download
  )

  expect_equal(result, dev_bin)
  expect_false(called)
})

test_that("resolve_microhaplot_extract_bin() downloads and caches when no dev build exists", {
  cache_dir <- withr::local_tempdir()
  requested_urls <- character()

  fake_download <- function(url, destfile, mode, quiet) {
    requested_urls <<- c(requested_urls, url)
    writeLines("fake binary contents", destfile)
    0L
  }

  result <- resolve_microhaplot_extract_bin(
    version = "9.9.9",
    platform = "linux-x86_64",
    cache_dir = cache_dir,
    dev_lookup_fn = function() NA_character_,
    download_fn = fake_download
  )

  expect_true(file.exists(result))
  expect_equal(
    requested_urls,
    "https://github.com/ltalignani/microhaplot-2/releases/download/v9.9.9/microhaplot-extract-linux-x86_64"
  )
  expect_equal(readLines(result), "fake binary contents")
  # Sys.chmod's effect isn't portably readable back as an exact mode string,
  # but file.access(..., mode = 1) checks the execute bit directly.
  expect_equal(file.access(result, mode = 1)[[1]], 0L)
})

test_that("resolve_microhaplot_extract_bin() reuses a cached download without re-downloading", {
  cache_dir <- withr::local_tempdir()
  cache_path <- microhaplot_extract_cache_path("9.9.9", "linux-x86_64", cache_dir)
  dir.create(dirname(cache_path), recursive = TRUE)
  writeLines("already cached", cache_path)

  fake_download <- function(...) stop("should not be called -- cache hit expected")

  result <- resolve_microhaplot_extract_bin(
    version = "9.9.9",
    platform = "linux-x86_64",
    cache_dir = cache_dir,
    dev_lookup_fn = function() NA_character_,
    download_fn = fake_download
  )

  expect_equal(result, cache_path)
  expect_equal(readLines(result), "already cached")
})

test_that("resolve_microhaplot_extract_bin() reports a clear error when the download fails", {
  cache_dir <- withr::local_tempdir()
  fake_download <- function(...) stop("simulated network failure")

  expect_error(
    resolve_microhaplot_extract_bin(
      version = "9.9.9",
      platform = "linux-x86_64",
      cache_dir = cache_dir,
      dev_lookup_fn = function() NA_character_,
      download_fn = fake_download
    ),
    "failed to download microhaplot-extract.*simulated network failure"
  )
})

test_that("resolve_microhaplot_extract_bin() reports a clear error on a non-zero download status", {
  cache_dir <- withr::local_tempdir()
  # A downloader that "succeeds" (no error thrown) but returns a non-zero
  # status -- e.g. download.file()'s own contract for some failure modes.
  fake_download <- function(url, destfile, mode, quiet) {
    writeLines("", destfile)
    1L
  }

  expect_error(
    resolve_microhaplot_extract_bin(
      version = "9.9.9",
      platform = "linux-x86_64",
      cache_dir = cache_dir,
      dev_lookup_fn = function() NA_character_,
      download_fn = fake_download
    ),
    "failed to download microhaplot-extract"
  )
})

test_that("resolve_bin_or_stop() returns an explicit bin.path unchanged", {
  dev_bin <- withr::local_tempfile()
  writeLines("#!/bin/sh", dev_bin)
  expect_equal(resolve_bin_or_stop(dev_bin), dev_bin)
})

test_that("resolve_bin_or_stop() errors clearly when an explicit bin.path doesn't exist", {
  expect_error(
    resolve_bin_or_stop(file.path(withr::local_tempdir(), "no-such-binary")),
    "microhaplot-extract binary not found"
  )
})
