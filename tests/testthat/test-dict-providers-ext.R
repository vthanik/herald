# Tests for R/dict-providers-ext.R -- meddra_provider, whodrug_provider.
# Uses synthetic fixtures that mimic the MSSO / UMC file formats.

# --------------------------------------------------------------------------
# MedDRA
# --------------------------------------------------------------------------

.fake_mdhier <- function(dir) {
  # $-delimited rows -- column order per MSSO hierarchy spec.
  lines <- c(
    # pt_code|hlt_code|hlgt_code|soc_code|pt_name|hlt_name|hlgt_name|
    # soc_name|soc_abbrev|null|pt_soc_code|primary|null
    "10019211$10019217$10019221$10010331$Headache$Headaches NEC$Neurological disorders NEC$Nervous system disorders$Nerv$$10010331$Y$",
    "10028411$10028419$10028423$10029104$Nausea$Nausea and vomiting symptoms$Gastrointestinal signs and symptoms$Gastrointestinal disorders$Gast$$10029104$Y$",
    "10058030$10058031$10058032$10029104$Vomiting$Nausea and vomiting symptoms$Gastrointestinal signs and symptoms$Gastrointestinal disorders$Gast$$10029104$Y$"
  )
  writeLines(lines, file.path(dir, "mdhier.asc"))
}

.fake_llt <- function(dir) {
  lines <- c(
    # llt_code | llt_name | pt_code | ... trailing nulls
    "10019228$Cephalalgia$10019211$$$$$$$$$",
    "10028420$Sickness nausea$10028411$$$$$$$$$"
  )
  writeLines(lines, file.path(dir, "llt.asc"))
}

test_that("meddra_provider(dir) parses mdhier + llt, serves all fields", {
  dir <- tempfile("mdd-")
  dir.create(dir)
  .fake_mdhier(dir)
  .fake_llt(dir)
  p <- meddra_provider(dir, version = "27.0")

  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "meddra")
  expect_equal(p$version, "27.0")
  expect_equal(p$source, "user-file")
  expect_setequal(
    p$fields,
    c(
      "pt",
      "pt_code",
      "hlt",
      "hlt_code",
      "hlgt",
      "hlgt_code",
      "soc",
      "soc_code",
      "llt",
      "llt_code"
    )
  )

  expect_true(p$contains("Headache", field = "pt"))
  expect_true(p$contains("Nausea", field = "pt"))
  expect_false(p$contains("NotATerm", field = "pt"))

  expect_true(p$contains("Nausea and vomiting symptoms", field = "hlt"))
  expect_true(p$contains("Nervous system disorders", field = "soc"))
  expect_true(p$contains("Cephalalgia", field = "llt"))

  expect_true(p$contains("headache", field = "pt", ignore_case = TRUE))
  expect_false(p$contains("headache", field = "pt", ignore_case = FALSE))
})

test_that("meddra_provider accepts a direct mdhier.asc file path", {
  dir <- tempfile("mdd-direct-")
  dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(file.path(dir, "mdhier.asc"), version = "27.0")
  expect_s3_class(p, "herald_dict_provider")
  expect_false("llt" %in% p$fields)
})

test_that("meddra_provider errors on missing mdhier.asc", {
  dir <- tempfile("mdd-missing-")
  dir.create(dir)
  expect_error(meddra_provider(dir), class = "herald_error_input")
})

test_that("meddra_provider errors on non-existent path", {
  expect_error(meddra_provider("/no/such/path"), class = "herald_error_input")
})

test_that("meddra_provider lookup() returns matching rows", {
  dir <- tempfile("mdd-look-")
  dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  hits <- p$lookup("Headache", field = "pt")
  expect_equal(nrow(hits), 1L)
  expect_equal(hits$soc_name, "Nervous system disorders")
})

test_that("meddra_provider returns NA for unknown field", {
  dir <- tempfile("mdd-nf-")
  dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  expect_true(all(is.na(p$contains("X", field = "not_a_level"))))
})

