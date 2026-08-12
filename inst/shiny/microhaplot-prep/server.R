library(shiny)
library(shinyFiles)
library(microhaplot)
library(future)
library(promises)

future::plan(future::multisession)

# Shiny's default upload ceiling is 5 MB, which rejects any realistic VCF —
# a panel of a few hundred amplicons across a field campaign runs to tens or
# hundreds of megabytes. Raise it, and let it be raised further still with
# MICROHAPLOT_MAX_UPLOAD_MB for anyone whose VCF is larger again.
max_upload_mb <- suppressWarnings(
  as.numeric(Sys.getenv("MICROHAPLOT_MAX_UPLOAD_MB", "2048"))
)
if (is.na(max_upload_mb) || max_upload_mb <= 0) max_upload_mb <- 2048
options(shiny.maxRequestSize = max_upload_mb * 1024^2)

TSV_TEMPLATE_HEADER <- "bam_file\tindividual_id\tgroup\tcolor"
STEP_LABELS <- c("Select folder", "Upload files", "Validate", "Extract", "Done")

read_metadata_tsv <- function(path) {
  utils::read.delim(path, header = TRUE, sep = "\t", colClasses = "character",
                     check.names = FALSE, stringsAsFactors = FALSE)
}

step_indicator <- function(step) {
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
  )
}

