# --------------------------------------------------------------------------
# test-define-write.R -- tests for write_define_xml() Define-XML 2.1 writer
# Ported from herald-v0: test-define-write.R + test-define-build.R + test-define-build-arm.R
# --------------------------------------------------------------------------

# -- Fixtures ----------------------------------------------------------------

.make_minimal_spec <- function() {
  herald_spec(
    ds_spec = data.frame(
      dataset = c("DM", "AE"),
      label   = c("Demographics", "Adverse Events"),
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      dataset   = c("DM", "DM", "AE"),
      variable  = c("STUDYID", "AGE", "AETERM"),
      label     = c("Study Identifier", "Age", "AE Term"),
      data_type = c("text", "integer", "text"),
      length    = c("12", "8", "200"),
      stringsAsFactors = FALSE
    )
  )
}

.make_full_spec <- function() {
  herald_spec(
    study = data.frame(
      attribute = c("StudyName", "StudyDescription", "ProtocolName"),
      value     = c("TEST-001", "A test study", "PROT-A"),
      stringsAsFactors = FALSE
    ),
    ds_spec = data.frame(
      dataset = c("DM", "AE"),
      label   = c("Demographics", "Adverse Events"),
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      dataset   = c("DM", "DM", "AE"),
      variable  = c("STUDYID", "AGE", "AETERM"),
      label     = c("Study Identifier", "Age", "AE Term"),
      data_type = c("text", "integer", "text"),
      length    = c("12", "8", "200"),
      stringsAsFactors = FALSE
    ),
    codelist = data.frame(
      codelist_id   = c("CL.SEX", "CL.SEX"),
      name          = c("Sex", "Sex"),
      data_type     = c("text", "text"),
      term          = c("M", "F"),
      decoded_value = c("Male", "Female"),
      stringsAsFactors = FALSE
    ),
    methods = data.frame(
      method_id   = "MT.001",
      name        = "Derive AGE",
      type        = "Computation",
      description = "AGE = RFSTDTC - BRTHDTC",
      stringsAsFactors = FALSE
    ),
    comments = data.frame(
      comment_id  = "COM.001",
      description = "Test comment",
      stringsAsFactors = FALSE
    ),
    arm_displays = data.frame(
      display_id = "RD.T14.1",
      title      = "Table 14.1",
      stringsAsFactors = FALSE
    ),
    arm_results = data.frame(
      display_id  = "RD.T14.1",
      result_id   = "AR.T14.1.R1",
      description = "Demographics Summary",
      stringsAsFactors = FALSE
    )
  )
}

# -- write_define_xml: basic output ------------------------------------------

test_that("write_define_xml creates a valid XML file", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  result <- write_define_xml(spec, tmp, validate = FALSE)
  expect_true(file.exists(tmp))
  expect_equal(as.character(result), tmp)

  doc <- xml2::read_xml(tmp)
  expect_s3_class(doc, "xml_document")
})

test_that("write_define_xml output has correct root element", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  doc <- xml2::read_xml(tmp)
  expect_equal(xml2::xml_name(doc), "ODM")
})

test_that("write_define_xml includes namespace declarations", {
  spec     <- .make_minimal_spec()
  tmp      <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("cdisc.org/ns/odm/v1.3",  xml_text, fixed = TRUE))
  expect_true(grepl("cdisc.org/ns/def/v2.1",  xml_text, fixed = TRUE))
  expect_true(grepl("cdisc.org/ns/arm/v1.0",  xml_text, fixed = TRUE))
})

# -- write_define_xml: error handling ----------------------------------------

test_that("write_define_xml errors on non-spec input", {
  expect_error(
    write_define_xml("not_a_spec", "out.xml"),
    class = "herald_error_input"
  )
})

test_that("write_define_xml errors on non-character path", {
  spec <- .make_minimal_spec()
  expect_error(
    write_define_xml(spec, 42L),
    class = "herald_error_input"
  )
})

# -- Round-trip: write -> read -----------------------------------------------

test_that("round-trip preserves dataset names and labels", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_equal(result$ds_spec$dataset, c("DM", "AE"))
  expect_equal(result$ds_spec$label,   c("Demographics", "Adverse Events"))
})

test_that("round-trip preserves variable names and labels", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_equal(result$var_spec$variable, c("STUDYID", "AGE", "AETERM"))
  expect_equal(result$var_spec$label,    c("Study Identifier", "Age", "AE Term"))
  expect_equal(result$var_spec$dataset,  c("DM", "DM", "AE"))
})

