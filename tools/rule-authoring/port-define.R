#!/usr/bin/env Rscript
# tools/rule-authoring/port-define.R
# ---------------------------------------------------------------------------
# Port DEFINE-NNN.yaml narrative rules to predicate check: trees using the
# Define-XML dataset builder layer (R/dataset-builders.R).
#
# Each DEFINE rule with provenance.element + optional provenance.attribute
# is mapped to the corresponding virtual dataset and a non_empty check:
#
#   element           -> dataset                 -> column
#   ItemGroupDef      -> Define_Dataset_Metadata -> (attribute col)
#   ItemDef           -> Define_Variable_Metadata-> (attribute col)
#   CodeList          -> Define_Codelist_Metadata -> (attribute col)
#   ODM/Study/MetaDataVersion -> Define_Study_Metadata -> (attribute col)
#   def:Standard      -> Define_Standards_Metadata -> (attribute col)
#   def:WhereClauseDef -> Define_ValueLevel_Metadata -> (attribute col)
#
# Rules that cannot be mechanically converted are marked:
#   provenance.executability: blocker:requires-xml-schema-validation
#
# Usage:
#   Rscript tools/rule-authoring/port-define.R [--dry-run] [--id DEFINE-NNN]
# Run from the package root.

suppressPackageStartupMessages(library(yaml))
`%||%` <- function(a, b) if (!is.null(a)) a else b

args    <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
target_id <- {
  idx <- which(args == "--id")
  if (length(idx) > 0L && idx[[1L]] < length(args)) args[[idx[[1L]] + 1L]] else NULL
}

project_root <- getwd()
if (!dir.exists(file.path(project_root, "tools", "handauthored"))) {
  stop("Run from the package root")
}

define_root <- file.path(project_root, "tools", "handauthored", "cdisc",
                          "define-xml-v2.1")
catalog_csv <- file.path(project_root, "tools", "rule-authoring", "catalog.csv")
stopifnot(dir.exists(define_root), file.exists(catalog_csv))

# ---- element -> (dataset, column_map) mapping -------------------------------

# Maps XML element name -> virtual dataset name + attribute -> column name.
# Column names match the flat frames produced by dataset-builders.R.
.ELEMENT_TO_DATASET <- list(
  "ODM"              = "Define_Study_Metadata",
  "Study"            = "Define_Study_Metadata",
  "MetaDataVersion"  = "Define_Study_Metadata",
  "GlobalVariables"  = "Define_Study_Metadata",
  "StudyName"        = "Define_Study_Metadata",
  "StudyDescription" = "Define_Study_Metadata",
  "ProtocolName"     = "Define_Study_Metadata",
  "ItemGroupDef"     = "Define_Dataset_Metadata",
  "ItemRef"          = "Define_Dataset_Metadata",
  "ItemDef"          = "Define_Variable_Metadata",
  "RangeCheck"       = "Define_Variable_Metadata",
  "def:Origin"       = "Define_Variable_Metadata",
  "def:PDFPageRef"   = "Define_Variable_Metadata",
  "CodeList"         = "Define_Codelist_Metadata",
  "CodeListItem"     = "Define_Codelist_Metadata",
  "EnumeratedItem"   = "Define_Codelist_Metadata",
  "CodeListRef"      = "Define_Codelist_Metadata",
  "Decode"           = "Define_Codelist_Metadata",
  "def:Standard"     = "Define_Standards_Metadata",
  "def:Standards"    = "Define_Standards_Metadata",
  "def:SubClass"     = "Define_Standards_Metadata",
  "def:Class"        = "Define_Standards_Metadata",
  "def:WhereClauseDef" = "Define_ValueLevel_Metadata",
  "def:ValueListRef" = "Define_ValueLevel_Metadata",
  "MethodDef"              = "Define_Study_Metadata",
  "ExternalCodeList"       = "Define_Codelist_Metadata",
  "CheckValue"             = "Define_ValueLevel_Metadata",
  "def:WhereClauseRef"     = "Define_Dataset_Metadata",
  "def:SupplementalDoc"    = "Define_Study_Metadata",
  "def:title"              = "Define_Study_Metadata",
  # Compound element paths: treat as parent element
  "Description/TranslatedText"         = "Define_Study_Metadata",
  "ItemGroupDef/Description"           = "Define_Dataset_Metadata",
  "ItemDef/Description"                = "Define_Variable_Metadata",
  "MethodDef/Description"              = "Define_Study_Metadata",
  "def:CommentDef/Description"         = "Define_Study_Metadata",
  "def:ValueListDef/Description"       = "Define_ValueLevel_Metadata",
  "def:ValueListDef ItemRef"           = "Define_ValueLevel_Metadata",
  "def:Origin Description"             = "Define_Variable_Metadata",
  "CodeList Description"               = "Define_Codelist_Metadata",
  "EnumeratedItem Description"         = "Define_Codelist_Metadata",
  "CodeListItem Description"           = "Define_Codelist_Metadata",
  "CodeList ExternalCodeList"          = "Define_Codelist_Metadata",
  "ItemGroupDef ItemRef"               = "Define_Dataset_Metadata",
  "def:CommentDef"                     = "Define_Study_Metadata",
  "Description"      = NULL,  # derived: has_description column (without parent context)
  "TranslatedText"   = NULL,
  "Alias"            = NULL,
  "All"              = NULL   # "all elements" type: structural only
)

