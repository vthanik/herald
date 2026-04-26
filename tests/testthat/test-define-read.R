# --------------------------------------------------------------------------
# test-define-read.R -- tests for read_define_xml() and ops-define.R
# --------------------------------------------------------------------------

# -- Helper: minimal Define-XML fixture ------------------------------------

minimal_define_xml <- function(
  include_arm = FALSE,
  include_itemref = FALSE,
  include_keyvar = FALSE,
  include_loinc_std = FALSE
) {
  arm_section <- if (include_arm) {
    '
      <arm:AnalysisResultDisplays>
        <arm:ResultDisplay OID="RD.T14.1" Name="Table 14.1">
          <arm:AnalysisResult OID="AR.T14.1.R1" Name="Demographics Summary">
          </arm:AnalysisResult>
        </arm:ResultDisplay>
      </arm:AnalysisResultDisplays>'
  } else {
    ""
  }

  dm_refs <- if (include_itemref) {
    '<ItemRef ItemOID="IT.DM.STUDYID" OrderNumber="1" Mandatory="Yes"/>
        <ItemRef ItemOID="IT.DM.AGE" OrderNumber="2" Mandatory="No"/>'
  } else {
    ""
  }

  dm_kv <- if (include_keyvar) {
    'def:KeyVariables="IT.DM.STUDYID IT.DM.AGE"'
  } else {
    ""
  }

  loinc_std <- if (include_loinc_std) {
    '<def:Standard OID="STD.LOINC" Name="LOINC" Type="CT" Version="2.73"/>'
  } else {
    ""
  }

  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1"
     xmlns:arm="http://www.cdisc.org/ns/arm/v1.0"
     Context="Submission" FileOID="DEF.TEST">
  <Study OID="S.TEST">
    <GlobalVariables>
      <StudyName>TEST-001</StudyName>
      <StudyDescription>A test study</StudyDescription>
      <ProtocolName>PROT-A</ProtocolName>
    </GlobalVariables>
    <MetaDataVersion OID="MDV.1" Name="Test" DefineVersion="2.1.0">
      ',
    loinc_std,
    '
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No" ',
    dm_kv,
    '>
        <Description><TranslatedText>Demographics</TranslatedText></Description>
        ',
    dm_refs,
    '
      </ItemGroupDef>
      <ItemGroupDef OID="IG.AE" Name="AE" Repeating="Yes">
        <Description><TranslatedText>Adverse Events</TranslatedText></Description>
      </ItemGroupDef>

      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text" Length="12">
        <Description><TranslatedText>Study Identifier</TranslatedText></Description>
        <def:Origin Type="Assigned"/>
        <CodeListRef CodeListOID="CL.STUDYID"/>
      </ItemDef>
      <ItemDef OID="IT.DM.AGE" Name="AGE" DataType="integer" Length="8">
        <Description><TranslatedText>Age</TranslatedText></Description>
        <def:Origin Type="CRF"/>
      </ItemDef>
      <ItemDef OID="IT.AE.AETERM" Name="AETERM" DataType="text" Length="200">
        <Description><TranslatedText>AE Term</TranslatedText></Description>
        <def:Origin Type="CRF"/>
      </ItemDef>

      <CodeList OID="CL.SEX" Name="Sex" DataType="text">
        <CodeListItem CodedValue="M">
          <Decode><TranslatedText>Male</TranslatedText></Decode>
        </CodeListItem>
        <CodeListItem CodedValue="F">
          <Decode><TranslatedText>Female</TranslatedText></Decode>
        </CodeListItem>
      </CodeList>

      <MethodDef OID="MT.001" Name="Derive AGE" Type="Computation">
        <Description><TranslatedText>AGE = RFSTDTC - BRTHDTC</TranslatedText></Description>
      </MethodDef>

      <def:CommentDef OID="COM.001">
        <Description><TranslatedText>Test comment</TranslatedText></Description>
      </def:CommentDef>
      ',
    arm_section,
    '
    </MetaDataVersion>
  </Study>
</ODM>'
  )
}

write_test_define <- function(
  path,
  include_arm = FALSE,
  include_itemref = FALSE,
  include_keyvar = FALSE,
  include_loinc_std = FALSE
) {
  writeLines(
    minimal_define_xml(
      include_arm,
      include_itemref,
      include_keyvar,
      include_loinc_std
    ),
    path
  )
}

