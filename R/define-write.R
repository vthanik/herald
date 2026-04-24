# --------------------------------------------------------------------------
# define-write.R -- write_define_xml(): herald_spec -> Define-XML 2.1
# Merged from herald-v0: define-write.R + define-build.R + define-build-arm.R
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

#' Write a Define-XML 2.1 file from a herald specification
#'
#' @description
#' Generates a valid Define-XML 2.1 document from a \code{herald_spec} object
#' and writes it to disk. The output includes full namespace declarations for
#' ODM 1.3, Define-XML 2.1 extensions, and Analysis Results Metadata (ARM) 1.0.
#'
#' This is the inverse of \code{\link{read_define_xml}}: a spec created from
#' any source (programmatic or parsed Define-XML) can be written out as
#' Define-XML 2.1.
#'
#' @param spec A \code{herald_spec} object. At minimum, \code{ds_spec} and
#'   \code{var_spec} must be populated.
#' @param path File path for the output XML. Should end in \code{.xml}.
#' @param stylesheet Logical. Include an XSL stylesheet processing instruction
#'   in the output XML and copy \code{define2-1.xsl} alongside the output file?
#'   Default \code{TRUE}.
#' @param validate Logical. Run DD0001--DD0085 Define-XML rules against the
#'   spec before writing? Default \code{TRUE}. Findings are reported as
#'   warnings; generation is never blocked.
#'
#' @return The output path, invisibly. The validation result (if run) is
#'   attached as the \code{"validation"} attribute.
#'
#' @examples
#' spec <- as_herald_spec(
#'   ds_spec = data.frame(dataset = "DM", label = "Demographics",
#'                        stringsAsFactors = FALSE),
#'   var_spec = data.frame(dataset = "DM", variable = "STUDYID",
#'                         label = "Study Identifier", data_type = "text",
#'                         length = "12", stringsAsFactors = FALSE)
#' )
#'
#' ## -- Write to temporary file ----------------------------------------------
#' tmp <- tempfile(fileext = ".xml")
#' write_define_xml(spec, tmp, validate = FALSE)
#' unlink(tmp)
#'
#' @seealso [read_define_xml()] for the inverse operation.
#'
#' @family spec
#' @export
write_define_xml <- function(spec, path, stylesheet = TRUE, validate = TRUE) {
  call <- rlang::caller_env()
  check_herald_spec(spec, call = call)
  check_scalar_chr(path, call = call)

  if (!requireNamespace("xml2", quietly = TRUE)) {
    herald_error(
      c(
        "Package {.pkg xml2} is required to write Define-XML files.",
        "i" = "Install with: {.code install.packages(\"xml2\")}"
      ),
      class = "herald_error_input",
      call = call
    )
  }

  # Run DD0001-DD0085 Define-XML rules against the spec
  val_result <- NULL
  if (isTRUE(validate)) {
    val_result <- tryCatch(
      .validate_spec_define(spec),
      error = function(e) {
        rlang::warn(
          c(
            "Define-XML spec validation failed unexpectedly.",
            "x" = conditionMessage(e),
            "i" = "Proceeding with XML generation."
          )
        )
        NULL
      }
    )

    n_significant <- (val_result$summary$reject %||% 0L) +
      (val_result$summary$high %||% 0L) +
      (val_result$summary$medium %||% 0L)
    if (!is.null(val_result) && n_significant > 0L) {
      n_err <- val_result$summary$reject + val_result$summary$high
      n_warn <- val_result$summary$medium
      errs <- val_result$findings[
        val_result$findings$impact %in% c("Reject", "High", "Medium"),
        ,
        drop = FALSE
      ]
      shown <- utils::head(errs$message, 5L)
      more <- max(0L, nrow(errs) - 5L)

      rlang::warn(c(
        sprintf(
          "Define-XML spec validation found %d error(s) and %d warning(s).",
          n_err, n_warn
        ),
        stats::setNames(
          paste0("[", utils::head(errs$rule_id, 5L), "] ", shown),
          rep("x", length(shown))
        ),
        if (more > 0L) c("i" = sprintf("... and %d more.", more)),
        "i" = "Set validate = FALSE to suppress."
      ))
    }
  }

  doc <- .build_define_xml(spec)

  if (isTRUE(stylesheet)) {
    # Serialise the document, then inject the stylesheet PI before the root
    # element. xml2 does not expose a first-class API for pre-root PIs, so we
    # use the standard pattern: obtain the XML declaration line separately and
    # insert the PI immediately after it.
    xml_str <- as.character(doc)

    pi <- '<?xml-stylesheet type="text/xsl" href="define2-1.xsl"?>'

    # xml2::as.character() may or may not emit the XML declaration.
    # Detect and handle both forms so the PI always ends up before <ODM>.
    if (grepl("^<\\?xml", xml_str)) {
      # Replace first newline after the XML declaration with PI + newline
      xml_str <- sub(
        "(^<\\?xml[^>]*\\?>)(\\n?)",
        paste0("\\1\n", pi, "\n"),
        xml_str
      )
    } else {
      xml_str <- paste0(
        '<?xml version="1.0" encoding="UTF-8"?>',
        "\n",
        pi,
        "\n",
        xml_str
      )
    }

    writeLines(xml_str, path, useBytes = FALSE)
  } else {
    xml2::write_xml(doc, path)
  }

  if (isTRUE(stylesheet)) {
    xsl_dest <- file.path(dirname(path), "define2-1.xsl")
    if (!file.exists(xsl_dest)) {
      xsl_src <- system.file("extdata", "define2-1.xsl", package = "herald")
      if (nzchar(xsl_src) && file.exists(xsl_src)) {
        file.copy(xsl_src, xsl_dest)
      }
    }
  }

  result <- path
  if (!is.null(val_result)) {
    attr(result, "validation") <- val_result
  }
  invisible(result)
}

# --------------------------------------------------------------------------
# Internal: spec-level Define-XML validation (light subset of DD rules)
# --------------------------------------------------------------------------

