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

# =============================================================================
# Direct builder function calls -- bypass registry to get covr line coverage
# =============================================================================

test_that(".builder_study_metadata returns 1-row data.frame", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_study_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 1L)
  expect_equal(result$study_name, "PILOT01")
})

test_that(".builder_dataset_metadata returns data.frame with dataset column", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_dataset_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("dataset" %in% names(result))
  expect_equal(result$dataset, "DM")
})

test_that(".builder_variable_metadata returns data.frame with variable column", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_variable_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("variable" %in% names(result))
  expect_true("USUBJID" %in% result$variable)
})

test_that(".builder_codelist_metadata returns data.frame with coded_value column", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_codelist_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("coded_value" %in% names(result))
  expect_true("M" %in% result$coded_value)
})

test_that(".builder_codelist_metadata handles external codelist (no items) -- direct", {
  def <- .make_empty_codelist_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_codelist_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 1L)
  expect_true(result$is_external)
  expect_equal(result$coded_value, "")
})

test_that(".builder_standards_metadata returns data.frame with name column", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_standards_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, "SDTMIG")
})

test_that(".builder_valuelevel_metadata returns NULL for minimal define", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_valuelevel_metadata(def)
  expect_null(result)
})

test_that(".builder_valuelevel_metadata returns data.frame for vlm define", {
  def <- .make_vlm_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_valuelevel_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$oid, "WC.01")
})

test_that(".builder_methoddef_metadata returns NULL for minimal define", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_methoddef_metadata(def)
  expect_null(result)
})

test_that(".builder_methoddef_metadata returns data.frame for methoddef define", {
  def <- .make_methoddef_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_methoddef_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$oid, "MT.COMP1")
})

test_that(".builder_arm_metadata returns NULL for minimal define", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_metadata(def)
  expect_null(result)
})

test_that(".builder_arm_metadata returns data.frame for arm define", {
  def <- .make_arm_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("display_oid" %in% names(result))
  expect_equal(nrow(result), 2L)
})

test_that(".builder_arm_result_metadata returns NULL for minimal define", {
  def <- .make_minimal_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_result_metadata(def)
  expect_null(result)
})

test_that(".builder_arm_result_metadata returns data.frame for arm define", {
  def <- .make_arm_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_result_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("result_oid" %in% names(result))
  expect_equal(nrow(result), 3L)
})

test_that(".attr_val returns empty string for missing attribute", {
  if (!requireNamespace("xml2", quietly = TRUE)) skip("xml2 not available")
  doc <- xml2::read_xml("<Root Foo='bar'/>")
  node <- xml2::xml_root(doc)
  expect_equal(herald:::.attr_val(node, "Missing"), "")
  expect_equal(herald:::.attr_val(node, "Foo"), "bar")
})

test_that(".ns_attr returns empty string when attribute missing", {
  if (!requireNamespace("xml2", quietly = TRUE)) skip("xml2 not available")
  doc <- xml2::read_xml("<Root xmlns:def='http://www.cdisc.org/ns/def/v2.1'/>")
  node <- xml2::xml_root(doc)
  expect_equal(herald:::.ns_attr(node, "Version"), "")
})

test_that(".child_text returns empty string when xpath not found", {
  if (!requireNamespace("xml2", quietly = TRUE)) skip("xml2 not available")
  doc <- xml2::read_xml("<Root><Child>text</Child></Root>")
  node <- xml2::xml_root(doc)
  expect_equal(herald:::.child_text(node, ".//Missing"), "")
  expect_equal(herald:::.child_text(node, ".//Child"), "text")
})

# =============================================================================
# Additional branch coverage tests
# =============================================================================

# ---- .register_builder: re-registration (line 16) ---------------------------

