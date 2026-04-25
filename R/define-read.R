# --------------------------------------------------------------------------
# define-read.R -- read_define_xml(): Define-XML 2.1 -> herald_define
# --------------------------------------------------------------------------
# Returns a `herald_define` object -- a named list carrying:
#   $ds_spec       data.frame(dataset, label)
#   $var_spec      data.frame(dataset, variable, label, data_type, ...)
#   $study         data.frame(attribute, value)
#   $codelist      data.frame or NULL
#   $methods       data.frame or NULL
#   $comments      data.frame or NULL
#   $arm_displays  data.frame or NULL
#   $arm_results   data.frame or NULL
#   $key_vars      named list: dataset -> character vector of key var names
#   $loinc_version character scalar or NA_character_
#
# The object is S3 class c("herald_define", "list").
#
# Downstream:
#   as_herald_spec(d$ds_spec, d$var_spec)  -- convert to herald_spec
#   validate(..., define = d)              -- wire ctx$define for rule ops

#' Read a Define-XML 2.1 file
#'
#' @description
#' Parses a Define-XML 2.1 file and returns a \code{herald_define} object
#' carrying datasets, variables, codelists, methods, comments, ARM metadata,
#' sponsor-defined key variables, and the LOINC dictionary version declared
#' in `MetaDataVersion`. Requires the \code{xml2} package.
#'
#' @param path Path to the Define-XML file.
#' @param call Caller environment for error reporting.
#'
#' @return A `herald_define` S3 object (inherits from `list`).
#'
#' @examples
#' tmp <- tempfile(fileext = ".xml")
#' on.exit(unlink(tmp))
#' writeLines(c(
#'   '<?xml version="1.0" encoding="UTF-8"?>',
#'   '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
#'   '     xmlns:def="http://www.cdisc.org/ns/def/v2.1">',
#'   '  <Study OID="S.TEST">',
#'   '    <GlobalVariables>',
#'   '      <StudyName>PILOT01</StudyName>',
#'   '    </GlobalVariables>',
#'   '    <MetaDataVersion OID="MDV.1" Name="MDV1">',
#'   '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
#'   '        <Description>',
#'   '          <TranslatedText>Demographics</TranslatedText>',
#'   '        </Description>',
#'   '      </ItemGroupDef>',
#'   '    </MetaDataVersion>',
#'   '  </Study>',
#'   '</ODM>'
#' ), tmp)
#' d <- read_define_xml(tmp)
#' d$ds_spec
#'
#' @family spec
#' @export
read_define_xml <- function(path, call = rlang::caller_env()) {
  check_scalar_chr(path, call = call)

  if (!file.exists(path)) {
    herald_error(
      c(
        "File {.path {path}} does not exist.",
        "i" = "Supply a path to a valid Define-XML 2.1 file."
      ),
      class = "herald_error_file",
      call = call
    )
  }

  # Pre-validate: quick header check before hitting the C++ XML layer.
  first_line <- tryCatch(
    readLines(path, n = 1L, warn = FALSE),
    error = function(e) character(0L)
  )
  if (length(first_line) == 0L || !grepl("<", first_line[1L], fixed = TRUE)) {
    herald_error(
      c(
        "Failed to parse XML from {.path {path}}.",
        "x" = "File does not appear to contain XML (no '<' found on first line)."
      ),
      class = "herald_error_file",
      call = call
    )
  }

  doc <- tryCatch(
    xml2::read_xml(path),
    error = function(e) {
      herald_error(
        c(
          "Failed to parse XML from {.path {path}}.",
          "x" = conditionMessage(e)
        ),
        class = "herald_error_file",
        call = call
      )
    }
  )

  # Register namespaces
  ns <- xml2::xml_ns(doc)

  # Find MetaDataVersion -- the main container
  mdv <- xml2::xml_find_first(doc, ".//d1:MetaDataVersion", ns)
  if (is.na(mdv)) {
    mdv <- xml2::xml_find_first(doc, ".//MetaDataVersion")
  }
  if (is.na(mdv)) {
    herald_error(
      c(
        "No {.val MetaDataVersion} element found in {.path {path}}.",
        "i" = "File must be a valid Define-XML 2.1 document."
      ),
      class = "herald_error_file",
      call = call
    )
  }

  study <- .define_extract_study(doc, ns)
  ds_spec <- .define_extract_datasets(mdv, ns)
  var_spec <- .define_extract_variables(mdv, ns)
  codelist <- .define_extract_codelists(mdv, ns)
  methods <- .define_extract_methods(mdv, ns)
  comments <- .define_extract_comments(mdv, ns)
  arm <- .define_extract_arm(mdv, ns)
  key_vars <- .define_extract_key_vars(mdv, ns, ds_spec)
  loinc_ver <- .define_extract_loinc_version(mdv, ns)

  structure(
    list(
      ds_spec = ds_spec,
      var_spec = var_spec,
      study = study,
      codelist = codelist,
      methods = methods,
      comments = comments,
      arm_displays = arm$displays,
      arm_results = arm$results,
      key_vars = key_vars,
      loinc_version = loinc_ver,
      xml_doc = doc,
      xml_mdv = mdv,
      xml_ns = ns
    ),
    class = c("herald_define", "list")
  )
}

