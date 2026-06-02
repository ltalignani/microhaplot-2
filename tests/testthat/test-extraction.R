library(testthat)
source(here::here("app/R/extraction.R"))

# ---- fixtures ---------------------------------------------------------------

FIXTURES <- test_path("fixtures")
VCF_PATH <- file.path(FIXTURES, "sebastes.vcf")
BAM_PATH <- file.path(FIXTURES, "s6.bam")

mini_vcf <- function() {
  tmp <- tempfile(fileext = ".vcf")
  writeLines(c(
    "##fileformat=VCFv4.1",
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO",
    "locus_A\t10\t.\tG\tA\t.\t.\t.",
    "locus_A\t20\t.\tC\tT\t.\t.\t.",
    "locus_B\t5\t.\tA\tG\t.\t.\t.",
    # indels — should be excluded
    "locus_A\t30\t.\tGG\tAA\t.\t.\t.",
    "locus_B\t15\t.\tA\tGT\t.\t.\t."
  ), tmp)
  tmp
}

# ---- Cycle 1: parse_vcf_loci ------------------------------------------------

test_that("parse_vcf_loci returns SNP-only rows with correct columns", {
  vcf <- parse_vcf_loci(mini_vcf())

  expect_s3_class(vcf, "data.frame")
  expect_named(vcf, c("locus", "pos", "ref", "alt"))
  expect_equal(nrow(vcf), 3L)  # 3 SNPs, 2 indels excluded
  expect_equal(vcf$locus, c("locus_A", "locus_A", "locus_B"))
  expect_equal(vcf$pos, c(10L, 20L, 5L))
  expect_equal(vcf$ref, c("G", "C", "A"))
  expect_equal(vcf$alt, c("A", "T", "G"))
})

test_that("parse_vcf_loci skips indels (ref or alt length > 1)", {
  vcf <- parse_vcf_loci(mini_vcf())
  expect_true(all(nchar(vcf$ref) == 1L))
  expect_true(all(nchar(vcf$alt) == 1L))
})

# ---- Cycle 2: extract_read_haplotype ----------------------------------------

test_that("extract_read_haplotype extracts bases at SNP positions (all-M CIGAR)", {
  #           1234567890
  seq  <- "ACGTACGTAC"
  # aln_start = 1, cigar = "10M", ref_positions = c(3, 7)
  # ref pos 3 → query pos 3 → 'G'
  # ref pos 7 → query pos 7 → 'G'
  haplo <- extract_read_haplotype(seq, aln_start = 1L, cigar = "10M",
                                  ref_positions = c(3L, 7L))
  expect_equal(haplo, "GG")
})

test_that("extract_read_haplotype marks deletions as 'X'", {
  seq <- "ACGTACGT"
  # CIGAR: 4M 2D 4M  → ref 1-4: query 1-4, ref 5-6: deleted, ref 7-10: query 5-8
  haplo <- extract_read_haplotype(seq, aln_start = 1L, cigar = "4M2D4M",
                                  ref_positions = c(2L, 5L, 8L))
  expect_equal(haplo, "CXC")  # pos2=C, pos5=deletion=X, pos8→query6=C
})

test_that("extract_read_haplotype marks out-of-range positions as 'N'", {
  seq <- "ACGT"
  # CIGAR: 4M, aln_start=5 → covers ref 5-8
  # ref pos 3 is before alignment → N
  # ref pos 10 is after alignment → N
  haplo <- extract_read_haplotype(seq, aln_start = 5L, cigar = "4M",
                                  ref_positions = c(3L, 6L, 10L))
  expect_equal(haplo, "NCN")
})

test_that("extract_read_haplotype handles leading soft-clip in CIGAR", {
  #         123456789...
  seq <- "SSSACGT"  # first 3 are soft-clipped
  # CIGAR: 3S4M, aln_start = 1 → ref 1-4 align to query positions 4-7
  haplo <- extract_read_haplotype(seq, aln_start = 1L, cigar = "3S4M",
                                  ref_positions = c(1L, 3L))
  # ref pos 1 → query pos 4 → 'A'; ref pos 3 → query pos 6 → 'G'
  expect_equal(haplo, "AG")
})