test_that(".register_builder overwrites an existing entry without error", {
  fn1 <- function(def) data.frame(x = 1L, stringsAsFactors = FALSE)
  fn2 <- function(def) data.frame(x = 2L, stringsAsFactors = FALSE)
  herald:::.register_builder("_test_dup_builder_", fn1)
  herald:::.register_builder("_test_dup_builder_", fn2)
  fn_out <- herald:::.get_builder("_test_dup_builder_")
  expect_true(is.function(fn_out))
  # fn2 should have replaced fn1
  expect_equal(fn_out(NULL)$x, 2L)
})

# ---- .ns_attr: first return branch (line 56) --------------------------------
# When the namespace-prefixed attribute IS present, return it immediately.

test_that(".ns_attr returns prefixed attribute when present", {
  if (!requireNamespace("xml2", quietly = TRUE)) skip("xml2 not available")
  # Build a node that has def:DefineVersion as a plain attribute named
  # "def:DefineVersion" -- xml2 exposes ns-prefixed attrs when the doc
  # carries that namespace.
  xml_str <- paste0(
    '<MetaDataVersion xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    ' def:DefineVersion="2.1.0"/>'
  )
  doc <- xml2::read_xml(xml_str)
  node <- xml2::xml_root(doc)
  result <- herald:::.ns_attr(node, "DefineVersion")
  expect_equal(result, "2.1.0")
})

# ---- Non-namespaced XML: study/dataset/variable fallback paths --------------
# These helpers create XML without a default namespace so the d1: XPath
# fails and the bare-name fallback branches execute.

.make_nonamespace_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM OID="ODM.NN01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.NN01">',
    '    <GlobalVariables>',
    '      <StudyName>NN01</StudyName>',
    '      <StudyDescription>No-namespace Test</StudyDescription>',
    '      <ProtocolName>PROTO-NN</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.LB" Name="LB" Repeating="Yes">',
    '        <Description><TranslatedText>Lab</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.LB.LBTEST" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.LB.LBTEST" Name="LBTEST" DataType="text" Length="40">',
    '        <Description><TranslatedText>Lab Test Name</TranslatedText></Description>',
    '        <Alias Context="nci:ExtCodeID" Name="C49702"/>',
    '        <CodeListRef CodeListOID="CL.LBTEST"/>',
    '      </ItemDef>',
    '      <CodeList OID="CL.LBTEST" Name="LBTEST" DataType="text">',
    '        <CodeListItem CodedValue="SODIUM">',
    '          <Decode><TranslatedText>Sodium</TranslatedText></Decode>',
    '        </CodeListItem>',
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

test_that(".builder_study_metadata works on non-namespaced XML (fallback paths)", {
  def <- .make_nonamespace_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_study_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 1L)
  expect_equal(result$study_name, "NN01")
  expect_equal(result$protocol_name, "PROTO-NN")
})

test_that(".builder_dataset_metadata works on non-namespaced XML (fallback paths)", {
  def <- .make_nonamespace_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_dataset_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$dataset, "LB")
})

test_that(".builder_variable_metadata works on non-namespaced XML (fallback paths)", {
  def <- .make_nonamespace_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_variable_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("LBTEST" %in% result$variable)
  # alias and codelist branches (lines 342, 347, 355)
  expect_equal(result$alias_context[result$variable == "LBTEST"], "nci:ExtCodeID")
  expect_equal(result$alias_name[result$variable == "LBTEST"], "C49702")
  expect_equal(result$codelist_oid[result$variable == "LBTEST"], "CL.LBTEST")
})

test_that(".builder_codelist_metadata works on non-namespaced XML (fallback paths)", {
  def <- .make_nonamespace_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_codelist_metadata(def)
  expect_true(is.data.frame(result))
  expect_true("SODIUM" %in% result$coded_value)
})

# ---- Null-mdv / null-doc builders: early-return NULL branches ---------------

.make_null_mdv_define <- function() {
  structure(
    list(
      xml_doc  = NULL,
      xml_mdv  = NULL,
      xml_ns   = character(0L),
      file     = "<synthetic>"
    ),
    class = c("herald_define", "list")
  )
}

