# --------------------------------------------------------------------------
# ops-define.R -- ops that consume ctx$define (parsed Define-XML metadata)
# --------------------------------------------------------------------------
# ctx$define is a herald_define object populated when validate() is called
# with a define = read_define_xml("define.xml") argument.
# All ops here return NA (advisory) when ctx$define is absent so they
# degrade gracefully on submissions without a define.xml path.

# --------------------------------------------------------------------------
# op_key_not_unique_per_define
# --------------------------------------------------------------------------
# CG0019: each record is unique per sponsor-defined key variables as
# documented in the define.xml (ItemGroupDef[@def:KeyVariables]).
#
# Resolution order:
#   1. ctx$define$key_vars[[ds_name]] -- from parsed define.xml
#   2. NA advisory if define or key_vars absent (logged to missing_refs)
#
# When key_vars are found but some are absent from data, those columns
# are silently dropped (the remaining subset is still checked). If no
# valid key columns remain, NA advisory is returned.

#' @noRd
op_key_not_unique_per_define <- function(data, ctx) {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))

  # Obtain define metadata
  def <- if (!is.null(ctx)) ctx$define else NULL
  if (is.null(def)) {
    .record_missing_ref(ctx,
      rule_id = ctx$current_rule_id %||% "",
      kind    = "define",
      name    = "define.xml")
    return(rep(NA_integer_, n) != 0L)  # NA logical
  }

  ds_name <- toupper(ctx$current_dataset %||% "")
  key_vars <- def$key_vars[[ds_name]]

  if (is.null(key_vars) || length(key_vars) == 0L) {
    # No key variables documented for this dataset -- skip (advisory)
    return(rep(NA_integer_, n) != 0L)
  }

  # Filter to columns present in data
  available <- intersect(key_vars, names(data))
  if (length(available) == 0L) {
    # All key columns are absent from data -- advisory
    return(rep(NA_integer_, n) != 0L)
  }

  # Check uniqueness of the composite key
  key <- do.call(paste, c(data[, available, drop = FALSE], list(sep = "\x1f")))
  counts    <- table(key)
  rep_count <- as.integer(counts[key])
  # fires (TRUE) when duplicated
  rep_count > 1L
}
.register_op(
  "key_not_unique_per_define", op_key_not_unique_per_define,
  meta = list(
    kind          = "cross",
    summary       = "Record not unique per sponsor-defined key variables from define.xml",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = NA_character_,
    returns_na_ok = TRUE
  )
)
