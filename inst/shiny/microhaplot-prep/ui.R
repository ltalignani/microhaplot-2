library(shiny)
library(shinyFiles)

shinyUI(fluidPage(
  titlePanel("microhaplot — Field Genotyping Prep"),
  uiOutput("wizard")
))