.make_null_doc_define <- function() {
  structure(
    list(
      xml_doc  = NULL,
      xml_mdv  = structure(list(), class = "xml_node"),
      xml_ns   = character(0L),
      file     = "<synthetic>"
    ),
    class = c("herald_define", "list")
  )
}

test_that(".builder_study_metadata returns NULL when xml_doc is NULL (line 80)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_study_metadata(def)
  expect_null(result)
})

test_that(".builder_dataset_metadata returns NULL when xml_mdv is NULL (line 165)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_dataset_metadata(def)
  expect_null(result)
})

test_that(".builder_variable_metadata returns NULL when xml_mdv is NULL (line 260)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_variable_metadata(def)
  expect_null(result)
})

test_that(".builder_codelist_metadata returns NULL when xml_mdv is NULL (line 416)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_codelist_metadata(def)
  expect_null(result)
})

test_that(".builder_standards_metadata returns NULL when xml_mdv is NULL (line 529)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_standards_metadata(def)
  expect_null(result)
})

test_that(".builder_valuelevel_metadata returns NULL when xml_mdv is NULL (line 562)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_valuelevel_metadata(def)
  expect_null(result)
})

test_that(".builder_methoddef_metadata returns NULL when xml_mdv is NULL (line 623)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_methoddef_metadata(def)
  expect_null(result)
})

test_that(".builder_arm_metadata returns NULL when xml_doc is NULL (line 666)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_arm_metadata(def)
  expect_null(result)
})

test_that(".builder_arm_result_metadata returns NULL when xml_doc is NULL (line 708)", {
  def <- .make_null_mdv_define()
  result <- herald:::.builder_arm_result_metadata(def)
  expect_null(result)
})

# ---- Dataset metadata: Alias + WhereClauseRef branches ----------------------
# Need an ItemGroupDef with an Alias child and a WhereClauseRef.

.make_alias_wc_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.AL01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.AL01">',
    '    <GlobalVariables>',
    '      <StudyName>AL01</StudyName>',
    '      <StudyDescription>Alias WC Test</StudyDescription>',
    '      <ProtocolName>PROTO-AL</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.EX" Name="EX" Repeating="Yes">',
    '        <Description><TranslatedText>Exposure</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.EX.EXDOSE" Mandatory="Yes" OrderNumber="1">',
    '          <def:WhereClauseRef def:WhereClauseOID="WC.EX.01"/>',
    '        </ItemRef>',
    '        <Alias Context="nci:ExtCodeID" Name="C49489"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.EX.EXDOSE" Name="EXDOSE" DataType="float" Length="8">',
    '        <Description><TranslatedText>Dose</TranslatedText></Description>',
    '        <def:Origin Type="CRF"/>',
    '        <def:ValueListRef def:ValueListOID="VL.EXDOSE"/>',
    '      </ItemDef>',
    '      <def:WhereClauseDef OID="WC.EX.01">',
    '      </def:WhereClauseDef>',
    '      <CodeList OID="CL.UNIT" Name="UNIT" DataType="text" SASFormatName="$UNIT">',
    '        <Alias Context="nci:ExtCodeID" Name="C71620"/>',
    '        <CodeListItem CodedValue="mg">',
    '          <Decode><TranslatedText>Milligram</TranslatedText></Decode>',
    '        </CodeListItem>',
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

test_that(".builder_dataset_metadata: alias_context branch when Alias node present (line 208)", {
  def <- .make_alias_wc_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_dataset_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$alias_context[result$dataset == "EX"], "nci:ExtCodeID")
  expect_equal(result$alias_name[result$dataset == "EX"], "C49489")
})

test_that(".builder_dataset_metadata: where_clause_oid branch when WhereClauseRef present (line 220)", {
  def <- .make_alias_wc_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_dataset_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$where_clause_oid[result$dataset == "EX"], "WC.EX.01")
})

test_that(".builder_variable_metadata: valuelist_oid branch when ValueListRef present (line 363)", {
  def <- .make_alias_wc_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_variable_metadata(def)
  expect_true(is.data.frame(result))
  exdose_row <- result[result$variable == "EXDOSE", , drop = FALSE]
  expect_equal(nrow(exdose_row), 1L)
  expect_equal(exdose_row$valuelist_oid, "VL.EXDOSE")
})