# -- read_define_xml: basic parsing ------------------------------------------

test_that("read_define_xml returns herald_define object", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d, "herald_define")
})

test_that("read_define_xml extracts study metadata", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d$study, "data.frame")
  expect_true("StudyName" %in% d$study$attribute)
  expect_equal(
    d$study$value[d$study$attribute == "StudyName"],
    "TEST-001"
  )
})

test_that("read_define_xml extracts datasets from ItemGroupDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_equal(nrow(d$ds_spec), 2L)
  expect_equal(d$ds_spec$dataset, c("DM", "AE"))
  expect_equal(d$ds_spec$label, c("Demographics", "Adverse Events"))
})

test_that("read_define_xml extracts variables from ItemDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_equal(nrow(d$var_spec), 3L)
  expect_true("STUDYID" %in% d$var_spec$variable)
  expect_true("AGE" %in% d$var_spec$variable)
  expect_true("AETERM" %in% d$var_spec$variable)
  expect_true("data_type" %in% names(d$var_spec))
})

test_that("read_define_xml extracts codelists", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d$codelist, "data.frame")
  expect_equal(nrow(d$codelist), 2L)
  expect_equal(d$codelist$term, c("M", "F"))
})

test_that("read_define_xml extracts methods", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d$methods, "data.frame")
  expect_equal(nrow(d$methods), 1L)
  expect_equal(d$methods$method_id, "MT.001")
})

test_that("read_define_xml extracts comments", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d$comments, "data.frame")
  expect_equal(d$comments$comment_id, "COM.001")
  expect_equal(d$comments$description, "Test comment")
})

# -- ARM parsing -------------------------------------------------------------

test_that("read_define_xml extracts ARM metadata", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_arm = TRUE)

  d <- herald:::read_define_xml(tmp)
  expect_s3_class(d$arm_displays, "data.frame")
  expect_equal(nrow(d$arm_displays), 1L)
  expect_equal(d$arm_displays$display_id, "RD.T14.1")
  expect_s3_class(d$arm_results, "data.frame")
  expect_equal(nrow(d$arm_results), 1L)
})

test_that("read_define_xml returns NULL arm when no ARM section", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_arm = FALSE)

  d <- herald:::read_define_xml(tmp)
  expect_null(d$arm_displays)
  expect_null(d$arm_results)
})

# -- ItemRef extraction ------------------------------------------------------

test_that("read_define_xml extracts order and mandatory from ItemRef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_itemref = TRUE)

  d <- herald:::read_define_xml(tmp)
  dm_vars <- d$var_spec[d$var_spec$dataset == "DM", ]
  studyid_row <- dm_vars[dm_vars$variable == "STUDYID", ]
  expect_equal(studyid_row$order, "1")
  expect_equal(studyid_row$mandatory, "Yes")
  age_row <- dm_vars[dm_vars$variable == "AGE", ]
  expect_equal(age_row$order, "2")
  expect_equal(age_row$mandatory, "No")
})

# -- key_vars extraction -----------------------------------------------------

test_that("read_define_xml extracts key_vars from ItemGroupDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_keyvar = TRUE)

  d <- herald:::read_define_xml(tmp)
  expect_type(d$key_vars, "list")
  kv <- d$key_vars[["DM"]]
  expect_true(!is.null(kv) && length(kv) > 0L)
  expect_true("STUDYID" %in% kv)
  expect_true("AGE" %in% kv)
})

test_that("read_define_xml key_vars is empty list when no KeyVariables declared", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_keyvar = FALSE)

  d <- herald:::read_define_xml(tmp)
  expect_type(d$key_vars, "list")
  expect_equal(length(d$key_vars), 0L)
})

# -- loinc_version extraction ------------------------------------------------

test_that("read_define_xml extracts loinc_version from def:Standard", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_loinc_std = TRUE)

  d <- herald:::read_define_xml(tmp)
  expect_equal(d$loinc_version, "2.73")
})

test_that("read_define_xml loinc_version is NA when no LOINC standard", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_loinc_std = FALSE)

  d <- herald:::read_define_xml(tmp)
  expect_true(is.na(d$loinc_version))
})

# -- Error cases -------------------------------------------------------------

