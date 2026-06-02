inferentialUI <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header(
      shiny::tags$span(
        class = "badge bg-warning text-dark me-2",
        "En développement"
      ),
      "Analyse inférentielle"
    ),
    bslib::card_body(
      shiny::tags$div(
        class = "alert alert-info",
        role  = "alert",
        shiny::tags$h5(
          class = "alert-heading",
          "Fonctionnalité en développement"
        ),
        shiny::tags$p(
          "Cette section accueillera un module d'inférence bayésienne pour le ",
          "phasage des haplotypes en diplotypes.",
          "L'algorithme prévu est un échantillonneur de Gibbs hiérarchique ",
          "qui infère les vrais haplotypes diploïdes à partir des lectures ",
          "brutes par locus, en tenant compte des probabilités d'erreur de ",
          "séquençage et des fréquences alléliques de la population."
        ),
        shiny::tags$hr(),
        shiny::tags$p(
          class = "mb-0",
          "Pour toute question ou pour contribuer au développement de cette ",
          "fonctionnalité, veuillez contacter l'équipe de développement à ",
          shiny::tags$a(
            href  = "mailto:loic.talignani@ird.fr",
            "loic.talignani@ird.fr"
          ), "."
        )
      )
    )
  )
}

inferentialServer <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    invisible(NULL)
  })
}