#' Print a herald_define
#' @param x A `herald_define` object.
#' @param ... Ignored.
#' @return `x` invisibly.
#' @export
print.herald_define <- function(x, ...) {
  n_ds <- if (is.data.frame(x$ds_spec)) nrow(x$ds_spec) else 0L
  n_var <- if (is.data.frame(x$var_spec)) nrow(x$var_spec) else 0L
  n_kv <- length(x$key_vars)
  cat("<herald_define>\n")
  cat(sprintf(
    "  %d dataset%s, %d variable%s, %d key-var mapping%s\n",
    n_ds,
    if (n_ds == 1L) "" else "s",
    n_var,
    if (n_var == 1L) "" else "s",
    n_kv,
    if (n_kv == 1L) "" else "s"
  ))
  if (!is.na(x$loinc_version)) {
    cat(sprintf("  LOINC version: %s\n", x$loinc_version))
  }
  invisible(x)
}

# --------------------------------------------------------------------------
# Internal XML extraction helpers
# --------------------------------------------------------------------------

#' @noRd
.define_extract_study <- function(doc, ns) {
  gv <- xml2::xml_find_first(doc, ".//d1:GlobalVariables", ns)
  if (is.na(gv)) {
    gv <- xml2::xml_find_first(doc, ".//GlobalVariables")
  }
  if (is.na(gv)) {
    return(data.frame(
      attribute = character(),
      value = character(),
      stringsAsFactors = FALSE
    ))
  }
  children <- xml2::xml_children(gv)
  if (length(children) == 0L) {
    return(data.frame(
      attribute = character(),
      value = character(),
      stringsAsFactors = FALSE
    ))
  }
  attrs <- vapply(children, function(x) xml2::xml_name(x), character(1L))
  vals <- vapply(children, function(x) xml2::xml_text(x), character(1L))
  data.frame(attribute = attrs, value = vals, stringsAsFactors = FALSE)
}

#' @noRd
.define_extract_datasets <- function(mdv, ns) {
  igd_nodes <- xml2::xml_find_all(mdv, ".//d1:ItemGroupDef", ns)
  if (length(igd_nodes) == 0L) {
    igd_nodes <- xml2::xml_find_all(mdv, ".//ItemGroupDef")
  }
  if (length(igd_nodes) == 0L) {
    return(data.frame(
      dataset = character(),
      label = character(),
      stringsAsFactors = FALSE
    ))
  }

  datasets <- vapply(
    igd_nodes,
    function(n) {
      xml2::xml_attr(n, "Name") %||% ""
    },
    character(1L)
  )

  labels <- vapply(
    igd_nodes,
    function(n) {
      desc <- xml2::xml_find_first(n, ".//d1:Description/d1:TranslatedText", ns)
      if (is.na(desc)) {
        desc <- xml2::xml_find_first(n, ".//Description/TranslatedText")
      }
      if (is.na(desc)) {
        return(xml2::xml_attr(n, "def:Label") %||% "")
      }
      xml2::xml_text(desc)
    },
    character(1L)
  )

  data.frame(dataset = datasets, label = labels, stringsAsFactors = FALSE)
}