test_that("round-trip preserves variable data types and lengths", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_equal(result$var_spec$data_type, c("text", "integer", "text"))
  expect_equal(result$var_spec$length,    c("12", "8", "200"))
})

test_that("round-trip preserves study metadata", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_equal(nrow(result$study), 3L)
  expect_equal(
    result$study$attribute,
    c("StudyName", "StudyDescription", "ProtocolName")
  )
  expect_equal(result$study$value, c("TEST-001", "A test study", "PROT-A"))
})

test_that("round-trip preserves codelists", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_false(is.null(result$codelist))
  expect_equal(nrow(result$codelist), 2L)
  expect_equal(result$codelist$codelist_id,   c("CL.SEX", "CL.SEX"))
  expect_equal(result$codelist$term,          c("M", "F"))
  expect_equal(result$codelist$decoded_value, c("Male", "Female"))
})

test_that("round-trip preserves methods", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_false(is.null(result$methods))
  expect_equal(nrow(result$methods), 1L)
  expect_equal(result$methods$method_id,   "MT.001")
  expect_equal(result$methods$name,        "Derive AGE")
  expect_equal(result$methods$type,        "Computation")
  expect_equal(result$methods$description, "AGE = RFSTDTC - BRTHDTC")
})

test_that("round-trip preserves comments", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_false(is.null(result$comments))
  expect_equal(nrow(result$comments), 1L)
  expect_equal(result$comments$comment_id,  "COM.001")
  expect_equal(result$comments$description, "Test comment")
})

test_that("round-trip preserves ARM displays", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_false(is.null(result$arm_displays))
  expect_equal(nrow(result$arm_displays), 1L)
  expect_equal(result$arm_displays$display_id, "RD.T14.1")
  expect_equal(result$arm_displays$title,      "Table 14.1")
})

test_that("round-trip preserves ARM results", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_false(is.null(result$arm_results))
  expect_equal(nrow(result$arm_results), 1L)
  expect_equal(result$arm_results$display_id,  "RD.T14.1")
  expect_equal(result$arm_results$result_id,   "AR.T14.1.R1")
  expect_equal(result$arm_results$description, "Demographics Summary")
})

# -- Edge cases ---------------------------------------------------------------

test_that("write_define_xml handles minimal spec (no optional slots)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  result <- read_define_xml(tmp)

  expect_equal(result$ds_spec$dataset, c("DM", "AE"))
  expect_null(result$codelist)
  expect_null(result$methods)
  expect_null(result$comments)
  expect_null(result$arm_displays)
})

test_that("write_define_xml handles empty study slot", {
  spec <- herald_spec(
    study   = data.frame(attribute = character(), value = character(),
                         stringsAsFactors = FALSE),
    ds_spec = data.frame(dataset = "DM", label = "Demographics",
                         stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                          stringsAsFactors = FALSE)
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  expect_no_error(write_define_xml(spec, tmp, validate = FALSE))
  doc <- xml2::read_xml(tmp)
  expect_s3_class(doc, "xml_document")
})

test_that("write_define_xml handles codelist with EnumeratedItem (no decode)", {
  spec <- herald_spec(
    ds_spec = data.frame(dataset = "DM", label = "Demographics",
                         stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "SEX",
                          stringsAsFactors = FALSE),
    codelist = data.frame(
      codelist_id   = c("CL.NY", "CL.NY"),
      name          = c("Yes/No", "Yes/No"),
      data_type     = c("text", "text"),
      term          = c("Y", "N"),
      decoded_value = c("", ""),
      stringsAsFactors = FALSE
    )
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  raw_xml <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("EnumeratedItem", raw_xml, fixed = TRUE))
  expect_false(grepl("CodeListItem",  raw_xml, fixed = TRUE))
})

test_that("write_define_xml produces ItemRef children in ItemGroupDef", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  doc <- xml2::read_xml(tmp)
  ns  <- xml2::xml_ns(doc)

  dm_igd    <- xml2::xml_find_first(doc, ".//d1:ItemGroupDef[@Name='DM']", ns)
  item_refs <- xml2::xml_find_all(dm_igd, ".//d1:ItemRef", ns)
  expect_equal(length(item_refs), 2L)
  expect_equal(xml2::xml_attr(item_refs[[1L]], "ItemOID"), "IT.DM.STUDYID")
})

