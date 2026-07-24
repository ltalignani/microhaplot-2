# REFERENCE ONLY — not production code, not wired to the real backend.
#
# Winning UI design for the field genotyping prep app (ticket 15,
# .scratch/field-prep-app/issues/15-ui-wireframe.md): a linear, step-gated
# wizard. Chosen over a single-scroll page and a persistent-sidebar layout
# for its lower per-screen cognitive load, judged the better fit for a
# non-technical, one-shot field task.
#
# Kept as a structural reference for whoever implements the real app later
# — folder selection, TSV/VCF handling, validation, and extraction are all
# faked here with canned data and a timer.
#
# Run: shiny::runApp(".scratch/field-prep-app/prototype")

library(shiny)

FAKE_FOLDER <- "~/Downloads/mosquito_run_2026-07/"
FAKE_BAM_N  <- 1247
FAKE_OK <- c(
  "1,247 of 1,247 BAM files referenced in metadata.tsv were found",
  "VCF chromosome names match the BAM reference names",
  "No truncated BAM files detected (samtools quickcheck)"
)
FAKE_WARN <- c(
  "3 BAM files in the folder aren't referenced in metadata.tsv and will be ignored: extra_01.bam, extra_02.bam, extra_03.bam"
)
STEP_LABELS <- c("Select folder", "Upload files", "Validate", "Extract", "Done")

wizard_ui <- function(rv) {
  step <- rv$step
  tagList(
    tags$h3("Field Genotyping Prep — Wizard"),
    tags$div(
      style = "display:flex; gap:4px; margin-bottom:20px;",
      lapply(seq_along(STEP_LABELS), function(i) {
        active <- i == step
        done <- i < step
        tags$div(
          style = sprintf(
            "flex:1; padding:8px; text-align:center; border-radius:6px; font-size:12px;
             background:%s; color:%s;",
            if (active) "#2c3e50" else if (done) "#27ae60" else "#ecf0f1",
            if (active || done) "#fff" else "#7f8c8d"
          ),
          sprintf("%d. %s", i, STEP_LABELS[i])
        )
      })
    ),
    if (step == 1) tagList(
      p("Select the folder on your computer that contains all the BAM files for this run."),
      actionButton("pick_folder", "Browse for folder…", icon = icon("folder-open")),
      if (!is.null(rv$folder)) tags$p(style = "color:#27ae60;", sprintf("✓ %s (%s BAM files found)", rv$folder, FAKE_BAM_N))
    ) else if (step == 2) tagList(
      p("Upload your metadata file (TSV) and the VCF defining the target SNPs."),
      fileInput("tsv", "Metadata TSV", accept = ".tsv"),
      downloadButton("template", "Download TSV template"),
      tags$br(), tags$br(),
      fileInput("vcf", "VCF file", accept = ".vcf")
    ) else if (step == 3) tagList(
      p("Checking your files before starting extraction…"),
      lapply(FAKE_OK, function(x) tags$p(style = "color:#27ae60;", paste("✓", x))),
      lapply(FAKE_WARN, function(x) tags$p(style = "color:#e67e22;", paste("⚠", x)))
    ) else if (step == 4) tagList(
      p("Extracting haplotypes… this can take a while for large batches."),
      tags$div(style = "background:#ecf0f1; border-radius:6px; overflow:hidden; height:24px;",
        tags$div(style = sprintf("background:#2c3e50; width:%d%%; height:100%%; transition:width .2s;", rv$progress))
      ),
      tags$p(sprintf("%d / %d samples processed (%d%%)", round(rv$progress / 100 * FAKE_BAM_N), FAKE_BAM_N, rv$progress))
    ) else tagList(
      tags$h4(style = "color:#27ae60;", "✓ Done!"),
      p("2 files were created and copied to your microhaplot app folder:"),
      tags$ul(tags$li("mosquito_run_2026-07-24.rds"), tags$li("mosquito_run_2026-07-24_posinfo.rds")),
      p("Open microhaplot to explore your data.")
    ),
    tags$div(
      style = "margin-top:24px; display:flex; gap:8px;",
      if (step > 1) actionButton("back", "← Back"),
      if (step == 1 && !is.null(rv$folder)) actionButton("next_step", "Next →"),
      if (step == 2) actionButton("next_step", "Validate →"),
      if (step == 3) actionButton("next_step", "Start extraction →"),
      if (step == 4 && rv$progress >= 100) actionButton("next_step", "Continue →")
    )
  )
}

ui <- fluidPage(uiOutput("wizard"))

server <- function(input, output, session) {
  rv <- reactiveValues(step = 1, folder = NULL, progress = 0)

  observeEvent(input$pick_folder, rv$folder <- FAKE_FOLDER)
  observeEvent(input$next_step, {
    if (rv$step < 5) rv$step <- rv$step + 1
    if (rv$step == 4) rv$extracting <- TRUE
  })
  observeEvent(input$back, if (rv$step > 1) rv$step <- rv$step - 1)

  timer <- reactiveTimer(150)
  observe({
    timer()
    isolate({
      if (isTRUE(rv$extracting) && rv$progress < 100) {
        rv$progress <- min(100, rv$progress + 4)
        if (rv$progress >= 100) rv$extracting <- FALSE
      }
    })
  })

  output$template <- downloadHandler(
    filename = "metadata_template.tsv",
    content = function(file) writeLines("bam_file\tindividual_id\tgroup\tcolor", file)
  )

  output$wizard <- renderUI(wizard_ui(rv))
}

shinyApp(ui, server)
