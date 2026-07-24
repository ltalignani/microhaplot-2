Type: research
Status: open

## Question

What mechanism should this app use to let a user select a local folder
(containing potentially thousands of BAM files) from within a Shiny app
running locally — not deployed to a browser-only/server context? Survey
the options (e.g. the `shinyFiles` package, HTML5
`webkitdirectory`-attributed file inputs, a plain text path input with
validation, `rstudioapi`-based pickers when run inside RStudio, etc.),
their platform support (macOS/Linux/Windows), and trade-offs, and
recommend one.
