#' Run shiny microhaplot
#'
#' Run shiny microhaplot app
#' @param path Path to shiny microhaplot app. Optional. If not specified, the path is default to local app path.
#' @return Runs shiny microhaplot application via \code{shiny::runApp} which typically doesn't return; interrupt R to stop the application (usually by pressing Ctrl+C or Esc).
#' @export
#' @examples
#' if(interactive()){
#' runShinyHaplot()
#' }
runShinyHaplot <- function(path = system.file("shiny", "microhaplot", package = "microhaplot")) {
  if (path == "" || !file.exists(path)) {
    #stop("Could not find Shiny directory. Try re-installing `mypackage`.", call. = FALSE)
    stop("Could not find Shiny directory", call. = FALSE)
  }
  shiny::runApp(path, display.mode = "normal")
}

#' Run shiny microhaplot field genotyping prep app
#'
#' Run the companion Shiny app that turns a local folder of BAM files, a
#' VCF, and a metadata TSV into the two .rds files the main microhaplot
#' app's "Data Set" tab consumes — for users who don't want to call
#' \code{prepHaplotFiles()} from an R console directly.
#' @param path Path to the shiny microhaplot-prep app. Optional. If not specified, the path is default to local app path.
#' @return Runs the microhaplot-prep Shiny application via \code{shiny::runApp} which typically doesn't return; interrupt R to stop the application (usually by pressing Ctrl+C or Esc).
#' @export
#' @examples
#' if(interactive()){
#' runShinyHaplotPrep()
#' }
runShinyHaplotPrep <- function(path = system.file("shiny", "microhaplot-prep", package = "microhaplot")) {
  if (path == "" || !file.exists(path)) {
    stop("Could not find Shiny directory", call. = FALSE)
  }
  shiny::runApp(path, display.mode = "normal")
}

#' Transfer a copy of microhaplot app.
#'
#' Moves shiny microhaplot app to a different directory
#' @param path string. directory path. Required
#' @return a logical value of whether \code{file.copy} is successfully transferred Shiny app to its new directory
#' @export
#' @examples
#'
#' mvShinyHaplot(tempdir())
#'
mvShinyHaplot <- function(path) {
  app.dir <- system.file("shiny", "microhaplot", package = "microhaplot")
  if (app.dir == "") {
    stop("Could not find shiny directory. Try re-installing `mypackage`.", call. = FALSE)
  }

  if (!file.exists(paste0(path))) dir.create(path)

  file.copy(app.dir, path, overwrite = TRUE, recursive = TRUE)
}




