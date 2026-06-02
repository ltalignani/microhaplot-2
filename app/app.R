library(shiny)
library(bslib)
library(DT)
library(here)

source(here("app/R/extraction.R"))
source(here("app/R/input_validation.R"))
source(here("app/R/dataInputModule.R"))
source(here("app/R/summary_stats.R"))
source(here("app/R/summaryModule.R"))
source(here("app/R/filter_annotation.R"))
source(here("app/R/filterAnnotationModule.R"))
source(here("app/R/inferentialModule.R"))
source(here("app/R/output_utils.R"))
source(here("app/R/outputModule.R"))

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
  ),
  nav_panel(
    "Filtrage",
    filterAnnotationUI("filter_ann")
  ),
  nav_panel(
    "Téléchargement",
    outputUI("output_dl")
  ),
  nav_panel(
    "Analyse inférentielle",
    inferentialUI("inferential")
  )
)

server <- function(input, output, session) {
  result      <- dataInputServer("data_input")
  filter_res  <- filterAnnotationServer("filter_ann", result$haplo_data)
  summaryServer("summary", result$haplo_data)
  outputServer("output_dl",
               haplo_data    = result$haplo_data,
               filtered_data = filter_res$filtered_data,
               run_label     = result$run_label)
  inferentialServer("inferential")
}

shinyApp(ui, server)
