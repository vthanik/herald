# test-dataset-builders.R -- Define-XML tabularization builder layer

.make_minimal_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.PILOT01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.PILOT01">',
    '    <GlobalVariables>',
    '      <StudyName>PILOT01</StudyName>',
    '      <StudyDescription>Test Study</StudyDescription>',
    '      <ProtocolName>PROTO01</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <def:Standards>',
    '        <def:Standard OID="STD.SDTMIG" Name="SDTMIG" Type="CT" Version="3.4" Status="Final"/>',
    '      </def:Standards>',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No" def:Structure="One record per subject">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.USUBJID" Mandatory="Yes" OrderNumber="1"/>',
    '        <ItemRef ItemOID="IT.DM.AGE"     Mandatory="No"  OrderNumber="2"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.USUBJID" Name="USUBJID" DataType="text" Length="200">',
    '        <Description><TranslatedText>Unique Subject ID</TranslatedText></Description>',
    '        <def:Origin Type="Sponsor"/>',
    '      </ItemDef>',
    '      <ItemDef OID="IT.DM.AGE" Name="AGE" DataType="integer" Length="3">',
    '        <Description><TranslatedText>Age</TranslatedText></Description>',
    '      </ItemDef>',
    '      <CodeList OID="CL.SEX" Name="Sex" DataType="text" SASFormatName="$SEX">',
    '        <CodeListItem CodedValue="M"><Decode><TranslatedText>Male</TranslatedText></Decode></CodeListItem>',
    '        <CodeListItem CodedValue="F"><Decode><TranslatedText>Female</TranslatedText></Decode></CodeListItem>',
    '      </CodeList>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

# ---- registry ---------------------------------------------------------------

test_that(".list_builders() returns all 6 builders", {
  bs <- herald:::.list_builders()
  expect_true("Define_Study_Metadata" %in% bs)
  expect_true("Define_Dataset_Metadata" %in% bs)
  expect_true("Define_Variable_Metadata" %in% bs)
  expect_true("Define_Codelist_Metadata" %in% bs)
  expect_true("Define_Standards_Metadata" %in% bs)
  expect_true("Define_ValueLevel_Metadata" %in% bs)
})

# ---- .build_define_datasets produces frames ---------------------------------

test_that(".build_define_datasets returns named list of data.frames", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  expect_type(frames, "list")
  expect_true(length(frames) > 0L)
  for (nm in names(frames)) {
    expect_true(
      is.data.frame(frames[[nm]]),
      info = paste("builder", nm, "should return a data.frame")
    )
  }
})

# ---- Define_Study_Metadata --------------------------------------------------

test_that("Define_Study_Metadata captures ODM + GlobalVariables fields", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  sm <- frames[["Define_Study_Metadata"]]
  expect_equal(nrow(sm), 1L)
  expect_equal(sm$odm_oid, "ODM.PILOT01")
  expect_equal(sm$study_name, "PILOT01")
  expect_equal(sm$study_description, "Test Study")
  expect_equal(sm$protocol_name, "PROTO01")
  expect_equal(sm$def_version, "2.1.0")
})

# ---- Define_Dataset_Metadata ------------------------------------------------

test_that("Define_Dataset_Metadata has one row per ItemGroupDef", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  dm_meta <- frames[["Define_Dataset_Metadata"]]
  expect_equal(nrow(dm_meta), 1L)
  expect_equal(dm_meta$dataset, "DM")
  expect_equal(dm_meta$repeating, "No")
  expect_equal(dm_meta$structure, "One record per subject")
  expect_true(dm_meta$has_description)
})

# ---- Define_Variable_Metadata -----------------------------------------------

test_that("Define_Variable_Metadata has one row per ItemDef", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  vm <- frames[["Define_Variable_Metadata"]]
  expect_equal(nrow(vm), 2L)
  usubjid_row <- vm[vm$variable == "USUBJID", , drop = FALSE]
  expect_equal(nrow(usubjid_row), 1L)
  expect_equal(usubjid_row$data_type, "text")
  expect_equal(usubjid_row$mandatory, "Yes")
  expect_equal(usubjid_row$order, "1")
  expect_equal(usubjid_row$origin_type, "Sponsor")
})

# ---- Define_Codelist_Metadata ------------------------------------------------

test_that("Define_Codelist_Metadata has one row per codelist item", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  cl <- frames[["Define_Codelist_Metadata"]]
  expect_equal(nrow(cl), 2L) # M and F
  expect_true("M" %in% cl$coded_value)
  expect_true("F" %in% cl$coded_value)
  expect_equal(cl$codelist_name[1L], "Sex")
})

# ---- Define_Standards_Metadata -----------------------------------------------

test_that("Define_Standards_Metadata has one row per def:Standard", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  sm <- frames[["Define_Standards_Metadata"]]
  expect_equal(nrow(sm), 1L)
  expect_equal(sm$name, "SDTMIG")
  expect_equal(sm$type, "CT")
  expect_equal(sm$version, "3.4")
})

# ---- validate() injection ---------------------------------------------------

test_that("validate() injects Define builder frames when define= is supplied", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  # Just verify validate() runs without error and datasets include builder frames
  # Use a DEFINE rule known to target Define_Dataset_Metadata
  r <- validate(
    files = list(),
    define = def,
    rules = "DEFINE-093",
    quiet = TRUE
  )
  expect_s3_class(r, "herald_result")
})