#' Extracts haplotype from alignment reads.
#'
#' The function \code{microhaplot} extracts haplotype from BAM alignment
#' files via the \code{microhaplot-extract} binary and returns a summary
#' table of the read depth and read quality associated with each haplotype.
#'
#' @param run.label character vector. Run label to be used to display in haPLOType. Required
#' @param sam.path string. Directory path folder containing all alignment files (BAM). Required
#' @param label.path string. Label file path. This customized label file is a tab-separate file that contains entries of BAM file name, individual ID, and group label. Required
#' @param vcf.path string. VCF file path (plain or gzip-compressed). Required
#' @param out.path string. Optional. If not specified, the intermediate files are created under \code{TEMPDIR}, with the assumption that directory is granted for written permission.
#' @param add.filter boolean. Optional. If true, this removes any haplotype with unknown and deletion alignment characters i.e. "*" and "_", removes any locus with large number of haplotypes ( # > 40) , and remove any locus with fewer than half of the total individuals.
#' @param app.path string. Path to shiny haPLOType app. Optional. If not specified, the path is default to \code{TEMPDIR}.
#' @param n.jobs positive integer. Number of alignment files to process concurrently. Optional.
#' @return This function returns a dataframe of 9 columns i.e group, id, locus, haplotype, depth, sum of Phred score, max of Phred score, allele balance and haplotype rank from highest to lowest read depth. This dataframe will also be saved in \code{out.path}.
#' @export
#' @examples
#'
#' run.label <- "sebastes"
#'
#' sam.path <- tempdir()
#' untar(system.file("extdata",
#'                   "sebastes_bam.tar.gz",
#'                   package="microhaplot"),
#'       exdir = sam.path)
#'
#' metadata <- read.delim(file.path(sam.path, "sebastes_metadata.tsv"))
#' label.path <- file.path(sam.path, "label.txt")
#' build_prep_label_file(metadata, label.path)
#' vcf.path <- file.path(sam.path, "sebastes.vcf")
#'
#' mvShinyHaplot(tempdir())
#' app.path <- file.path(tempdir(), "microhaplot")
#'
#' haplo.read.tbl <- prepHaplotFiles(run.label = run.label,
#'                             sam.path = sam.path,
#'                             out.path = tempdir(),
#'                             label.path = label.path,
#'                             vcf.path = vcf.path,
#'                             app.path = app.path)
#'
prepHaplotFiles <- function(run.label, sam.path, label.path, vcf.path,
  out.path=tempdir(),
  add.filter=FALSE,
  app.path=tempdir(),
  n.jobs = 1){

  run.label <- gsub(" +","_",run.label)

  # Need to check whether all path and files exist
  if (!file.exists(sam.path)) stop("the path for 'sam.path' - ", sam.path, " does not exist")
  if (!file.exists(label.path)) stop("the path for 'label.path' - ", label.path, " does not exist")
  if (!file.exists(vcf.path)) stop("the path for 'vcf.path' - ", vcf.path, " does not exist")
  if (!file.exists(out.path)) stop("the path for 'out.path' - ", out.path, " does not exist")
  if (!file.exists(app.path)) stop("the path for 'app.path' - ", app.path, " does not exist; try to run mvShinyHaplot()")

  # check for numeric state

  if(!is.numeric(n.jobs)) stop("the n.jobs sepcificed is expected to be numeric")

  n.jobs <- round(n.jobs)
  if(n.jobs<=0) stop("the n.jobs is expected to be positive integer")

  intermed.path <- file.path(out.path, "intermed")

  if (file.exists(intermed.path)) file.remove(
    list.files(intermed.path, full.names=TRUE))

  if (!file.exists(intermed.path)) dir.create(intermed.path)

  # microhaplot-extract (wayfinder tickets #28-#35), since the cutover in
  # ticket #36: one call extracts every sample in the label file, in
  # parallel, against vcf.path, replacing hapture.pl's per-sample
  # shell-script generation entirely. No samtools/gunzip shell-outs here
  # any more -- BAM decoding is native, and run_microhaplot_extract() shims
  # gzipped VCF input on its own.
  message("...running microhaplot-extract to extract haplotype information (takes a while)...")

  haplo.sum <- run_microhaplot_extract(
    label.path = label.path, sam.path = sam.path, vcf.path = vcf.path,
    out.path = intermed.path, n.jobs = n.jobs
  )

  num.id <- length(unique(haplo.sum$id))

  message(paste0("\n...Prepping rds file : ",out.path, "/",run.label,".rds\n"))

  if (add.filter) {

    haplo.cleanup <- haplo.sum %>%
      dplyr::filter(!grepl("[N]", haplo)) %>%
      dplyr::group_by(locus, id) %>%
      dplyr::mutate(n.haplo.per.indiv = dplyr::n()) %>%
      dplyr::ungroup() %>%
      dplyr::group_by(locus) %>%
      dplyr::mutate(n.indiv.per.locus = length(unique(id)), max.uniq.hapl = max(n.haplo.per.indiv)) %>%
      dplyr::ungroup() %>%
      dplyr::filter(n.indiv.per.locus > num.id/2, max.uniq.hapl < 40)  %>%
      dplyr::select(group, id, locus, haplo, depth, sum.Phred.C, max.Phred.C)
    } else {
      haplo.cleanup <- haplo.sum %>% dplyr::select(group, id, locus, haplo, depth, sum.Phred.C, max.Phred.C)
    }

  haplo.add.balance <- haplo.cleanup %>%
    dplyr::arrange(dplyr::desc(depth)) %>%
    dplyr::group_by(locus,id) %>%
    dplyr::mutate(allele.balance = depth/depth[1], rank = dplyr::row_number() ) %>%
    dplyr::ungroup()

  vcf.pos.tbl <- read.table(vcf.path) %>%
    .[,1:2] %>% # grabbing locus name, and pos
    dplyr::group_by(V1) %>%
    dplyr::summarise(pos = paste0(V2, collapse = ","))

  colnames(vcf.pos.tbl) <- c("locus","pos")

  saveRDS(haplo.add.balance, paste0(out.path, "/",run.label,".rds"))
  saveRDS(vcf.pos.tbl, paste0(out.path, "/",run.label,"_posinfo.rds"))

  message(paste0("RDS file: copied into shiny directory: ",app.path, "/",run.label,"*.rds ", "\n\nRun the following to open shiny app: runShinyHaplot(\"",app.path,"\")"))

  if(file.exists(file.path(app.path, paste0(run.label,"*.rds")))) message("Overwritting previous version -  ", run.label, ".rds in ", app.path)


  if (out.path != app.path) system(paste0("cp ", out.path, "/",run.label,"*.rds ", app.path, "/.") )

  return(haplo.add.balance)
}
