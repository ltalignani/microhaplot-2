library(shiny)
library(bslib)
library(here)

source(here("app/R/extraction.R"))
source(here("app/R/input_validation.R"))
source(here("app/R/dataInputModule.R"))

ui <- page_navbar(
  title = "microhaplot2",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  nav_panel(
    "Saisie des données",
    dataInputUI("data_input")
  )
)

server <- function(input, output, session) {
  result <- dataInputServer("data_input")
}

shinyApp(ui, server)
