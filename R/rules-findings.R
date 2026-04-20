# -----------------------------------------------------------------------------
# rules-findings.R — findings tibble schema + emitter
# -----------------------------------------------------------------------------
# Every validate() call produces a tibble of findings. One row per
# (rule, dataset, record) tuple that failed or returned an advisory.
#
# Schema matches the shape the HTML/XLSX renderers will consume in M6.

#' Empty findings tibble with canonical column types
#' @noRd
empty_findings <- function() {
  tibble::tibble(
    rule_id         = character(),
    authority       = character(),
    standard        = character(),
    severity        = character(),
    status          = character(),   # "fired" | "advisory" | "error"
    dataset         = character(),
    variable        = character(),
    row             = integer(),
    value           = character(),
    expected        = character(),
    message         = character(),
    source_url      = character(),
    p21_id_equivalent = character(),
    license         = character()
  )
}

#' Emit findings from a walk_tree() mask for a single (rule, dataset) pair
#'
#' @param rule a single-row slice of rules.rds (or an equivalent named list)
#' @param ds_name character(1) dataset name
#' @param mask logical(nrow(data)) returned by walk_tree
#' @param data the dataset rows were evaluated against (same row order)
#' @param variable character(1) or NA — the primary variable touched by the
#'        rule, derived from the check_tree at the outermost leaf if known
#' @return tibble of findings (may be 0 rows)
#' @noRd
emit_findings <- function(rule, ds_name, mask, data, variable = NA_character_) {
  n <- length(mask)
  if (n == 0L) return(empty_findings())

  is_false   <- !is.na(mask) & !mask
  is_na      <- is.na(mask)

  # "fired" rows -- rule failed on this record
  fired_rows <- which(is_false)
  # "advisory" rows -- check_tree could not be evaluated (narrative, op error, etc.)
  # We emit ONE advisory row per (rule, dataset) rather than per record, because
  # narrative rules would otherwise dominate the finding table.
  adv_once <- any(is_na) && !any(is_false)

  out <- empty_findings()
  if (length(fired_rows) > 0L) {
    val <- if (!is.na(variable) && variable %in% names(data)) {
      as.character(data[[variable]][fired_rows])
    } else {
      rep(NA_character_, length(fired_rows))
    }
    out <- tibble::tibble(
      rule_id           = rep(rule[["id"]] %||% NA_character_, length(fired_rows)),
      authority         = rep(rule[["authority"]] %||% NA_character_, length(fired_rows)),
      standard          = rep(rule[["standard"]] %||% NA_character_, length(fired_rows)),
      severity          = rep(rule[["severity"]] %||% "Medium", length(fired_rows)),
      status            = rep("fired", length(fired_rows)),
      dataset           = rep(ds_name, length(fired_rows)),
      variable          = rep(variable, length(fired_rows)),
      row               = as.integer(fired_rows),
      value             = val,
      expected          = rep(NA_character_, length(fired_rows)),
      message           = rep(rule[["message"]] %||% "", length(fired_rows)),
      source_url        = rep(rule[["source_url"]] %||% NA_character_, length(fired_rows)),
      p21_id_equivalent = rep(rule[["p21_id_equivalent"]] %||% NA_character_, length(fired_rows)),
      license           = rep(rule[["license"]] %||% NA_character_, length(fired_rows))
    )
  }

  if (adv_once) {
    adv <- tibble::tibble(
      rule_id           = rule[["id"]] %||% NA_character_,
      authority         = rule[["authority"]] %||% NA_character_,
      standard          = rule[["standard"]] %||% NA_character_,
      severity          = rule[["severity"]] %||% "Medium",
      status            = "advisory",
      dataset           = ds_name,
      variable          = variable,
      row               = NA_integer_,
      value             = NA_character_,
      expected          = NA_character_,
      message           = rule[["message"]] %||% "",
      source_url        = rule[["source_url"]] %||% NA_character_,
      p21_id_equivalent = rule[["p21_id_equivalent"]] %||% NA_character_,
      license           = rule[["license"]] %||% NA_character_
    )
    out <- rbind(out, adv)
  }
  out
}

#' Peek at a check_tree and guess the primary variable for finding attribution
#'
#' Walks the tree looking for the first leaf with a `name` field. Returns
#' NA if the tree has no attributable variable (e.g. pure combinators or
#' narrative-only).
#' @noRd
primary_variable <- function(node) {
  if (is.null(node) || length(node) == 0L) return(NA_character_)
  if (!is.null(node[["name"]])) return(as.character(node[["name"]]))
  for (key in c("all", "any")) {
    children <- node[[key]]
    if (!is.null(children) && length(children) > 0L) {
      for (child in children) {
        v <- primary_variable(child)
        if (!is.na(v)) return(v)
      }
    }
  }
  if (!is.null(node[["not"]])) return(primary_variable(node[["not"]]))
  NA_character_
}