#' Validate a herald_spec for Define-XML 2.1 conformance
#'
#' Checks the spec data frames against a selection of the 225 CDISC
#' Define-XML v2.1 conformance rules and returns a summary list. This is
#' called by \code{write_define_xml(validate = TRUE)}.
#'
#' @param spec A \code{herald_spec}.
#' @return A list with class \code{herald_validation} containing
#'   \code{$findings} (data.frame) and \code{$summary} (named integer vector).
#' @noRd
.validate_spec_define <- function(spec) {
  call <- rlang::caller_env()
  check_herald_spec(spec, call = call)

  findings <- list()

  .add <- function(rule_id, impact, message, dataset = NA_character_,
                   variable = NA_character_) {
    findings[[length(findings) + 1L]] <<- data.frame(
      rule_id  = rule_id,
      impact   = impact,
      message  = message,
      dataset  = dataset,
      variable = variable,
      stringsAsFactors = FALSE
    )
  }

  ds_spec  <- spec$ds_spec
  var_spec <- spec$var_spec
  study    <- spec$study

  # DD0018: StudyName required
  if (is.null(study) || nrow(study) == 0L ||
      !any(study$attribute == "StudyName", na.rm = TRUE)) {
    .add("DD0018", "High", "StudyName missing from study metadata.")
  }
  # DD0020: StudyDescription required
  if (is.null(study) || nrow(study) == 0L ||
      !any(study$attribute == "StudyDescription", na.rm = TRUE)) {
    .add("DD0020", "Medium", "StudyDescription missing from study metadata.")
  }
  # DD0022: ProtocolName required
  if (is.null(study) || nrow(study) == 0L ||
      !any(study$attribute == "ProtocolName", na.rm = TRUE)) {
    .add("DD0022", "Medium", "ProtocolName missing from study metadata.")
  }

  # DD0117: Purpose required for each dataset
  if (is.data.frame(ds_spec) && nrow(ds_spec) > 0L) {
    if (!"purpose" %in% names(ds_spec)) {
      for (i in seq_len(nrow(ds_spec))) {
        .add("DD0117", "High",
             sprintf("Purpose missing for dataset %s.", ds_spec$dataset[i]),
             dataset = ds_spec$dataset[i])
      }
    }
  }

  # DD0131: def:Class required for each dataset in submission
  if (is.data.frame(ds_spec) && nrow(ds_spec) > 0L) {
    if (!"class" %in% names(ds_spec)) {
      for (i in seq_len(nrow(ds_spec))) {
        .add("DD0131", "High",
             sprintf("Class missing for dataset %s.", ds_spec$dataset[i]),
             dataset = ds_spec$dataset[i])
      }
    }
  }

  # DD0108: SASDatasetName (= dataset name) should match
  # In write, we use Name=dataset which also becomes SASDatasetName,
  # so this is a writer-level check -- no action needed here.

  # DD0139: DataType required for each variable
  if (is.data.frame(var_spec) && nrow(var_spec) > 0L) {
    if ("data_type" %in% names(var_spec)) {
      for (i in seq_len(nrow(var_spec))) {
        dt <- .safe_col(var_spec, "data_type", i)
        if (!nzchar(dt)) {
          .add("DD0139", "High",
               sprintf("DataType missing for variable %s.%s.",
                       var_spec$dataset[i], var_spec$variable[i]),
               dataset  = var_spec$dataset[i],
               variable = var_spec$variable[i])
        }
      }
    } else {
      .add("DD0139", "High",
           "Column 'data_type' missing from var_spec; DataType is required.")
    }
  }

  # DD0141: Length required for text/integer/float variables
  if (is.data.frame(var_spec) && nrow(var_spec) > 0L) {
    numeric_types <- c("text", "integer", "float")
    for (i in seq_len(nrow(var_spec))) {
      dt <- .safe_col(var_spec, "data_type", i)
      len <- .safe_col(var_spec, "length", i)
      if (tolower(dt) %in% numeric_types && !nzchar(len)) {
        .add("DD0141", "High",
             sprintf("Length missing for %s variable %s.%s.",
                     dt, var_spec$dataset[i], var_spec$variable[i]),
             dataset  = var_spec$dataset[i],
             variable = var_spec$variable[i])
      }
    }
  }

  # DD0154/DD0155: def:Origin required for all variables
  if (is.data.frame(var_spec) && nrow(var_spec) > 0L) {
    for (i in seq_len(nrow(var_spec))) {
      origin <- .safe_col(var_spec, "origin", i)
      if (!nzchar(origin)) {
        .add("DD0154", "Medium",
             sprintf("Origin missing for variable %s.%s.",
                     var_spec$dataset[i], var_spec$variable[i]),
             dataset  = var_spec$dataset[i],
             variable = var_spec$variable[i])
      }
    }
  }

  # Collect findings
  if (length(findings) == 0L) {
    findings_df <- data.frame(
      rule_id  = character(),
      impact   = character(),
      message  = character(),
      dataset  = character(),
      variable = character(),
      stringsAsFactors = FALSE
    )
  } else {
    findings_df <- do.call(rbind, findings)
  }

  summary_vec <- list(
    total  = nrow(findings_df),
    reject = sum(findings_df$impact == "Reject", na.rm = TRUE),
    high   = sum(findings_df$impact == "High",   na.rm = TRUE),
    medium = sum(findings_df$impact == "Medium",  na.rm = TRUE),
    low    = sum(findings_df$impact == "Low",     na.rm = TRUE)
  )

  structure(
    list(findings = findings_df, summary = summary_vec),
    class = "herald_validation"
  )
}

# --------------------------------------------------------------------------
# Internal: XML document builder
# --------------------------------------------------------------------------

# Namespace URIs
.define_ns <- list(
  odm   = "http://www.cdisc.org/ns/odm/v1.3",
  def   = "http://www.cdisc.org/ns/def/v2.1",
  arm   = "http://www.cdisc.org/ns/arm/v1.0",
  xlink = "http://www.w3.org/1999/xlink"
)

