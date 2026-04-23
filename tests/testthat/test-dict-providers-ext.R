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
  expect_setequal(p$fields, c("pt", "hlt", "hlgt", "soc", "llt"))

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
  dir <- tempfile("mdd-direct-"); dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(file.path(dir, "mdhier.asc"), version = "27.0")
  expect_s3_class(p, "herald_dict_provider")
  expect_false("llt" %in% p$fields)
})

test_that("meddra_provider errors on missing mdhier.asc", {
  dir <- tempfile("mdd-missing-"); dir.create(dir)
  expect_error(meddra_provider(dir), class = "herald_error_input")
})

test_that("meddra_provider errors on non-existent path", {
  expect_error(meddra_provider("/no/such/path"),
               class = "herald_error_input")
})

test_that("meddra_provider lookup() returns matching rows", {
  dir <- tempfile("mdd-look-"); dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  hits <- p$lookup("Headache", field = "pt")
  expect_equal(nrow(hits), 1L)
  expect_equal(hits$soc_name, "Nervous system disorders")
})

test_that("meddra_provider returns NA for unknown field", {
  dir <- tempfile("mdd-nf-"); dir.create(dir)
  .fake_mdhier(dir)
  p <- meddra_provider(dir, version = "27.0")
  expect_true(all(is.na(p$contains("X", field = "not_a_level"))))
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
  expect_setequal(p$fields,
                  c("drug_name", "drug_record_number", "alternate_name"))
  expect_true(p$contains("ASPIRIN", field = "drug_name"))
  expect_true(p$contains("IBUPROFEN", field = "drug_name"))
  expect_false(p$contains("NOT_A_DRUG", field = "drug_name"))

  expect_true(p$contains("ACETYLSALICYLIC ACID", field = "alternate_name"))
  expect_true(p$contains("000001", field = "drug_record_number"))
})

test_that("whodrug_provider errors on missing DD.txt", {
  dir <- tempfile("whod-missing-"); dir.create(dir)
  expect_error(whodrug_provider(dir), class = "herald_error_input")
})

test_that("whodrug_provider rejects unsupported format", {
  dir <- tempfile("whod-fmt-"); dir.create(dir)
  .fake_whodrug_dd(dir)
  expect_error(whodrug_provider(dir, format = "c3"),
               class = "herald_error_input")
})

test_that("meddra / whodrug providers work end-to-end via register_dictionary", {
  on.exit(unregister_dictionary("meddra"), add = TRUE)
  dir <- tempfile("mdd-reg-"); dir.create(dir)
  .fake_mdhier(dir)
  register_dictionary("meddra", meddra_provider(dir, version = "27.0"))

  dfs <- list_dictionaries()
  expect_true("meddra" %in% dfs$name)
  expect_equal(dfs$license[dfs$name == "meddra"], "MSSO")
})