shinyServer(function(input, output, session) {

  roots <- c(home = normalizePath("~"), getVolumes()())
  shinyDirChoose(input, "dir_choose", roots = roots, session = session)

  rv <- reactiveValues(
    step             = 1,
    folder           = NULL,
    tsv              = NULL,
    vcf              = NULL,
    extracting       = FALSE,
    out_path         = NULL,
    expected_total   = NULL,
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

  # Takes its inputs as arguments rather than reading rv$ directly: it is
  # called from session$onFlushed() (see the input$next_step observer), which
  # runs outside any reactive context.
  run_extraction <- function(tsv_datapath, vcf_datapath, folder) {
    rv$extraction_error <- NULL

    tryCatch({
      tsv_df <- read_metadata_tsv(tsv_datapath)
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
      vcf.path <- vcf_datapath

      # rv$out_path/expected_total feed the progress-bar polling observer
      # below; rv$extracting gates it on/off.
      rv$out_path <- out.path
      rv$expected_total <- nrow(tsv_df)
      rv$extracting <- TRUE

      # prepHaplotFiles() itself is not modified — it's called exactly as
      # in the synchronous version, just handed to a background worker
      # process (future::plan(multisession)) so the main Shiny session
      # stays free to keep polling intermed/*.summary for progress. Only
      # plain values are referenced inside future({...}) — never `rv`,
      # `input`, or `session`, none of which are meaningful across
      # process boundaries.
      f <- future::future({
        prepHaplotFiles(
          run.label  = run.label,
          sam.path   = folder,
          label.path = label_path,
          vcf.path   = vcf.path,
          out.path   = out.path,
          app.path   = app.path,
          n.jobs     = n.jobs
        )
      }, seed = TRUE)

      promises::then(
        f,
        onFulfilled = function(value) {
          rv$extracting <- FALSE
          rv$result_rds     <- file.path(app.path, paste0(run.label, ".rds"))
          rv$result_posinfo <- file.path(app.path, paste0(run.label, "_posinfo.rds"))
          rv$step <- 5
        },
        onRejected = function(error) {
          rv$extracting <- FALSE
          rv$extraction_error <- conditionMessage(error)
        }
      )
    }, error = function(e) {
      rv$extracting <- FALSE
      rv$extraction_error <- conditionMessage(e)
    })
  }

  # Progress bar: poll the count of *.summary files prepHaplotFiles()
  # produces in intermed/ (one per processed SAM/BAM row) while extraction
  # runs in the background. Self-stops once rv$extracting is FALSE.
  progress_count <- reactiveVal(0)
  observe({
    req(isTRUE(rv$extracting))
    invalidateLater(300, session)
    intermed_dir <- file.path(rv$out_path, "intermed")
    count <- if (dir.exists(intermed_dir)) {
      # Excludes "all.summary", the final concatenated file
      # prepHaplotFiles() also writes into the same directory — only the
      # per-sample "<run.label>_<id>_<i>.summary" files should count.
      length(list.files(intermed_dir, pattern = "\\.summary$")) -
        file.exists(file.path(intermed_dir, "all.summary"))
    } else {
      0
    }
    progress_count(count)
  })

  observeEvent(input$next_step, {
    if (rv$step == 3) {
      rv$step <- 4
      # Shiny serialises async work within a session: a promise created in
      # this same flush cycle holds back every output computed alongside it,
      # so launching the extraction here would keep step 4 — the progress
      # bar — from ever reaching the browser. The user would sit on a
      # greyed-out step 3 for the whole run and then jump straight to
      # "Done". Deferring to onFlushed() lets step 4 be delivered first.
      # The reactive values have to be read here, in the reactive context,
      # because the deferred callback no longer has one.
      tsv_datapath <- rv$tsv$datapath
      vcf_datapath <- rv$vcf$datapath
      folder <- rv$folder
      session$onFlushed(
        function() run_extraction(tsv_datapath, vcf_datapath, folder),
        once = TRUE
      )
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

  # step1_ui()/step2_ui() must not read rv$folder/rv$tsv/rv$vcf directly:
  # they're called from inside output$wizard's renderUI, and a Shiny
  # fileInput/shinyDirButton re-created by a re-render loses the browser's
  # native "file selected" display even though the upload itself already
  # succeeded. The "✓ selected" indicators live in their own small
  # uiOutputs below instead, so picking a file/folder no longer
  # invalidates (and hence never recreates) these widgets.
  step1_ui <- function() {
    tagList(
      p("Select the folder on your computer that contains all the BAM files for this run."),
      shinyDirButton("dir_choose", "Browse for folder…", "Select a BAM folder"),
      uiOutput("folder_status")
    )
  }

  step2_ui <- function() {
    tagList(
      p("Upload your metadata file (TSV) and the VCF defining the target SNPs."),
      fileInput("tsv_file", "Metadata TSV", accept = ".tsv"),
      downloadButton("template", "Download TSV template"),
      tags$br(), tags$br(),
      fileInput("vcf_file", "VCF file",
                accept = c(".vcf", ".vcf.gz", "application/gzip",
                           "application/x-gzip", "text/plain")),
      uiOutput("file_status")
    )
  }

  output$folder_status <- renderUI({
    if (!is.null(rv$folder)) tags$p(style = "color:#27ae60;", paste("✓", rv$folder))
  })

  output$file_status <- renderUI({
    tagList(
      if (!is.null(rv$tsv)) tags$p(style = "color:#27ae60;", paste("✓ TSV:", rv$tsv$name)),
      if (!is.null(rv$vcf)) tags$p(style = "color:#27ae60;", paste("✓ VCF:", rv$vcf$name))
    )
  })

  step4_ui <- function() {
    if (!is.null(rv$extraction_error)) {
      tagList(
        tags$p(style = "color:#c0392b;", paste("✗ Extraction failed:", rv$extraction_error)),
        p("Go back and check your inputs, then try again.")
      )
    } else {
      total <- rv$expected_total
      done <- progress_count()
      pct <- if (is.null(total) || total == 0) 0 else min(100, round(100 * done / total))
      tagList(
        p("Extracting haplotypes… this can take a while for large batches."),
        tags$div(
          style = "background:#ecf0f1; border-radius:6px; overflow:hidden; height:24px;",
          tags$div(style = sprintf(
            "background:#2c3e50; width:%d%%; height:100%%; transition:width .3s;", pct
          ))
        ),
        tags$p(sprintf("%d / %s samples processed (%d%%)", done, if (is.null(total)) "?" else total, pct))
      )
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

  # Separate output so steps 1-2 (which hold fileInput/shinyDirButton
  # widgets) don't get invalidated by the same rv$folder/tsv/vcf changes
  # this needs to react to — see the note on step1_ui()/step2_ui() above.
  output$nav_buttons <- renderUI({
    step <- rv$step
    tagList(
      if (step > 1 && step < 5) actionButton("back_step", "← Back"),
      if (step == 1 && !is.null(rv$folder)) actionButton("next_step", "Next →"),
      if (step == 2 && !is.null(rv$tsv) && !is.null(rv$vcf)) actionButton("next_step", "Validate →"),
      if (step == 3 && isTRUE(validation()$ok)) actionButton("next_step", "Start extraction →")
    )
  })

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
        uiOutput("nav_buttons", inline = TRUE)
      )
    )
  })
})