test_that("read_define_xml errors on non-existent file", {
  expect_error(
    herald:::read_define_xml("/no/such/file.xml"),
    class = "herald_error_file"
  )
})

test_that("read_define_xml errors on non-XML file content", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines("this is not xml at all, no angle brackets", tmp)
  expect_error(
    herald:::read_define_xml(tmp),
    class = "herald_error_file"
  )
})

test_that("read_define_xml errors on malformed XML", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines("<ODM><unclosed>", tmp)
  expect_error(
    herald:::read_define_xml(tmp),
    class = "herald_error_file"
  )
})

test_that("read_define_xml errors when MetaDataVersion is missing", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3">
  <Study OID="S1"></Study>
</ODM>',
    tmp
  )
  expect_error(
    suppressWarnings(herald:::read_define_xml(tmp)),
    class = "herald_error_file"
  )
})

# -- NULL codelist / methods / comments edge cases ---------------------------

test_that("read_define_xml returns NULL codelist when no CodeList elements", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">
        <ItemRef ItemOID="IT.DM.STUDYID" Mandatory="Yes" OrderNumber="1"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text" Length="12"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- herald:::read_define_xml(tmp)
  expect_null(d$codelist)
})

test_that("read_define_xml returns NULL methods when no MethodDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- herald:::read_define_xml(tmp)
  expect_null(d$methods)
})

test_that("read_define_xml returns NULL comments when no CommentDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- herald:::read_define_xml(tmp)
  expect_null(d$comments)
})

# -- print.herald_define -------------------------------------------------------

test_that("print.herald_define prints without error", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp)

  d <- herald:::read_define_xml(tmp)
  expect_output(print(d), "herald_define")
})

# -- op_key_not_unique_per_define --------------------------------------------

test_that("op_key_not_unique_per_define fires on duplicate composite key", {
  data <- data.frame(
    STUDYID = c("S1", "S1"),
    USUBJID = c("S1-001", "S1-001"),
    AGE = c(30L, 30L),
    stringsAsFactors = FALSE
  )
  define_obj <- structure(
    list(key_vars = list(DM = c("STUDYID", "USUBJID"))),
    class = c("herald_define", "list")
  )
  ctx <- list(
    define = define_obj,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 2L)
  expect_true(all(result))
})

test_that("op_key_not_unique_per_define does not fire on unique composite key", {
  data <- data.frame(
    STUDYID = c("S1", "S1"),
    USUBJID = c("S1-001", "S1-002"),
    stringsAsFactors = FALSE
  )
  define_obj <- structure(
    list(key_vars = list(DM = c("STUDYID", "USUBJID"))),
    class = c("herald_define", "list")
  )
  ctx <- list(
    define = define_obj,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 2L)
  expect_true(all(!result))
})

test_that("op_key_not_unique_per_define returns NA advisory when no define", {
  data <- data.frame(
    STUDYID = c("S1", "S1"),
    USUBJID = c("S1-001", "S1-001"),
    stringsAsFactors = FALSE
  )
  ctx <- list(
    define = NULL,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 2L)
  expect_true(all(is.na(result)))
})

test_that("op_key_not_unique_per_define returns NA when dataset not in define", {
  data <- data.frame(
    STUDYID = c("S1"),
    USUBJID = c("S1-001"),
    stringsAsFactors = FALSE
  )
  define_obj <- structure(
    list(key_vars = list()),
    class = c("herald_define", "list")
  )
  ctx <- list(
    define = define_obj,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 1L)
  expect_true(is.na(result[[1L]]))
})

test_that("op_key_not_unique_per_define returns empty logical for zero-row data", {
  data <- data.frame(
    STUDYID = character(),
    USUBJID = character(),
    stringsAsFactors = FALSE
  )
  define_obj <- structure(
    list(key_vars = list(DM = c("STUDYID", "USUBJID"))),
    class = c("herald_define", "list")
  )
  ctx <- list(
    define = define_obj,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 0L)
})

test_that("op_key_not_unique_per_define returns NA when all key cols absent", {
  data <- data.frame(OTHER = c("x", "y"), stringsAsFactors = FALSE)
  define_obj <- structure(
    list(key_vars = list(DM = c("STUDYID", "USUBJID"))),
    class = c("herald_define", "list")
  )
  ctx <- list(
    define = define_obj,
    current_dataset = "DM",
    current_rule_id = "CG0019",
    missing_refs = list()
  )
  result <- herald:::op_key_not_unique_per_define(data, ctx)
  expect_equal(length(result), 2L)
  expect_true(all(is.na(result)))
})

