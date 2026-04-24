# ops-does-not-equal-string-part.R -- does_not_equal_string_part
# Returns TRUE when the column value does not equal a substring of the dataset
# name. Used by CG0334: RDOMAIN must equal chars 5-6 of the SUPP-- dataset
# name (e.g. for SUPPAE, chars 5-6 = "AE").
# Unlocks: CORE-000538 (CG0334).
#
# params: name (column), start (1-based char start), end (1-based char end).

op_does_not_equal_string_part <- function(data, ctx, name,
                                           start = 5L, end = 6L, ...) {
  col <- name
  n   <- nrow(data)
  if (!col %in% names(data)) return(rep(NA, n))
  ds_name <- ctx$current_dataset %||% ""
  expected <- toupper(substr(ds_name, as.integer(start), as.integer(end)))
  if (!nzchar(expected)) return(rep(NA, n))
  toupper(as.character(data[[col]])) != expected
}

.register_op(
  "does_not_equal_string_part",
  op_does_not_equal_string_part,
  meta = list(
    kind       = "compare",
    summary    = "TRUE when column value != the specified chars of the dataset name.",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      start = list(type = "integer", default  = 5L),
      end   = list(type = "integer", default  = 6L)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE
  )
)