test_that("meddra_provider exposes code fields for pt, hlt, hlgt, soc, llt", {
  dir <- tempfile("mdd-codes-")
  dir.create(dir)
  .fake_mdhier(dir)
  .fake_llt(dir)
  p <- meddra_provider(dir, version = "27.0")

  # Codes from mdhier.asc (see .fake_mdhier for values)
  expect_true(p$contains("10019211", field = "pt_code")) # Headache PT code
  expect_true(p$contains("10019217", field = "hlt_code")) # Headaches NEC HLT code
  expect_true(p$contains("10019221", field = "hlgt_code")) # Neurological HLGT code
  expect_true(p$contains("10010331", field = "soc_code")) # Nervous system SOC code
  expect_false(p$contains("00000000", field = "pt_code")) # unknown code

  # LLT code from llt.asc
  expect_true(p$contains("10019228", field = "llt_code")) # Cephalalgia LLT code
  expect_false(p$contains("99999999", field = "llt_code")) # unknown LLT code
})

# --------------------------------------------------------------------------
# WHO-Drug
# --------------------------------------------------------------------------

.fake_whodrug_dd <- function(dir) {
  # DD.txt: 6 chars drug record, 1 char seq1, 1 char seq2, then name.
  lines <- c(
    sprintf("%-6s%-1s%-1s%-1500s", "000001", "0", "1", "ASPIRIN"),
    sprintf("%-6s%-1s%-1s%-1500s", "000002", "0", "1", "IBUPROFEN"),
    sprintf("%-6s%-1s%-1s%-1500s", "000003", "0", "1", "PARACETAMOL")
  )
  writeLines(lines, file.path(dir, "DD.txt"))
}

.fake_whodrug_dda <- function(dir) {
  lines <- c(
    sprintf("%-6s%-3s%-1500s", "000001", "001", "ACETYLSALICYLIC ACID"),
    sprintf("%-6s%-3s%-1500s", "000003", "001", "ACETAMINOPHEN")
  )
  writeLines(lines, file.path(dir, "DDA.txt"))
}

test_that("whodrug_provider parses DD + DDA, serves drug names", {
  dir <- tempfile("whod-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  .fake_whodrug_dda(dir)
  p <- whodrug_provider(dir, version = "2026-Mar-01")

  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "whodrug")
  expect_setequal(
    p$fields,
    c("drug_name", "drug_record_number", "alternate_name")
  )
  expect_true(p$contains("ASPIRIN", field = "drug_name"))
  expect_true(p$contains("IBUPROFEN", field = "drug_name"))
  expect_false(p$contains("NOT_A_DRUG", field = "drug_name"))

  expect_true(p$contains("ACETYLSALICYLIC ACID", field = "alternate_name"))
  expect_true(p$contains("000001", field = "drug_record_number"))
})

test_that("whodrug_provider errors on missing DD.txt", {
  dir <- tempfile("whod-missing-")
  dir.create(dir)
  expect_error(whodrug_provider(dir), class = "herald_error_input")
})

test_that("whodrug_provider rejects unsupported format", {
  dir <- tempfile("whod-fmt-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  expect_error(
    whodrug_provider(dir, format = "c3"),
    class = "herald_error_input"
  )
})

test_that("meddra / whodrug providers work end-to-end via register_dictionary", {
  on.exit(unregister_dictionary("meddra"), add = TRUE)
  dir <- tempfile("mdd-reg-")
  dir.create(dir)
  .fake_mdhier(dir)
  register_dictionary("meddra", meddra_provider(dir, version = "27.0"))

  dfs <- list_dictionaries()
  expect_true("meddra" %in% dfs$name)
  expect_equal(dfs$license[dfs$name == "meddra"], "MSSO")
})

# --------------------------------------------------------------------------
# LOINC
# --------------------------------------------------------------------------