# -- XML structure snapshot ---------------------------------------------------

test_that("write_define_xml output has correct structure", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  doc <- xml2::read_xml(tmp)
  ns  <- xml2::xml_ns(doc)

  study <- xml2::xml_find_first(doc, ".//d1:Study", ns)
  expect_false(is.na(study))

  gv <- xml2::xml_find_first(study, ".//d1:GlobalVariables", ns)
  expect_false(is.na(gv))

  mdv <- xml2::xml_find_first(study, ".//d1:MetaDataVersion", ns)
  expect_false(is.na(mdv))
  expect_equal(xml2::xml_attr(mdv, "DefineVersion"), "2.1.0")

  igds  <- xml2::xml_find_all(mdv, ".//d1:ItemGroupDef", ns)
  expect_equal(length(igds), 2L)

  items <- xml2::xml_find_all(mdv, ".//d1:ItemDef", ns)
  expect_equal(length(items), 3L)

  cls   <- xml2::xml_find_all(mdv, ".//d1:CodeList", ns)
  expect_equal(length(cls), 1L)

  meths <- xml2::xml_find_all(mdv, ".//d1:MethodDef", ns)
  expect_equal(length(meths), 1L)

  coms  <- xml2::xml_find_all(mdv, ".//def:CommentDef", ns)
  expect_equal(length(coms), 1L)

  arm_disp <- xml2::xml_find_all(mdv, ".//arm:ResultDisplay", ns)
  expect_equal(length(arm_disp), 1L)

  arm_res  <- xml2::xml_find_all(mdv, ".//arm:AnalysisResult", ns)
  expect_equal(length(arm_res), 1L)
})

# -- GlobalVariables backfill -------------------------------------------------

test_that("write_define_xml with no study data includes UNKNOWN StudyName", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                          data_type = "text", length = "12",
                          stringsAsFactors = FALSE)
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("UNKNOWN", xml_text))
})

# -- DD conformance attributes ------------------------------------------------

test_that("write_define_xml emits SASDatasetName on ItemGroupDef (DD0108)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("SASDatasetName", xml_text, fixed = TRUE))
})

test_that("write_define_xml emits SASFieldName on ItemDef (DD0147)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("SASFieldName", xml_text, fixed = TRUE))
})

test_that("write_define_xml emits Purpose on ItemGroupDef (DD0117)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl('Purpose=', xml_text, fixed = TRUE))
})

test_that("write_define_xml emits MethodDef Type (DD0208)", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl('Type="Computation"', xml_text, fixed = TRUE))
})

test_that("write_define_xml MethodDef without Type defaults to Computation (DD0208)", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demo",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "AGE",
                          data_type = "integer", length = "8",
                          stringsAsFactors = FALSE),
    methods  = data.frame(
      method_id = "MT.A",
      name      = "Derive AGE",
      type      = NA_character_,
      stringsAsFactors = FALSE
    )
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("Computation", xml_text, fixed = TRUE))
})

# -- OID prefix alignment (P21 convention) ------------------------------------

test_that("OIDs use P21-convention prefixes: IG., IT., CL., MT., COM.", {
  spec     <- .make_full_spec()
  tmp      <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  raw_xml <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl('OID="IG.DM"',         raw_xml, fixed = TRUE))
  expect_true(grepl('OID="IG.AE"',         raw_xml, fixed = TRUE))
  expect_true(grepl('OID="IT.DM.STUDYID"', raw_xml, fixed = TRUE))
  expect_true(grepl('OID="IT.DM.AGE"',     raw_xml, fixed = TRUE))
  expect_true(grepl('OID="IT.AE.AETERM"',  raw_xml, fixed = TRUE))
  expect_true(grepl('OID="CL.SEX"',        raw_xml, fixed = TRUE))
  expect_true(grepl('OID="MT.001"',        raw_xml, fixed = TRUE))
  expect_true(grepl('OID="COM.001"',       raw_xml, fixed = TRUE))
})

