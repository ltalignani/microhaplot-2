# Runs inside a container. Sources the Shiny app's own ui.R and server.R to
# prove they load in this image.
#
# This exists because an HTTP 200 proves almost nothing: Shiny serves the page
# over plain HTTP, but the server function only runs when a browser opens a
# websocket. An app whose very first lines fail — `library()` on a package
# that is not a declared dependency, say — still answers 200 while every
# session dies on connect and the UI comes up empty. That shipped once
# already; this is the check that would have caught it.

app <- file.path(Sys.getenv("HOME"), "Shiny", "microhaplot")
if (!dir.exists(app)) stop("no Shiny app directory at ", app)

for (f in c("ui.R", "server.R")) {
  path <- file.path(app, f)
  if (!file.exists(path)) stop("missing ", path)
  tryCatch(
    local(source(path, local = TRUE)),
    error = function(e) {
      stop(f, " failed to load: ", conditionMessage(e), call. = FALSE)
    }
  )
  cat(sprintf("  %-10s loads\n", f))
}
