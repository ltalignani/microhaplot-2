library(shiny)
library(shinyFiles)

STEP_LABELS <- c("Select folder", "Upload files", "Validate", "Extract", "Done")

step_indicator <- function(step) {
  tags$div(
    style = "display:flex; gap:4px; margin-bottom:20px;",
    lapply(seq_along(STEP_LABELS), function(i) {
      active <- i == step
      done <- i < step
      tags$div(
        style = sprintf(
          "flex:1; padding:8px; text-align:center; border-radius:6px; font-size:12px;
           background:%s; color:%s;",
          if (active) "#2c3e50" else if (done) "#27ae60" else "#ecf0f1",
          if (active || done) "#fff" else "#7f8c8d"
        ),
        sprintf("%d. %s", i, STEP_LABELS[i])
      )
    })
  )
}

shinyUI(fluidPage(
  titlePanel("microhaplot — Field Genotyping Prep"),
  uiOutput("wizard")
))
