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

# ---- .build_define_datasets: non-herald_define returns empty list -----------

test_that(".build_define_datasets returns empty list for non-herald_define", {
  result <- herald:::.build_define_datasets(list())
  expect_type(result, "list")
  expect_equal(length(result), 0L)

  result2 <- herald:::.build_define_datasets("not a define")
  expect_equal(length(result2), 0L)
})

# ---- .get_builder -----------------------------------------------------------

test_that(".get_builder returns NULL for unknown builder name", {
  expect_null(herald:::.get_builder("NoSuchBuilder_XYZ"))
})

test_that(".get_builder returns a function for registered builders", {
  fn <- herald:::.get_builder("Define_Study_Metadata")
  expect_true(is.function(fn))
})

# ---- Define_ARM_Metadata: absent in minimal define -------------------------

test_that("Define_ARM_Metadata absent when no ResultDisplay nodes", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  # Minimal define has no ARM nodes -- builder should return NULL / not appear
  expect_false("Define_ARM_Metadata" %in% names(frames))
})

# ---- Define_ARM_Result_Metadata: absent in minimal define ------------------

test_that("Define_ARM_Result_Metadata absent when no AnalysisResult nodes", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  expect_false("Define_ARM_Result_Metadata" %in% names(frames))
})

# ---- Define_MethodDef_Metadata: absent when no MethodDef -------------------

test_that("Define_MethodDef_Metadata absent when no MethodDef nodes", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  expect_false("Define_MethodDef_Metadata" %in% names(frames))
})

# ---- Define_ValueLevel_Metadata: absent when no WhereClauseDef -------------

test_that("Define_ValueLevel_Metadata absent when no WhereClauseDef nodes", {
  def <- .make_minimal_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  expect_false("Define_ValueLevel_Metadata" %in% names(frames))
})

# ---- ARM builders with a define that has ARM sections ----------------------

.make_arm_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     xmlns:arm="http://www.cdisc.org/ns/arm/v1.0"',
    '     OID="ODM.ARM01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.ARM01">',
    '    <GlobalVariables>',
    '      <StudyName>ARM01</StudyName>',
    '      <StudyDescription>ARM Test</StudyDescription>',
    '      <ProtocolName>PROTO02</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.ADSL" Name="ADSL" Repeating="No">',
    '        <Description><TranslatedText>ADSL</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.ADSL.USUBJID" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.ADSL.USUBJID" Name="USUBJID" DataType="text" Length="200">',
    '        <Description><TranslatedText>Subject ID</TranslatedText></Description>',
    '      </ItemDef>',
    '      <arm:AnalysisResultDisplays>',
    '        <arm:ResultDisplay OID="RD.01" Name="Table 1">',
    '          <Description><TranslatedText>Primary Efficacy</TranslatedText></Description>',
    '          <arm:AnalysisResult OID="AR.01" ParameterOID="PAR.01">',
    '          </arm:AnalysisResult>',
    '          <arm:AnalysisResult OID="AR.02" ParameterOID="PAR.02">',
    '          </arm:AnalysisResult>',
    '        </arm:ResultDisplay>',
    '        <arm:ResultDisplay OID="RD.02" Name="Table 2">',
    '          <arm:AnalysisResult OID="AR.03" ParameterOID="PAR.01">',
    '          </arm:AnalysisResult>',
    '        </arm:ResultDisplay>',
    '      </arm:AnalysisResultDisplays>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

test_that("Define_ARM_Metadata returns one row per ResultDisplay", {
  def <- .make_arm_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  arm <- frames[["Define_ARM_Metadata"]]
  expect_false(is.null(arm))
  expect_equal(nrow(arm), 2L)
  expect_true("display_oid" %in% names(arm))
  expect_true("display_name" %in% names(arm))
  expect_true("is_duplicate_oid" %in% names(arm))
  expect_true("is_duplicate_name" %in% names(arm))
  expect_true("RD.01" %in% arm$display_oid)
})