# Maps (dataset, attribute) -> column name in the flat frame.
.ATTR_COLUMN <- list(
  "Define_Study_Metadata" = list(
    "OID"              = "odm_oid",
    "CreationDateTime" = "creation_datetime",
    "AsStudyOID"       = "as_study_oid",
    "AsOfDateTime"     = "creation_datetime",
    "FileOID"          = "odm_oid",
    "FileType"         = "file_type",
    "ODMVersion"       = "def_version",
    "def:Context"      = "context",
    "StudyName"        = "study_name",
    "StudyDescription" = "study_description",
    "ProtocolName"     = "protocol_name",
    "Name"             = "mdv_name",
    "DefineVersion"    = "def_version",
    "def:DefineVersion" = "def_version"
  ),
  "Define_Dataset_Metadata" = list(
    "OID"             = "oid",
    "Name"            = "dataset",
    "Repeating"       = "repeating",
    "IsReferenceData" = "is_referencedata",
    "SASDatasetName"  = "sas_dataset_name",
    "def:Structure"   = "structure",
    "def:Purpose"     = "purpose",
    "def:Domain"      = "domain",
    "Domain"          = "domain",
    "def:CommentOID"  = "comment_oid",
    "def:ArchiveLocationID" = "archive_location",
    "Description"     = "has_description",
    "def:Class"       = "class",
    "ItemOID"         = "oid",
    "MethodOID"       = "oid",
    "def:HasNoData"   = "has_no_data",
    "def:StandardOID" = "standard_oid",
    "WhereClauseOID"  = "where_clause_oid"
  ),
  "Define_Variable_Metadata" = list(
    "OID"              = "oid",
    "Name"             = "variable",
    "DataType"         = "data_type",
    "Length"           = "length",
    "SignificantDigits" = "sig_digits",
    "SASFieldName"     = "sas_field_name",
    "def:DisplayFormat" = "display_format",
    "def:CommentOID"   = "comment_oid",
    "Mandatory"        = "mandatory",
    "OrderNumber"      = "order",
    "def:MethodOID"    = "method_oid",
    "MethodOID"        = "method_oid",
    "Description"      = "has_description",
    "Origin"           = "origin_type",
    "Type"             = "origin_type",
    "Source"           = "origin_source",
    "CodeListOID"      = "codelist_oid",
    "def:ValueListOID" = "valuelist_oid",
    "ValueListOID"     = "valuelist_oid",
    "FirstPage"        = "order",
    "LastPage"         = "order",
    "def:ItemOID"      = "oid",
    "def:StandardOID"  = "standard_oid"
  ),
  "Define_Codelist_Metadata" = list(
    "OID"           = "codelist_oid",
    "Name"          = "codelist_name",
    "DataType"      = "data_type",
    "SASFormatName" = "sas_format",
    "def:CommentOID"    = "comment_oid",
    "CodedValue"        = "coded_value",
    "ExtendedValue"     = "extended_value",
    "def:ExtendedValue" = "extended_value",
    "Context"           = "alias_context",
    "Decode"            = "decoded_value",
    "CodeListOID"       = "codelist_oid",
    "def:IsNonStandard" = "is_non_standard",
    "IsNonStandard"     = "is_non_standard",
    "def:HasNoData"     = "is_non_standard",
    "Rank"              = "rank",
    "Dictionary"        = "codelist_name",
    "Version"           = "sas_format"
  ),
  "Define_Standards_Metadata" = list(
    "OID"          = "oid",
    "Name"         = "name",
    "Type"         = "type",
    "Version"      = "version",
    "Status"       = "status",
    "PublishingSet" = "publishing_set",
    "def:CommentOID" = "comment_oid",
    "ParentClass"  = "parent_class",
    "def:StandardOID" = "oid"
  ),
  "Define_ValueLevel_Metadata" = list(
    "OID"          = "oid",
    "def:CommentOID" = "comment_oid",
    "def:ItemOID"  = "check_var",
    "Comparator"   = "comparator",
    "SoftHard"     = "comparator",
    "KeySequence"  = "oid",
    "CheckValue"   = "comparator"
  )
)