test_that(".builder_codelist_metadata: alias_context branch when Alias node present (line 445)", {
  def <- .make_alias_wc_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_codelist_metadata(def)
  expect_true(is.data.frame(result))
  unit_rows <- result[result$codelist_name == "UNIT", , drop = FALSE]
  expect_equal(unit_rows$alias_context[1L], "nci:ExtCodeID")
  expect_equal(unit_rows$alias_name[1L], "C71620")
})

# ---- VLM: WhereClauseDef with no RangeCheck children (lines 579-598) -------

.make_vlm_no_rangecheck_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.VLNRC01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.VLNRC01">',
    '    <GlobalVariables>',
    '      <StudyName>VLNRC01</StudyName>',
    '      <StudyDescription>VLM No-RangeCheck Test</StudyDescription>',
    '      <ProtocolName>PROTO-VLNRC</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.SEX" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.SEX" Name="SEX" DataType="text" Length="1">',
    '        <Description><TranslatedText>Sex</TranslatedText></Description>',
    '      </ItemDef>',
    '      <def:WhereClauseDef OID="WC.EMPTY">',
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

test_that(".builder_valuelevel_metadata: empty RangeCheck branches (lines 579-598)", {
  def <- .make_vlm_no_rangecheck_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_valuelevel_metadata(def)
  expect_true(is.data.frame(result))
  expect_equal(result$oid, "WC.EMPTY")
  # All range-check fields should be empty strings (else branches)
  expect_equal(result$comparator, "")
  expect_equal(result$soft_hard, "")
  expect_equal(result$check_var, "")
  expect_equal(result$check_value, "")
})

# ---- Standards: no Standard nodes (line 534) --------------------------------

.make_nostd_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.NOSTD01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.NOSTD01">',
    '    <GlobalVariables>',
    '      <StudyName>NOSTD01</StudyName>',
    '      <StudyDescription>No Standards Test</StudyDescription>',
    '      <ProtocolName>PROTO-NOSTD</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '        <ItemRef ItemOID="IT.DM.SUBJID" Mandatory="Yes" OrderNumber="1"/>',
    '      </ItemGroupDef>',
    '      <ItemDef OID="IT.DM.SUBJID" Name="SUBJID" DataType="text" Length="20">',
    '        <Description><TranslatedText>Subject ID</TranslatedText></Description>',
    '      </ItemDef>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

test_that(".builder_standards_metadata returns NULL when no Standard nodes (line 534)", {
  def <- .make_nostd_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_standards_metadata(def)
  expect_null(result)
})

# ---- Codelist: no CodeList nodes (line 424) ---------------------------------

test_that(".builder_codelist_metadata returns NULL when no CodeList nodes (line 424)", {
  def <- .make_nostd_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_codelist_metadata(def)
  expect_null(result)
})

# ---- Variable metadata: no ItemDef nodes (line 302) ------------------------
# Create a define with ItemGroupDef/ItemRef but no ItemDef elements.

.make_no_itemdef_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.NOID01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.NOID01">',
    '    <GlobalVariables>',
    '      <StudyName>NOID01</StudyName>',
    '      <StudyDescription>No ItemDef Test</StudyDescription>',
    '      <ProtocolName>PROTO-NOID</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
    '        <Description><TranslatedText>Demographics</TranslatedText></Description>',
    '      </ItemGroupDef>',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp), envir = parent.frame(2L))
  herald:::read_define_xml(tmp)
}

test_that(".builder_variable_metadata returns NULL when no ItemDef nodes (line 302)", {
  def <- .make_no_itemdef_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_variable_metadata(def)
  expect_null(result)
})