#' Normalise an OID to use a required P21-convention prefix.
#'
#' Adds \code{prefix} to \code{oid} when it is not already present.
#' Empty or NA values are returned as-is.
#' @noRd
.norm_oid <- function(oid, prefix) {
  if (is.null(oid) || is.na(oid) || !nzchar(oid)) {
    return(oid)
  }
  if (startsWith(oid, prefix)) {
    return(oid)
  }
  paste0(prefix, oid)
}

#' Build a complete Define-XML 2.1 document from a herald_spec.
#'
#' @param spec A herald_spec object.
#' @return An xml2 xml_document.
#' @noRd
.build_define_xml <- function(spec) {
  # ODM root with namespace declarations
  odm <- xml2::xml_new_root(
    "ODM",
    xmlns    = .define_ns$odm,
    "xmlns:def"   = .define_ns$def,
    "xmlns:arm"   = .define_ns$arm,
    "xmlns:xlink" = .define_ns$xlink,
    Context            = "Submission",
    FileOID            = "DEF.HERALD",
    FileType           = "Snapshot",
    CreationDateTime   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    Originator         = "herald",
    SourceSystem       = "herald",
    SourceSystemVersion = as.character(utils::packageVersion("herald")),
    ODMVersion         = "1.3.2"
  )

  # Study container (DD0010/DD0012)
  study_node <- xml2::xml_add_child(odm, "Study", OID = "S.HERALD")

  # GlobalVariables (DD0014/DD0018-DD0023)
  .build_global_variables(study_node, spec$study)

  # MetaDataVersion (DD0024/DD0026/DD0027/DD0028/DD0029)
  mdv <- xml2::xml_add_child(
    study_node,
    "MetaDataVersion",
    OID  = "MDV.1",
    Name = "herald",
    "def:DefineVersion" = "2.1.0"
  )

  # Elements in strict Define-XML 2.1 order (per XSD)
  .build_standards(mdv, spec$ds_spec)             # def:Standards (DD0031)
  .build_annotated_crf(mdv, spec$documents)       # def:AnnotatedCRF (DD0038)
  .build_supplemental_doc(mdv, spec$documents)    # def:SupplementalDoc (DD0051)
  .build_value_list_defs(mdv, spec$value_spec, spec$var_spec)
  .build_where_clause_defs(mdv, spec$value_spec)

  # Core ODM elements
  .build_item_group_defs(mdv, spec$ds_spec, spec$var_spec)
  .build_item_defs(mdv, spec$var_spec)
  .build_codelists(mdv, spec$codelist)
  .build_method_defs(mdv, spec$methods)

  # Post-include extensions
  .build_comment_defs(mdv, spec$comments)
  .build_leaf_defs(mdv, spec$ds_spec, spec$documents)
  .build_arm(mdv, spec$arm_displays, spec$arm_results)

  odm
}

# --------------------------------------------------------------------------
# Node builders (internal helpers)
# --------------------------------------------------------------------------

#' Build GlobalVariables from study data.frame.
#' Ensures StudyName/StudyDescription/ProtocolName are always present (DD0018-DD0023).
#' @noRd
.build_global_variables <- function(study_node, study_df) {
  gv <- xml2::xml_add_child(study_node, "GlobalVariables")

  if (is.null(study_df) || nrow(study_df) == 0L) {
    xml2::xml_add_child(gv, "StudyName",        "UNKNOWN")
    xml2::xml_add_child(gv, "StudyDescription", "")
    xml2::xml_add_child(gv, "ProtocolName",     "UNKNOWN")
    return(invisible(gv))
  }

  # Emit each row from study_df (preserves order)
  for (i in seq_len(nrow(study_df))) {
    xml2::xml_add_child(gv, study_df$attribute[i], study_df$value[i])
  }

  # Backfill any missing mandatory elements (DD0018/DD0020/DD0022)
  present <- study_df$attribute
  if (!"StudyName" %in% present) {
    xml2::xml_add_child(gv, "StudyName", "UNKNOWN")
  }
  if (!"StudyDescription" %in% present) {
    xml2::xml_add_child(gv, "StudyDescription", "")
  }
  if (!"ProtocolName" %in% present) {
    xml2::xml_add_child(gv, "ProtocolName", "UNKNOWN")
  }

  invisible(gv)
}

#' Build def:Standards element from ds_spec (DD0031-DD0036).
#' @noRd
.build_standards <- function(mdv, ds_spec) {
  if (is.null(ds_spec) || nrow(ds_spec) == 0L) {
    return(invisible(NULL))
  }

  standards_list <- list()
  std_counter    <- 0L

  if ("standard" %in% names(ds_spec)) {
    raw_standards <- unique(stats::na.omit(ds_spec[["standard"]]))
    raw_standards <- raw_standards[nzchar(raw_standards)]

    for (raw_std in raw_standards) {
      parsed <- .parse_standard_string(raw_std)
      if (!is.null(parsed)) {
        std_counter <- std_counter + 1L
        parsed$oid  <- paste0("STD.", std_counter)
        standards_list <- c(standards_list, list(parsed))
      }
    }
  }

  if (length(standards_list) == 0L) {
    return(invisible(NULL))
  }

  stds_node <- xml2::xml_add_child(mdv, "def:Standards")

  for (std in standards_list) {
    attrs <- list(
      OID     = std$oid,
      Name    = std$name,
      Type    = std$type,
      Version = std$version,
      Status  = std$status
    )
    # DD0035: PublishingSet required when Type="CT"
    if (!is.null(std$publishing_set)) {
      attrs$PublishingSet <- std$publishing_set
    } else if (identical(std$type, "CT")) {
      attrs$PublishingSet <- std$name
    }
    do.call(xml2::xml_add_child, c(list(stds_node, "def:Standard"), attrs))
  }

  invisible(stds_node)
}

