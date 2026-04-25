# dataset-builders.R -- Define-XML tabularization layer
#
# Mirrors the CDISC rules-engine DatasetBuilderFactory pattern.
# Five builders produce flat data.frames from a `herald_define` object.
# Each builder is keyed by the virtual dataset name that DEFINE rules
# reference in their scope.
#
# Builder naming convention: the virtual dataset name (e.g.
# "Define_Dataset_Metadata") used by rules is the key in the builder
# registry. validate() injects the frame into datasets when ctx$define
# is available.

.BUILDER_REGISTRY <- new.env(parent = emptyenv())

.register_builder <- function(name, fn) {
  assign(name, fn, envir = .BUILDER_REGISTRY)
}

.get_builder <- function(name) {
  if (!exists(name, envir = .BUILDER_REGISTRY, inherits = FALSE)) {
    return(NULL)
  }
  get(name, envir = .BUILDER_REGISTRY)
}

.list_builders <- function() sort(ls(.BUILDER_REGISTRY))

# Build all available virtual datasets from a herald_define object.
# Returns a named list of data.frames.
.build_define_datasets <- function(def) {
  if (!inherits(def, "herald_define")) {
    return(list())
  }
  result <- list()
  for (nm in .list_builders()) {
    fn <- .get_builder(nm)
    df <- tryCatch(fn(def), error = function(e) NULL)
    if (!is.null(df) && is.data.frame(df) && nrow(df) > 0L) {
      result[[nm]] <- df
    }
  }
  result
}

# ---------- helpers ----------------------------------------------------------

.attr_val <- function(node, attr) {
  v <- xml2::xml_attr(node, attr)
  if (is.na(v)) "" else v
}

.ns_attr <- function(node, attr, ns_prefix = "def") {
  # Try namespace-prefixed then unprefixed
  v <- xml2::xml_attr(node, paste0(ns_prefix, ":", attr))
  if (!is.na(v)) {
    return(v)
  }
  v <- xml2::xml_attr(node, attr)
  if (!is.na(v)) {
    return(v)
  }
  ""
}

.child_text <- function(node, xpath) {
  ch <- xml2::xml_find_first(node, xpath)
  if (is.na(ch)) {
    return("")
  }
  xml2::xml_text(ch)
}

# ---------- builder: Define_Study_Metadata -----------------------------------
# One row covering ODM + Study + MetaDataVersion + GlobalVariables attributes.

.builder_study_metadata <- function(def) {
  doc <- def$xml_doc
  ns <- def$xml_ns
  if (is.null(doc)) {
    return(NULL)
  }

  odm_node <- xml2::xml_find_first(doc, "/d1:ODM", ns)
  if (is.na(odm_node)) {
    odm_node <- xml2::xml_find_first(doc, "/ODM")
  }

  .a <- function(node, a) if (is.na(node)) "" else .attr_val(node, a)
  .na <- function(node, a) if (is.na(node)) "" else .ns_attr(node, a)

  odm_oid <- .a(odm_node, "OID")
  odm_creation_datetime <- .a(odm_node, "CreationDateTime")
  odm_as_study_oid <- .a(odm_node, "AsStudyOID")
  odm_orig_desc <- .na(odm_node, "OriginalCodingDictionary")
  odm_context <- .na(odm_node, "Context")
  odm_file_type <- .a(odm_node, "FileType")

  study_node <- xml2::xml_find_first(doc, ".//d1:Study", ns)
  if (is.na(study_node)) {
    study_node <- xml2::xml_find_first(doc, ".//Study")
  }
  study_oid <- .a(study_node, "OID")

  mdv <- def$xml_mdv
  mdv_oid <- .a(mdv, "OID")
  mdv_name <- .a(mdv, "Name")
  mdv_desc <- .a(mdv, "Description")
  mdv_def_version <- .ns_attr(mdv, "DefineVersion")

  gv_node <- xml2::xml_find_first(doc, ".//d1:GlobalVariables", ns)
  if (is.na(gv_node)) {
    gv_node <- xml2::xml_find_first(doc, ".//GlobalVariables")
  }
  study_name <- .child_text(gv_node, "*[local-name()='StudyName']")
  study_desc <- .child_text(gv_node, "*[local-name()='StudyDescription']")
  protocol_name <- .child_text(gv_node, "*[local-name()='ProtocolName']")

  # def:Standards block presence
  std_nodes <- xml2::xml_find_all(mdv, ".//*[local-name()='Standards']")
  has_standards <- length(std_nodes) > 0L

  mdv_comment_oid <- .ns_attr(mdv, "CommentOID")

  # Detect ADaM-based define (any referenced standard with Name containing "adam")
  std_nodes2 <- xml2::xml_find_all(mdv, ".//*[local-name()='Standard']")
  is_adam <- any(vapply(
    std_nodes2,
    function(n) {
      nm <- xml2::xml_attr(n, "Name")
      !is.na(nm) && grepl("adam", nm, ignore.case = TRUE)
    },
    logical(1L)
  ))

  data.frame(
    odm_oid = odm_oid,
    creation_datetime = odm_creation_datetime,
    as_study_oid = odm_as_study_oid,
    original_coding = odm_orig_desc,
    context = odm_context,
    file_type = odm_file_type,
    study_oid = study_oid,
    mdv_oid = mdv_oid,
    mdv_name = mdv_name,
    mdv_description = mdv_desc,
    mdv_comment_oid = mdv_comment_oid,
    def_version = mdv_def_version,
    study_name = study_name,
    study_description = study_desc,
    protocol_name = protocol_name,
    has_standards = has_standards,
    is_adam = is_adam,
    stringsAsFactors = FALSE
  )
}
.register_builder("Define_Study_Metadata", .builder_study_metadata)