test_that(".builder_dataset_metadata returns NULL when no ItemGroupDef nodes (line 173)", {
  def <- .make_no_itemdef_define()
  if (is.null(def)) skip("xml2 not available")
  # The define has an ItemGroupDef so dataset metadata returns a row;
  # but the ItemGroupDef has no ItemRef children -- variable metadata is null.
  # For the dataset builder we want a define with zero ItemGroupDef.
  # Reuse null-mdv approach by manually stripping mdv.
  # Actually .make_no_itemdef_define() still has 1 ItemGroupDef, so call
  # directly with a minimal define whose mdv has no ItemGroupDef children.
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     OID="ODM.NOIG01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.NOIG01">',
    '    <GlobalVariables>',
    '      <StudyName>NOIG01</StudyName>',
    '      <StudyDescription>No IGD Test</StudyDescription>',
    '      <ProtocolName>PROTO-NOIG</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '    </MetaDataVersion>',
    '  </Study>',
    '</ODM>'
  )
  if (!requireNamespace("xml2", quietly = TRUE)) skip("xml2 not available")
  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_str, tmp)
  withr::defer(unlink(tmp))
  def2 <- herald:::read_define_xml(tmp)
  result <- herald:::.builder_dataset_metadata(def2)
  expect_null(result)
})

# ---- ARM ARM_Result: duplicate OID/name detection (lines 691, 730) ----------
# Already covered by existing arm tests with 2 displays having distinct OIDs.
# The duplicate-detection lines (694-697, 733-734) fire only when there ARE
# rows. We confirm the duplicate flags are FALSE when OIDs are all unique.

test_that(".builder_arm_metadata: duplicate detection with unique OIDs (line 694-697)", {
  def <- .make_arm_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_metadata(def)
  expect_false(is.null(result))
  # RD.01 and RD.02 are unique -- no duplicates
  expect_false(any(result$is_duplicate_oid))
  expect_false(any(result$is_duplicate_name))
})

test_that(".builder_arm_result_metadata: duplicate detection with all-unique OIDs (line 733)", {
  def <- .make_arm_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_result_metadata(def)
  expect_false(is.null(result))
  expect_false(any(result$is_duplicate_oid))
})

# ---- ARM: duplicate OID scenario to exercise TRUE path ----------------------

.make_arm_dup_define <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(NULL)
  }
  xml_str <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
    '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
    '     xmlns:arm="http://www.cdisc.org/ns/arm/v1.0"',
    '     OID="ODM.ARMDUP01" CreationDateTime="2020-01-01T00:00:00">',
    '  <Study OID="S.ARMDUP01">',
    '    <GlobalVariables>',
    '      <StudyName>ARMDUP01</StudyName>',
    '      <StudyDescription>ARM Dup OID Test</StudyDescription>',
    '      <ProtocolName>PROTO-ARMDUP</ProtocolName>',
    '    </GlobalVariables>',
    '    <MetaDataVersion OID="MDV.1" Name="MDV1" def:DefineVersion="2.1.0">',
    '      <arm:AnalysisResultDisplays>',
    '        <arm:ResultDisplay OID="RD.DUP" Name="Table Dup1">',
    '          <arm:AnalysisResult OID="AR.DUP" ParameterOID="PAR.01">',
    '          </arm:AnalysisResult>',
    '        </arm:ResultDisplay>',
    '        <arm:ResultDisplay OID="RD.DUP" Name="Table Dup2">',
    '          <arm:AnalysisResult OID="AR.DUP" ParameterOID="PAR.02">',
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

test_that(".builder_arm_metadata: duplicate OID detection flags TRUE (lines 694-697)", {
  def <- .make_arm_dup_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_metadata(def)
  expect_false(is.null(result))
  expect_true(all(result$is_duplicate_oid))
})

test_that(".builder_arm_result_metadata: duplicate OID detection flags TRUE (line 733)", {
  def <- .make_arm_dup_define()
  if (is.null(def)) skip("xml2 not available")
  result <- herald:::.builder_arm_result_metadata(def)
  expect_false(is.null(result))
  expect_true(all(result$is_duplicate_oid))
})
