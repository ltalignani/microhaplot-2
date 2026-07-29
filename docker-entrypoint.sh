#!/usr/bin/env bash
set -e

case "$MICROHAPLOT_APP" in
  main|prep)
    ;;
  *)
    echo "MICROHAPLOT_APP must be set to 'main' or 'prep'" >&2
    exit 1
    ;;
esac

exec Rscript -e '
  options(shiny.host = "0.0.0.0", shiny.port = 3838)
  app <- Sys.getenv("MICROHAPLOT_APP")
  if (app == "main") {
    shiny_dir <- path.expand("~/Shiny")
    app_path  <- file.path(shiny_dir, "microhaplot")
    if (!dir.exists(app_path)) microhaplot::mvShinyHaplot(shiny_dir)
    microhaplot::runShinyHaplot(app_path)
  } else {
    microhaplot::runShinyHaplotPrep()
  }
'
