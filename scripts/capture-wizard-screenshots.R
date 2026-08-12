# Captures the Field Genotyping Prep wizard screenshots used by the
# "Extracting haplotypes with Docker" vignette, driving the wizard through
# all five steps against the bundled sebastes demo data.
#
# This exists mainly for step 4: on the 20-sample demo dataset the extraction
# finishes in a couple of seconds and the progress bar polls every 300 ms, so
# catching it by hand is a coin toss. A script can click and shoot inside the
# same second.
#
# Prerequisites: `docker compose up -d` with the demo data unpacked into
# ./microhaplot-data/sebastes-demo (see the vignette).
#
# Usage, from the repository root:
#   Rscript scripts/capture-wizard-screenshots.R [app_url] [folder] [shots]
#
# `folder` is a directory name under ./microhaplot-data (default
# "sebastes-demo"), and `shots` a comma-separated list of file names to keep
# (default all). Step 4 is captured from a deliberately larger batch — see
# scripts/make-big-batch.sh — because on 20 samples the progress bar is gone
# before it renders.

library(chromote)

args <- commandArgs(trailingOnly = TRUE)
app_url <- if (length(args) >= 1) args[[1]] else "http://localhost:3839/"
folder <- if (length(args) >= 2) args[[2]] else "sebastes-demo"
shots <- if (length(args) >= 3) strsplit(args[[3]], ",")[[1]] else NULL

out_dir <- file.path(getwd(), "vignettes")
if (!dir.exists(out_dir)) {
  stop("run this from the repository root (no ./vignettes here)")
}

# Uploaded through the browser, so these are host paths, not container paths.
demo_dir <- file.path(getwd(), "microhaplot-data", folder)
tsv_path <- Sys.glob(file.path(demo_dir, "*metadata.tsv"))[1]
vcf_path <- Sys.glob(file.path(demo_dir, "*.vcf"))[1]
for (f in c(tsv_path, vcf_path)) {
  if (is.na(f) || !file.exists(f)) {
    stop("missing metadata TSV or VCF in ", demo_dir)
  }
}

b <- ChromoteSession$new(width = 1200, height = 1000)
on.exit(b$close(), add = TRUE)

# Retina-density captures, so the text stays crisp at the 100% width the
# vignette renders these at.
b$Emulation$setDeviceMetricsOverride(
  width = 1200, height = 1000, deviceScaleFactor = 2, mobile = FALSE
)

js <- function(expr) b$Runtime$evaluate(expr)$result$value

body_text <- function() js("document.body.innerText")

wait_for_text <- function(pattern, what, timeout = 60) {
  deadline <- Sys.time() + timeout
  repeat {
    txt <- body_text()
    if (is.character(txt) && grepl(pattern, txt)) {
      return(invisible(TRUE))
    }
    if (Sys.time() > deadline) {
      stop("timed out waiting for ", what, "\nlast seen:\n", txt)
    }
    Sys.sleep(0.3)
  }
}

click_text <- function(text) {
  script <- sprintf(
    "(function(){var els=Array.from(
       document.querySelectorAll('button, a, .btn'));
     var el=els.find(function(x){return x.innerText.trim().indexOf(%s)===0;});
     if(!el){return false;} el.click(); return true;})()",
    paste0("'", text, "'")
  )
  if (!isTRUE(js(script))) {
    stop("no clickable element starting with: ", text)
  }
}

shoot <- function(file) {
  if (!is.null(shots) && !(file %in% shots)) {
    return(invisible(FALSE))
  }
  path <- file.path(out_dir, file)
  # A fixed viewport rectangle at 2x, rather than the default clip to the
  # <html> box: the app's pages are short, and the folder picker is a fixed
  # overlay that the html box doesn't even cover, so element clipping
  # truncates exactly the screenshot that matters most.
  b$screenshot(
    filename = path, cliprect = c(0, 0, 1200, 780), scale = 2, show = FALSE
  )
  message(sprintf("  %-32s %d KB", file, round(file.size(path) / 1024)))
  invisible(TRUE)
}

# Shiny's file input is a real <input type=file>; the only way to populate it
# without a native file dialog is to hand Chrome the paths over CDP.
upload <- function(selector, path) {
  doc <- b$DOM$getDocument()
  node <- b$DOM$querySelector(doc$root$nodeId, selector)
  b$DOM$setFileInputFiles(files = list(path), nodeId = node$nodeId)
}

message("navigating to ", app_url)
b$Page$navigate(app_url)
wait_for_text("Select the folder", "step 1 to render")
Sys.sleep(1)

message("step 1")
shoot("prep-01-select-folder.png")

# The folder picker is a modal served by shinyFiles. Opening it for the
# screenshot is worth it — it is the one view that shows `home` resolving to
# the mounted volume, which is the whole point of running this under Docker.
click_text("Browse for folder")
wait_for_text("Select a BAM folder", "the folder picker modal")
Sys.sleep(2)
shoot("prep-01b-folder-picker.png")

# Close it again: the folder is set programmatically below rather than by
# clicking through the tree, so an open modal would otherwise sit on top of
# every later screenshot.
click_text("Cancel")
Sys.sleep(1)

# Rather than click through the modal's tree, set the input shinyFiles would
# have produced. parseDirPath() on the server takes it from here.
js(sprintf(
  "Shiny.setInputValue('dir_choose',
     {root: 'home', path: ['%s']}, {priority: 'event'})",
  folder
))
wait_for_text(folder, "the selected folder to be confirmed")
Sys.sleep(1)

message("step 2")
click_text("Next")
wait_for_text("Metadata TSV", "step 2 to render")
Sys.sleep(1)
upload("#tsv_file", tsv_path)
upload("#vcf_file", vcf_path)
wait_for_text("Validate", "both uploads to complete")
Sys.sleep(1.5)
shoot("prep-02-upload-files.png")

message("step 3")
click_text("Validate")
wait_for_text("Start extraction", "validation to pass")
Sys.sleep(1)
shoot("prep-03-validate.png")

message("step 4 (racing the progress bar)")
click_text("Start extraction")
# Poll hard: the bar is only on screen for a second or two. Keep shooting
# until the text reports a partial count, then stop.
deadline <- Sys.time() + 120
captured <- FALSE
repeat {
  txt <- body_text()
  if (is.character(txt) && grepl("Done!", txt)) {
    break
  }
  if (is.character(txt) && grepl("samples processed", txt)) {
    # Hold out for a bar that reads as genuinely mid-run rather than 0%,
    # but take whatever is on screen once the window starts closing.
    pct <- suppressWarnings(as.integer(
      sub(".*\\((\\d+)%\\).*", "\\1", gsub("\n", " ", txt))
    ))
    if (!is.na(pct) && pct >= 25) {
      shoot("prep-04-extract.png")
      captured <- TRUE
      break
    }
  }
  if (Sys.time() > deadline) {
    break
  }
}
if (!captured) {
  warning("never saw the progress bar; prep-04-extract.png not updated")
}

message("step 5")
wait_for_text("Done!", "extraction to finish")
Sys.sleep(1)
shoot("prep-05-done.png")

message("done")