#' Parse a standard string like "ADaMIG 1.1" into components.
#' @noRd
.parse_standard_string <- function(raw) {
  if (is.na(raw) || !nzchar(raw)) {
    return(NULL)
  }

  parts    <- strsplit(trimws(raw), "\\s+")[[1L]]
  name     <- parts[1L]
  version  <- if (length(parts) >= 2L) parts[2L] else "1.0"

  name_upper    <- toupper(name)
  type          <- "IG"
  publishing_set <- NULL

  if (grepl("^ADAM", name_upper)) {
    name           <- "ADaMIG"
    publishing_set <- "ADaM"
  } else if (grepl("^SDTM", name_upper)) {
    if      (grepl("AP$",  name_upper)) { name <- "SDTMIG-AP" }
    else if (grepl("MD$",  name_upper)) { name <- "SDTMIG-MD" }
    else                                { name <- "SDTMIG"    }
    publishing_set <- "SDTM"
  } else if (grepl("^SEND", name_upper)) {
    if      (grepl("AR$",      name_upper)) { name <- "SENDIG-AR"      }
    else if (grepl("DART$",    name_upper)) { name <- "SENDIG-DART"    }
    else if (grepl("GENETOX$", name_upper)) { name <- "SENDIG-GENETOX" }
    else                                    { name <- "SENDIG"         }
    publishing_set <- "SEND"
  } else if (grepl("^CDISC", name_upper) || grepl("^NCI", name_upper)) {
    name <- "CDISC/NCI"
    type <- "CT"
  } else if (grepl("^BIMO", name_upper)) {
    name <- "BIMO"
  }

  list(
    name           = name,
    type           = type,
    version        = version,
    status         = "Final",
    publishing_set = publishing_set
  )
}

#' Build ItemGroupDef elements from ds_spec (DD0093/DD0094/DD0104/DD0108/DD0113/DD0117/DD0118/DD0119/DD0128/DD0131).
#' @noRd
.build_item_group_defs <- function(mdv, ds_spec, var_spec) {
  if (is.null(ds_spec) || nrow(ds_spec) == 0L) {
    return(invisible(NULL))
  }

  # Parse key variables for each dataset
  key_vars_map <- list()
  if ("keys" %in% names(ds_spec)) {
    for (i in seq_len(nrow(ds_spec))) {
      keys_str <- ds_spec$keys[i]
      if (!is.na(keys_str) && nzchar(keys_str)) {
        key_vars_map[[ds_spec$dataset[i]]] <- trimws(
          strsplit(keys_str, "[,\\s]+")[[1L]]
        )
      }
    }
  }

  for (i in seq_len(nrow(ds_spec))) {
    ds_name  <- ds_spec$dataset[i]
    ds_label <- .safe_col(ds_spec, "label", i)
    leaf_id  <- paste0("LF.", ds_name)

    # Repeating attribute (DD0113/DD0114)
    repeating <- if ("repeating" %in% names(ds_spec)) {
      val <- ds_spec$repeating[i]
      if (identical(toupper(.safe_col(ds_spec, "repeating", i)), "YES") ||
          isTRUE(val)) "Yes" else "No"
    } else {
      "No"
    }

    # def:Structure (DD0118) -- required
    structure <- .safe_col(ds_spec, "structure", i)
    if (!nzchar(structure)) {
      structure <- "One record per subject"
    }

    # Purpose (DD0117) -- required in submission
    purpose <- .safe_col(ds_spec, "purpose", i)
    if (!nzchar(purpose)) {
      purpose <- "Tabulation"
    }

    # SASDatasetName (DD0108/DD0110) -- must match Name
    igd_attrs <- list(
      OID               = paste0("IG.", ds_name),
      Name              = ds_name,
      SASDatasetName    = ds_name,          # DD0108/DD0110
      Repeating         = repeating,
      Purpose           = purpose,          # DD0117
      "def:Structure"   = structure,        # DD0118
      "def:ArchiveLocationID" = leaf_id     # DD0119
    )

    # def:HasNoData
    has_no_data <- .safe_col(ds_spec, "has_no_data", i)
    if (identical(toupper(has_no_data), "YES")) {
      igd_attrs[["def:HasNoData"]] <- "Yes"
    }

    # def:StandardOID -- link to the def:Standard element (DD0124)
    if ("standard" %in% names(ds_spec)) {
      std_raw <- ds_spec$standard[i]
      if (!is.na(std_raw) && nzchar(std_raw)) {
        igd_attrs[["def:StandardOID"]] <- "STD.1"
      }
    }

    igd <- do.call(xml2::xml_add_child, c(list(mdv, "ItemGroupDef"), igd_attrs))

    # Description/TranslatedText (DD0128/DD0060)
    if (nzchar(ds_label)) {
      desc <- xml2::xml_add_child(igd, "Description")
      xml2::xml_add_child(desc, "TranslatedText", ds_label, "xml:lang" = "en")
    } else {
      # DD0128: Description is required in submission context
      desc <- xml2::xml_add_child(igd, "Description")
      xml2::xml_add_child(desc, "TranslatedText", ds_name, "xml:lang" = "en")
    }

    # def:Class element (DD0131)
    ds_class <- .safe_col(ds_spec, "class", i)
    if (nzchar(ds_class)) {
      class_node <- xml2::xml_add_child(igd, "def:Class", Name = ds_class)
      ds_subclass <- .safe_col(ds_spec, "subclass", i)
      if (nzchar(ds_subclass)) {
        xml2::xml_add_child(class_node, "def:SubClass", Name = ds_subclass)
      }
    }

    # ItemRef children for variables in this dataset (DD0241)
    if (!is.null(var_spec) && nrow(var_spec) > 0L) {
      ds_vars <- var_spec[var_spec$dataset == ds_name, , drop = FALSE]
      ds_keys <- key_vars_map[[ds_name]] %||% character()

      for (j in seq_len(nrow(ds_vars))) {
        var_name <- ds_vars$variable[j]

        mandatory <- if ("mandatory" %in% names(ds_vars)) {
          val <- .safe_col(ds_vars, "mandatory", j)
          if (identical(toupper(val), "YES") || isTRUE(val)) "Yes" else "No"
        } else {
          "No"
        }

        ref_attrs <- list(
          ItemOID     = paste0("IT.", ds_name, ".", var_name),
          OrderNumber = as.character(j),
          Mandatory   = mandatory           # DD0068/DD0069
        )

        # KeySequence (DD0070/DD0071/DD0072)
        key_pos <- match(var_name, ds_keys)
        if (!is.na(key_pos)) {
          ref_attrs$KeySequence <- as.character(key_pos)
        }

        # MethodOID -- normalise to MT. prefix (DD0074)
        method_id <- .safe_col(ds_vars, "method_id", j)
        if (nzchar(method_id)) {
          ref_attrs$MethodOID <- .norm_oid(method_id, "MT.")
        }

        do.call(xml2::xml_add_child, c(list(igd, "ItemRef"), ref_attrs))
      }
    }

    # def:leaf for this dataset (inside ItemGroupDef for archive reference)
    leaf <- xml2::xml_add_child(
      igd,
      "def:leaf",
      ID              = leaf_id,
      "xlink:href"    = paste0(tolower(ds_name), ".xpt")   # DD0248
    )
    xml2::xml_add_child(leaf, "def:title", paste0(tolower(ds_name), ".xpt")) # DD0218
  }
  invisible(NULL)
}