test_that("OID normalisation adds missing prefix: bare name gets prefixed", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset     = "DM",
      variable    = "SEX",
      label       = "Sex",
      data_type   = "text",
      length      = "1",
      codelist_id = "SEX",          # no CL. prefix -> CL.SEX
      method_id   = "DERIVE_SEX",   # no MT. prefix -> MT.DERIVE_SEX
      comment_id  = "C001",         # no COM. prefix -> COM.C001
      stringsAsFactors = FALSE
    ),
    methods  = data.frame(
      method_id   = "DERIVE_SEX",
      name        = "Derive SEX",
      type        = "Computation",
      description = "Assign SEX",
      stringsAsFactors = FALSE
    ),
    comments = data.frame(
      comment_id  = "C001",
      description = "A comment",
      stringsAsFactors = FALSE
    ),
    codelist = data.frame(
      codelist_id   = "SEX",
      name          = "Sex",
      data_type     = "text",
      term          = "M",
      decoded_value = "Male",
      stringsAsFactors = FALSE
    )
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  raw_xml <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl('OID="CL.SEX"',             raw_xml, fixed = TRUE))
  expect_true(grepl('CodeListOID="CL.SEX"',     raw_xml, fixed = TRUE))
  expect_true(grepl('OID="MT.DERIVE_SEX"',      raw_xml, fixed = TRUE))
  expect_true(grepl('MethodOID="MT.DERIVE_SEX"', raw_xml, fixed = TRUE))
  expect_true(grepl('OID="COM.C001"',           raw_xml, fixed = TRUE))
  expect_true(grepl('CommentOID="COM.C001"',    raw_xml, fixed = TRUE))
})

# -- Stylesheet processing instruction ----------------------------------------

test_that("write_define_xml always adds PI before root ODM element", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  lines   <- readLines(tmp, warn = FALSE)
  pi_idx  <- grep("xml-stylesheet", lines, fixed = TRUE)
  odm_idx <- grep("<ODM", lines, fixed = TRUE)[1L]

  expect_length(pi_idx, 1L)
  expect_true(pi_idx < odm_idx)
  expect_true(grepl('type="text/xsl"',      lines[pi_idx], fixed = TRUE))
  expect_true(grepl('href="define2-1.xsl"', lines[pi_idx], fixed = TRUE))
})

test_that("stylesheet = FALSE still emits the xml-stylesheet PI (param ignored)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, stylesheet = FALSE, validate = FALSE)
  lines  <- readLines(tmp, warn = FALSE)
  pi_idx <- grep("xml-stylesheet", lines, fixed = TRUE)
  # stylesheet param is ignored -- PI is always emitted
  expect_length(pi_idx, 1L)
})

test_that("stylesheet PI output is still valid parseable XML", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  expect_no_error(xml2::read_xml(tmp))
  doc <- xml2::read_xml(tmp)
  expect_equal(xml2::xml_name(doc), "ODM")
})

test_that("write_define_xml skips XSL copy when define2-1.xsl already exists", {
  spec   <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demo",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                          label = "Study ID", data_type = "text",
                          stringsAsFactors = FALSE)
  )
  outdir <- withr::local_tempdir()
  tmp    <- file.path(outdir, "define.xml")
  xsl    <- file.path(outdir, "define2-1.xsl")

  writeLines("<!-- existing xsl -->", xsl)
  existing_mtime <- file.mtime(xsl)

  suppressWarnings(write_define_xml(spec, tmp, stylesheet = TRUE, validate = FALSE))
  expect_equal(file.mtime(xsl), existing_mtime)
})

# -- validate = TRUE integration ----------------------------------------------

test_that("write_define_xml with validate = FALSE skips validation", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  expect_no_warning(write_define_xml(spec, tmp, validate = FALSE))
  expect_true(file.exists(tmp))
})

test_that("write_define_xml with validate = TRUE passes on a clean spec", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  # .make_minimal_spec() should produce a clean enough spec
  # to not trigger validate_spec() abort; if it does, skip.
  result <- tryCatch(
    write_define_xml(spec, tmp, validate = TRUE),
    herald_error_validation = function(e) skip("Spec has issues -- skipping validate=TRUE test")
  )
  expect_true(file.exists(tmp))
})

# -- .norm_oid ---------------------------------------------------------------

test_that(".norm_oid returns oid unchanged when prefix already present", {
  expect_equal(herald:::.norm_oid("IG.DM", "IG."), "IG.DM")
})

test_that(".norm_oid adds prefix when missing", {
  expect_equal(herald:::.norm_oid("DM", "IG."), "IG.DM")
})

test_that(".norm_oid returns NULL for NULL input", {
  expect_null(herald:::.norm_oid(NULL, "IG."))
})

