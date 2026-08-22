#' Translate a validated metadata TSV into prepHaplotFiles()'s label file format
#'
#' \code{prepHaplotFiles()} expects a tab-separated, headerless label file
#' with 3 columns: alignment file name, individual ID, group. The field
#' prep app's user-facing TSV has a header row and a 4th (\code{color})
#' column that \code{prepHaplotFiles()} doesn't use — this writes the
#' internal format from the validated TSV, preserving row order.
#'
#' @param tsv data.frame. Validated metadata TSV with columns
#'   \code{bam_file}, \code{individual_id}, \code{group}. Required.
#' @param path string. Destination path for the generated label file. Required.
#' @return \code{path}, invisibly.
#' @export
build_prep_label_file <- function(tsv, path) {
  utils::write.table(
    tsv[, c("bam_file", "individual_id", "group")],
    file = path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE
  )
  invisible(path)
}

#' Run hapture.pl over every sample in a label file and concatenate the results
#'
#' \code{prepHaplotFiles()}'s current Perl-invocation logic (wayfinder
#' ticket #27): checks Perl is installed and current enough, builds one
#' shell command per label-file row (backgrounding up to \code{n.jobs} at a
#' time, streaming BAM/gzipped-VCF input through \code{samtools}/\code{gunzip}
#' where needed), writes them to a generated shell/batch script, runs it,
#' and concatenates the per-sample \code{.summary} outputs it produces into
#' one combined file. Moved out of \code{prepHaplotFiles()} verbatim (no
#' behavior change) so the eventual microhaplot-extract cutover (wayfinder
#' ticket #36) has a single, clearly-bounded call site to swap out, instead
#' of rewriting a large function inline.
#'
#' Every argument, and every path/file this touches, is exactly what
#' \code{prepHaplotFiles()} already validated and prepared before calling
#' this: the \code{out.path/intermed} directory already exists and has been
#' cleared of any previous run's files, and \code{label.path} is known to
#' point at a real, at-least-3-column file.
#'
#' @param run.label character. Run label (already space-to-underscore
#'   normalized by the caller). Required.
#' @param sam.path string. Directory containing the alignment files named
#'   in the label file. Required.
#' @param label.path string. Path to the (already-validated) label file. Required.
#' @param vcf.path string. Path to the VCF file. Required.
#' @param out.path string. Run output directory; \code{out.path/intermed}
#'   must already exist. Required.
#' @param n.jobs positive integer. Number of alignment files to process in
#'   parallel (already validated as a positive integer by the caller). Required.
#' @return string. The path to the combined \code{all.summary} file this
#'   function just wrote (\code{out.path/intermed/all.summary}).
#' @keywords internal
#' @noRd
run_hapture_perl_pipeline <- function(run.label, sam.path, label.path, vcf.path, out.path, n.jobs) {
  haptureDir <- system.file("perl", "hapture", package = "microhaplot")

  # check whether perl is installed
  tryCatch({system("perl -v", intern=TRUE); message("Perl is found in system")},
           error= function(d) {
             if(.Platform$OS.type == "windows") {
               message("Perl is not found in system. Recommend installation from strawberryperl. Be sure to install version >=5.014")
             }else {
               message("Perl is not found in system. Recommend Installation from perl.org. Be sure to install version >=5.014")
             }
           })

  # ensure that the perl's version is at least 5.014
  perl.version <- system('perl -e "print $];"', intern=TRUE) %>% as.numeric
  if(perl.version < 5.014) stop ("The version Perl found in your current system is old-dated/incompatible. Microhaplot requires Perl v. >=5.014.")

  # the perl script hapture should display any warning if the label field contains any missing or invalid elements

  runHap.name <- ifelse(.Platform$OS.type == "windows", "runHapture.bat", "runHapture.sh")

  if (file.exists(file.path(out.path, runHap.name))) file.remove(file.path(out.path, runHap.name))

  summary.path <- file.path(out.path, "intermed", "all.summary")

  if(file.exists(summary.path)) file.remove(summary.path)

  # catch any problem in label file
  read.label <- tryCatch(read.table(label.path,sep = "\t",stringsAsFactors = FALSE), error = function(c) {
    c$message <- paste0(c$message, " (in ", label.path , ")")
    stop(c)
  })
  if (dim(read.label)[2] < 3) stop(label.path, "contains less than 3 columns.")

  # BAM support: hapture.pl only ever reads its SAM input as a forward,
  # line-by-line stream, so a BAM file can be fed to it by streaming
  # `samtools view -h` through Perl's piped-open idiom (a two-argument
  # `open` whose expression ends in "|" runs a shell command and reads its
  # stdout) instead of materializing a SAM file on disk. This needs no
  # change to hapture.pl itself, only to how the -s argument is built here.
  is.bam.row <- tolower(tools::file_ext(read.label[[1]])) == "bam"

  if (any(is.bam.row)) {
    if (.Platform$OS.type == "windows") {
      stop("BAM input is not yet supported on Windows. Please convert your BAM files to SAM before calling prepHaplotFiles().")
    }
    if (!nzchar(Sys.which("samtools"))) {
      stop("BAM input detected in the label file, but 'samtools' was not found on your PATH. Install samtools (http://www.htslib.org/) to use BAM files with prepHaplotFiles().")
    }
  }

  # gzipped VCF support: same piped-open idiom as BAM above (hapture.pl's
  # `open VCF, $opt{v}` doesn't decompress gzip on its own, but a path
  # string ending in "|" runs it as a shell command and streams stdout).
  is.gz.vcf <- tolower(tools::file_ext(vcf.path)) == "gz"
  if (is.gz.vcf) {
    if (.Platform$OS.type == "windows") {
      stop("Gzipped VCF input is not yet supported on Windows. Please decompress the VCF before calling prepHaplotFiles().")
    }
    if (!nzchar(Sys.which("gunzip"))) {
      stop("A gzipped VCF was supplied, but 'gunzip' was not found on your PATH. Install gzip/gunzip to use a .vcf.gz file with prepHaplotFiles().")
    }
  }
  vcf.arg <- if (is.gz.vcf) paste0('"gunzip -c ', vcf.path, ' |"') else vcf.path

  garb <- sapply(1:nrow(read.label), function(i) {

    line <- read.label[i,] %>% unlist
    if (!file.exists(file.path(sam.path,line[1]))) stop("the alignment file, ", file.path(sam.path,line[1]), ", does not exist")

    sam.arg <- if (is.bam.row[i]) {
      paste0('"samtools view -h ', sam.path, "/", line[1], ' |"')
    } else {
      paste0(sam.path, "/", line[1])
    }

    if(.Platform$OS.type == "windows") {
      run.perl.script <- paste0("perl ", haptureDir,
                                " -v ", vcf.path, " ",
                                " -s ", sam.path, "\\", line[1],
                                " -i ", line[2],
                                " -g ", line[3], " > ",
                                out.path, "\\intermed\\", run.label, "_", line[2],"_",i,".summary")
    } else {
      wait.ln <- ifelse(i %% n.jobs == 0," wait;"," ")
      run.perl.script <- paste0("perl ", haptureDir,
                                " -v ", vcf.arg,
                                " -s ", sam.arg,
                                " -i ", line[2],
                                " -g ", line[3], " > ",
                                out.path, "/intermed/", run.label, "_", line[2],"_",i,".summary &",
                                wait.ln)
    }

    write(run.perl.script,
      file = file.path(out.path, runHap.name),
      append = TRUE)
  })

  message("...running Hapture.pl to extract haplotype information (takes a while)...")

  if(.Platform$OS.type != "windows") {

    write(paste0("wait;"),
    file = file.path(out.path, runHap.name),
    append = TRUE)

    concat.cmd <- paste0("cat ",out.path, "/intermed/", run.label, "_", "*.summary"," > ",summary.path)

    # just in case if the user has loads of sam files and running out of buffer
    if (nrow(read.label) > 100) {
      concat.cmd <- paste0("find ",out.path, "/intermed -name ", run.label, "_", "*.summary",
                            "| while read F; do cat ${F} >>",summary.path, ";done")
    }

    write(concat.cmd,
          file = file.path(out.path, runHap.name),
          append = TRUE)

    system(paste0("bash ",out.path,"/runHapture.sh"))
  } else {
    concat.cmd <- paste0("type ",out.path, "\\intermed\\", run.label, "_", "*.summary"," > ",summary.path)

    write(concat.cmd,
          file = file.path(out.path, runHap.name),
          append = TRUE)


    system(file.path(out.path, runHap.name))
  }

  summary.path
}