.fake_loinc_csv <- function(dir) {
  lines <- c(
    "LOINC_NUM,COMPONENT,SHORTNAME,LONG_COMMON_NAME,STATUS,CLASS",
    "12345-6,Hemoglobin,Hgb,Hemoglobin [Mass/volume] in Blood,ACTIVE,HEM/BC",
    "78910-2,Glucose,Gluc,Glucose [Mass/volume] in Serum or Plasma,ACTIVE,CHEM"
  )
  writeLines(lines, file.path(dir, "Loinc.csv"))
}

test_that("loinc_provider parses Loinc.csv and serves membership", {
  dir <- tempfile("loinc-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")

  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "loinc")
  expect_equal(p$size_rows, 2L)
  expect_true(p$contains("12345-6", field = "loinc_num"))
  expect_true(p$contains("Hemoglobin", field = "component"))
  expect_false(p$contains("NOT_A_CODE", field = "loinc_num"))
})

test_that("loinc_provider accepts a direct Loinc.csv path", {
  dir <- tempfile("loinc-direct-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(file.path(dir, "Loinc.csv"), version = "2.77")
  expect_s3_class(p, "herald_dict_provider")
})

test_that("loinc_provider errors on missing file", {
  dir <- tempfile("loinc-miss-")
  dir.create(dir)
  expect_error(loinc_provider(dir), class = "herald_error_input")
})

# --------------------------------------------------------------------------
# SNOMED CT
# --------------------------------------------------------------------------

.fake_snomed_snapshot <- function(dir) {
  lines <- c(
    paste(
      "id",
      "effectiveTime",
      "active",
      "moduleId",
      "conceptId",
      "languageCode",
      "typeId",
      "term",
      "caseSignificanceId",
      sep = "\t"
    ),
    paste(
      "1",
      "20250101",
      "1",
      "900000000000207008",
      "25064002",
      "en",
      "900000000000013009",
      "Headache",
      "900000000000448009",
      sep = "\t"
    ),
    paste(
      "2",
      "20250101",
      "1",
      "900000000000207008",
      "422587007",
      "en",
      "900000000000013009",
      "Nausea",
      "900000000000448009",
      sep = "\t"
    )
  )
  path <- file.path(dir, "sct2_Description_Snapshot-en_x.txt")
  writeLines(lines, path)
  path
}

test_that("snomed_provider parses the RF2 description snapshot", {
  dir <- tempfile("snomed-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")

  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "snomed")
  expect_true(p$contains("Headache", field = "term"))
  expect_true(p$contains("25064002", field = "concept_id"))
  expect_false(p$contains("Not a term", field = "term"))
})

test_that("snomed_provider errors when no snapshot file is present", {
  dir <- tempfile("snomed-empty-")
  dir.create(dir)
  expect_error(snomed_provider(dir), class = "herald_error_input")
})

# --------------------------------------------------------------------------
# custom_provider
# --------------------------------------------------------------------------

test_that("custom_provider wraps a data frame for membership lookup", {
  tbl <- data.frame(
    code = c("A", "B", "C"),
    label = c("Asian", "Black", "Caucasian"),
    stringsAsFactors = FALSE
  )
  p <- custom_provider(tbl, name = "sponsor-race", fields = c("code", "label"))
  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "sponsor-race")
  expect_equal(p$source, "sponsor")
  expect_true(p$contains("A", field = "code"))
  expect_true(p$contains("Black", field = "label"))
  expect_false(p$contains("Z", field = "code"))
  hits <- p$lookup("A", field = "code")
  expect_equal(hits$label, "Asian")
})

test_that("custom_provider errors on non-data-frame input", {
  expect_error(
    custom_provider(list(), name = "x"),
    class = "herald_error_input"
  )
})

test_that("custom_provider errors when fields reference unknown columns", {
  tbl <- data.frame(x = 1:3)
  expect_error(
    custom_provider(tbl, name = "bad", fields = c("x", "nope")),
    class = "herald_error_input"
  )
})

test_that("custom_provider defaults fields to all columns", {
  tbl <- data.frame(a = "1", b = "x", stringsAsFactors = FALSE)
  p <- custom_provider(tbl, name = "c")
  expect_setequal(p$fields, c("a", "b"))
})

