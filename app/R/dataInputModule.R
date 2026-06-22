library(shiny)
library(bslib)
source(here::here("app/R/input_validation.R"))
source(here::here("app/R/extraction.R"))

dataInputUI <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Données d'entrée"),
      card_body(
        layout_column_wrap(
          width = 1/2,
          card(
            card_header("Métadonnées (CSV)"),
            fileInput(ns("csv_file"), "Fichier CSV des métadonnées",
                      accept = ".csv", buttonLabel = "Parcourir…"),
            downloadButton(ns("csv_template"), "Télécharger le modèle CSV",
                           class = "btn-outline-secondary btn-sm")
          ),
          card(
            card_header("Variants (VCF)"),
            fileInput(ns("vcf_file"), "Fichier VCF des SNP cibles",
                      accept = c(".vcf", ".vcf.gz", "application/gzip",
                                 "application/x-gzip", "text/plain"),
                      buttonLabel = "Parcourir…"),
            shiny::helpText("Pour les fichiers volumineux (.vcf.gz > 1 Go), la barre ",
                            "atteint 100 % dès la fin du transfert réseau. ",
                            "Le message « Upload complete » confirme que le fichier ",
                            "est prêt — attendez-le avant de lancer l'extraction.")
          )
        ),
        uiOutput(ns("validation_errors")),
        actionButton(ns("run"), "Lancer l'extraction",
                     class = "btn-primary mt-2",
                     icon = icon("play")),
        uiOutput(ns("run_errors"))
      )
    )
  )
}

dataInputServer <- function(id, data_dir = NULL) {
  moduleServer(id, function(input, output, session) {

    output$csv_template <- downloadHandler(
      filename = "microhaplot2_metadata_template.csv",
      content  = function(file) write.csv(csv_template(), file, row.names = FALSE)
    )

    # Reactive: parsed metadata data.frame or NULL
    meta_df <- reactive({
      req(input$csv_file)
      tryCatch(
        read.csv(input$csv_file$datapath, stringsAsFactors = FALSE),
        error = function(e) NULL
      )
    })

    # Reactive: validation result list
    validation <- reactive({
      df <- meta_df()
      if (is.null(df)) return(list(ok = FALSE, errors = "Impossible de lire le fichier CSV."))

      csv_check <- validate_metadata_csv(df)
      if (!csv_check$ok) return(csv_check)

      resolve_bam_paths(df, data_dir = data_dir)
    })

    output$validation_errors <- renderUI({
      req(input$csv_file)
      v <- validation()
      if (v$ok) return(NULL)
      div(class = "alert alert-danger mt-2",
          tags$ul(lapply(v$errors, tags$li)))
    })

    # Reactive: extraction result tibble (triggered by Run button)
    result <- eventReactive(input$run, {
      req(input$csv_file, input$vcf_file)
      v <- validation()
      if (!v$ok) return(NULL)

      df <- meta_df()
      resolved_dir <- if (!is.null(data_dir)) data_dir else
        Sys.getenv("MICROHAPLOT_DATA_DIR", unset = "/data/lovelace")

      # Rename individual_id → id for extraction engine
      meta <- data.frame(
        bam_file = df$bam_file,
        id       = df$individual_id,
        group    = df$group,
        stringsAsFactors = FALSE
      )

      vcf_path <- input$vcf_file$datapath
      n <- nrow(meta)
      withProgress(message = "Extraction en cours…", value = 0, {
        rows <- lapply(seq_len(n), function(i) {
          incProgress(1 / n, detail = paste("BAM", i, "/", n))
          extract_haplotypes(resolved_dir, vcf_path, meta[i, , drop = FALSE])
        })
      })

      do.call(rbind, rows)
    })

    output$run_errors <- renderUI({
      req(input$run)
      v <- validation()
      if (v$ok) return(NULL)
      div(class = "alert alert-warning mt-2",
          "Veuillez corriger les erreurs ci-dessus avant de lancer l'extraction.")
    })

    run_label <- reactive({
      req(input$vcf_file)
      tools::file_path_sans_ext(basename(input$vcf_file$name))
    })

    list(haplo_data = result, run_label = run_label)
  })
}