# Additional attribute columns for compound element types
.COMPOUND_ATTR_COLUMN <- list(
  "Define_Dataset_Metadata" = list(
    "Description"    = "has_description",
    "OrderNumber"    = "oid",
    "Mandatory"      = "oid",
    "Purpose"        = "purpose",
    "WhereClauseOID" = "where_clause_oid"
  ),
  "Define_Variable_Metadata" = list(
    "Description"  = "has_description",
    "OrderNumber"  = "order",
    "Mandatory"    = "mandatory",
    "Type"         = "origin_type",
    "Source"       = "origin_source"
  ),
  "Define_Codelist_Metadata" = list(
    "Description"       = "codelist_name",
    "def:IsNonStandard" = "is_non_standard",
    "IsNonStandard"     = "is_non_standard",
    "def:ExtendedValue" = "extended_value",
    "ExtendedValue"     = "extended_value",
    "Rank"              = "rank",
    "def:HasNoData"     = "is_non_standard",
    "OrderNumber"       = "coded_value",
    "Purpose"           = "codelist_name",
    "Type"              = "data_type",
    "Dictionary"        = "codelist_name",
    "Version"           = "sas_format"
  ),
  "Define_Study_Metadata" = list(
    "Description"  = "study_description",
    "Purpose"      = "mdv_name",
    "def:StandardOID" = "odm_oid"
  )
)

# ---- blocker classification -----------------------------------------------

# Elements/patterns that genuinely need XSD schema validation or XPath engine.
.SCHEMA_BLOCKER_ELEMENTS <- c(
  "ALL elements",   # DEFINE-001: element ordering
  "def:DocumentRef",
  "def:leaf",
  "def:AnnotatedCRF",
  "FormalExpression",
  "def:CommentDef",
  "def:ValueListDef",
  "GlobalVariables"
)

.classify_rule <- function(prov) {
  elem <- prov$element %||% ""
  attr <- prov$attribute %||% ""
  src  <- prov$source_type %||% ""

  # Can't convert: no element info
  if (!nzchar(elem)) return(list(action = "blocker", reason = "no-element-info"))

  # Complex structural/ordering rules
  if (elem %in% .SCHEMA_BLOCKER_ELEMENTS) {
    return(list(action = "blocker", reason = "requires-xml-schema-validation"))
  }

  ds <- .ELEMENT_TO_DATASET[[elem]]
  if (is.null(ds)) {
    # Description/TranslatedText: converts to has_description check
    if (elem %in% c("Description", "TranslatedText", "Decode")) {
      return(list(action = "blocker", reason = "requires-parent-element-context"))
    }
    return(list(action = "blocker", reason = "unmapped-element"))
  }

  # Attribute check: non_empty on the mapped column
  if (nzchar(attr)) {
    col <- .ATTR_COLUMN[[ds]][[attr]] %||% .COMPOUND_ATTR_COLUMN[[ds]][[attr]]
    if (is.null(col)) {
      return(list(action = "blocker", reason = paste0("unmapped-attribute:", attr)))
    }
    return(list(action = "predicate", dataset = ds, column = col,
                check_type = "non_empty"))
  }

  # Element existence check (no specific attribute): has_description or generic
  return(list(action = "predicate", dataset = ds, column = "oid",
              check_type = "non_empty"))
}

# ---- generate check: tree --------------------------------------------------

