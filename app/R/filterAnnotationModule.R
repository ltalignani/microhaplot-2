library(shiny)
library(bslib)

# filterAnnotationModule — per-locus filter controls and annotation.
#
# Input:  haplo_data  — reactive() returning the raw haplo_data data.frame
#                       (from dataInputServer result$haplo_data)
#         session_dir — character scalar, writable temp dir for this session
#                       (defaults to a per-session tempdir so concurrent users
#                        never overwrite each other's annotations)
#
# Returns: list with one reactive:
#   $filtered_data — haplo_data after applying the current filter params

filterAnnotationUI <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      width = 320,
      shiny::selectInput(ns("locus"), "Locus", choices = NULL),

      shiny::hr(),
      shiny::h6("Paramètres de filtrage"),

      shiny::selectInput(
        ns("filter_mode"), "Mode",
        choices  = c("Global" = "global",
                     "Local par locus" = "local",
                     "Minimum de référence" = "min_baseline"),
        selected = "global"
      ),

      shiny::numericInput(ns("min_rd"),    "min.rd (profondeur min.)",   value = 10,  min = 0),
      shiny::numericInput(ns("min_ar"),    "min.ar (ratio allélique min.)", value = 0.1, min = 0, max = 1, step = 0.05),
      shiny::numericInput(ns("n_alleles"), "n.alleles (nb max haplo.)",  value = 2,   min = 1, step = 1),
      shiny::numericInput(ns("max_ar_hm"), "max.ar.hm (hom. max)",       value = 0.9, min = 0, max = 1, step = 0.05),
      shiny::numericInput(ns("min_ar_hz"), "min.ar.hz (hét. min.)",      value = 0.3, min = 0, max = 1, step = 0.05),

      shiny::actionButton(ns("save_params"), "Enregistrer paramètres du locus",
                          class = "btn-sm btn-outline-primary w-100"),

      shiny::hr(),
      shiny::h6("Annotation du locus"),
      shiny::textAreaInput(ns("comment"), "Commentaire", rows = 2),
      shiny::selectInput(ns("status"), "Statut",
                         choices = c("—" = "", "Accept" = "Accept", "Reject" = "Reject")),
      shiny::actionButton(ns("save_ann"), "Enregistrer annotation",
                          class = "btn-sm btn-outline-success w-100")
    ),

    bslib::layout_columns(
      col_widths = c(12),
      bslib::card(
        bslib::card_header("Résumé du filtrage par locus"),
        shiny::tableOutput(ns("filter_tbl"))
      ),
      bslib::card(
        bslib::card_header("Annotations enregistrées"),
        shiny::tableOutput(ns("ann_tbl"))
      )
    )
  )
}

filterAnnotationServer <- function(id, haplo_data, session_dir = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    if (is.null(session_dir)) {
      session_dir <- tempfile("microhaplot_session_")
      dir.create(session_dir, recursive = TRUE)
    }

    # Per-locus saved params stored in memory for this session
    local_params_store <- shiny::reactiveValues()

    # Update locus selector when haplo_data arrives
    shiny::observe({
      shiny::req(haplo_data())
      loci <- sort(unique(haplo_data()$locus))
      shiny::updateSelectInput(session, "locus", choices = loci,
                               selected = loci[[1L]])
    })

    # When locus changes, load its saved params (if any) and fill inputs
    shiny::observeEvent(input$locus, {
      shiny::req(input$locus)
      saved <- local_params_store[[input$locus]]
      if (!is.null(saved)) {
        shiny::updateNumericInput(session, "min_rd",    value = saved$min_rd)
        shiny::updateNumericInput(session, "min_ar",    value = saved$min_ar)
        shiny::updateNumericInput(session, "n_alleles", value = saved$n_alleles)
        shiny::updateNumericInput(session, "max_ar_hm", value = saved$max_ar_hm)
        shiny::updateNumericInput(session, "min_ar_hz", value = saved$min_ar_hz)
      }
      # Load saved annotation into inputs
      ann <- load_annotation(input$locus, session_dir)
      if (!is.null(ann)) {
        shiny::updateTextAreaInput(session, "comment", value = ann$comment)
        shiny::updateSelectInput(session, "status", selected = ann$status)
      } else {
        shiny::updateTextAreaInput(session, "comment", value = "")
        shiny::updateSelectInput(session, "status", selected = "")
      }
    })

    # Save per-locus params to in-memory store
    shiny::observeEvent(input$save_params, {
      shiny::req(input$locus)
      local_params_store[[input$locus]] <- list(
        min_rd    = input$min_rd,
        min_ar    = input$min_ar,
        n_alleles = as.integer(input$n_alleles),
        max_ar_hm = input$max_ar_hm,
        min_ar_hz = input$min_ar_hz
      )
    })

    # Save annotation to session tempdir
    shiny::observeEvent(input$save_ann, {
      shiny::req(input$locus)
      save_annotation(input$locus,
                      comment     = input$comment %||% "",
                      status      = input$status  %||% "",
                      session_dir = session_dir)
      shiny::showNotification(
        paste0("Annotation enregistrée pour ", input$locus),
        type = "message", duration = 3
      )
    })

    # Effective params for the selected locus
    current_params <- shiny::reactive({
      global <- list(
        min_rd    = input$min_rd    %||% 10,
        min_ar    = input$min_ar    %||% 0.1,
        n_alleles = as.integer(input$n_alleles %||% 2L),
        max_ar_hm = input$max_ar_hm %||% 0.9,
        min_ar_hz = input$min_ar_hz %||% 0.3
      )
      local <- local_params_store[[input$locus %||% ""]]
      resolve_filter_params(
        locus         = input$locus %||% "",
        global_params = global,
        local_params  = local,
        mode          = input$filter_mode %||% "global"
      )
    })

    # Filtered data across all loci using the global params
    filtered_data <- shiny::reactive({
      shiny::req(haplo_data())
      global <- list(
        min_rd    = input$min_rd    %||% 10,
        min_ar    = input$min_ar    %||% 0.1,
        n_alleles = as.integer(input$n_alleles %||% 2L),
        max_ar_hm = input$max_ar_hm %||% 0.9,
        min_ar_hz = input$min_ar_hz %||% 0.3
      )
      filter_by_rd_ar(haplo_data(), global)
    })

    # Filter summary table for all loci
    output$filter_tbl <- shiny::renderTable({
      shiny::req(haplo_data())
      global <- list(
        min_rd    = input$min_rd    %||% 10,
        min_ar    = input$min_ar    %||% 0.1,
        n_alleles = as.integer(input$n_alleles %||% 2L),
        max_ar_hm = input$max_ar_hm %||% 0.9,
        min_ar_hz = input$min_ar_hz %||% 0.3
      )
      s <- filter_summary(haplo_data(), global)
      s$callable <- ifelse(s$callable, "Oui", "Non")
      s
    }, striped = TRUE, hover = TRUE)

    # Annotation table
    output$ann_tbl <- shiny::renderTable({
      input$save_ann  # re-run on save
      load_all_annotations(session_dir)
    }, striped = TRUE, hover = TRUE)

    list(filtered_data = filtered_data)
  })
}

# Null-coalescing operator (compatible with R < 4.4)
`%||%` <- function(x, y) if (!is.null(x)) x else y