test_that("custom_provider contains() with ignore_case=TRUE", {
  df <- data.frame(TERM = c("Y", "N"), stringsAsFactors = FALSE)
  p <- custom_provider(df, name = "test", fields = "TERM")
  expect_equal(p$contains(c("Y", "X"), field = "TERM"), c(TRUE, FALSE))
  expect_equal(
    p$contains(c("y", "n"), field = "TERM", ignore_case = TRUE),
    c(TRUE, TRUE)
  )
})

test_that("custom_provider contains() returns NA for unknown field", {
  df <- data.frame(x = "A", stringsAsFactors = FALSE)
  p <- custom_provider(df, name = "x", fields = "x")
  result <- p$contains("A", field = "not_a_field")
  expect_true(is.na(result))
})

test_that("custom_provider lookup() returns NULL for no-match", {
  df <- data.frame(x = c("A", "B"), stringsAsFactors = FALSE)
  p <- custom_provider(df, name = "x", fields = "x")
  expect_null(p$lookup("Z", field = "x"))
})

test_that("custom_provider lookup() returns NULL for unknown field", {
  df <- data.frame(x = "A", stringsAsFactors = FALSE)
  p <- custom_provider(df, name = "x", fields = "x")
  expect_null(p$lookup("A", field = "not_a_col"))
})

# --------------------------------------------------------------------------
# meddra lookup for llt, NULL-returning lookup paths
# --------------------------------------------------------------------------

test_that("meddra_provider lookup() for llt returns matching llt rows", {
  dir <- tempfile("mdd-llt-look-")
  dir.create(dir)
  .fake_mdhier(dir)
  .fake_llt(dir)
  p <- meddra_provider(dir, version = "27.0")
  hits <- p$lookup("Cephalalgia", field = "llt")
  expect_equal(nrow(hits), 1L)
  expect_equal(as.character(hits$llt_code), "10019228")
})

test_that("meddra_provider lookup() returns NULL for unknown field", {
  dir <- tempfile("mdd-null-look-")
  dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  expect_null(p$lookup("Headache", field = "not_a_level"))
})

test_that("meddra_provider lookup() returns NULL when no rows match", {
  dir <- tempfile("mdd-nohit-")
  dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  expect_null(p$lookup("NoSuchTerm", field = "pt"))
})

# --------------------------------------------------------------------------
# whodrug additional coverage
# --------------------------------------------------------------------------

test_that("whodrug_provider errors on non-existent directory", {
  expect_error(
    whodrug_provider("/no/such/dir"),
    class = "herald_error_input"
  )
})

