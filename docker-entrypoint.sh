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
    # Refresh the app on every start, not just the first. ui.R and server.R
    # live in the mounted volume, so a container that only seeded them once
    # would keep serving whatever version first created the folder: pulling a
    # newer image would change nothing the user could see. mvShinyHaplot()
    # copies with overwrite = TRUE and deletes nothing that is not part of
    # the app, so extracted .rds files and saved annotations are untouched.
    microhaplot::mvShinyHaplot(shiny_dir)
    microhaplot::runShinyHaplot(app_path)
  } else {
    microhaplot::runShinyHaplotPrep()
  }
'
