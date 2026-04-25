# -----------------------------------------------------------------------------
# rules-findings.R  --  findings tibble schema + emitter
# -----------------------------------------------------------------------------
# Every validate() call produces a tibble of findings. One row per
# (rule, dataset, record) tuple that failed or returned an advisory.
#
# Schema matches the shape the HTML/XLSX renderers will consume in M6.

#' Empty findings tibble with canonical column types
#' @noRd
empty_findings <- function() {
  tibble::tibble(
    rule_id = character(),
    authority = character(),
    standard = character(),
    severity = character(),
    severity_override = character(), # original severity when overridden via severity_map; NA otherwise
    status = character(), # "fired" | "advisory" | "error"
    dataset = character(),
    variable = character(),
    row = integer(),
    value = character(),
    expected = character(),
    message = character(),
    source_url = character(),
    p21_id_equivalent = character(),
    license = character()
  )
}

#' Emit findings from a walk_tree() mask for a single (rule, dataset) pair
#'
#' @param rule a single-row slice of rules.rds (or an equivalent named list)
#' @param ds_name character(1) dataset name
#' @param mask logical(nrow(data)) returned by walk_tree
#' @param data the dataset rows were evaluated against (same row order)
#' @param variable character(1) or NA  --  the primary variable touched by the
#'        rule, derived from the check_tree at the outermost leaf if known
#' @return tibble of findings (may be 0 rows)
#' @noRd
emit_findings <- function(rule, ds_name, mask, data, variable = NA_character_) {
  n <- length(mask)
  if (n == 0L) {
    return(empty_findings())
  }

  # CDISC CORE semantics: check_tree returns TRUE for rows that VIOLATE
  # the rule (emit a finding). FALSE means the rule passes. NA means we
  # could not decide (narrative-only, unknown operator, op error).
  is_true <- !is.na(mask) & mask
  is_na <- is.na(mask)

  # "fired" rows -- check_tree evaluated TRUE (violation condition met)
  fired_rows <- which(is_true)
  # "advisory" rows -- one emitted per (rule, dataset) when nothing fired
  # but at least one row was NA (narrative / unknown op / op error).
  adv_once <- any(is_na) && !any(is_true)

  # Render SDTM `--` placeholders in message / variable against this
  # dataset's domain prefix, so findings on AE show "AEREASND" rather
  # than "--REASND". Safe no-op for ADaM (skips the substitution).
  msg_txt <- .render_domain_prefix(rule[["message"]] %||% "", ds_name)
  var_txt <- .render_domain_prefix(variable, ds_name)

  out <- empty_findings()
  if (length(fired_rows) > 0L) {
    # When the primary variable is a composite key (vector of column
    # names, e.g. is_not_unique_set with name=[STUDYID, SUBJID]), use
    # the first column's value as the reported `value` and join the
    # column names for display.
    var_first <- if (length(var_txt) > 1L) var_txt[[1L]] else var_txt
    val <- if (
      !is.null(var_first) &&
        !is.na(var_first) &&
        nzchar(var_first) &&
        var_first %in% names(data)
    ) {
      as.character(data[[var_first]][fired_rows])
    } else {
      rep(NA_character_, length(fired_rows))
    }
    var_display <- if (length(var_txt) > 1L) {
      paste(var_txt, collapse = ",")
    } else {
      var_txt
    }
    out <- tibble::tibble(
      rule_id = rep(rule[["id"]] %||% NA_character_, length(fired_rows)),
      authority = rep(
        rule[["authority"]] %||% NA_character_,
        length(fired_rows)
      ),
      standard = rep(rule[["standard"]] %||% NA_character_, length(fired_rows)),
      severity = rep(rule[["severity"]] %||% "Medium", length(fired_rows)),
      severity_override = rep(NA_character_, length(fired_rows)),
      status = rep("fired", length(fired_rows)),
      dataset = rep(ds_name, length(fired_rows)),
      variable = rep(var_display, length(fired_rows)),
      row = as.integer(fired_rows),
      value = val,
      expected = rep(NA_character_, length(fired_rows)),
      message = rep(msg_txt, length(fired_rows)),
      source_url = rep(
        rule[["source_url"]] %||% NA_character_,
        length(fired_rows)
      ),
      p21_id_equivalent = rep(
        rule[["p21_id_equivalent"]] %||% NA_character_,
        length(fired_rows)
      ),
      license = rep(rule[["license"]] %||% NA_character_, length(fired_rows))
    )
  }

  if (adv_once) {
    adv <- tibble::tibble(
      rule_id = rule[["id"]] %||% NA_character_,
      authority = rule[["authority"]] %||% NA_character_,
      standard = rule[["standard"]] %||% NA_character_,
      severity = rule[["severity"]] %||% "Medium",
      severity_override = NA_character_,
      status = "advisory",
      dataset = ds_name,
      variable = if (length(var_txt) > 1L) {
        paste(var_txt, collapse = ",")
      } else {
        var_txt
      },
      row = NA_integer_,
      value = NA_character_,
      expected = NA_character_,
      message = msg_txt,
      source_url = rule[["source_url"]] %||% NA_character_,
      p21_id_equivalent = rule[["p21_id_equivalent"]] %||% NA_character_,
      license = rule[["license"]] %||% NA_character_
    )
    out <- rbind(out, adv)
  }
  out
}