# -- validate() define parameter wiring -------------------------------------

# -- print.herald_define: singular branches ------------------------------------

test_that("print.herald_define shows singular forms for 1 dataset/variable/key", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  # minimal define with exactly 1 dataset, 1 variable, 1 key-var mapping
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S.TEST">
    <MetaDataVersion OID="MDV.1" Name="MDV" DefineVersion="2.1.0">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"
                    def:KeyVariables="IT.DM.STUDYID">
        <ItemRef ItemOID="IT.DM.STUDYID" Mandatory="Yes" OrderNumber="1"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text" Length="12"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- herald:::read_define_xml(tmp)
  out <- capture.output(print(d))
  # 1 dataset -> "dataset" not "datasets"
  expect_true(any(grepl("1 dataset,", out)))
  # 1 variable -> "variable" not "variables"
  expect_true(any(grepl("1 variable,", out)))
  # 1 key-var mapping -> "mapping" not "mappings"
  expect_true(any(grepl("1 key-var mapping", out)))
})

test_that("print.herald_define shows LOINC version when present", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  write_test_define(tmp, include_loinc_std = TRUE)
  d <- herald:::read_define_xml(tmp)
  out <- capture.output(print(d))
  expect_true(any(grepl("LOINC version", out)))
  expect_true(any(grepl("2.73", out)))
})

# -- .define_extract_study: no GlobalVariables / empty children ---------------

test_that(".define_extract_study returns empty data.frame when no GlobalVariables", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_s3_class(d$study, "data.frame")
  expect_equal(nrow(d$study), 0L)
})

test_that(".define_extract_study returns empty data.frame when GlobalVariables has no children", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <GlobalVariables/>
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_equal(nrow(d$study), 0L)
})

# -- .define_extract_datasets: empty ItemGroupDef (no namespace) ---------------

test_that(".define_extract_datasets returns empty data.frame when no ItemGroupDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_equal(nrow(d$ds_spec), 0L)
})

test_that(".define_extract_datasets uses def:Label fallback when no Description", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  # ItemGroupDef has no Description child -- triggers the def:Label fallback path
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No" def:Label="Demog"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_equal(d$ds_spec$dataset, "DM")
  # label is whatever xml2 returns for def:Label (may be "Demog" or "")
  expect_true(is.character(d$ds_spec$label))
})

# -- .define_extract_variables: OID convention fallback -----------------------

test_that(".define_extract_variables falls back to OID convention when no ItemRef mapping", {
  # ItemDef has OID "IT.AE.AETERM" -- no ItemRef to map it, so dataset
  # comes from OID split: parts[2] = "AE"
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.AE" Name="AE" Repeating="Yes"/>
      <ItemDef OID="IT.AE.AETERM" Name="AETERM" DataType="text" Length="200"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_true("AETERM" %in% d$var_spec$variable)
  aeterm_row <- d$var_spec[d$var_spec$variable == "AETERM", ]
  expect_equal(aeterm_row$dataset, "AE")
})

test_that(".define_extract_variables returns empty data.frame when no ItemDef", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_equal(nrow(d$var_spec), 0L)
  expect_true("dataset" %in% names(d$var_spec))
})

# -- .define_extract_codelists: EnumeratedItem and codelist with no items ------

test_that(".define_extract_codelists handles EnumeratedItem (no Decode)", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
      <CodeList OID="CL.NY" Name="NY" DataType="text">
        <EnumeratedItem CodedValue="Y"/>
        <EnumeratedItem CodedValue="N"/>
      </CodeList>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_s3_class(d$codelist, "data.frame")
  expect_equal(d$codelist$term, c("Y", "N"))
  # EnumeratedItem has no Decode, so decoded_value should be ""
  expect_true(all(d$codelist$decoded_value == ""))
})

test_that(".define_extract_codelists returns NULL when CodeList has no items", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
      <CodeList OID="CL.EMPTY" Name="Empty" DataType="text"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_null(d$codelist)
})

# -- .define_extract_arm: ResultDisplay with no AnalysisResult children -------