#' @noRd
.define_extract_variables <- function(mdv, ns) {
  # Build OID -> (dataset, order, mandatory) from ItemGroupDef > ItemRef.
  igd_nodes <- xml2::xml_find_all(mdv, ".//d1:ItemGroupDef", ns)
  if (length(igd_nodes) == 0L) {
    igd_nodes <- xml2::xml_find_all(mdv, ".//ItemGroupDef")
  }

  oid_dataset <- list()
  oid_order <- list()
  oid_mandatory <- list()

  for (ign in igd_nodes) {
    ds_name <- xml2::xml_attr(ign, "Name") %||% ""
    refs <- xml2::xml_find_all(ign, "d1:ItemRef", ns)
    if (length(refs) == 0L) {
      refs <- xml2::xml_find_all(ign, "ItemRef")
    }
    for (ref in refs) {
      item_oid <- xml2::xml_attr(ref, "ItemOID") %||% ""
      if (nzchar(item_oid)) {
        oid_dataset[[item_oid]] <- ds_name
        oid_order[[item_oid]] <- xml2::xml_attr(ref, "OrderNumber") %||% ""
        oid_mandatory[[item_oid]] <- xml2::xml_attr(ref, "Mandatory") %||% ""
      }
    }
  }

  item_nodes <- xml2::xml_find_all(mdv, ".//d1:ItemDef", ns)
  if (length(item_nodes) == 0L) {
    item_nodes <- xml2::xml_find_all(mdv, ".//ItemDef")
  }

  if (length(item_nodes) == 0L) {
    return(data.frame(
      dataset = character(),
      variable = character(),
      label = character(),
      data_type = character(),
      length = character(),
      origin = character(),
      codelist = character(),
      mandatory = character(),
      order = character(),
      format = character(),
      stringsAsFactors = FALSE
    ))
  }

  oids <- vapply(
    item_nodes,
    function(n) xml2::xml_attr(n, "OID") %||% "",
    character(1L)
  )
  names_vec <- vapply(
    item_nodes,
    function(n) xml2::xml_attr(n, "Name") %||% "",
    character(1L)
  )
  data_types <- vapply(
    item_nodes,
    function(n) xml2::xml_attr(n, "DataType") %||% "",
    character(1L)
  )
  lengths <- vapply(
    item_nodes,
    function(n) xml2::xml_attr(n, "Length") %||% "",
    character(1L)
  )

  labels <- vapply(
    item_nodes,
    function(n) {
      desc <- xml2::xml_find_first(n, ".//d1:Description/d1:TranslatedText", ns)
      if (is.na(desc)) {
        desc <- xml2::xml_find_first(n, ".//Description/TranslatedText")
      }
      if (is.na(desc)) {
        return("")
      }
      xml2::xml_text(desc)
    },
    character(1L)
  )

  # Origin: <def:Origin Type="CRF"/> child element (namespace-agnostic)
  origins <- vapply(
    item_nodes,
    function(n) {
      orig <- xml2::xml_find_first(n, "*[local-name()='Origin']")
      if (is.na(orig)) {
        return("")
      }
      xml2::xml_attr(orig, "Type") %||% ""
    },
    character(1L)
  )

  # CodeListRef
  codelist_refs <- vapply(
    item_nodes,
    function(n) {
      clr <- xml2::xml_find_first(n, "*[local-name()='CodeListRef']")
      if (is.na(clr)) {
        return("")
      }
      xml2::xml_attr(clr, "CodeListOID") %||% ""
    },
    character(1L)
  )

  # DisplayFormat (may appear as def:DisplayFormat attribute)
  formats <- vapply(
    item_nodes,
    function(n) {
      all_attrs <- xml2::xml_attrs(n)
      idx <- which(grepl("DisplayFormat", names(all_attrs), fixed = TRUE))
      if (length(idx) > 0L) all_attrs[[idx[[1L]]]] else ""
    },
    character(1L)
  )

  # Dataset: prefer ItemRef map, fallback to OID convention IT.DATASET.VARIABLE
  datasets <- vapply(
    oids,
    function(oid) {
      d <- oid_dataset[[oid]]
      if (!is.null(d) && nzchar(d)) {
        return(d)
      }
      parts <- strsplit(oid, ".", fixed = TRUE)[[1L]]
      if (length(parts) >= 2L) parts[2L] else ""
    },
    character(1L)
  )

  orders <- vapply(oids, function(oid) oid_order[[oid]] %||% "", character(1L))
  mandatories <- vapply(
    oids,
    function(oid) oid_mandatory[[oid]] %||% "",
    character(1L)
  )

  data.frame(
    dataset = datasets,
    variable = names_vec,
    label = labels,
    data_type = data_types,
    length = lengths,
    origin = origins,
    codelist = codelist_refs,
    mandatory = mandatories,
    order = orders,
    format = formats,
    stringsAsFactors = FALSE
  )
}