# -----------------------------------------------------------------------------
# Submission-level findings
# -----------------------------------------------------------------------------
# Some rules live above the dataset layer (e.g. "ADSL dataset does not
# exist"). These emit a single finding with dataset = "<submission>"
# and row = NA so that reviewers see a first-class entry rather than a
# silent rule-disable.

#' Sentinel dataset name for submission-level findings.
#' @noRd
.SUBMISSION_DATASET <- "<submission>"

#' Emit a single submission-level finding.
#'
#' @param rule Single-row slice of rules.rds or equivalent named list.
#' @param status One of `"fired"` or `"advisory"`. Defaults to `"fired"`.
#' @param message Optional override; defaults to `rule$message`.
#' @param severity Optional override; defaults to `rule$severity`.
#' @param variable Optional variable attribution (e.g. the dataset name
#'   that is missing); passed through to the `variable` column.
#' @param value Optional `value` column content.
#'
#' @return A one-row tibble matching `empty_findings()`.
#' @noRd
emit_submission_finding <- function(
  rule,
  status = "fired",
  message = NULL,
  severity = NULL,
  variable = NA_character_,
  value = NA_character_
) {
  if (!status %in% c("fired", "advisory")) {
    herald_error_runtime(
      "{.arg status} must be one of {.val fired} or {.val advisory}."
    )
  }
  tibble::tibble(
    rule_id = rule[["id"]] %||% NA_character_,
    authority = rule[["authority"]] %||% NA_character_,
    standard = rule[["standard"]] %||% NA_character_,
    severity = severity %||% rule[["severity"]] %||% "Medium",
    severity_override = NA_character_,
    status = status,
    dataset = .SUBMISSION_DATASET,
    variable = variable,
    row = NA_integer_,
    value = value,
    expected = NA_character_,
    message = message %||% rule[["message"]] %||% NA_character_,
    source_url = rule[["source_url"]] %||% NA_character_,
    p21_id_equivalent = rule[["p21_id_equivalent"]] %||% NA_character_,
    license = rule[["license"]] %||% NA_character_
  )
}

#' Peek at a check_tree and guess the primary variable for finding attribution
#'
#' Walks the tree looking for the first leaf with a `name` field. Returns
#' NA if the tree has no attributable variable (e.g. pure combinators or
#' narrative-only).
#' @noRd
primary_variable <- function(node) {
  if (is.null(node) || length(node) == 0L) {
    return(NA_character_)
  }
  if (!is.null(node[["name"]])) {
    return(as.character(node[["name"]]))
  }
  for (key in c("all", "any")) {
    children <- node[[key]]
    if (!is.null(children) && length(children) > 0L) {
      for (child in children) {
        v <- primary_variable(child)
        if (!is.na(v)) return(v)
      }
    }
  }
  if (!is.null(node[["not"]])) {
    return(primary_variable(node[["not"]]))
  }
  NA_character_
}