#' Build ItemDef elements from var_spec (DD0137-DD0148/DD0168).
#' @noRd
.build_item_defs <- function(mdv, var_spec) {
  if (is.null(var_spec) || nrow(var_spec) == 0L) {
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(var_spec))) {
    ds       <- var_spec$dataset[i]
    var_name <- var_spec$variable[i]
    oid      <- paste0("IT.", ds, ".", var_name)

    attrs <- list(
      OID  = oid,       # DD0137
      Name = var_name   # DD0138
    )

    # SASFieldName (DD0147) -- set equal to variable name
    attrs$SASFieldName <- var_name

    # DataType (DD0139/DD0140)
    data_type <- .safe_col(var_spec, "data_type", i)
    if (nzchar(data_type)) {
      attrs$DataType <- data_type
    }

    # Length (DD0141/DD0144)
    len <- .safe_col(var_spec, "length", i)
    if (nzchar(len)) {
      attrs$Length <- as.character(len)
    }

    # SignificantDigits (DD0145/DD0146)
    sig_digits <- .safe_col(var_spec, "sig_digits", i)
    if (nzchar(sig_digits)) {
      attrs$SignificantDigits <- as.character(sig_digits)
    }

    # def:DisplayFormat
    display_fmt <- .safe_col(var_spec, "format", i)
    if (nzchar(display_fmt)) {
      attrs[["def:DisplayFormat"]] <- display_fmt
    }

    # def:CommentOID (DD0148) -- normalise to COM. prefix
    comment_id <- .safe_col(var_spec, "comment_id", i)
    if (nzchar(comment_id)) {
      attrs[["def:CommentOID"]] <- .norm_oid(comment_id, "COM.")
    }

    item <- do.call(xml2::xml_add_child, c(list(mdv, "ItemDef"), attrs))

    # Description/TranslatedText (DD0168/DD0060)
    lbl <- .safe_col(var_spec, "label", i)
    if (nzchar(lbl)) {
      desc <- xml2::xml_add_child(item, "Description")
      xml2::xml_add_child(desc, "TranslatedText", lbl, "xml:lang" = "en")
    }

    # CodeListRef (DD0135/DD0151) -- normalise to CL. prefix
    codelist_id <- .safe_col(var_spec, "codelist_id", i)
    if (nzchar(codelist_id)) {
      xml2::xml_add_child(
        item,
        "CodeListRef",
        CodeListOID = .norm_oid(codelist_id, "CL.")
      )
    }

    # def:Origin (DD0154/DD0155/DD0158)
    origin_type <- .safe_col(var_spec, "origin", i)
    if (nzchar(origin_type)) {
      origin_attrs <- list(Type = origin_type)          # DD0158
      origin_source <- .safe_col(var_spec, "source", i)
      if (nzchar(origin_source)) {
        origin_attrs$Source <- origin_source
      }
      origin_node <- do.call(
        xml2::xml_add_child,
        c(list(item, "def:Origin"), origin_attrs)
      )

      # Pages for CRF origin (DD0044/DD0159)
      pages <- .safe_col(var_spec, "pages", i)
      if (nzchar(pages) && tolower(origin_type) %in% c("collected", "crf")) {
        xml2::xml_add_child(
          origin_node,
          "def:DocumentRef",
          leafID = "LF.ACRF"
        )
      }
    }
  }
  invisible(NULL)
}

#' Build CodeList elements from codelist data.frame (DD0165-DD0177).
#' @noRd
.build_codelists <- function(mdv, codelist) {
  if (is.null(codelist) || nrow(codelist) == 0L) {
    return(invisible(NULL))
  }

  cl_ids <- unique(codelist$codelist_id)
  for (cl_id in cl_ids) {
    cl_rows  <- codelist[codelist$codelist_id == cl_id, , drop = FALSE]
    cl_name  <- .safe_col(cl_rows, "name",      1L)
    cl_dtype <- .safe_col(cl_rows, "data_type", 1L)

    cl_attrs <- list(
      OID      = .norm_oid(cl_id, "CL."),   # DD0166
      Name     = cl_name,                    # DD0171
      DataType = cl_dtype                    # DD0173
    )

    # NCI codelist code -- link to CT standard
    nci_code <- .safe_col(cl_rows, "nci_code", 1L)
    if (nzchar(nci_code)) {
      cl_attrs[["def:StandardOID"]] <- "STD.CT"
    }

    cl_node <- do.call(xml2::xml_add_child, c(list(mdv, "CodeList"), cl_attrs))

    for (j in seq_len(nrow(cl_rows))) {
      term <- .safe_col(cl_rows, "term", j)
      if (!nzchar(term)) {
        next
      }

      decoded  <- .safe_col(cl_rows, "decoded_value",  j)
      nci_term <- .safe_col(cl_rows, "nci_term_code",  j)

      if (nzchar(decoded)) {
        # CodeListItem with Decode (DD0191/DD0199)
        cli_attrs <- list(CodedValue = term)
        if (nzchar(nci_term)) {
          cli_attrs[["nci:ExtCodeID"]] <- nci_term
        }
        cli_node <- do.call(
          xml2::xml_add_child,
          c(list(cl_node, "CodeListItem"), cli_attrs)
        )
        decode_node <- xml2::xml_add_child(cli_node, "Decode")
        xml2::xml_add_child(decode_node, "TranslatedText", decoded)
      } else {
        # EnumeratedItem (DD0180)
        enum_attrs <- list(CodedValue = term)
        if (nzchar(nci_term)) {
          enum_attrs[["nci:ExtCodeID"]] <- nci_term
        }
        do.call(
          xml2::xml_add_child,
          c(list(cl_node, "EnumeratedItem"), enum_attrs)
        )
      }
    }
  }
  invisible(NULL)
}