#' @noRd
.define_extract_codelists <- function(mdv, ns) {
  cl_nodes <- xml2::xml_find_all(mdv, ".//d1:CodeList", ns)
  if (length(cl_nodes) == 0L) {
    cl_nodes <- xml2::xml_find_all(mdv, ".//CodeList")
  }
  if (length(cl_nodes) == 0L) {
    return(NULL)
  }

  rows <- list()
  for (cl in cl_nodes) {
    cl_oid <- xml2::xml_attr(cl, "OID") %||% ""
    cl_name <- xml2::xml_attr(cl, "Name") %||% ""
    cl_dtype <- xml2::xml_attr(cl, "DataType") %||% ""

    items <- xml2::xml_find_all(cl, ".//d1:CodeListItem", ns)
    if (length(items) == 0L) {
      items <- xml2::xml_find_all(cl, ".//CodeListItem")
    }
    enum_items <- xml2::xml_find_all(cl, ".//d1:EnumeratedItem", ns)
    if (length(enum_items) == 0L) {
      enum_items <- xml2::xml_find_all(cl, ".//EnumeratedItem")
    }

    all_items <- c(items, enum_items)
    for (item in all_items) {
      term <- xml2::xml_attr(item, "CodedValue") %||% ""
      decode <- xml2::xml_find_first(item, ".//d1:Decode/d1:TranslatedText", ns)
      if (is.na(decode)) {
        decode <- xml2::xml_find_first(item, ".//Decode/TranslatedText")
      }
      decoded_val <- if (!is.na(decode)) xml2::xml_text(decode) else ""

      rows <- c(
        rows,
        list(data.frame(
          codelist_id = cl_oid,
          name = cl_name,
          data_type = cl_dtype,
          term = term,
          decoded_value = decoded_val,
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

#' @noRd
.define_extract_methods <- function(mdv, ns) {
  meth_nodes <- xml2::xml_find_all(mdv, ".//d1:MethodDef", ns)
  if (length(meth_nodes) == 0L) {
    meth_nodes <- xml2::xml_find_all(mdv, ".//MethodDef")
  }
  if (length(meth_nodes) == 0L) {
    return(NULL)
  }

  method_ids <- vapply(
    meth_nodes,
    function(n) xml2::xml_attr(n, "OID") %||% "",
    character(1L)
  )
  names_vec <- vapply(
    meth_nodes,
    function(n) xml2::xml_attr(n, "Name") %||% "",
    character(1L)
  )
  types <- vapply(
    meth_nodes,
    function(n) xml2::xml_attr(n, "Type") %||% "",
    character(1L)
  )
  descriptions <- vapply(
    meth_nodes,
    function(n) {
      desc <- xml2::xml_find_first(n, ".//d1:Description/d1:TranslatedText", ns)
      if (is.na(desc)) {
        desc <- xml2::xml_find_first(n, ".//Description/TranslatedText")
      }
      if (is.na(desc)) {
        return("")
      }
      xml2::xml_text(desc)
    },
    character(1L)
  )

  data.frame(
    method_id = method_ids,
    name = names_vec,
    type = types,
    description = descriptions,
    stringsAsFactors = FALSE
  )
}

#' @noRd
.define_extract_comments <- function(mdv, ns) {
  com_nodes <- xml2::xml_find_all(mdv, ".//def:CommentDef", ns)
  if (length(com_nodes) == 0L) {
    com_nodes <- xml2::xml_find_all(mdv, ".//CommentDef")
  }
  if (length(com_nodes) == 0L) {
    return(NULL)
  }

  comment_ids <- vapply(
    com_nodes,
    function(n) xml2::xml_attr(n, "OID") %||% "",
    character(1L)
  )
  descriptions <- vapply(
    com_nodes,
    function(n) {
      desc <- xml2::xml_find_first(n, ".//d1:Description/d1:TranslatedText", ns)
      if (is.na(desc)) {
        desc <- xml2::xml_find_first(n, ".//Description/TranslatedText")
      }
      if (is.na(desc)) {
        return("")
      }
      xml2::xml_text(desc)
    },
    character(1L)
  )

  data.frame(
    comment_id = comment_ids,
    description = descriptions,
    stringsAsFactors = FALSE
  )
}

#' @noRd
.define_extract_arm <- function(mdv, ns) {
  # Use local-name() to be namespace-agnostic for the arm namespace
  displays_node <- xml2::xml_find_all(
    mdv,
    ".//*[local-name()='ResultDisplay']"
  )

  if (length(displays_node) == 0L) {
    return(list(displays = NULL, results = NULL))
  }

  display_ids <- vapply(
    displays_node,
    function(n) xml2::xml_attr(n, "OID") %||% "",
    character(1L)
  )
  display_names <- vapply(
    displays_node,
    function(n) xml2::xml_attr(n, "Name") %||% "",
    character(1L)
  )

  displays <- data.frame(
    display_id = display_ids,
    title = display_names,
    stringsAsFactors = FALSE
  )

  result_rows <- list()
  for (i in seq_along(displays_node)) {
    ar_nodes <- xml2::xml_find_all(
      displays_node[[i]],
      ".//*[local-name()='AnalysisResult']"
    )
    for (ar in ar_nodes) {
      result_rows <- c(
        result_rows,
        list(data.frame(
          display_id = display_ids[i],
          result_id = xml2::xml_attr(ar, "OID") %||% "",
          description = xml2::xml_attr(ar, "Name") %||% "",
          stringsAsFactors = FALSE
        ))
      )
    }
  }

  results <- if (length(result_rows) > 0L) do.call(rbind, result_rows) else NULL
  list(displays = displays, results = results)
}

#' Extract sponsor-defined key variables per dataset.
#'
#' Reads KeyVariables attribute on ItemGroupDef elements, which is a
#' space-separated list of ItemOID references. We resolve each OID to the
#' variable name using the ItemDef Name attribute.
#'
#' @noRd
.define_extract_key_vars <- function(mdv, ns, ds_spec) {
  igd_nodes <- xml2::xml_find_all(mdv, ".//d1:ItemGroupDef", ns)
  if (length(igd_nodes) == 0L) {
    igd_nodes <- xml2::xml_find_all(mdv, ".//ItemGroupDef")
  }
  if (length(igd_nodes) == 0L) {
    return(list())
  }

  # Build OID -> variable name map from ItemDef
  item_nodes <- xml2::xml_find_all(mdv, ".//d1:ItemDef", ns)
  if (length(item_nodes) == 0L) {
    item_nodes <- xml2::xml_find_all(mdv, ".//ItemDef")
  }
  oid_to_name <- list()
  for (n in item_nodes) {
    oid <- xml2::xml_attr(n, "OID") %||% ""
    name <- xml2::xml_attr(n, "Name") %||% ""
    if (nzchar(oid) && nzchar(name)) {
      oid_to_name[[oid]] <- name
    }
  }

  key_vars <- list()
  for (ign in igd_nodes) {
    ds_name <- xml2::xml_attr(ign, "Name") %||% ""
    if (!nzchar(ds_name)) {
      next
    }

    # KeyVariables is a space-separated list of ItemOIDs in Define-XML 2.1.
    # xml2::xml_attr() does not resolve namespace prefixes on attributes, so
    # scan all attributes and match by local name (strips any "prefix:" part).
    kv_raw <- ""
    all_attrs <- xml2::xml_attrs(ign)
    for (nm in names(all_attrs)) {
      local_nm <- sub("^.*:", "", nm)
      if (identical(local_nm, "KeyVariables")) {
        kv_raw <- all_attrs[[nm]]
        break
      }
    }

    if (!nzchar(kv_raw)) {
      # Fallback: look for def:KeyVariable child elements (older convention)
      kv_nodes <- xml2::xml_find_all(ign, ".//*[local-name()='KeyVariable']")
      if (length(kv_nodes) > 0L) {
        kv_raw <- paste(
          vapply(
            kv_nodes,
            function(n) xml2::xml_attr(n, "OID") %||% "",
            character(1L)
          ),
          collapse = " "
        )
      }
    }

    if (!nzchar(kv_raw)) {
      next
    }

    oids <- trimws(strsplit(kv_raw, "[[:space:],]+")[[1L]])
    oids <- oids[nzchar(oids)]
    if (length(oids) == 0L) {
      next
    }

    # Resolve OIDs to variable names
    var_names <- vapply(
      oids,
      function(oid) {
        oid_to_name[[oid]] %||% ""
      },
      character(1L)
    )
    var_names <- var_names[nzchar(var_names)]

    if (length(var_names) > 0L) {
      key_vars[[toupper(ds_name)]] <- toupper(var_names)
    }
  }

  key_vars
}

#' Extract LOINC dictionary version from MetaDataVersion.
#'
#' Looks for a def:Standard or def:ExternalCodeList element with Type == "LOINC"
#' or Name matching "LOINC" to retrieve the version declared in the
#' Define-XML.
#'
#' @noRd
.define_extract_loinc_version <- function(mdv, ns) {
  # Strategy 1: def:Standard element with Name="LOINC"
  std_nodes <- xml2::xml_find_all(
    mdv,
    ".//*[local-name()='Standard']"
  )
  for (n in std_nodes) {
    nm <- toupper(xml2::xml_attr(n, "Name") %||% "")
    type <- toupper(xml2::xml_attr(n, "Type") %||% "")
    ver <- xml2::xml_attr(n, "Version") %||% ""
    if ((nm == "LOINC" || type == "LOINC") && nzchar(ver)) {
      return(ver)
    }
  }

  # Strategy 2: def:ExternalCodeList with Dictionary="LOINC"
  ecl_nodes <- xml2::xml_find_all(
    mdv,
    ".//*[local-name()='ExternalCodeList']"
  )
  for (n in ecl_nodes) {
    dict <- toupper(xml2::xml_attr(n, "Dictionary") %||% "")
    ver <- xml2::xml_attr(n, "Version") %||% ""
    if (dict == "LOINC" && nzchar(ver)) {
      return(ver)
    }
  }

  NA_character_
}