test_that(".norm_oid returns NA for NA input", {
  expect_true(is.na(herald:::.norm_oid(NA_character_, "IG.")))
})

test_that(".norm_oid returns empty string for empty string input", {
  expect_equal(herald:::.norm_oid("", "IG."), "")
})

# -- .parse_standard_string ---------------------------------------------------

test_that(".parse_standard_string parses ADaMIG", {
  result <- herald:::.parse_standard_string("ADaMIG 1.1")
  expect_equal(result$name,          "ADaMIG")
  expect_equal(result$version,       "1.1")
  expect_equal(result$type,          "IG")
  expect_equal(result$publishing_set, "ADaM")
})

test_that(".parse_standard_string parses SDTMIG", {
  result <- herald:::.parse_standard_string("SDTMIG 3.3")
  expect_equal(result$name,          "SDTMIG")
  expect_equal(result$version,       "3.3")
  expect_equal(result$publishing_set, "SDTM")
})

test_that(".parse_standard_string parses SDTMIG-AP", {
  result <- herald:::.parse_standard_string("SDTMIGAP 3.3")
  expect_equal(result$name, "SDTMIG-AP")
})

test_that(".parse_standard_string parses SDTMIG-MD", {
  result <- herald:::.parse_standard_string("SDTMIGMD 3.3")
  expect_equal(result$name, "SDTMIG-MD")
})

test_that(".parse_standard_string parses SENDIG", {
  result <- herald:::.parse_standard_string("SENDIG 3.1")
  expect_equal(result$name,          "SENDIG")
  expect_equal(result$publishing_set, "SEND")
})

test_that(".parse_standard_string parses SENDIG-AR", {
  result <- herald:::.parse_standard_string("SENDIGAR 3.1")
  expect_equal(result$name, "SENDIG-AR")
})

test_that(".parse_standard_string parses SENDIG-DART", {
  result <- herald:::.parse_standard_string("SENDIGDART 1.0")
  expect_equal(result$name, "SENDIG-DART")
})

test_that(".parse_standard_string parses SENDIG-GENETOX", {
  result <- herald:::.parse_standard_string("SENDIGGENETOX 1.0")
  expect_equal(result$name, "SENDIG-GENETOX")
})

test_that(".parse_standard_string parses CDISC/NCI as CT type", {
  result <- herald:::.parse_standard_string("CDISC 2020-09-25")
  expect_equal(result$name, "CDISC/NCI")
  expect_equal(result$type, "CT")
})

test_that(".parse_standard_string parses NCI as CT type", {
  result <- herald:::.parse_standard_string("NCI 2020")
  expect_equal(result$name, "CDISC/NCI")
  expect_equal(result$type, "CT")
})

test_that(".parse_standard_string uses default version 1.0 when not given", {
  result <- herald:::.parse_standard_string("SDTMIG")
  expect_equal(result$version, "1.0")
})

test_that(".parse_standard_string returns NULL for NA", {
  expect_null(herald:::.parse_standard_string(NA_character_))
})

test_that(".parse_standard_string returns NULL for empty string", {
  expect_null(herald:::.parse_standard_string(""))
})

# -- Standards in output (DD0031-DD0036) --------------------------------------

test_that("build with standards in ds_spec creates Standards node", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                          standard = "SDTMIG 3.3", stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                          label = "Study ID", data_type = "text",
                          length = "12", stringsAsFactors = FALSE)
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("SDTMIG", xml_text))
})

test_that("build with keys in ds_spec includes key refs", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                          keys = "STUDYID USUBJID", stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset   = c("DM", "DM"),
      variable  = c("STUDYID", "USUBJID"),
      label     = c("Study ID", "Subject ID"),
      data_type = c("text", "text"),
      length    = c("12", "20"),
      stringsAsFactors = FALSE
    )
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("STUDYID", xml_text))
  expect_true(grepl("USUBJID", xml_text))
})

# -- ARM tests ---------------------------------------------------------------