#' Build MethodDef elements from methods data.frame (DD0205-DD0210).
#' @noRd
.build_method_defs <- function(mdv, methods) {
  if (is.null(methods) || nrow(methods) == 0L) {
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(methods))) {
    method_type <- .safe_col(methods, "type", i)
    # DD0208/DD0209: Type is required; default to "Computation" when missing
    if (!nzchar(method_type)) {
      method_type <- "Computation"
    }

    m_attrs <- list(
      OID  = .norm_oid(methods$method_id[i], "MT."),  # DD0206
      Name = methods$name[i],                          # DD0207
      Type = method_type                               # DD0208
    )

    meth <- do.call(xml2::xml_add_child, c(list(mdv, "MethodDef"), m_attrs))

    # Description/TranslatedText (DD0210/DD0056/DD0060)
    desc_text <- .safe_col(methods, "description", i)
    if (nzchar(desc_text)) {
      desc <- xml2::xml_add_child(meth, "Description")
      xml2::xml_add_child(desc, "TranslatedText", desc_text, "xml:lang" = "en")
    } else {
      # DD0210: Description is required -- use Name as fallback
      desc <- xml2::xml_add_child(meth, "Description")
      xml2::xml_add_child(desc, "TranslatedText", methods$name[i], "xml:lang" = "en")
    }

    # FormalExpression (DD0221: Context required)
    expr_context <- .safe_col(methods, "expression_context", i)
    expr_code    <- .safe_col(methods, "expression_code",    i)
    if (nzchar(expr_code)) {
      fc_attrs <- list(Context = if (nzchar(expr_context)) expr_context else "SAS")
      fc <- do.call(
        xml2::xml_add_child,
        c(list(meth, "FormalExpression"), fc_attrs)
      )
      xml2::xml_add_child(fc, "Code", expr_code)
    }

    # DocumentRef for method
    doc_id <- .safe_col(methods, "document_id", i)
    if (nzchar(doc_id)) {
      doc_ref <- xml2::xml_add_child(meth, "def:DocumentRef", leafID = doc_id)
      pages   <- .safe_col(methods, "pages", i)
      if (nzchar(pages)) {
        xml2::xml_add_child(
          doc_ref,
          "def:PDFPageRef",
          PageRefs = pages,
          Type     = "PhysicalRef"         # DD0045/DD0046
        )
      }
    }
  }
  invisible(NULL)
}

#' Build def:CommentDef elements from comments data.frame (DD0212-DD0215).
#' @noRd
.build_comment_defs <- function(mdv, comments) {
  if (is.null(comments) || nrow(comments) == 0L) {
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(comments))) {
    com <- xml2::xml_add_child(
      mdv,
      "def:CommentDef",
      OID = .norm_oid(comments$comment_id[i], "COM.")  # DD0212
    )

    desc_text <- .safe_col(comments, "description", i)
    if (nzchar(desc_text)) {
      desc <- xml2::xml_add_child(com, "Description")   # DD0214
      xml2::xml_add_child(desc, "TranslatedText", desc_text, "xml:lang" = "en")
    }

    # DocumentRef
    doc_id <- .safe_col(comments, "document_id", i)
    if (nzchar(doc_id)) {
      doc_ref <- xml2::xml_add_child(com, "def:DocumentRef", leafID = doc_id)
      pages   <- .safe_col(comments, "pages", i)
      if (nzchar(pages)) {
        xml2::xml_add_child(
          doc_ref,
          "def:PDFPageRef",
          PageRefs = pages,
          Type     = "PhysicalRef"   # DD0045/DD0046
        )
      }
    }
  }
  invisible(NULL)
}

#' Build def:ValueListDef elements from value_spec.
#' @noRd
.build_value_list_defs <- function(mdv, value_spec, var_spec) {
  if (is.null(value_spec) || nrow(value_spec) == 0L) {
    return(invisible(NULL))
  }

  vl_keys    <- paste(value_spec$dataset, value_spec$variable, sep = ".")
  unique_vl  <- unique(vl_keys)

  for (vl_key in unique_vl) {
    parts    <- strsplit(vl_key, ".", fixed = TRUE)[[1L]]
    ds_name  <- parts[1L]
    var_name <- parts[2L]
    vl_oid   <- paste0("VL.", ds_name, ".", var_name)

    vl_rows <- value_spec[vl_keys == vl_key, , drop = FALSE]

    vld <- xml2::xml_add_child(mdv, "def:ValueListDef", OID = vl_oid) # DD0236

    for (j in seq_len(nrow(vl_rows))) {
      vl_item_oid <- paste0("IT.", ds_name, ".", var_name, ".VL", j)

      ref_attrs <- list(
        ItemOID     = vl_item_oid,
        OrderNumber = as.character(j),
        Mandatory   = "No"           # DD0068/DD0069
      )

      method_id <- .safe_col(vl_rows, "method_id", j)
      if (nzchar(method_id)) {
        ref_attrs$MethodOID <- .norm_oid(method_id, "MT.")
      }

      item_ref <- do.call(
        xml2::xml_add_child,
        c(list(vld, "ItemRef"), ref_attrs)
      )

      # WhereClauseRef (DD0080/DD0081)
      where_clause <- .safe_col(vl_rows, "where_clause", j)
      if (nzchar(where_clause)) {
        wc_oid <- paste0("WC.", ds_name, ".", var_name, ".WC", j)
        xml2::xml_add_child(
          item_ref,
          "def:WhereClauseRef",
          WhereClauseOID = wc_oid
        )
      }
    }
  }

  invisible(NULL)
}

