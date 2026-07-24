library(shiny)
library(shinyFiles)
library(microhaplot)

TSV_TEMPLATE_HEADER <- "bam_file\tindividual_id\tgroup\tcolor"

read_metadata_tsv <- function(path) {
  utils::read.delim(path, header = TRUE, sep = "\t", colClasses = "character",
                     check.names = FALSE, stringsAsFactors = FALSE)
}

shinyServer(function(input, output, session) {

  roots <- c(home = normalizePath("~"), getVolumes()())
  shinyDirChoose(input, "dir_choose", roots = roots, session = session)

  rv <- reactiveValues(
    step             = 1,
    folder           = NULL,
    tsv              = NULL,
    vcf              = NULL,
    extraction_error = NULL,
    result_rds       = NULL,
    result_posinfo   = NULL
  )

  observeEvent(input$dir_choose, {
    sel <- input$dir_choose
    if (is.list(sel) && length(sel$path) > 0) {
      rv$folder <- parseDirPath(roots, sel)
    }
  })

  observeEvent(input$tsv_file, rv$tsv <- input$tsv_file)
  observeEvent(input$vcf_file, rv$vcf <- input$vcf_file)

  run_extraction <- function() {
    rv$extraction_error <- NULL

    tryCatch({
      tsv_df <- read_metadata_tsv(rv$tsv$datapath)
      label_path <- tempfile(fileext = ".txt")
      build_prep_label_file(tsv_df, label_path)

      run.label <- paste0("prep_", format(Sys.time(), "%Y%m%d_%H%M%S"))
      out.path <- tempfile("microhaplot_prep_")
      dir.create(out.path)

      # Match the documented microhaplot workflow: a user-writable copy of
      # the visualization app under ~/Shiny/microhaplot (see README), not
      # the installed package directory itself, which is commonly
      # read-only and isn't where prepHaplotFiles()'s output is meant to
      # land for the user to open afterward.
      shiny_dir <- path.expand("~/Shiny")
      app.path <- file.path(shiny_dir, "microhaplot")
      if (!dir.exists(app.path)) mvShinyHaplot(shiny_dir)

      n.jobs <- max(1, parallel::detectCores() - 1)

      prepHaplotFiles(
        run.label = run.label,
        sam.path  = rv$folder,
        label.path = label_path,
        vcf.path  = rv$vcf$datapath,
        out.path  = out.path,
        app.path  = app.path,
        n.jobs    = n.jobs
      )
      rv$result_rds     <- file.path(app.path, paste0(run.label, ".rds"))
      rv$result_posinfo <- file.path(app.path, paste0(run.label, "_posinfo.rds"))
      rv$step <- 5
    }, error = function(e) {
      rv$extraction_error <- conditionMessage(e)
    })
  }

  observeEvent(input$next_step, {
    if (rv$step == 3) {
      rv$step <- 4
      run_extraction()
    } else if (rv$step < length(STEP_LABELS)) {
      rv$step <- rv$step + 1
    }
  })
  observeEvent(input$back_step, {
    if (rv$step > 1) rv$step <- rv$step - 1
  })

  output$template <- downloadHandler(
    filename = "metadata_template.tsv",
    content  = function(file) writeLines(TSV_TEMPLATE_HEADER, file)
  )

  step1_ui <- function() {
    tagList(
      p("Select the folder on your computer that contains all the BAM files for this run."),
      shinyDirButton("dir_choose", "Browse for folder…", "Select a BAM folder"),
      if (!is.null(rv$folder)) tags$p(style = "color:#27ae60;", paste("✓", rv$folder))
    )
  }

  step2_ui <- function() {
    tagList(
      p("Upload your metadata file (TSV) and the VCF defining the target SNPs."),
      fileInput("tsv_file", "Metadata TSV", accept = ".tsv"),
      downloadButton("template", "Download TSV template"),
      tags$br(), tags$br(),
      fileInput("vcf_file", "VCF file", accept = ".vcf")
    )
  }

  step4_ui <- function() {
    if (!is.null(rv$extraction_error)) {
      tagList(
        tags$p(style = "color:#c0392b;", paste("✗ Extraction failed:", rv$extraction_error)),
        p("Go back and check your inputs, then try again.")
      )
    } else {
      p("Extracting haplotypes… this can take a while for large batches. The app may appear unresponsive until this finishes.")
    }
  }

  step5_ui <- function() {
    tagList(
      tags$h4(style = "color:#27ae60;", "✓ Done!"),
      p("2 files were created:"),
      tags$ul(tags$li(rv$result_rds), tags$li(rv$result_posinfo)),
      p("Open microhaplot separately to explore your data.")
    )
  }

  # Computed once per entry to step 3; re-read whenever the inputs it
  # depends on change while step 3 is showing.
  validation <- reactive({
    req(rv$folder, rv$tsv, rv$vcf)
    tsv_df <- tryCatch(read_metadata_tsv(rv$tsv$datapath), error = function(e) NULL)
    if (is.null(tsv_df)) {
      return(list(ok = FALSE, errors = "Could not read the metadata TSV file.", warnings = character(), passes = character()))
    }
    validate_prep_inputs(rv$folder, tsv_df, rv$vcf$datapath)
  })

  step3_ui <- function() {
    res <- validation()
    tagList(
      p("Checking your files before starting extraction…"),
      lapply(res$passes, function(x) tags$p(style = "color:#27ae60;", paste("✓", x))),
      lapply(res$warnings, function(x) tags$p(style = "color:#e67e22;", paste("⚠", x))),
      lapply(res$errors, function(x) tags$p(style = "color:#c0392b;", paste("✗", x)))
    )
  }

  output$wizard <- renderUI({
    step <- rv$step
    tagList(
      step_indicator(step),
      switch(step,
        step1_ui(),
        step2_ui(),
        step3_ui(),
        step4_ui(),
        step5_ui()
      ),
      tags$div(
        style = "margin-top:24px; display:flex; gap:8px;",
        if (step > 1 && step < 5) actionButton("back_step", "← Back"),
        if (step == 1 && !is.null(rv$folder)) actionButton("next_step", "Next →"),
        if (step == 2 && !is.null(rv$tsv) && !is.null(rv$vcf)) actionButton("next_step", "Validate →"),
        if (step == 3 && isTRUE(validation()$ok)) actionButton("next_step", "Start extraction →")
      )
    )
  })
})
