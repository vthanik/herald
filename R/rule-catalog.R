# rule-catalog.R -- public helpers for inspecting the compiled rule corpus

#' Compiled rule catalog
#'
#' Returns every rule shipped with herald (conformance rules from
#' `inst/rules/rules.rds` plus spec pre-flight rules from
#' `inst/rules/spec_rules.rds`) as a flat tibble.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{rule_id}{Rule identifier (e.g. `"CG0006"`, `"1"`,
#'       `"define_version_is_2_1"`).}
#'     \item{standard}{CDISC standard family (`"SDTM-IG"`, `"ADaM-IG"`,
#'       `"Define-XML"`, `"SEND-IG"`, `"herald-spec"`).}
#'     \item{authority}{Rule authority (`"CDISC"`, `"FDA"`, `"HERALD"`).}
#'     \item{severity}{Finding severity (`"Error"`, `"Warning"`,
#'       `"Medium"`, etc.).}
#'     \item{message}{Short finding message / error code.}
#'     \item{source_document}{Upstream source (e.g. `"CDISC ADaM
#'       Conformance Rules v5.0"`).}
#'     \item{has_predicate}{`TRUE` when an executable check-tree is
#'       compiled for this rule; `FALSE` for rules that are authored
#'       as narrative stubs awaiting predicate implementation.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' cat <- rule_catalog()
#' cat[cat$standard == "ADaM-IG" & !cat$has_predicate, ]
#' }
rule_catalog <- function() {
  rules <- .load_rule_rds("rules.rds")
  spec  <- .load_rule_rds("spec_rules.rds")
  combined <- rbind(rules, spec)
  tibble::tibble(
    rule_id       = as.character(combined$id),
    standard      = as.character(combined$standard),
    authority     = as.character(combined$authority),
    severity      = as.character(combined$severity),
    message       = as.character(combined$message),
    source_document = as.character(combined$source_document),
    has_predicate = vapply(combined$check_tree,
                           function(ct) !is.null(ct) && length(ct) > 0L,
                           logical(1L))
  )
}

#' Summarise herald's standards coverage
#'
#' Returns a cross-tab of rule counts by standard and authority, with
#' predicate vs narrative split and corpus metadata.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{standard}{CDISC standard family.}
#'     \item{authority}{Rule authority.}
#'     \item{n_rules}{Total rules.}
#'     \item{n_predicate}{Rules with an executable predicate.}
#'     \item{n_narrative}{Rules pending predicate authoring.}
#'     \item{pct_predicate}{Fraction of rules with a predicate (0--1).}
#'   }
#'   The tibble carries two attributes:
#'   \describe{
#'     \item{compiled_at}{ISO-8601 timestamp when the corpus was last
#'       compiled.}
#'     \item{herald_version}{Package version at compile time.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' supported_standards()
#' }
supported_standards <- function() {
  cat <- rule_catalog()

  # Aggregate
  keys <- unique(cat[, c("standard", "authority"), drop = FALSE])
  keys <- keys[order(keys$standard, keys$authority), ]

  rows <- lapply(seq_len(nrow(keys)), function(i) {
    std <- keys$standard[i]
    aut <- keys$authority[i]
    sub <- cat[cat$standard == std & cat$authority == aut, , drop = FALSE]
    n_pred <- sum(sub$has_predicate)
    n_total <- nrow(sub)
    list(
      standard     = std,
      authority    = aut,
      n_rules      = n_total,
      n_predicate  = n_pred,
      n_narrative  = n_total - n_pred,
      pct_predicate = if (n_total > 0L) n_pred / n_total else NA_real_
    )
  })

  out <- tibble::tibble(
    standard      = vapply(rows, `[[`, character(1L), "standard"),
    authority     = vapply(rows, `[[`, character(1L), "authority"),
    n_rules       = vapply(rows, `[[`, integer(1L), "n_rules"),
    n_predicate   = vapply(rows, `[[`, integer(1L), "n_predicate"),
    n_narrative   = vapply(rows, `[[`, integer(1L), "n_narrative"),
    pct_predicate = vapply(rows, `[[`, double(1L), "pct_predicate")
  )

  manifest <- .read_manifest()
  attr(out, "compiled_at")    <- manifest$compiled_at %||% NA_character_
  attr(out, "herald_version") <- manifest$herald_version %||% NA_character_
  out
}

# ---- internals ----------------------------------------------------------------

.load_rule_rds <- function(filename) {
  path <- system.file("rules", filename, package = "herald")
  if (!nzchar(path)) {
    herald_error_runtime(
      "Could not find {.path inst/rules/{filename}} in the installed package.",
      call = rlang::caller_env()
    )
  }
  readRDS(path)
}

.read_manifest <- function() {
  path <- system.file("rules", "MANIFEST.json", package = "herald")
  if (!nzchar(path)) return(list())
  jsonlite::fromJSON(path)
}
