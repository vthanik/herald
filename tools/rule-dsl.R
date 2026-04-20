# tools/rule-dsl.R
# Tiny R DSL for hand-authoring rules. Sourced by tools/compile-rules.R
# before any tools/handauthored/*.R file. Not installed, not user-facing.
#
# Shape:
#   rule(
#     id       = "HRL-SD-010",
#     standard = "SDTM-IG",
#     severity = "Medium",
#     domains  = c("AE", "EX"),
#     check    = all_(
#       greater_than_or_equal_to(AESTDTC, min_by(EXSTDTC, USUBJID, "EX"))
#     ),
#     message  = "AE start date precedes earliest exposure"
#   )

# ---- internal registry -----------------------------------------------------

.rule_registry <- new.env(parent = emptyenv())
.rule_registry$rules <- list()

.reset_rule_registry <- function() {
  .rule_registry$rules <- list()
}

.collect_rules <- function() {
  .rule_registry$rules
}

# ---- rule() constructor ----------------------------------------------------

rule <- function(
  id,
  standard,
  severity,
  check,
  message,
  domains      = character(0),
  classes      = character(0),
  exclude_domains = character(0),
  authority    = "HERALD",
  standard_ver = NA_character_,
  source_document = "",
  source_url   = "herald-own",
  source_version = "1",
  license      = "MIT",
  p21_id_equivalent = NA_character_
) {
  if (missing(id) || !nzchar(id))
    stop("rule() requires id=")
  if (missing(check) || is.null(check))
    stop("rule() requires check=")
  if (missing(message) || !nzchar(message))
    stop("rule() requires message=")
  if (missing(standard) || !nzchar(standard))
    stop("rule() requires standard=")
  if (missing(severity) || !nzchar(severity))
    stop("rule() requires severity=")

  rec <- list(
    id             = id,
    authority      = authority,
    standard       = standard,
    standard_ver   = standard_ver,
    severity       = severity,
    scope          = list(
      classes         = classes,
      domains         = domains,
      exclude_domains = exclude_domains
    ),
    check_tree     = check,
    message        = message,
    source_document = source_document,
    source_url     = source_url,
    source_version = source_version,
    fetched_at     = as.POSIXct(NA),
    license        = license,
    p21_id_equivalent = p21_id_equivalent,
    .origin        = "r-dsl"
  )

  n <- length(.rule_registry$rules)
  .rule_registry$rules[[n + 1L]] <- rec
  invisible(rec)
}

# ---- tree combinators ------------------------------------------------------

all_ <- function(...) list(all = list(...))
any_ <- function(...) list(any = list(...))
not_ <- function(x)   list(`not` = x)

# ---- leaf operator helpers -------------------------------------------------
# Each returns one node:
#   list(name = "COLUMN", operator = "op-name", ...args...)
# Column names are captured as symbols via rlang; strings also accepted,
# so loops and !!var both work.

.col <- function(x) {
  q <- rlang::enquo(x)
  e <- rlang::quo_get_expr(q)
  if (is.character(e) && length(e) == 1L) return(e)
  if (is.symbol(e)) return(as.character(e))
  val <- tryCatch(rlang::eval_tidy(q), error = function(e) NULL)
  if (is.character(val) && length(val) == 1L) return(val)
  stop("Rule DSL: column argument must be a symbol (AESTDTC) or string (\"AESTDTC\").")
}

# presence / absence
non_empty      <- function(col)          list(name = .col(col), operator = "non_empty")
empty          <- function(col)          list(name = .col(col), operator = "empty")
is_missing     <- function(col)          list(name = .col(col), operator = "is_missing")
is_present     <- function(col)          list(name = .col(col), operator = "is_present")

# equality
equal_to       <- function(col, value)   list(name = .col(col), operator = "equal_to",
                                              value = value, value_is_literal = TRUE)
not_equal_to   <- function(col, value)   list(name = .col(col), operator = "not_equal_to",
                                              value = value, value_is_literal = TRUE)
in_set         <- function(col, values)  list(name = .col(col), operator = "in_set",
                                              value = values)
not_in_set     <- function(col, values)  list(name = .col(col), operator = "not_in_set",
                                              value = values)

# numeric / order
greater_than             <- function(col, value) list(name = .col(col), operator = "greater_than", value = value)
greater_than_or_equal_to <- function(col, value) list(name = .col(col), operator = "greater_than_or_equal_to", value = value)
less_than                <- function(col, value) list(name = .col(col), operator = "less_than", value = value)
less_than_or_equal_to    <- function(col, value) list(name = .col(col), operator = "less_than_or_equal_to", value = value)
between                  <- function(col, lo, hi) list(name = .col(col), operator = "between", value = list(low = lo, high = hi))

# strings
matches_regex  <- function(col, pattern) list(name = .col(col), operator = "matches_regex", value = pattern)
iso8601        <- function(col)          list(name = .col(col), operator = "iso8601")
length_le      <- function(col, max_len) list(name = .col(col), operator = "length_le", value = max_len)

# cross-dataset references
no_matching_record <- function(col, reference_dataset, by) {
  list(
    name     = .col(col),
    operator = "no_matching_record",
    value    = list(reference_dataset = reference_dataset, by = by)
  )
}

# aggregate comparison ("min/max of X from dataset D, grouped by G")
min_by <- function(col, by, dataset) {
  list(
    name      = .col(col),
    aggregate = "min",
    by        = if (is.character(by)) by else .col(by),
    dataset   = dataset
  )
}
max_by <- function(col, by, dataset) {
  list(
    name      = .col(col),
    aggregate = "max",
    by        = if (is.character(by)) by else .col(by),
    dataset   = dataset
  )
}
