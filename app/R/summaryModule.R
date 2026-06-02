library(shiny)
library(bslib)
library(DT)

# summaryModule — exploratory visualisations by locus, individual, and group.
#
# Inputs:
#   haplo_data    reactive — raw data (group, id, locus, haplo, depth,
#                            allele.balance, rank)
#   filtered_data reactive — filtered data from filterAnnotationModule
#                            (same schema); used for HWE and entropy tabs.
#
# Parameters that control the display (pagination, group filter) are managed
# internally; the module emits no return value.

summaryUI <- function(id) {
  ns <- shiny::NS(id)
  bslib::navset_card_tab(
    title = "Résumé",
    bslib::nav_panel(
      "Par locus",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::selectInput(ns("locus_select"), "Locus",
                             choices = NULL, selected = NULL),
          shiny::actionButton(ns("locus_prev"), icon("chevron-left"),
                              class = "btn-sm btn-outline-secondary"),
          shiny::actionButton(ns("locus_next"), icon("chevron-right"),
                              class = "btn-sm btn-outline-secondary"),
          shiny::hr(),
          shiny::numericInput(ns("locus_per_page"), "Par page", value = 15,
                              min = 1, max = 100),
          shiny::numericInput(ns("locus_page"), "Page", value = 1, min = 1)
        ),
        bslib::layout_columns(
          col_widths = c(2, 2, 2, 3, 3),
          shiny::plotOutput(ns("haplo_density")),
          shiny::plotOutput(ns("uniq_haplo")),
          shiny::plotOutput(ns("frac_callable")),
          shiny::plotOutput(ns("read_depth")),
          shiny::plotOutput(ns("entropy_plot"))
        )
      )
    ),
    bslib::nav_panel(
      "HWE / Diversité",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::selectInput(ns("hwe_locus_select"), "Locus",
                             choices = NULL, selected = NULL)
        ),
        bslib::card(
          bslib::card_header("Fréquences diplotypiques observées vs attendues (HWE)"),
          DT::DTOutput(ns("hwe_table"))
        )
      )
    ),
    bslib::nav_panel(
      "Par individu",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          shiny::selectInput(ns("group_select"), "Groupe",
                             choices = NULL, selected = NULL),
          shiny::selectInput(ns("indiv_select"), "Individu",
                             choices = NULL, selected = NULL),
          shiny::actionButton(ns("indiv_prev"), icon("chevron-left"),
                              class = "btn-sm btn-outline-secondary"),
          shiny::actionButton(ns("indiv_next"), icon("chevron-right"),
                              class = "btn-sm btn-outline-secondary"),
          shiny::hr(),
          shiny::numericInput(ns("indiv_per_page"), "Par page", value = 15,
                              min = 1, max = 100),
          shiny::numericInput(ns("indiv_page"), "Page", value = 1, min = 1)
        ),
        bslib::layout_columns(
          col_widths = c(4, 4, 4),
          shiny::plotOutput(ns("allele_balance")),
          shiny::plotOutput(ns("uniq_haplo_indiv")),
          shiny::plotOutput(ns("frac_callable_indiv"))
        )
      )
    )
  )
}