test_that("whodrug_provider contains() with ignore_case=TRUE", {
  dir <- tempfile("whod-ci-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  p <- whodrug_provider(dir, version = "2026-Mar-01")
  expect_true(p$contains("aspirin", field = "drug_name", ignore_case = TRUE))
  expect_false(p$contains("aspirin", field = "drug_name", ignore_case = FALSE))
})

test_that("whodrug_provider contains() returns NA for unknown field", {
  dir <- tempfile("whod-na-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  p <- whodrug_provider(dir, version = "2026-Mar-01")
  expect_true(is.na(p$contains("ASPIRIN", field = "not_a_field")))
})

test_that("whodrug_provider lookup() returns NULL for unknown field", {
  dir <- tempfile("whod-look-null-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  p <- whodrug_provider(dir, version = "2026-Mar-01")
  expect_null(p$lookup("ASPIRIN", field = "not_a_field"))
})

test_that("whodrug_provider lookup() returns NULL for no match", {
  dir <- tempfile("whod-look-nomatch-")
  dir.create(dir)
  .fake_whodrug_dd(dir)
  p <- whodrug_provider(dir, version = "2026-Mar-01")
  expect_null(p$lookup("NOTADRUG", field = "drug_name"))
})

# --------------------------------------------------------------------------
# loinc additional coverage
# --------------------------------------------------------------------------

test_that("loinc_provider errors on non-existent direct file path", {
  expect_error(
    loinc_provider("/no/such/Loinc.csv"),
    class = "herald_error_input"
  )
})

test_that("loinc_provider errors when LOINC_NUM column is missing", {
  dir <- tempfile("loinc-nocolumn-")
  dir.create(dir)
  writeLines(
    c("FOO,BAR", "a,b"),
    file.path(dir, "Loinc.csv")
  )
  expect_error(loinc_provider(dir), class = "herald_error_runtime")
})

test_that("loinc_provider contains() with ignore_case=TRUE", {
  dir <- tempfile("loinc-ci-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")
  expect_true(
    p$contains("hemoglobin", field = "component", ignore_case = TRUE)
  )
  expect_false(
    p$contains("hemoglobin", field = "component", ignore_case = FALSE)
  )
})

test_that("loinc_provider contains() returns NA for unknown field", {
  dir <- tempfile("loinc-na-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")
  expect_true(is.na(p$contains("X", field = "not_a_field")))
})

test_that("loinc_provider lookup() returns matching rows", {
  dir <- tempfile("loinc-look-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")
  hits <- p$lookup("12345-6", field = "loinc_num")
  expect_equal(nrow(hits), 1L)
  expect_equal(hits$COMPONENT, "Hemoglobin")
})

test_that("loinc_provider lookup() returns NULL for no match", {
  dir <- tempfile("loinc-look-null-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")
  expect_null(p$lookup("99999-9", field = "loinc_num"))
})

test_that("loinc_provider lookup() returns NULL for unknown field", {
  dir <- tempfile("loinc-look-unk-")
  dir.create(dir)
  .fake_loinc_csv(dir)
  p <- loinc_provider(dir, version = "2.77")
  expect_null(p$lookup("12345-6", field = "not_a_field"))
})

# --------------------------------------------------------------------------
# snomed additional coverage
# --------------------------------------------------------------------------

test_that("snomed_provider errors when direct file path does not exist", {
  expect_error(
    snomed_provider("/no/such/file.txt"),
    class = "herald_error_input"
  )
})

test_that("snomed_provider errors when description file missing required columns", {
  dir <- tempfile("snomed-badcols-")
  dir.create(dir)
  path <- file.path(dir, "sct2_Description_Snapshot-en_x.txt")
  writeLines(c("foo\tbar", "1\t2"), path)
  expect_error(
    snomed_provider(dir, version = "20250101"),
    class = "herald_error_runtime"
  )
})

test_that("snomed_provider contains() with ignore_case=TRUE", {
  dir <- tempfile("snomed-ci-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  expect_true(p$contains("headache", field = "term", ignore_case = TRUE))
  expect_false(p$contains("headache", field = "term", ignore_case = FALSE))
})

test_that("snomed_provider contains() returns NA for unknown field", {
  dir <- tempfile("snomed-na-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  expect_true(is.na(p$contains("Headache", field = "not_a_field")))
})

test_that("snomed_provider lookup() returns matching rows", {
  dir <- tempfile("snomed-look-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  hits <- p$lookup("Headache", field = "term")
  expect_equal(nrow(hits), 1L)
  expect_equal(as.character(hits$conceptId), "25064002")
})

test_that("snomed_provider lookup() returns NULL for no match", {
  dir <- tempfile("snomed-look-null-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  expect_null(p$lookup("NoSuchTerm", field = "term"))
})

test_that("snomed_provider lookup() returns NULL for unknown field", {
  dir <- tempfile("snomed-look-unk-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  expect_null(p$lookup("Headache", field = "not_a_field"))
})

test_that("snomed_provider lookup() by concept_id returns matching rows", {
  dir <- tempfile("snomed-conceptid-")
  dir.create(dir)
  .fake_snomed_snapshot(dir)
  p <- snomed_provider(dir, version = "20250101")
  hits <- p$lookup("25064002", field = "concept_id")
  expect_equal(nrow(hits), 1L)
  expect_equal(hits$term, "Headache")
})
