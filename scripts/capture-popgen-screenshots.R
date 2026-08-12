# Captures the Population Genetics screenshots used by the
# "microhaplot walkthrough" vignette.
#
# The vignette documents these four tabs against fish2.rds, the only bundled
# dataset with more than one group — F-statistics and the outlier scan are
# between-group analyses and are meaningless on fish1.rds.
#
# Usage, from the repository root:
#   Rscript scripts/capture-popgen-screenshots.R [app_url]
#
# With no argument the script starts its own Shiny instance from a temporary
# mvShinyHaplot() directory, so it needs nothing running beforehand. Pass a
# URL (e.g. http://localhost:3838) to shoot an app that is already up.
#
# Re-run this whenever the Population Genetics UI changes; the PNGs it writes
# into vignettes/ are meant to be regenerated, not hand-edited.

library(chromote)

args <- commandArgs(trailingOnly = TRUE)

out_dir <- file.path(getwd(), "vignettes")
if (!dir.exists(out_dir)) {
  stop("run this from the repository root (no ./vignettes here)")
}

dataset <- "fish2.rds"

# PCA / Projection and Outlier scan are two-phase: nothing is computed until
# "Explore" runs, and the Phase 2 button only exists once Phase 1 has
# rendered. Capturing them without driving those buttons yields an empty
# form, so each tab carries the sequence of buttons to press first.
#
# Every tab defaults to the "Raw" data source, which on these datasets scores
# nearly every individual heterozygous (Ho = 1, strongly negative Fis) because
# an unfiltered top-2-haplotype diplotype is heterozygous by construction.
# "Filtered" is the honest view, so it is what the vignette shows — except for
# one deliberate Raw capture kept to illustrate exactly that trap.
radio <- function(id, value = "filtered") {
  sprintf("input[name=%s][value=%s]", id, value)
}

tabs <- list(
  list(
    label = "F-statistics",
    file = "popgen-fstatistics-raw.png",
    clicks = radio("popgenDataSource_fstats", "raw")
  ),
  list(
    label = "F-statistics",
    file = "popgen-fstatistics.png",
    clicks = radio("popgenDataSource_fstats")
  ),
  list(
    label = "Allelic diversity",
    file = "popgen-allelic-diversity.png",
    clicks = radio("popgenDataSource_richness")
  ),
  list(
    label = "PCA / Projection",
    file = "popgen-pca.png",
    clicks = c(radio("popgenDataSource_pca"),
               "#popgenPcaExploreBtn", "#popgenPcaRunBtn")
  ),
  list(
    label = "Outlier scan",
    file = "popgen-outlier-scan.png",
    clicks = c(radio("popgenDataSource_outlier"),
               "#popgenPcadaptExploreBtn", "#popgenPcadaptRunBtn")
  )
)

# ---- app under test ---------------------------------------------------------

owned_process <- NULL
if (length(args) >= 1) {
  app_url <- args[[1]]
} else {
  port <- 7799
  app_url <- paste0("http://127.0.0.1:", port, "/")
  shiny_dir <- tempfile("mhshiny_")
  dir.create(shiny_dir)
  microhaplot::mvShinyHaplot(shiny_dir)
  app_path <- file.path(shiny_dir, "microhaplot")
  owned_process <- callr::r_bg(
    function(app_path, port) {
      options(shiny.host = "127.0.0.1", shiny.port = port,
              shiny.launch.browser = FALSE)
      microhaplot::runShinyHaplot(app_path)
    },
    args = list(app_path = app_path, port = port)
  )
  message("started a Shiny instance on ", app_url)
  Sys.sleep(8)
}

on.exit({
  if (!is.null(owned_process) && owned_process$is_alive()) {
    owned_process$kill()
  }
}, add = TRUE)

# ---- browser ----------------------------------------------------------------

b <- ChromoteSession$new(width = 1400, height = 900)
on.exit(b$close(), add = TRUE)

js <- function(expr) b$Runtime$evaluate(expr)$result$value

quote_js <- function(x) paste0("'", gsub("'", "\\\\'", x), "'")

# Shiny flags itself busy on <html> while any output is recalculating. Polling
# that is far more reliable than a fixed sleep, which either flakes on a slow
# plot or wastes time on a fast one.
wait_idle <- function(timeout = 60) {
  deadline <- Sys.time() + timeout
  Sys.sleep(0.5)
  repeat {
    busy <- js("document.documentElement.classList.contains('shiny-busy')")
    if (isFALSE(busy)) {
      break
    }
    if (Sys.time() > deadline) {
      warning("still busy after ", timeout, "s; capturing anyway")
      break
    }
    Sys.sleep(0.4)
  }
  Sys.sleep(1)
}

# Polls a JS predicate until it returns true. Needed because "Shiny is idle"
# is not the same as "the server has sent its updateSelectInput yet": on a
# fast load the busy flag can clear before the dataset list arrives, and
# setValue() on an option selectize doesn't know about silently sets "".
wait_for <- function(predicate, what, timeout = 60) {
  deadline <- Sys.time() + timeout
  repeat {
    if (isTRUE(js(predicate))) {
      return(invisible(TRUE))
    }
    if (Sys.time() > deadline) {
      stop("timed out waiting for ", what)
    }
    Sys.sleep(0.4)
  }
}

click_by_text <- function(text) {
  script <- sprintf(
    "(function(){var a=Array.from(document.querySelectorAll('a')).find(
       function(x){return x.textContent.trim()===%s;});
     if(!a){return false;} a.click(); return true;})()",
    quote_js(text)
  )
  if (!isTRUE(js(script))) {
    stop("could not find a link labelled: ", text)
  }
}

click_selector <- function(selector) {
  wait_for(
    sprintf("!!document.querySelector(%s)", quote_js(selector)),
    paste("element", selector, "to appear")
  )
  js(sprintf("document.querySelector(%s).click()", quote_js(selector)))
  wait_idle()
}

# The navbar is position:fixed-bottom, so in a full-page screenshot it floats
# across the middle of the image instead of sitting at an edge. Pinning it to
# static makes it flow with the document and the capture readable.
unpin_navbar <- function() {
  js("(function(){var s=document.createElement('style');
      s.innerHTML='.navbar-fixed-bottom{position:static !important;}';
      document.head.appendChild(s);})()")
}

b$Page$navigate(app_url)
wait_idle()

wait_for(
  sprintf(
    "(function(){var e=$('#selectDB')[0];
       return !!(e && e.selectize && e.selectize.options[%s]);})()",
    quote_js(dataset)
  ),
  paste(dataset, "to appear in the Data Set dropdown")
)

# Pick the dataset. The widget is selectized, so setting the underlying
# <select> alone would not notify Shiny.
select_script <- sprintf(
  "(function(){var s=$('#selectDB')[0].selectize;
     if(!s){return 'no selectize';} s.setValue(%s); return s.getValue();})()",
  quote_js(dataset)
)
selected <- js(select_script)
if (!identical(selected, dataset)) {
  stop("failed to select ", dataset, "; got: ", selected)
}
wait_idle()

for (tab in tabs) {
  click_by_text("Population Genetics")
  Sys.sleep(0.3)
  click_by_text(tab$label)
  wait_idle()
  for (selector in tab$clicks) {
    click_selector(selector)
  }
  unpin_navbar()
  Sys.sleep(0.5)
  path <- file.path(out_dir, tab$file)
  b$screenshot(filename = path, show = FALSE)
  message(sprintf("%-20s -> %s (%d KB)", tab$label, tab$file,
                  round(file.size(path) / 1024)))
}

message("done")
