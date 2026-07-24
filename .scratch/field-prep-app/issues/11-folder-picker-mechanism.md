Type: research
Status: resolved

## Question

What mechanism should this app use to let a user select a local folder
(containing potentially thousands of BAM files) from within a Shiny app
running locally — not deployed to a browser-only/server context? Survey
the options (e.g. the `shinyFiles` package, HTML5
`webkitdirectory`-attributed file inputs, a plain text path input with
validation, `rstudioapi`-based pickers when run inside RStudio, etc.),
their platform support (macOS/Linux/Windows), and trade-offs, and
recommend one.

## Answer

`shinyFiles::shinyDirButton()` / `shinyDirChoose()` — purpose-built for
browsing the local filesystem from a locally-run Shiny app, cross-platform,
actively maintained, stays inside the browser window (no native-dialog
focus/z-order risk). HTML5 `webkitdirectory` was disqualified (it's
actually a per-file upload in disguise, ruled out already). `rstudioapi`
requires RStudio to be running (too fragile). `tcltk::tk_choose.dir()` is
a plausible runner-up but risks the native dialog opening behind the
browser window, confusing for this non-technical audience. Full survey:
[folder-picker research](11-folder-picker-research.md).
