# -----------------------------------------------------------------------------
# ops-set.R — set-membership operators
# -----------------------------------------------------------------------------
# ~120 CDISC rule uses, mostly controlled-terminology checks.

.as_set <- function(x) {
  if (is.null(x)) return(character(0))
  as.character(unlist(x))
}

op_is_contained_by <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  # Apply the P21 rtrim-null convention to the lookup value so
  # "S1-001 " matches "S1-001" in the set. Whitespace-only or NA
  # values become NA in the mask (caller cannot verify containment
  # when the value itself is missing).
  raw <- as.character(col)
  v   <- sub("\\s+$", "", raw)
  is_missing <- is.na(raw) | !nzchar(v)
  out <- v %in% .as_set(value)
  out[is_missing] <- NA
  out
}
.register_op(
  "is_contained_by", op_is_contained_by,
  meta = list(
    kind = "set",
    summary = "Column value is in set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_not_contained_by <- function(data, ctx, name, value) {
  m <- op_is_contained_by(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "is_not_contained_by", op_is_not_contained_by,
  meta = list(
    kind = "set",
    summary = "Column value is not in set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_contained_by_ci <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  tolower(as.character(col)) %in% tolower(.as_set(value))
}
.register_op(
  "is_contained_by_case_insensitive", op_is_contained_by_ci,
  meta = list(
    kind = "set",
    summary = "Column value is in set (case-insensitive)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_not_contained_by_ci <- function(data, ctx, name, value) {
  !op_is_contained_by_ci(data, ctx, name, value)
}
.register_op(
  "is_not_contained_by_case_insensitive", op_is_not_contained_by_ci,
  meta = list(
    kind = "set",
    summary = "Column value is not in set (case-insensitive)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

# --- uniqueness (within a single column or a composite key) ------------------

op_is_unique_set <- function(data, ctx, name) {
  # name may be a scalar column name or a vector of column names (composite key)
  names_vec <- .as_set(name)
  missing_cols <- setdiff(names_vec, names(data))
  if (length(missing_cols) > 0L) return(rep(NA, nrow(data)))
  key <- do.call(paste, c(data[, names_vec, drop = FALSE], list(sep = "\x1f")))
  counts <- table(key)
  rep_count <- as.integer(counts[key])
  rep_count == 1L
}
.register_op(
  "is_unique_set", op_is_unique_set,
  meta = list(
    kind = "set",
    summary = "Row's column (or composite key) value is unique within dataset",
    arg_schema = list(
      name = list(type = "list", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = NA_character_,
    returns_na_ok = TRUE
  )
)

op_is_not_unique_set <- function(data, ctx, name) {
  !op_is_unique_set(data, ctx, name)
}
.register_op(
  "is_not_unique_set", op_is_not_unique_set,
  meta = list(
    kind = "set",
    summary = "Row's column value is duplicated within dataset",
    arg_schema = list(
      name = list(type = "list", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = NA_character_,
    returns_na_ok = TRUE
  )
)

# --- contains_all / not_contains_all ----------------------------------------
# For each row, check whether column's value (possibly tokenised on
# whitespace / commas / pipes) contains ALL of the values in `value`.
# Used e.g. to assert a flag column enumerates a required keyword set.

.tokenize <- function(x) {
  # Split on separators commonly used in SDTM: comma, pipe, semicolon, whitespace
  trimws(unlist(strsplit(as.character(x), "[,;|[:space:]]+", perl = TRUE)))
}

op_contains_all <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  need <- .as_set(value)
  if (length(need) == 0L) return(rep(TRUE, nrow(data)))
  vapply(col, function(v) {
    if (is.na(v) || !nzchar(as.character(v))) return(NA)
    have <- .tokenize(v)
    all(need %in% have)
  }, logical(1))
}
.register_op(
  "contains_all", op_contains_all,
  meta = list(
    kind = "set",
    summary = "Column value tokenises to a superset of `value` (all needed tokens present)",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_not_contains_all <- function(data, ctx, name, value) {
  m <- op_contains_all(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "not_contains_all", op_not_contains_all,
  meta = list(
    kind = "set",
    summary = "Column value is missing at least one required token",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- shares_no_elements_with ------------------------------------------------
# Row-level: column's tokenised set has no intersection with the `value` set.

op_shares_no_elements_with <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  banned <- .as_set(value)
  vapply(col, function(v) {
    if (is.na(v) || !nzchar(as.character(v))) return(NA)
    have <- .tokenize(v)
    !any(have %in% banned)
  }, logical(1))
}
.register_op(
  "shares_no_elements_with", op_shares_no_elements_with,
  meta = list(
    kind = "set",
    summary = "Column value shares no tokens with the banned set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- is_ordered_subset_of / is_not_ordered_subset_of ------------------------
# For a column whose values are SEQUENTIALLY ordered (e.g. VISITNUM), assert
# that the row-ordered sequence is a subset of `value` IN ORDER (i.e. each
# observed value appears in `value` and preserves the ordering).

op_is_ordered_subset_of <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  ordered_universe <- .as_set(value)
  observed <- as.character(col)
  pos <- match(observed, ordered_universe)
  # A row is "in order" if its position is strictly greater than the max
  # position seen in the rows above it.
  n <- length(observed)
  out <- logical(n)
  running_max <- 0L
  for (i in seq_len(n)) {
    if (is.na(pos[i])) { out[i] <- NA; next }
    out[i] <- pos[i] > running_max
    if (!is.na(out[i]) && isTRUE(out[i])) running_max <- pos[i]
  }
  out
}
.register_op(
  "is_ordered_subset_of", op_is_ordered_subset_of,
  meta = list(
    kind = "set",
    summary = "Column value is in the ordered universe AND follows row-order (monotonic within dataset)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_is_not_ordered_subset_of <- function(data, ctx, name, value) {
  m <- op_is_ordered_subset_of(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "is_not_ordered_subset_of", op_is_not_ordered_subset_of,
  meta = list(
    kind = "set",
    summary = "Column value breaks the ordered-subset invariant (out of order or unknown value)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- value_in_codelist (CT-driven membership; plan Q7) ----------------------
# Fires when a row value is NOT in the given CDISC codelist. The CT is
# loaded once per validate() run via ctx$ct[[package]] and looked up
# by submission short name, NCI code, or long name.
#
# Extensible codelists accept any non-empty sponsor value in addition
# to the listed terms (CDISC extensible-codelist contract).
# match_synonyms merges the codelist's synonym field into the
# accepted-values set for ISO 21090 null-flavor style rules.

op_value_in_codelist <- function(data, ctx, name, codelist,
                                 extensible     = FALSE,
                                 match_synonyms = FALSE,
                                 package        = "sdtm") {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))

  # Dictionary Provider Protocol: resolve the CDISC CT dictionary
  # via ctx$dict if populated (Phase 2+); fall back to the legacy
  # ctx$ct cache so older test fixtures that pre-populate ctx$ct
  # directly continue to work.
  provider <- .resolve_provider(ctx, paste0("ct-", package))
  if (is.null(provider)) {
    # Auto-install a ct_provider for this package on first use and
    # memoise on ctx$dict so the subsequent rules share the load.
    provider <- tryCatch(ct_provider(package), error = function(e) NULL)
    if (is.null(provider)) {
      .record_missing_ref(ctx,
        rule_id = ctx$current_rule_id,
        kind = "dictionary",
        name = paste0("ct-", package))
      return(rep(NA, n))
    }
    if (is.null(ctx$dict)) ctx$dict <- list()
    ctx$dict[[paste0("ct-", package)]] <- provider
  }

  # The provider's bundled CT object is exposed via the lookup
  # closure; reach it only for the synonyms branch (not in schema).
  accepted <- NULL
  if (isTRUE(match_synonyms)) {
    # Fall back to the raw CT so we can read the synonyms field.
    ct <- ctx$ct[[package]] %||% tryCatch(load_ct(package),
                                          error = function(e) NULL)
    if (!is.null(ct)) {
      if (is.null(ctx$ct[[package]])) ctx$ct[[package]] <- ct
      entry <- .lookup_codelist(ct, codelist)
      if (!is.null(entry)) {
        accepted <- as.character(entry$terms$submissionValue %||% character())
        syn <- entry$terms$synonyms %||% character(0)
        syn <- unlist(strsplit(as.character(syn), ";"), use.names = FALSE)
        accepted <- unique(c(accepted, trimws(syn)))
      }
    }
  }

  vals <- as.character(data[[name]])
  vals <- sub(" +$", "", vals)
  out <- rep(NA, n)
  non_empty <- !is.na(vals) & nzchar(vals)

  if (!is.null(accepted)) {
    # synonyms path (merged set)
    out[non_empty] <- !(vals[non_empty] %in% accepted)
  } else {
    # standard path: delegate to provider$contains
    hit_mask <- provider$contains(vals[non_empty], field = codelist,
                                  ignore_case = FALSE)
    if (all(is.na(hit_mask))) {
      # Codelist not found in provider; surface as advisory rather
      # than silently pass. Matches prior behaviour.
      return(rep(NA, n))
    }
    out[non_empty] <- !hit_mask
  }

  if (isTRUE(extensible)) {
    # Extensible codelist: any non-empty value passes (fire only on NA).
    out[non_empty] <- FALSE
  }
  out
}
.register_op(
  "value_in_codelist", op_value_in_codelist,
  meta = list(
    kind = "set",
    summary = "Row value is in the named CDISC CT codelist",
    arg_schema = list(
      name           = list(type = "string",  required = TRUE),
      codelist       = list(type = "string",  required = TRUE),
      extensible     = list(type = "boolean", default  = FALSE),
      match_synonyms = list(type = "boolean", default  = FALSE),
      package        = list(type = "string",  default  = "sdtm")
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- value_in_srs_table -------------------------------------------------------
# Fires when a row value is NOT found in the FDA SRS / UNII registry.
# The SRS provider is resolved via ctx$dict[["srs"]] (injected by
# srs_provider() or validate(dictionaries = list(srs = srs_provider()))).
# When no cached SRS table exists, records a missing_ref and returns NA
# (advisory) so the rule stays predicate even without the download.
#
# field: "preferred_name" checks the PT column; "unii" checks UNII codes.
#
# Arg shape in rules:
#   { name: "TSVAL", operator: "value_in_srs_table", field: "preferred_name" }

op_value_in_srs_table <- function(data, ctx, name, field = "preferred_name") {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))
  if (is.null(data[[name]])) return(rep(NA, n))

  field <- as.character(field %||% "preferred_name")

  provider <- .resolve_provider(ctx, "srs")
  if (is.null(provider)) {
    provider <- tryCatch(srs_provider(), error = function(e) NULL)
    if (is.null(provider)) {
      .record_missing_ref(ctx,
        rule_id = ctx$current_rule_id %||% NA_character_,
        kind    = "dictionary",
        name    = "srs")
      return(rep(NA, n))
    }
    if (is.null(ctx$dict)) ctx$dict <- list()
    ctx$dict[["srs"]] <- provider
  }

  vals      <- sub(" +$", "", as.character(data[[name]]))
  out       <- rep(NA, n)
  non_empty <- !is.na(vals) & nzchar(vals)
  if (!any(non_empty)) return(out)

  hit_mask <- provider$contains(vals[non_empty], field = field)
  if (all(is.na(hit_mask))) return(rep(NA, n))

  out[non_empty] <- !hit_mask   # fires (TRUE) when NOT in SRS
  out
}
.register_op(
  "value_in_srs_table", op_value_in_srs_table,
  meta = list(
    kind    = "set",
    summary = "Row value is in the FDA SRS / UNII registry (fires when not found)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      field = list(type = "string", default  = "preferred_name")
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- value_in_dictionary -------------------------------------------------------
# Fires when a row value is NOT found in a user-registered external
# dictionary (MedDRA, WHO-Drug, etc.). The dictionary is resolved via
# ctx$dict[[dict_name]] which is populated when the user calls
# register_dictionary(dict_name, <provider>).
#
# When no provider is registered the op returns NA (advisory) with a
# .record_missing_ref so the result surfaces an actionable hint.
#
# field: the provider field to check (e.g. "pt", "soc", "pt_code").
#
# Arg shape in rules:
#   { name: "--DECOD", operator: "value_in_dictionary",
#     dict_name: "meddra", field: "pt" }

op_value_in_dictionary <- function(data, ctx, name,
                                   dict_name = "meddra",
                                   field     = "pt") {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))
  if (is.null(data[[name]])) return(rep(NA, n))

  dict_name <- as.character(dict_name %||% "meddra")
  field     <- as.character(field     %||% "pt")

  provider <- .resolve_provider(ctx, dict_name)
  if (is.null(provider)) {
    .record_missing_ref(ctx,
      rule_id = ctx$current_rule_id %||% NA_character_,
      kind    = "dictionary",
      name    = dict_name)
    return(rep(NA, n))
  }

  vals      <- sub(" +$", "", as.character(data[[name]]))
  out       <- rep(NA, n)
  non_empty <- !is.na(vals) & nzchar(vals)
  if (!any(non_empty)) return(out)

  hit_mask <- provider$contains(vals[non_empty], field = field)
  if (all(is.na(hit_mask))) return(rep(NA, n))

  out[non_empty] <- !hit_mask   # fires (TRUE) when NOT in dictionary
  out
}
.register_op(
  "value_in_dictionary", op_value_in_dictionary,
  meta = list(
    kind    = "set",
    summary = "Row value is in the named external dictionary (fires when not found)",
    arg_schema = list(
      name      = list(type = "string", required = TRUE),
      dict_name = list(type = "string", default  = "meddra"),
      field     = list(type = "string", default  = "pt")
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

#' Resolve a codelist by submission name, NCI code, or long name.
#' @noRd
.lookup_codelist <- function(ct, codelist) {
  key <- as.character(codelist)
  if (key %in% names(ct)) return(ct[[key]])
  # Fall back on codelist_code or codelist_name
  for (e in ct) {
    if (identical(e$codelist_code, key)) return(e)
    if (identical(e$codelist_name, key)) return(e)
  }
  NULL
}