summaryServer <- function(id, haplo_data, filtered_data = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Use filtered_data for HWE/entropy if provided; else fall back to haplo_data
    hwe_source <- shiny::reactive({
      if (!is.null(filtered_data) && !is.null(filtered_data())) {
        filtered_data()
      } else {
        haplo_data()
      }
    })

    # ---- derived labels -------------------------------------------------------

    all_loci <- shiny::reactive({
      req(haplo_data())
      sort(unique(haplo_data()$locus))
    })

    all_indiv <- shiny::reactive({
      req(haplo_data())
      d <- haplo_data()
      if (!is.null(input$group_select) && input$group_select != "ALL")
        d <- d[d$group == input$group_select, ]
      sort(unique(d$id))
    })

    shiny::observe({
      req(all_loci())
      shiny::updateSelectInput(session, "locus_select",
                               choices  = c("ALL", all_loci()),
                               selected = "ALL")
    })

    shiny::observe({
      req(haplo_data())
      grps <- c("ALL", sort(unique(haplo_data()$group)))
      shiny::updateSelectInput(session, "group_select",
                               choices  = grps,
                               selected = "ALL")
    })

    shiny::observe({
      req(all_indiv())
      shiny::updateSelectInput(session, "indiv_select",
                               choices  = c("ALL", all_indiv()),
                               selected = "ALL")
    })

    # ---- locus pagination -----------------------------------------------------

    loci_page <- shiny::reactive({
      req(all_loci())
      loci <- all_loci()
      if (!is.null(input$locus_select) && input$locus_select != "ALL")
        return(input$locus_select)
      n   <- length(loci)
      per <- max(1L, as.integer(input$locus_per_page %||% 15L))
      pg  <- max(1L, as.integer(input$locus_page %||% 1L))
      start <- (pg - 1L) * per + 1L
      end   <- min(n, pg * per)
      loci[start:end]
    })

    shiny::observeEvent(input$locus_prev, {
      req(input$locus_select)
      lbl <- c("ALL", all_loci())
      i   <- which(lbl == input$locus_select)
      if (i > 1L) shiny::updateSelectInput(session, "locus_select",
                                           selected = lbl[i - 1L])
    })
    shiny::observeEvent(input$locus_next, {
      req(input$locus_select)
      lbl <- c("ALL", all_loci())
      i   <- which(lbl == input$locus_select)
      if (i < length(lbl)) shiny::updateSelectInput(session, "locus_select",
                                                    selected = lbl[i + 1L])
    })

    # ---- individual pagination ------------------------------------------------

    indiv_page <- shiny::reactive({
      req(all_indiv())
      indiv <- all_indiv()
      if (!is.null(input$indiv_select) && input$indiv_select != "ALL")
        return(input$indiv_select)
      n   <- length(indiv)
      per <- max(1L, as.integer(input$indiv_per_page %||% 15L))
      pg  <- max(1L, as.integer(input$indiv_page %||% 1L))
      start <- (pg - 1L) * per + 1L
      end   <- min(n, pg * per)
      indiv[start:end]
    })

    shiny::observeEvent(input$indiv_prev, {
      req(input$indiv_select)
      lbl <- c("ALL", all_indiv())
      i   <- which(lbl == input$indiv_select)
      if (i > 1L) shiny::updateSelectInput(session, "indiv_select",
                                           selected = lbl[i - 1L])
    })
    shiny::observeEvent(input$indiv_next, {
      req(input$indiv_select)
      lbl <- c("ALL", all_indiv())
      i   <- which(lbl == input$indiv_select)
      if (i < length(lbl)) shiny::updateSelectInput(session, "indiv_select",
                                                    selected = lbl[i + 1L])
    })

    # ---- filtered data --------------------------------------------------------

    haplo_filtered <- shiny::reactive({
      req(haplo_data())
      d <- haplo_data()
      if (!is.null(input$group_select) && input$group_select != "ALL")
        d <- d[d$group == input$group_select, ]
      d
    })

    # ---- by-locus plots -------------------------------------------------------

    output$haplo_density <- shiny::renderPlot({
      req(haplo_filtered(), loci_page())
      tbl <- haplo_density_tbl(haplo_filtered())
      plot_haplo_density(tbl, loci_subset = loci_page())
    })

    output$uniq_haplo <- shiny::renderPlot({
      req(haplo_filtered(), loci_page())
      tbl <- uniq_haplo_per_locus(haplo_filtered())
      plot_uniq_haplo_per_locus(tbl, loci_subset = loci_page())
    })

    output$frac_callable <- shiny::renderPlot({
      req(haplo_filtered(), loci_page())
      n  <- dplyr::n_distinct(haplo_filtered()$id)
      tbl <- frac_callable_by_locus(haplo_filtered(), n_indiv = n)
      plot_frac_callable_indiv(tbl, loci_subset = loci_page())
    })

    output$read_depth <- shiny::renderPlot({
      req(haplo_filtered(), loci_page())
      tbl <- read_depth_by_locus(haplo_filtered())
      tbl <- tbl[tbl$locus %in% loci_page(), ]
      plot_read_depth_violin(tbl, loci_subset = loci_page())
    })

    # ---- by-individual plots --------------------------------------------------

    output$allele_balance <- shiny::renderPlot({
      req(haplo_filtered(), indiv_page())
      tbl <- allele_balance_by_indiv(haplo_filtered())
      plot_allele_balance_by_indiv(tbl, indiv_subset = indiv_page())
    })

    output$uniq_haplo_indiv <- shiny::renderPlot({
      req(haplo_filtered(), indiv_page())
      tbl <- haplo_counts_by_indiv(haplo_filtered())
      plot_uniq_haplo_by_indiv(tbl, indiv_subset = indiv_page())
    })

    output$frac_callable_indiv <- shiny::renderPlot({
      req(haplo_filtered(), indiv_page())
      n   <- dplyr::n_distinct(haplo_filtered()$locus)
      tbl <- frac_callable_by_indiv(haplo_filtered(), n_loci = n)
      plot_frac_callable_loci_by_indiv(tbl, indiv_subset = indiv_page())
    })

    # ---- entropy (5th by-locus plot) -----------------------------------------

    output$entropy_plot <- shiny::renderPlot({
      req(hwe_source(), loci_page())
      tbl <- shannon_entropy_per_locus(hwe_source())
      plot_entropy_by_locus(tbl, loci_subset = loci_page())
    })

    # ---- HWE tab -------------------------------------------------------------

    shiny::observe({
      req(hwe_source())
      loci <- sort(unique(hwe_source()$locus))
      shiny::updateSelectInput(session, "hwe_locus_select",
                               choices  = c("ALL", loci),
                               selected = loci[1])
    })

    hwe_data_for_locus <- shiny::reactive({
      req(hwe_source())
      d <- hwe_source()
      if (!is.null(input$hwe_locus_select) && input$hwe_locus_select != "ALL")
        d <- d[d$locus == input$hwe_locus_select, ]
      haplo_freq_tbl(d)
    })

    output$hwe_table <- DT::renderDT({
      req(hwe_data_for_locus())
      tbl <- hwe_data_for_locus()
      tbl$obs.freq      <- round(tbl$obs.freq, 4)
      tbl$expected.freq <- round(tbl$expected.freq, 4)
      DT::datatable(tbl,
                    rownames = FALSE,
                    options  = list(pageLength = 20, scrollX = TRUE))
    })
  })
}

# NULL-coalescing helper (base R ≥ 4.4 has this built in; inline for safety)
`%||%` <- function(x, y) if (!is.null(x)) x else y