#' Build def:WhereClauseDef elements from value_spec (DD0082-DD0092).
#' @noRd
.build_where_clause_defs <- function(mdv, value_spec) {
  if (is.null(value_spec) || nrow(value_spec) == 0L) {
    return(invisible(NULL))
  }

  vl_keys   <- paste(value_spec$dataset, value_spec$variable, sep = ".")
  unique_vl <- unique(vl_keys)

  for (vl_key in unique_vl) {
    parts    <- strsplit(vl_key, ".", fixed = TRUE)[[1L]]
    ds_name  <- parts[1L]
    var_name <- parts[2L]

    vl_rows <- value_spec[vl_keys == vl_key, , drop = FALSE]

    for (j in seq_len(nrow(vl_rows))) {
      where_clause <- .safe_col(vl_rows, "where_clause", j)
      if (!nzchar(where_clause)) {
        next
      }

      wc_oid <- paste0("WC.", ds_name, ".", var_name, ".WC", j)
      wcd    <- xml2::xml_add_child(mdv, "def:WhereClauseDef", OID = wc_oid) # DD0082

      parsed <- .parse_where_clause(where_clause, ds_name)
      for (rc in parsed) {
        rc_attrs <- list(
          Comparator    = rc$comparator,   # DD0087/DD0086
          SoftHard      = "Soft",          # DD0089/DD0088
          "def:ItemOID" = rc$item_oid      # DD0090
        )
        rc_node <- do.call(
          xml2::xml_add_child,
          c(list(wcd, "RangeCheck"), rc_attrs)
        )
        for (val in rc$values) {
          xml2::xml_add_child(rc_node, "CheckValue", val)  # DD0092
        }
      }
    }
  }

  invisible(NULL)
}

#' Parse a where clause string into RangeCheck components.
#'
#' Handles formats:
#'   "PARAMCD EQ SYSBP"
#'   "PARAMCD IN (SYSBP, DIABP)"
#'   "PARAMCD EQ SYSBP AND AVISIT EQ BASELINE"
#' @noRd
.parse_where_clause <- function(clause, ds_name) {
  parts_list <- strsplit(clause, "\\s+(?i:AND)\\s+")[[1L]]
  result     <- vector("list", length(parts_list))

  for (k in seq_along(parts_list)) {
    part   <- trimws(parts_list[k])
    tokens <- strsplit(part, "\\s+")[[1L]]

    if (length(tokens) < 3L) {
      result[[k]] <- list(
        item_oid   = paste0("IT.", ds_name, ".", tokens[1L]),
        comparator = "EQ",
        values     = tokens[length(tokens)]
      )
      next
    }

    var_name   <- tokens[1L]
    comparator <- toupper(tokens[2L])
    remaining  <- paste(tokens[3L:length(tokens)], collapse = " ")

    if (comparator == "IN") {
      remaining <- gsub("[()]", "", remaining)
      vals      <- trimws(strsplit(remaining, ",")[[1L]])
    } else {
      vals <- remaining
    }

    result[[k]] <- list(
      item_oid   = paste0("IT.", ds_name, ".", var_name),
      comparator = comparator,
      values     = vals
    )
  }

  result
}

#' Build def:AnnotatedCRF from documents (DD0038/DD0039).
#' @noRd
.build_annotated_crf <- function(mdv, documents) {
  if (is.null(documents) || nrow(documents) == 0L) {
    return(invisible(NULL))
  }

  acrf_rows <- documents[
    grepl(
      "acrf|annotated.*crf|blankcrf",
      tolower(documents$title %||% ""),
      perl = TRUE
    ),
    ,
    drop = FALSE
  ]

  if (nrow(acrf_rows) == 0L) {
    return(invisible(NULL))
  }

  acrf_node <- xml2::xml_add_child(mdv, "def:AnnotatedCRF")
  for (i in seq_len(nrow(acrf_rows))) {
    xml2::xml_add_child(
      acrf_node,
      "def:DocumentRef",
      leafID = acrf_rows$document_id[i]   # DD0042
    )
  }
  invisible(acrf_node)
}

#' Build def:SupplementalDoc from documents (DD0051/DD0054).
#' @noRd
.build_supplemental_doc <- function(mdv, documents) {
  if (is.null(documents) || nrow(documents) == 0L) {
    return(invisible(NULL))
  }

  is_acrf   <- grepl(
    "acrf|annotated.*crf|blankcrf",
    tolower(documents$title %||% ""),
    perl = TRUE
  )
  supp_rows <- documents[!is_acrf, , drop = FALSE]

  if (nrow(supp_rows) == 0L) {
    return(invisible(NULL))
  }

  supp_node <- xml2::xml_add_child(mdv, "def:SupplementalDoc")
  for (i in seq_len(nrow(supp_rows))) {
    xml2::xml_add_child(
      supp_node,
      "def:DocumentRef",
      leafID = supp_rows$document_id[i]   # DD0042
    )
  }
  invisible(supp_node)
}