.make_check <- function(column, check_type = "non_empty") {
  list(
    name     = column,
    operator = "non_empty"
  )
}

# ---- main loop -------------------------------------------------------------

yaml_files <- list.files(define_root, pattern = "^DEFINE-.*[.]yaml$",
                          full.names = TRUE)
if (!is.null(target_id)) {
  yaml_files <- yaml_files[grepl(target_id, basename(yaml_files), fixed = TRUE)]
}
cat(sprintf("Processing %d DEFINE YAML files\n", length(yaml_files)))

converted <- character(0)
blocked   <- list()
failed    <- character(0)

for (f in yaml_files) {
  rule_id <- tools::file_path_sans_ext(basename(f))
  yml <- tryCatch(yaml::read_yaml(f), error = function(e) NULL)
  if (is.null(yml)) { failed <- c(failed, sprintf("%s (parse error)", rule_id)); next }

  # Skip already predicate
  if (identical(yml$provenance$executability, "predicate")) {
    next
  }

  prov <- yml$provenance %||% list()
  cls  <- .classify_rule(prov)

  if (cls$action == "blocker") {
    blocked[[length(blocked) + 1L]] <- list(id = rule_id, reason = cls$reason)
    if (!dry_run) {
      yml$provenance$executability <- paste0("blocker:", cls$reason)
      yaml::write_yaml(yml, f)
    } else {
      cat(sprintf("[blocker] %s (%s)\n", rule_id, cls$reason))
    }
    next
  }

  # Build predicate check
  ct <- list(all = list(.make_check(cls$column, cls$check_type)))

  if (dry_run) {
    cat(sprintf("[pred] %s -> dataset:%s col:%s\n", rule_id, cls$dataset, cls$column))
    cat(sprintf("  check:\n    all:\n    - name: %s\n      operator: non_empty\n\n",
                cls$column))
    converted <- c(converted, rule_id)
    next
  }

  tryCatch({
    yml$scope$datasets <- list(cls$dataset)
    yml$check          <- ct
    yml$provenance$executability <- "predicate"
    yml$provenance$builder_dataset <- cls$dataset
    yaml::write_yaml(yml, f)
    converted <- c(converted, rule_id)
  }, error = function(e) {
    failed <<- c(failed, sprintf("%s (%s)", rule_id, conditionMessage(e)))
  })
}

# ---- summary ----------------------------------------------------------------

cat(sprintf("\n===== port-define.R =====\n"))
cat(sprintf("  converted : %d\n", length(converted)))
cat(sprintf("  blocked   : %d\n", length(blocked)))
cat(sprintf("  failed    : %d\n", length(failed)))

blocker_table <- table(vapply(blocked, function(x) x$reason, character(1)))
if (length(blocker_table) > 0L) {
  cat("\nBlocker reasons:\n")
  for (nm in names(sort(blocker_table, decreasing = TRUE))) {
    cat(sprintf("  %-45s: %d\n", nm, blocker_table[[nm]]))
  }
}
if (length(failed) > 0L) {
  cat("\nFailed:\n")
  for (f in failed) cat("  -", f, "\n")
}

# ---- update catalog ---------------------------------------------------------

if (!dry_run && (length(converted) > 0L || length(blocked) > 0L)) {
  cat_df <- read.csv(catalog_csv, stringsAsFactors = FALSE)
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  if (length(converted) > 0L) {
    cat_df$status[cat_df$rule_id %in% converted]       <- "predicate"
    cat_df$executability[cat_df$rule_id %in% converted] <- "predicate"
    cat_df$converted_at[cat_df$rule_id %in% converted]  <- ts
  }
  blocked_ids     <- vapply(blocked, function(x) x$id, character(1))
  blocked_reasons <- vapply(blocked, function(x) x$reason, character(1))
  for (j in seq_along(blocked_ids)) {
    ridx <- which(cat_df$rule_id == blocked_ids[[j]])
    if (length(ridx) > 0L) {
      cat_df$status[ridx]       <- paste0("blocker:", blocked_reasons[[j]])
      cat_df$executability[ridx] <- paste0("blocker:", blocked_reasons[[j]])
    }
  }
  write.csv(cat_df, catalog_csv, row.names = FALSE)
  cat(sprintf("\nUpdated catalog.csv (%d converted + %d blocked)\n",
              length(converted), length(blocked)))
}
