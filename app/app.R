library(shiny)
library(bslib)
library(here)

source(here("app/R/extraction.R"))
source(here("app/R/input_validation.R"))
source(here("app/R/dataInputModule.R"))
source(here("app/R/summary_stats.R"))
source(here("app/R/summaryModule.R"))

ui <- page_navbar(
  title = "microhaplot2",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  nav_panel(
    "Saisie des données",
    dataInputUI("data_input")
  ),
  nav_panel(
    "Résumé",
    summaryUI("summary")
  )
)

server <- function(input, output, session) {
  result <- dataInputServer("data_input")
  summaryServer("summary", reactive(result$haplo_data))
}

shinyApp(ui, server)