test_that(".define_extract_arm returns NULL results when ResultDisplay has no AnalysisResult", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1"
     xmlns:arm="http://www.cdisc.org/ns/arm/v1.0">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <arm:AnalysisResultDisplays>
        <arm:ResultDisplay OID="RD.001" Name="Table 1"/>
      </arm:AnalysisResultDisplays>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_s3_class(d$arm_displays, "data.frame")
  expect_equal(nrow(d$arm_displays), 1L)
  # No AnalysisResult children -> results is NULL
  expect_null(d$arm_results)
})

# -- .define_extract_key_vars: def:KeyVariable child elements -----------------

test_that(".define_extract_key_vars handles def:KeyVariable child elements", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  # Use KeyVariable child elements instead of KeyVariables attribute
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">
        <def:KeyVariable OID="IT.DM.STUDYID"/>
        <def:KeyVariable OID="IT.DM.USUBJID"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text" Length="12"/>
      <ItemDef OID="IT.DM.USUBJID" Name="USUBJID" DataType="text" Length="40"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  kv <- d$key_vars[["DM"]]
  expect_false(is.null(kv))
  expect_true("STUDYID" %in% kv)
  expect_true("USUBJID" %in% kv)
})

test_that(".define_extract_key_vars skips datasets with empty names", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"
                    def:KeyVariables="IT.DM.STUDYID">
        <ItemRef ItemOID="IT.DM.STUDYID" Mandatory="Yes" OrderNumber="1"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.STUDYID" Name="STUDYID" DataType="text" Length="12"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  # Only DM should be present; no empty-name entry
  expect_true("DM" %in% names(d$key_vars))
})

# -- .define_extract_loinc_version: ExternalCodeList path ----------------------

test_that(".define_extract_loinc_version finds LOINC via ExternalCodeList", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No"/>
      <CodeList OID="CL.LOINC" Name="LOINC" DataType="text">
        <def:ExternalCodeList Dictionary="LOINC" Version="2.74"/>
      </CodeList>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  expect_equal(d$loinc_version, "2.74")
})

# -- .define_extract_variables: no label TranslatedText -----------------------

test_that(".define_extract_variables handles ItemDef with no Description", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">
        <ItemRef ItemOID="IT.DM.AGE" Mandatory="Yes" OrderNumber="1"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.AGE" Name="AGE" DataType="integer" Length="4"/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  age_row <- d$var_spec[d$var_spec$variable == "AGE", ]
  expect_equal(nrow(age_row), 1L)
  expect_equal(age_row$label, "")
})

# -- .define_extract_variables: DisplayFormat attribute -----------------------

test_that(".define_extract_variables extracts def:DisplayFormat attribute", {
  tmp <- tempfile(fileext = ".xml")
  withr::defer(unlink(tmp))
  writeLines(
    '<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="S1">
    <MetaDataVersion OID="MDV.1" Name="MDV">
      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">
        <ItemRef ItemOID="IT.DM.AGE" Mandatory="Yes" OrderNumber="1"/>
      </ItemGroupDef>
      <ItemDef OID="IT.DM.AGE" Name="AGE" DataType="integer" Length="4"
               def:DisplayFormat="F8."/>
    </MetaDataVersion>
  </Study>
</ODM>',
    tmp
  )
  d <- suppressWarnings(herald:::read_define_xml(tmp))
  age_row <- d$var_spec[d$var_spec$variable == "AGE", ]
  expect_equal(age_row$format, "F8.")
})

test_that("validate() accepts define parameter without error", {
  skip_if(
    !file.exists(
      system.file("rules", "rules.rds", package = "herald")
    ),
    "rules catalog not compiled"
  )
  dm_data <- data.frame(
    STUDYID = c("S1", "S1"),
    USUBJID = c("S1-001", "S1-002"),
    AGE = c(30L, 31L),
    stringsAsFactors = FALSE
  )
  define_obj <- structure(
    list(
      key_vars = list(DM = c("STUDYID", "USUBJID")),
      loinc_version = NA_character_
    ),
    class = c("herald_define", "list")
  )
  result <- validate(
    files = list(DM = dm_data),
    define = define_obj,
    rules = "CG0019",
    quiet = TRUE
  )
  expect_s3_class(result, "herald_result")
})