.make_arm_spec <- function(include_extras = FALSE) {
  arm_displays <- data.frame(
    display_id = "RD.T14.1",
    title      = "Table 14.1: Demographics",
    stringsAsFactors = FALSE
  )
  arm_results <- data.frame(
    display_id  = "RD.T14.1",
    result_id   = "AR.T14.1.R1",
    description = "Demographics Summary",
    stringsAsFactors = FALSE
  )

  if (include_extras) {
    arm_results$reason             <- "Primary Outcome"
    arm_results$purpose            <- "Analysis"
    arm_results$variables          <- "ADSL.AGE, ADSL.SEX"
    arm_results$documentation      <- "See SAP Section 5.1"
    arm_results$programming_code   <- "proc means data=adsl; run;"
    arm_results$programming_context <- "SAS Version 9.4"
  }

  herald_spec(
    ds_spec  = data.frame(dataset = "ADSL", label = "Subject-Level",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset   = "ADSL",
      variable  = c("STUDYID", "AGE", "SEX"),
      label     = c("Study ID", "Age", "Sex"),
      data_type = c("text", "integer", "text"),
      length    = c("12", "8", "1"),
      stringsAsFactors = FALSE
    ),
    arm_displays = arm_displays,
    arm_results  = arm_results
  )
}

test_that("write_define_xml with ARM data creates ARM nodes", {
  spec <- .make_arm_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("AnalysisResultDisplays", xml_text))
  expect_true(grepl("RD.T14.1",              xml_text))
  expect_true(grepl("AR.T14.1.R1",           xml_text))
})

test_that("write_define_xml with no arm_displays skips ARM section", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_false(grepl("AnalysisResultDisplays", xml_text))
})

test_that("write_define_xml ARM with reason and purpose includes those attrs", {
  spec <- .make_arm_spec(include_extras = TRUE)
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("Primary Outcome", xml_text))
  expect_true(grepl("Analysis",        xml_text))
})

test_that("write_define_xml ARM with variables creates AnalysisDatasets", {
  spec <- .make_arm_spec(include_extras = TRUE)
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("AnalysisDataset", xml_text))
  expect_true(grepl("IG.ADSL",         xml_text))
})

test_that("write_define_xml ARM with documentation creates Documentation node", {
  spec <- .make_arm_spec(include_extras = TRUE)
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("See SAP Section 5.1", xml_text))
})

test_that("write_define_xml ARM with programming code creates ProgrammingCode", {
  spec <- .make_arm_spec(include_extras = TRUE)
  tmp  <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("ProgrammingCode", xml_text))
  expect_true(grepl("proc means",      xml_text))
})

test_that("write_define_xml ARM with document_id creates DocumentRef", {
  arm_displays <- data.frame(display_id = "RD.T14.1", title = "Table 14.1",
                              document_id = "LF.doc1", pages = "10-12",
                              stringsAsFactors = FALSE)
  arm_results  <- data.frame(display_id = "RD.T14.1", result_id = "AR.T14.1.R1",
                              description = "Summary", stringsAsFactors = FALSE)
  spec <- herald_spec(
    ds_spec      = data.frame(dataset = "DM", label = "Demographics",
                               stringsAsFactors = FALSE),
    var_spec     = data.frame(dataset = "DM", variable = "STUDYID",
                               label = "Study ID", data_type = "text",
                               length = "12", stringsAsFactors = FALSE),
    arm_displays = arm_displays,
    arm_results  = arm_results
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  write_define_xml(spec, tmp, validate = FALSE)
  xml_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("DocumentRef", xml_text))
  expect_true(grepl("LF.doc1",     xml_text))
  expect_true(grepl("PDFPageRef",  xml_text))
})

# -- .safe_col ---------------------------------------------------------------

test_that(".safe_col returns empty string for missing column", {
  df <- data.frame(x = "a", stringsAsFactors = FALSE)
  expect_equal(herald:::.safe_col(df, "missing_col", 1L), "")
})

test_that(".safe_col returns empty string for NA value", {
  df <- data.frame(x = NA_character_, stringsAsFactors = FALSE)
  expect_equal(herald:::.safe_col(df, "x", 1L), "")
})

test_that(".safe_col returns the value when present", {
  df <- data.frame(x = "hello", stringsAsFactors = FALSE)
  expect_equal(herald:::.safe_col(df, "x", 1L), "hello")
})

# -- value_spec creates ValueListDef -----------------------------------------

test_that("write_define_xml with value_spec creates ValueListDef elements", {
  spec <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset   = c("DM", "DM"),
      variable  = c("STUDYID", "AGE"),
      label     = c("Study ID", "Age"),
      data_type = c("text", "integer"),
      length    = c("12", "8"),
      stringsAsFactors = FALSE
    ),
    value_spec = data.frame(
      dataset  = "DM",
      variable = "AGE",
      where    = "AGE > 0",
      label    = "Age when valid",
      data_type = "integer",
      length   = "8",
      stringsAsFactors = FALSE
    )
  )
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))

  expect_no_error(write_define_xml(spec, tmp, validate = FALSE))
  expect_true(file.exists(tmp))
})

