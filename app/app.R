library(shiny)
library(bslib)

ui <- page_navbar(
  title = "microhaplot2",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  nav_panel(
    "Accueil",
    layout_column_wrap(
      width = 1,
      card(
        card_header("microhaplot2"),
        card_body(
          p("Outil de construction et de curation de microhaplotypes à partir de séquences courtes."),
          p(
            tags$strong("Version :"), " 2.0 (en développement)",
            tags$br(),
            tags$strong("Statut :"), " initialisation de l'infrastructure"
          ),
          hr(),
          p(
            class = "text-muted",
            "Cette interface confirme le bon fonctionnement de la chaîne de déploiement.",
            tags$br(),
            "Les fonctionnalités d'analyse seront disponibles dans les prochaines versions."
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {}

shinyApp(ui, server)
