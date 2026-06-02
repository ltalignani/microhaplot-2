library(shiny)
library(bslib)

# outputModule — CSV download of raw and filtered haplotype tables.
#
# Inputs:
#   haplo_data    — reactive() returning the raw haplo_data data.frame
#   filtered_data — reactive() returning the filtered haplo_data data.frame
#   run_label     — reactive() returning a character scalar used in filenames
#                   (defaults to "microhaplot" when NULL / empty)

outputUI <- function(id) {
  ns <- shiny::NS(id)

  bslib::layout_columns(
    col_widths = c(4, 8),

    bslib::card(
      bslib::card_header("Sélection des colonnes"),

      bslib::card(
        bslib::card_header("Tableau brut", class = "bg-light"),
        shiny::uiOutput(ns("raw_field_selector"))
      ),

      bslib::card(
        bslib::card_header("Tableau filtré (diploïdes)", class = "bg-light"),
        shiny::uiOutput(ns("filtered_field_selector"))
      )
    ),

    bslib::layout_columns(
      col_widths = c(12),

      bslib::card(
        bslib::card_header("Tableau brut"),
        shiny::downloadButton(ns("dl_raw"), "Télécharger (brut)",
                              class = "btn-outline-primary mb-2"),
        DT::dataTableOutput(ns("raw_preview"))
      ),

      bslib::card(
        bslib::card_header("Tableau filtré — résumé diploïde"),
        shiny::downloadButton(ns("dl_filtered"), "Télécharger (filtré)",
                              class = "btn-outline-success mb-2"),
        DT::dataTableOutput(ns("filtered_preview"))
      )
    )
  )
}

outputServer <- function(id, haplo_data, filtered_data, run_label = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    effective_label <- shiny::reactive({
      lbl <- if (is.null(run_label)) NULL else run_label()
      if (is.null(lbl) || nchar(trimws(lbl)) == 0L) "microhaplot" else trimws(lbl)
    })

    # Dynamic field checkboxes for the raw table
    raw_cols <- shiny::reactive({
      shiny::req(haplo_data())
      names(haplo_data())
    })

    output$raw_field_selector <- shiny::renderUI({
      shiny::checkboxGroupInput(
        session$ns("raw_fields"), NULL,
        choices  = raw_cols(),
        selected = raw_cols()
      )
    })

    # Dynamic field checkboxes for the diploid table
    diploid_cols <- c("group", "id", "locus",
                      "haplotype.1", "read.depth.1",
                      "haplotype.2", "read.depth.2", "ar")

    output$filtered_field_selector <- shiny::renderUI({
      shiny::checkboxGroupInput(
        session$ns("filtered_fields"), NULL,
        choices  = diploid_cols,
        selected = diploid_cols
      )
    })

    # Prepared tables
    raw_table <- shiny::reactive({
      shiny::req(haplo_data())
      select_fields(haplo_data(), input$raw_fields)
    })

    diploid_table <- shiny::reactive({
      shiny::req(filtered_data())
      dip <- pivot_diploid(filtered_data())
      select_fields(dip, input$filtered_fields)
    })

    # Previews
    output$raw_preview <- DT::renderDataTable({
      raw_table()
    }, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)

    output$filtered_preview <- DT::renderDataTable({
      diploid_table()
    }, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)

    # Downloads
    output$dl_raw <- shiny::downloadHandler(
      filename = function() make_filename(effective_label(), "raw"),
      content  = function(file) utils::write.csv(raw_table(), file, row.names = FALSE)
    )

    output$dl_filtered <- shiny::downloadHandler(
      filename = function() make_filename(effective_label(), "filtered"),
      content  = function(file) utils::write.csv(diploid_table(), file, row.names = FALSE)
    )

    invisible(NULL)
  })
}