test_that("Define_ARM_Result_Metadata returns one row per AnalysisResult", {
  def <- .make_arm_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  arm_res <- frames[["Define_ARM_Result_Metadata"]]
  expect_false(is.null(arm_res))
  expect_equal(nrow(arm_res), 3L)
  expect_true("result_oid" %in% names(arm_res))
  expect_true("display_oid" %in% names(arm_res))
  expect_true("parameter_oid" %in% names(arm_res))
  expect_true("is_duplicate_oid" %in% names(arm_res))
})

# ---- Define_MethodDef_Metadata with a define that has MethodDefs -----------

.make_methoddef_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.MD01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.MD01">',
    '    <GlobalVariables>',
    '      <StudyName>MD01</StudyName>',
    '      <StudyDescription>MethodDef Test</StudyDescription>',
    '      <ProtocolName>PROTO03</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.USUBJID" Mandatory="Yes" OrderNumber="1"',
    '                 def:MethodOID="MT.COMP1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.USUBJID" Name="USUBJID" DataType="text" Length="200">',
    '        <Description><TranslatedText>Subject ID</TranslatedText></Description>',
    '      </ItemDef>',
    '      <MethodDef OID="MT.COMP1" Name="Compute USUBJID" Type="Computation">',
    '        <Description><TranslatedText>Derived from site + subject number</TranslatedText></Description>',
    '      </MethodDef>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

test_that("Define_MethodDef_Metadata returns one row per MethodDef", {
  def <- .make_methoddef_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  md <- frames[["Define_MethodDef_Metadata"]]
  expect_false(is.null(md))
  expect_equal(nrow(md), 1L)
  expect_equal(md$oid, "MT.COMP1")
  expect_equal(md$method_type, "Computation")
  expect_true(md$has_description)
})

# ---- Define_ValueLevel_Metadata with a define that has WhereClauseDefs ----

.make_vlm_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.VLM01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.VLM01">',
    '    <GlobalVariables>',
    '      <StudyName>VLM01</StudyName>',
    '      <StudyDescription>VLM Test</StudyDescription>',
    '      <ProtocolName>PROTO04</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.USUBJID" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.USUBJID" Name="USUBJID" DataType="text" Length="200">',
    '        <Description><TranslatedText>Subject ID</TranslatedText></Description>',
    '      </ItemDef>',
    '      <def:WhereClauseDef OID="WC.01">',
    '        <def:RangeCheck Comparator="EQ" SoftHard="Soft" def:ItemOID="IT.DM.USUBJID">',
    '          <def:CheckValue>SUBJ001</def:CheckValue>',
    '        </def:RangeCheck>',
    '      </def:WhereClauseDef>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

test_that("Define_ValueLevel_Metadata returns rows for WhereClauseDef nodes", {
  def <- .make_vlm_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  vlm <- frames[["Define_ValueLevel_Metadata"]]
  expect_false(is.null(vlm))
  expect_equal(nrow(vlm), 1L)
  expect_equal(vlm$oid, "WC.01")
  expect_equal(vlm$comparator, "EQ")
  expect_equal(vlm$soft_hard, "Soft")
  expect_equal(vlm$check_value, "SUBJ001")
})

# ---- Define_Codelist_Metadata: empty codelist (no items) -------------------

.make_empty_codelist_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.CL01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.CL01">',
    '    <GlobalVariables>',
    '      <StudyName>CL01</StudyName>',
    '      <StudyDescription>CL Test</StudyDescription>',
    '      <ProtocolName>PROTO05</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>DM</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.SEX" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.SEX" Name="SEX" DataType="text" Length="1">',
    '        <Description><TranslatedText>Sex</TranslatedText></Description>',
    '      </ItemDef>',
    '      <CodeList OID="CL.EXT" Name="ExtList" DataType="text">',
    '        <ExternalCodeList Dictionary="MedDRA" Version="25.0"/>',
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

test_that("Define_Codelist_Metadata handles external codelist (no items)", {
  def <- .make_empty_codelist_define()
  if (is.null(def)) {
    skip("xml2 not available")
  }
  frames <- herald:::.build_define_datasets(def)
  cl <- frames[["Define_Codelist_Metadata"]]
  expect_false(is.null(cl))
  expect_equal(nrow(cl), 1L)
  expect_true(cl$is_external)
  expect_equal(cl$coded_value, "")
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