# ---- Cycle 3: add_allele_balance --------------------------------------------

test_that("add_allele_balance computes allele.balance and rank correctly", {
  haplo_counts <- data.frame(
    locus = c("L1", "L1", "L1"),
    id    = c("s1", "s1", "s1"),
    haplo = c("AA", "AB", "AC"),
    depth = c(50L, 10L, 2L),
    stringsAsFactors = FALSE
  )
  result <- add_allele_balance(haplo_counts)

  expect_named(result, c("locus", "id", "haplo", "depth", "allele.balance", "rank"))
  expect_equal(result$rank, 1:3)
  expect_equal(result$allele.balance, c(1.0, 10/50, 2/50))
})

test_that("add_allele_balance orders by depth descending within locus×id", {
  haplo_counts <- data.frame(
    locus = c("L1", "L1"),
    id    = c("s1", "s1"),
    haplo = c("AB", "AA"),
    depth = c(10L, 50L),
    stringsAsFactors = FALSE
  )
  result <- add_allele_balance(haplo_counts)
  expect_equal(result$haplo, c("AA", "AB"))  # sorted descending
  expect_equal(result$rank, c(1L, 2L))
})

# ---- Cycle 4: empty result --------------------------------------------------

test_that("extract_haplotypes returns empty tibble when no reads overlap locus", {
  # Create a VCF with a locus that doesn't exist in the BAM
  tmp_vcf <- tempfile(fileext = ".vcf")
  writeLines(c(
    "##fileformat=VCFv4.1",
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO",
    "nonexistent_locus\t10\t.\tG\tA\t.\t.\t."
  ), tmp_vcf)

  meta <- data.frame(bam_file = basename(BAM_PATH), id = "s6", group = "gr",
                     stringsAsFactors = FALSE)
  result <- extract_haplotypes(
    bam_dir  = dirname(BAM_PATH),
    vcf_path = tmp_vcf,
    metadata = meta
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
  expect_named(result, c("group", "id", "locus", "haplo", "depth", "allele.balance", "rank"))
})

# ---- Cycle 5: integration on real BAM ---------------------------------------

test_that("extract_haplotypes on s6.bam reproduces Perl hapture output for tag_id_843", {
  meta <- data.frame(bam_file = "s6.bam", id = "s6", group = "gr",
                     stringsAsFactors = FALSE)
  result <- extract_haplotypes(
    bam_dir  = FIXTURES,
    vcf_path = VCF_PATH,
    metadata = meta
  )

  expect_s3_class(result, "data.frame")
  expect_named(result, c("group", "id", "locus", "haplo", "depth", "allele.balance", "rank"))

  locus_843 <- result[result$locus == "tag_id_843", ]
  expect_gt(nrow(locus_843), 0L)

  # Perl reference: GCGTGAG depth=52 (rank 1), GCGTGGG depth=2 (rank 2)
  top <- locus_843[locus_843$rank == 1L, ]
  expect_equal(top$haplo, "GCGTGAG")
  expect_equal(top$depth, 52L)
  expect_equal(top$allele.balance, 1.0)

  second <- locus_843[locus_843$rank == 2L, ]
  expect_equal(second$haplo, "GCGTGGG")
  expect_equal(second$depth, 2L)
  expect_equal(round(second$allele.balance, 4), round(2/52, 4))
})

test_that("extract_haplotypes result columns have correct types", {
  meta <- data.frame(bam_file = "s6.bam", id = "s6", group = "gr",
                     stringsAsFactors = FALSE)
  result <- extract_haplotypes(
    bam_dir  = FIXTURES,
    vcf_path = VCF_PATH,
    metadata = meta
  )
  expect_type(result$group, "character")
  expect_type(result$id, "character")
  expect_type(result$locus, "character")
  expect_type(result$haplo, "character")
  expect_type(result$depth, "integer")
  expect_type(result$allele.balance, "double")
  expect_type(result$rank, "integer")
})