# ---------- builder: Define_Dataset_Metadata ---------------------------------
# One row per ItemGroupDef.

.builder_dataset_metadata <- function(def) {
  mdv <- def$xml_mdv
  ns <- def$xml_ns
  if (is.null(mdv)) {
    return(NULL)
  }

  igd_nodes <- xml2::xml_find_all(mdv, "d1:ItemGroupDef", ns)
  if (length(igd_nodes) == 0L) {
    igd_nodes <- xml2::xml_find_all(mdv, "ItemGroupDef")
  }
  if (length(igd_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(igd_nodes, function(n) {
    oid <- .attr_val(n, "OID")
    name <- .attr_val(n, "Name")
    repeating <- .attr_val(n, "Repeating")
    is_ref_data <- .attr_val(n, "IsReferenceData")
    sas_ds_name <- .attr_val(n, "SASDatasetName")
    domain <- .ns_attr(n, "Domain")
    structure <- .ns_attr(n, "Structure")
    purpose <- .ns_attr(n, "Purpose")
    comment_oid <- .ns_attr(n, "CommentOID")
    archive_loc <- .ns_attr(n, "ArchiveLocationID")

    # Description / label
    desc_node <- xml2::xml_find_first(
      n,
      "*[local-name()='Description']/*[local-name()='TranslatedText']"
    )
    label <- if (is.na(desc_node)) "" else xml2::xml_text(desc_node)
    has_description <- !is.na(desc_node) && nzchar(label)

    # def:Class
    class_node <- xml2::xml_find_first(n, "*[local-name()='Class']")
    class_name <- if (is.na(class_node)) "" else .attr_val(class_node, "Name")

    # def:IsNonStandard
    is_non_standard <- .ns_attr(n, "IsNonStandard")

    # Alias child (Context + Name)
    alias_node <- xml2::xml_find_first(n, "*[local-name()='Alias']")
    alias_context <- if (is.na(alias_node)) {
      ""
    } else {
      .attr_val(alias_node, "Context")
    }
    alias_name <- if (is.na(alias_node)) "" else .attr_val(alias_node, "Name")

    # def:HasNoData, def:StandardOID
    has_no_data <- .ns_attr(n, "HasNoData")
    standard_oid <- .ns_attr(n, "StandardOID")

    # WhereClauseRef children (for value-level metadata presence)
    wc_refs <- xml2::xml_find_all(n, ".//*[local-name()='WhereClauseRef']")
    has_where_clause_ref <- length(wc_refs) > 0L
    where_clause_oid <- if (length(wc_refs) > 0L) {
      .ns_attr(wc_refs[[1L]], "WhereClauseOID")
    } else {
      ""
    }

    data.frame(
      oid = oid,
      dataset = name,
      label = label,
      has_description = has_description,
      repeating = repeating,
      is_referencedata = is_ref_data,
      sas_dataset_name = sas_ds_name,
      domain = domain,
      structure = structure,
      purpose = purpose,
      comment_oid = comment_oid,
      archive_location = archive_loc,
      class = class_name,
      has_no_data = has_no_data,
      standard_oid = standard_oid,
      where_clause_oid = where_clause_oid,
      is_non_standard = is_non_standard,
      alias_context = alias_context,
      alias_name = alias_name,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
.register_builder("Define_Dataset_Metadata", .builder_dataset_metadata)

# ---------- builder: Define_Variable_Metadata --------------------------------
# One row per ItemDef (joined with ItemRef for order/mandatory/dataset).

.builder_variable_metadata <- function(def) {
  mdv <- def$xml_mdv
  ns <- def$xml_ns
  if (is.null(mdv)) {
    return(NULL)
  }

  # Build OID-keyed maps from ItemGroupDef/ItemRef
  igd_nodes <- xml2::xml_find_all(mdv, "d1:ItemGroupDef", ns)
  if (length(igd_nodes) == 0L) {
    igd_nodes <- xml2::xml_find_all(mdv, "ItemGroupDef")
  }

  oid_ds <- list()
  oid_order <- list()
  oid_mand <- list()
  oid_methodoid <- list()
  oid_vl_oid <- list()
  oid_key_seq <- list()
  oid_ns_itemref <- list()

  for (ign in igd_nodes) {
    ds_nm <- .attr_val(ign, "Name")
    refs <- xml2::xml_find_all(ign, "d1:ItemRef", ns)
    if (length(refs) == 0L) {
      refs <- xml2::xml_find_all(ign, "ItemRef")
    }
    for (ref in refs) {
      ioid <- .attr_val(ref, "ItemOID")
      if (!nzchar(ioid)) {
        next
      }
      oid_ds[[ioid]] <- ds_nm
      oid_order[[ioid]] <- .attr_val(ref, "OrderNumber")
      oid_mand[[ioid]] <- .attr_val(ref, "Mandatory")
      oid_methodoid[[ioid]] <- .ns_attr(ref, "MethodOID")
      oid_key_seq[[ioid]] <- .attr_val(ref, "KeySequence")
      oid_ns_itemref[[ioid]] <- .ns_attr(ref, "IsNonStandard")
    }
  }

  item_nodes <- xml2::xml_find_all(mdv, "d1:ItemDef", ns)
  if (length(item_nodes) == 0L) {
    item_nodes <- xml2::xml_find_all(mdv, "ItemDef")
  }
  if (length(item_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(item_nodes, function(n) {
    oid <- .attr_val(n, "OID")
    name <- .attr_val(n, "Name")
    data_type <- .attr_val(n, "DataType")
    length <- .attr_val(n, "Length")
    sig_digits <- .attr_val(n, "SignificantDigits")
    sas_field_name <- .attr_val(n, "SASFieldName")
    display_format <- .ns_attr(n, "DisplayFormat")
    comment_oid <- .ns_attr(n, "CommentOID")

    # Description
    desc_node <- xml2::xml_find_first(
      n,
      "*[local-name()='Description']/*[local-name()='TranslatedText']"
    )
    label <- if (is.na(desc_node)) "" else xml2::xml_text(desc_node)
    has_description <- !is.na(desc_node) && nzchar(label)

    # def:Origin (including AssignedValue)
    orig_node <- xml2::xml_find_first(n, "*[local-name()='Origin']")
    origin_type <- if (is.na(orig_node)) "" else .attr_val(orig_node, "Type")
    origin_source <- if (is.na(orig_node)) {
      ""
    } else {
      .attr_val(orig_node, "Source")
    }
    assigned_value <- if (is.na(orig_node)) {
      ""
    } else {
      .ns_attr(orig_node, "AssignedValue")
    }

    # Alias child (Context + Name)
    alias_node_v <- xml2::xml_find_first(n, "*[local-name()='Alias']")
    alias_context_v <- if (is.na(alias_node_v)) {
      ""
    } else {
      .attr_val(alias_node_v, "Context")
    }
    alias_name_v <- if (is.na(alias_node_v)) {
      ""
    } else {
      .attr_val(alias_node_v, "Name")
    }

    # CodeListRef
    clr_node <- xml2::xml_find_first(n, "*[local-name()='CodeListRef']")
    codelist_oid <- if (is.na(clr_node)) {
      ""
    } else {
      .attr_val(clr_node, "CodeListOID")
    }

    # def:ValueListRef
    vlr_node <- xml2::xml_find_first(n, "*[local-name()='ValueListRef']")
    valuelist_oid <- if (is.na(vlr_node)) {
      ""
    } else {
      .ns_attr(vlr_node, "ValueListOID")
    }

    ds <- oid_ds[[oid]] %||% ""
    order <- oid_order[[oid]] %||% ""
    mand <- oid_mand[[oid]] %||% ""
    method <- oid_methodoid[[oid]] %||% ""
    key_sequence <- oid_key_seq[[oid]] %||% ""
    is_ns_itemref <- oid_ns_itemref[[oid]] %||% ""

    # def:StandardOID (standards compliance reference)
    standard_oid <- .ns_attr(n, "StandardOID")

    data.frame(
      oid = oid,
      dataset = ds,
      variable = name,
      label = label,
      has_description = has_description,
      data_type = data_type,
      length = length,
      sig_digits = sig_digits,
      sas_field_name = sas_field_name,
      display_format = display_format,
      comment_oid = comment_oid,
      origin_type = origin_type,
      origin_source = origin_source,
      assigned_value = assigned_value,
      codelist_oid = codelist_oid,
      valuelist_oid = valuelist_oid,
      mandatory = mand,
      order = order,
      key_sequence = key_sequence,
      is_non_standard_itemref = is_ns_itemref,
      alias_context = alias_context_v,
      alias_name = alias_name_v,
      method_oid = method,
      standard_oid = standard_oid,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
.register_builder("Define_Variable_Metadata", .builder_variable_metadata)

# ---------- builder: Define_Codelist_Metadata --------------------------------
# One row per CodeList + CodeListItem/EnumeratedItem.

.builder_codelist_metadata <- function(def) {
  mdv <- def$xml_mdv
  ns <- def$xml_ns
  if (is.null(mdv)) {
    return(NULL)
  }

  cl_nodes <- xml2::xml_find_all(mdv, "d1:CodeList", ns)
  if (length(cl_nodes) == 0L) {
    cl_nodes <- xml2::xml_find_all(mdv, "CodeList")
  }
  if (length(cl_nodes) == 0L) {
    return(NULL)
  }

  rows <- list()
  for (cl in cl_nodes) {
    cl_oid <- .attr_val(cl, "OID")
    cl_name <- .attr_val(cl, "Name")
    cl_dtype <- .attr_val(cl, "DataType")
    cl_fmt <- .attr_val(cl, "SASFormatName")
    cl_comment <- .ns_attr(cl, "CommentOID")
    cl_std_oid <- .ns_attr(cl, "StandardOID")

    # External codelist vs enumerated
    ext_node <- xml2::xml_find_first(cl, "*[local-name()='ExternalCodeList']")
    is_external <- !is.na(ext_node)

    # Alias/Context
    alias_node <- xml2::xml_find_first(cl, "*[local-name()='Alias']")
    alias_context <- if (is.na(alias_node)) {
      ""
    } else {
      .attr_val(alias_node, "Context")
    }
    alias_name <- if (is.na(alias_node)) "" else .attr_val(alias_node, "Name")

    # Items (CodeListItem + EnumeratedItem)
    items <- c(
      xml2::xml_find_all(cl, "d1:CodeListItem", ns),
      xml2::xml_find_all(cl, "CodeListItem"),
      xml2::xml_find_all(cl, "d1:EnumeratedItem", ns),
      xml2::xml_find_all(cl, "EnumeratedItem")
    )

    if (length(items) == 0L) {
      rows <- c(
        rows,
        list(data.frame(
          codelist_oid = cl_oid,
          codelist_name = cl_name,
          data_type = cl_dtype,
          sas_format = cl_fmt,
          comment_oid = cl_comment,
          standard_oid = cl_std_oid,
          alias_context = alias_context,
          alias_name = alias_name,
          is_external = is_external,
          coded_value = "",
          decoded_value = "",
          extended_value = "",
          rank = "",
          is_non_standard = "",
          stringsAsFactors = FALSE
        ))
      )
      next
    }

    for (item in items) {
      coded <- .attr_val(item, "CodedValue")
      ext_v <- .attr_val(item, "ExtendedValue")
      rank <- .attr_val(item, "Rank")
      dec_node <- xml2::xml_find_first(
        item,
        "*[local-name()='Decode']/*[local-name()='TranslatedText']"
      )
      decoded <- if (is.na(dec_node)) "" else xml2::xml_text(dec_node)

      is_non_standard <- .ns_attr(item, "IsNonStandard")

      rows <- c(
        rows,
        list(data.frame(
          codelist_oid = cl_oid,
          codelist_name = cl_name,
          data_type = cl_dtype,
          sas_format = cl_fmt,
          comment_oid = cl_comment,
          standard_oid = cl_std_oid,
          alias_context = alias_context,
          alias_name = alias_name,
          is_external = is_external,
          coded_value = coded,
          decoded_value = decoded,
          extended_value = ext_v,
          rank = rank,
          is_non_standard = is_non_standard,
          stringsAsFactors = FALSE
        ))
      )
    }
  }

  if (length(rows) == 0L) {
    return(NULL)
  }
  do.call(rbind, rows)
}
.register_builder("Define_Codelist_Metadata", .builder_codelist_metadata)

# ---------- builder: Define_Standards_Metadata --------------------------------
# One row per def:Standard element (CDISC + user-defined standards declared).

.builder_standards_metadata <- function(def) {
  mdv <- def$xml_mdv
  if (is.null(mdv)) {
    return(NULL)
  }

  std_nodes <- xml2::xml_find_all(mdv, ".//*[local-name()='Standard']")
  if (length(std_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(std_nodes, function(n) {
    data.frame(
      oid = .attr_val(n, "OID"),
      name = .attr_val(n, "Name"),
      type = .attr_val(n, "Type"),
      version = .attr_val(n, "Version"),
      status = .attr_val(n, "Status"),
      comment_oid = .ns_attr(n, "CommentOID"),
      publishing_set = .attr_val(n, "PublishingSet"),
      parent_class = .attr_val(n, "ParentClass"),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
.register_builder("Define_Standards_Metadata", .builder_standards_metadata)

# ---------- builder: Define_ValueLevel_Metadata --------------------------------
# One row per def:WhereClauseDef (value-level metadata entries).

.builder_valuelevel_metadata <- function(def) {
  mdv <- def$xml_mdv
  ns <- def$xml_ns
  if (is.null(mdv)) {
    return(NULL)
  }

  wc_nodes <- xml2::xml_find_all(mdv, ".//*[local-name()='WhereClauseDef']")
  if (length(wc_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(wc_nodes, function(n) {
    oid <- .attr_val(n, "OID")
    comment <- .ns_attr(n, "CommentOID")

    # RangeCheck children
    rc_nodes <- xml2::xml_find_all(n, "*[local-name()='RangeCheck']")
    comparator <- if (length(rc_nodes) > 0L) {
      .attr_val(rc_nodes[[1L]], "Comparator")
    } else {
      ""
    }
    soft_hard <- if (length(rc_nodes) > 0L) {
      .attr_val(rc_nodes[[1L]], "SoftHard")
    } else {
      ""
    }
    check_var <- if (length(rc_nodes) > 0L) {
      .ns_attr(rc_nodes[[1L]], "ItemOID")
    } else {
      ""
    }
    check_value <- if (length(rc_nodes) > 0L) {
      cv_node <- xml2::xml_find_first(
        rc_nodes[[1L]],
        "*[local-name()='CheckValue']"
      )
      if (is.na(cv_node)) "" else xml2::xml_text(cv_node)
    } else {
      ""
    }

    data.frame(
      oid = oid,
      comment_oid = comment,
      comparator = comparator,
      soft_hard = soft_hard,
      check_var = check_var,
      check_value = check_value,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
.register_builder("Define_ValueLevel_Metadata", .builder_valuelevel_metadata)

# ---------- builder: Define_MethodDef_Metadata --------------------------------
# One row per MethodDef element.

.builder_methoddef_metadata <- function(def) {
  mdv <- def$xml_mdv
  ns <- def$xml_ns
  if (is.null(mdv)) {
    return(NULL)
  }

  md_nodes <- xml2::xml_find_all(mdv, "d1:MethodDef", ns)
  if (length(md_nodes) == 0L) {
    md_nodes <- xml2::xml_find_all(mdv, "MethodDef")
  }
  if (length(md_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(md_nodes, function(n) {
    oid <- .attr_val(n, "OID")
    method_name <- .attr_val(n, "Name")
    method_type <- .attr_val(n, "Type")
    comment_oid <- .ns_attr(n, "CommentOID")

    desc_node <- xml2::xml_find_first(
      n,
      "*[local-name()='Description']/*[local-name()='TranslatedText']"
    )
    has_description <- !is.na(desc_node) && nzchar(xml2::xml_text(desc_node))

    data.frame(
      oid = oid,
      method_name = method_name,
      method_type = method_type,
      has_description = has_description,
      comment_oid = comment_oid,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
.register_builder("Define_MethodDef_Metadata", .builder_methoddef_metadata)

# ---------- builder: Define_ARM_Metadata --------------------------------------
# One row per arm:ResultDisplay (Analysis Results Metadata).

.builder_arm_metadata <- function(def) {
  doc <- def$xml_doc
  if (is.null(doc)) {
    return(NULL)
  }

  arm_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='ResultDisplay']")
  if (length(arm_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(arm_nodes, function(n) {
    display_oid <- .attr_val(n, "OID")
    display_name <- .attr_val(n, "Name")
    desc_node <- xml2::xml_find_first(
      n,
      "*[local-name()='Description']/*[local-name()='TranslatedText']"
    )
    has_description <- !is.na(desc_node) && nzchar(xml2::xml_text(desc_node))
    data.frame(
      display_oid = display_oid,
      display_name = display_name,
      has_description = has_description,
      stringsAsFactors = FALSE
    )
  })

  if (length(rows) == 0L) {
    return(NULL)
  }
  df <- do.call(rbind, rows)
  df$is_duplicate_oid <- duplicated(df$display_oid) |
    duplicated(df$display_oid, fromLast = TRUE)
  df$is_duplicate_name <- duplicated(df$display_name) |
    duplicated(df$display_name, fromLast = TRUE)
  df
}
.register_builder("Define_ARM_Metadata", .builder_arm_metadata)

# ---------- builder: Define_ARM_Result_Metadata --------------------------------
# One row per arm:AnalysisResult (within its ResultDisplay).

.builder_arm_result_metadata <- function(def) {
  doc <- def$xml_doc
  if (is.null(doc)) {
    return(NULL)
  }

  result_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='AnalysisResult']")
  if (length(result_nodes) == 0L) {
    return(NULL)
  }

  rows <- lapply(result_nodes, function(n) {
    result_oid <- .attr_val(n, "OID")
    parameter_oid <- .attr_val(n, "ParameterOID")
    parent <- xml2::xml_parent(n)
    display_oid <- if (is.na(parent)) "" else .attr_val(parent, "OID")
    data.frame(
      result_oid = result_oid,
      display_oid = display_oid,
      parameter_oid = parameter_oid,
      stringsAsFactors = FALSE
    )
  })

  if (length(rows) == 0L) {
    return(NULL)
  }
  df <- do.call(rbind, rows)
  df$is_duplicate_oid <- duplicated(paste(df$display_oid, df$result_oid)) |
    duplicated(paste(df$display_oid, df$result_oid), fromLast = TRUE)
  df
}
.register_builder("Define_ARM_Result_Metadata", .builder_arm_result_metadata)