#' Build def:leaf elements for documents (DD0216/DD0218/DD0248/DD0259).
#' @noRd
.build_leaf_defs <- function(mdv, ds_spec, documents) {
  if (!is.null(documents) && nrow(documents) > 0L) {
    for (i in seq_len(nrow(documents))) {
      doc_id <- documents$document_id[i]
      href   <- .safe_col(documents, "href",  i)
      title  <- .safe_col(documents, "title", i)

      if (!nzchar(href))  { href  <- paste0(doc_id, ".pdf") }
      if (!nzchar(title)) { title <- doc_id }

      leaf <- xml2::xml_add_child(
        mdv,
        "def:leaf",
        ID           = doc_id,
        "xlink:href" = href         # DD0248
      )
      xml2::xml_add_child(leaf, "def:title", title)  # DD0218
    }
  }

  invisible(NULL)
}

# --------------------------------------------------------------------------
# ARM (Analysis Results Metadata) builder
# --------------------------------------------------------------------------

#' Build ARM elements from arm_displays and arm_results data.frames.
#' @noRd
.build_arm <- function(mdv, arm_displays, arm_results) {
  if (is.null(arm_displays) || nrow(arm_displays) == 0L) {
    return(invisible(NULL))
  }

  ard_container <- xml2::xml_add_child(mdv, "arm:AnalysisResultDisplays")

  for (i in seq_len(nrow(arm_displays))) {
    disp_id    <- arm_displays$display_id[i]
    disp_title <- .safe_col(arm_displays, "title", i)
    if (!nzchar(disp_title)) {
      disp_title <- disp_id
    }

    rd <- xml2::xml_add_child(
      ard_container,
      "arm:ResultDisplay",
      OID  = disp_id,
      Name = disp_title
    )

    # Description
    desc_node <- xml2::xml_add_child(rd, "Description")
    xml2::xml_add_child(desc_node, "TranslatedText", disp_title, "xml:lang" = "en")

    # DocumentRef for display
    doc_id <- .safe_col(arm_displays, "document_id", i)
    if (nzchar(doc_id)) {
      doc_ref <- xml2::xml_add_child(rd, "def:DocumentRef", leafID = doc_id)
      pages   <- .safe_col(arm_displays, "pages", i)
      if (nzchar(pages)) {
        xml2::xml_add_child(
          doc_ref,
          "def:PDFPageRef",
          PageRefs = pages,
          Type     = "PhysicalRef"  # DD0045/DD0046
        )
      }
    }

    # AnalysisResult children for this display
    if (!is.null(arm_results) && nrow(arm_results) > 0L) {
      display_results <- arm_results[
        arm_results$display_id == disp_id,
        ,
        drop = FALSE
      ]
      for (j in seq_len(nrow(display_results))) {
        ar_attrs <- list(
          OID  = display_results$result_id[j],
          Name = .safe_col(display_results, "description", j)
        )

        reason <- .safe_col(display_results, "reason", j)
        if (nzchar(reason)) {
          ar_attrs$AnalysisReason <- reason
        }

        purpose <- .safe_col(display_results, "purpose", j)
        if (nzchar(purpose)) {
          ar_attrs$AnalysisPurpose <- purpose
        }

        ar_node <- do.call(
          xml2::xml_add_child,
          c(list(rd, "arm:AnalysisResult"), ar_attrs)
        )

        # Description for result
        result_desc <- .safe_col(display_results, "description", j)
        if (nzchar(result_desc)) {
          desc_n <- xml2::xml_add_child(ar_node, "Description")
          xml2::xml_add_child(desc_n, "TranslatedText", result_desc, "xml:lang" = "en")
        }

        # AnalysisDatasets with variables
        vars_str <- .safe_col(display_results, "variables", j)
        if (nzchar(vars_str)) {
          ads      <- xml2::xml_add_child(ar_node, "arm:AnalysisDatasets")
          var_refs <- trimws(strsplit(vars_str, ",")[[1L]])
          ds_groups <- list()
          for (vr in var_refs) {
            dot_parts <- strsplit(vr, ".", fixed = TRUE)[[1L]]
            if (length(dot_parts) == 2L) {
              ds_nm <- dot_parts[1L]
              v_nm  <- dot_parts[2L]
              ds_groups[[ds_nm]] <- c(ds_groups[[ds_nm]], v_nm)
            }
          }
          for (ds_nm in names(ds_groups)) {
            ad <- xml2::xml_add_child(
              ads,
              "arm:AnalysisDataset",
              ItemGroupOID = paste0("IG.", ds_nm)
            )
            for (v_nm in ds_groups[[ds_nm]]) {
              xml2::xml_add_child(
                ad,
                "arm:AnalysisVariable",
                ItemOID = paste0("IT.", ds_nm, ".", v_nm)
              )
            }
          }
        }

        # Documentation
        doc_text <- .safe_col(display_results, "documentation", j)
        if (nzchar(doc_text)) {
          doc_n    <- xml2::xml_add_child(ar_node, "arm:Documentation")
          doc_desc <- xml2::xml_add_child(doc_n, "Description")
          xml2::xml_add_child(doc_desc, "TranslatedText", doc_text, "xml:lang" = "en")
        }

        # Programming code (Context is required -- DD0221 analog in ARM)
        prog_code <- .safe_col(display_results, "programming_code", j)
        if (nzchar(prog_code)) {
          prog_ctx <- .safe_col(display_results, "programming_context", j)
          if (!nzchar(prog_ctx)) {
            prog_ctx <- "SAS Version 9.4"
          }
          pc <- xml2::xml_add_child(ar_node, "arm:ProgrammingCode", Context = prog_ctx)
          xml2::xml_add_child(pc, "arm:Code", prog_code)
        }
      }
    }
  }
  invisible(NULL)
}

# --------------------------------------------------------------------------
# Shared lower-level helpers
# --------------------------------------------------------------------------

#' Safely extract a column value, returning "" for missing/NA.
#' @noRd
.safe_col <- function(df, col, i) {
  if (!col %in% names(df)) {
    return("")
  }
  val <- df[[col]][i]
  if (is.na(val) || !nzchar(val)) {
    return("")
  }
  as.character(val)
}
