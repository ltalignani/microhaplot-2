library(shiny)
library(shinyFiles)

TSV_TEMPLATE_HEADER <- "bam_file\tindividual_id\tgroup\tcolor"

shinyServer(function(input, output, session) {

  roots <- c(home = normalizePath("~"), getVolumes()())
  shinyDirChoose(input, "dir_choose", roots = roots, session = session)

  rv <- reactiveValues(
    step   = 1,
    folder = NULL,
    tsv    = NULL,
    vcf    = NULL
  )

  observeEvent(input$dir_choose, {
    sel <- input$dir_choose
    if (is.list(sel) && length(sel$path) > 0) {
      rv$folder <- parseDirPath(roots, sel)
    }
  })

  observeEvent(input$tsv_file, rv$tsv <- input$tsv_file)
  observeEvent(input$vcf_file, rv$vcf <- input$vcf_file)

  observeEvent(input$next_step, {
    if (rv$step < length(STEP_LABELS)) rv$step <- rv$step + 1
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

  placeholder_ui <- function(label) {
    tags$div(style = "color:#7f8c8d;", p(sprintf("%s — coming soon.", label)))
  }

  output$wizard <- renderUI({
    step <- rv$step
    tagList(
      step_indicator(step),
      switch(step,
        step1_ui(),
        step2_ui(),
        placeholder_ui("Validate"),
        placeholder_ui("Extract"),
        placeholder_ui("Done")
      ),
      tags$div(
        style = "margin-top:24px; display:flex; gap:8px;",
        if (step > 1) actionButton("back_step", "← Back"),
        if (step == 1 && !is.null(rv$folder)) actionButton("next_step", "Next →"),
        if (step == 2 && !is.null(rv$tsv) && !is.null(rv$vcf)) actionButton("next_step", "Validate →"),
        if (step >= 3 && step < length(STEP_LABELS)) actionButton("next_step", "Next →")
      )
    )
  })
})