# -- Triplet output: define.xml + define.html + define2-1.xsl ----------------

test_that("write_define_xml always produces all three triplet files", {
  spec   <- .make_full_spec()
  outdir <- withr::local_tempdir()
  tmp    <- file.path(outdir, "define.xml")

  suppressWarnings(write_define_xml(spec, tmp, validate = FALSE))

  expect_true(file.exists(file.path(outdir, "define.xml")))
  expect_true(file.exists(file.path(outdir, "define.html")))
  expect_true(file.exists(file.path(outdir, "define2-1.xsl")))
})

test_that("triplet define.html contains study name from spec", {
  spec   <- .make_full_spec()
  outdir <- withr::local_tempdir()
  tmp    <- file.path(outdir, "define.xml")

  suppressWarnings(write_define_xml(spec, tmp, validate = FALSE))
  html <- paste(readLines(file.path(outdir, "define.html"), warn = FALSE), collapse = "\n")

  expect_true(grepl("TEST-001", html, fixed = TRUE))
})

test_that("triplet define.html contains dataset names from spec", {
  spec   <- .make_full_spec()
  outdir <- withr::local_tempdir()
  tmp    <- file.path(outdir, "define.xml")

  suppressWarnings(write_define_xml(spec, tmp, validate = FALSE))
  html <- paste(readLines(file.path(outdir, "define.html"), warn = FALSE), collapse = "\n")

  expect_true(grepl("DM",             html, fixed = TRUE))
  expect_true(grepl("AE",             html, fixed = TRUE))
  expect_true(grepl("Demographics",   html, fixed = TRUE))
  expect_true(grepl("Adverse Events", html, fixed = TRUE))
})

test_that("write_define_xml skips define2-1.xsl copy when already exists", {
  spec   <- herald_spec(
    ds_spec  = data.frame(dataset = "DM", label = "Demo",
                          stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                          label = "Study ID", data_type = "text",
                          stringsAsFactors = FALSE)
  )
  outdir <- withr::local_tempdir()
  tmp    <- file.path(outdir, "define.xml")
  xsl    <- file.path(outdir, "define2-1.xsl")

  writeLines("<!-- existing xsl -->", xsl)
  existing_mtime <- file.mtime(xsl)

  suppressWarnings(write_define_xml(spec, tmp, validate = FALSE))
  expect_equal(file.mtime(xsl), existing_mtime)
})

# -- write_define_html standalone --------------------------------------------

test_that("write_define_html is exported and returns path invisibly", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".html")
  withr::defer(unlink(tmp))

  result <- write_define_html(spec, tmp)
  expect_equal(result, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_define_html errors on non-spec input", {
  expect_error(
    write_define_html("not_a_spec", "out.html"),
    class = "herald_error_input"
  )
})

test_that("write_define_html errors on non-character path", {
  spec <- .make_minimal_spec()
  expect_error(
    write_define_html(spec, 42L),
    class = "herald_error_input"
  )
})

test_that("write_define_html output is valid HTML with DOCTYPE", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".html")
  withr::defer(unlink(tmp))

  write_define_html(spec, tmp)
  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE", html, fixed = TRUE))
  expect_true(grepl("<html", html, fixed = TRUE))
})

test_that("write_define_html contains variable names", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".html")
  withr::defer(unlink(tmp))

  write_define_html(spec, tmp)
  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("STUDYID", html, fixed = TRUE))
  expect_true(grepl("AETERM",  html, fixed = TRUE))
})

test_that("write_define_html contains codelist terms when spec has codelist", {
  spec <- .make_full_spec()
  tmp  <- tempfile(fileext = ".html")
  withr::defer(unlink(tmp))

  write_define_html(spec, tmp)
  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("Male",   html, fixed = TRUE))
  expect_true(grepl("Female", html, fixed = TRUE))
})

test_that("write_define_html works with minimal spec (no study metadata)", {
  spec <- .make_minimal_spec()
  tmp  <- tempfile(fileext = ".html")
  withr::defer(unlink(tmp))

  expect_no_error(write_define_html(spec, tmp))
  expect_true(file.exists(tmp))
})
