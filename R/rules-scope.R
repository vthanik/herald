# -----------------------------------------------------------------------------
# rules-scope.R — which datasets a rule applies to
# -----------------------------------------------------------------------------
# Ported from herald-v0/R/execute.R::scoped_datasets with small cleanups.
# Three filters applied in order:
#   1. Standard-based exclusion: SDTM rules never fire against ADaM datasets
#      (ADSL/BDS/OCCDS/TTE/ADAM-OTHER or name prefix AD*), EXCEPT when the
#      rule has empty scope (a structural rule that applies universally) or
#      it is a Controlled Terminology rule.
#   2. Domain match: scope$domains contains the dataset name, OR contains
#      the dataset's class. "ALL" is a wildcard.
#   3. Class match: scope$classes normalised (BDS/OCCDS/ADSL/TTE long <->
#      short forms) against the dataset's class.
#
# Rules with an entirely empty scope run against every loaded dataset.

#' Return dataset names this rule applies to
#'
#' @param rule a herald rule row (list or 1-row tibble slice)
#' @param ctx  a herald_ctx env carrying `datasets` (named list of data frames)
#'             and `spec` (optional herald_spec S3 for class lookup)
#' @return character vector of dataset names (subset of names(ctx$datasets))
#' @noRd
scoped_datasets <- function(rule, ctx) {
  all_ds <- names(ctx$datasets %||% list())
  if (length(all_ds) == 0L) return(character())

  scope <- rule[["scope"]]
  if (is.null(scope) || length(scope) == 0L) {
    scope <- list(
      domains = rule[["domains"]] %||% list(),
      classes = rule[["classes"]] %||% list()
    )
  }
  norm_rule <- rule
  norm_rule$scope <- scope

  keep <- vapply(all_ds, function(ds_name) {
    ds_class <- .ds_class(ds_name, ctx)
    .rule_scope_matches_ctx(norm_rule, ds_name, ds_class)
  }, logical(1L))
  all_ds[keep]
}

# --- internals ---------------------------------------------------------------

.ds_class <- function(ds_name, ctx) {
  # Cascade: caller-supplied spec -> static dataset->class lookup ->
  # topic-variable prototype inference. Mirrors Pinnacle 21's runtime
  # class determination (ConfigurationManager.prepare / Template.matches
  # in their Java source): user config wins, then named-config match,
  # then prototype matching against column names.
  d <- ctx$datasets[[ds_name]]
  cols <- if (is.data.frame(d)) names(d) else character()
  infer_class(ds_name, cols, spec = ctx$spec)
}

.rule_scope_matches_ctx <- function(rule, ds_name, ds_class = NULL) {
  rule_std <- toupper(rule[["standard"]] %||% "")
  ds_up    <- toupper(ds_name)
  is_adam_name  <- grepl("^AD[A-Z]", ds_up)
  adam_classes <- c(
    "ADSL", "BDS", "OCCDS", "TTE", "ADAM OTHER",
    "SUBJECT LEVEL ANALYSIS DATASET",
    "BASIC DATA STRUCTURE",
    "OCCURRENCE DATA STRUCTURE",
    "TIME-TO-EVENT"
  )
  is_adam_class <- !is.null(ds_class) && !is.na(ds_class) &&
    nzchar(ds_class) &&
    (toupper(ds_class) %in% toupper(adam_classes) ||
       startsWith(toupper(ds_class), "AD"))
  is_adam_dataset <- is_adam_name || is_adam_class

  # SDTM / SEND rules do NOT fire against ADaM datasets (unless they have
  # entirely empty scope -- structural rules that apply universally -- or
  # they are Controlled Terminology rules).
  if (identical(rule_std, "SDTM") || identical(rule_std, "SDTM-IG") ||
      identical(rule_std, "SEND") || identical(rule_std, "SEND-IG")) {
    is_ct <- grepl("^HRL-CT-|^CT[0-9]", rule[["id"]] %||% rule[["rule_id"]] %||% "")
    if (!is_ct) {
      scope0 <- rule[["scope"]]
      has_sdtm_scope <- !is.null(scope0) &&
        (length(scope0[["domains"]]) > 0L || length(scope0[["classes"]]) > 0L)
      if (has_sdtm_scope && is_adam_dataset) return(FALSE)
    }
  }

  # Symmetric: ADaM-IG rules do NOT fire against SDTM / SEND datasets.
  if (identical(rule_std, "ADAM") || identical(rule_std, "ADAM-IG") ||
      identical(rule_std, "ADaM") || identical(rule_std, "ADaM-IG")) {
    if (!is_adam_dataset) return(FALSE)
  }

  scope <- rule[["scope"]]
  if (is.null(scope) || length(scope) == 0L) return(TRUE)

  ds_up <- toupper(ds_name)

  # Exclude-domains: if the dataset is listed here, rule does NOT apply.
  exclude <- scope[["exclude_domains"]]
  if (!is.null(exclude) && length(exclude) > 0L) {
    excl_up <- toupper(as.character(unlist(exclude)))
    if (ds_up %in% excl_up) return(FALSE)
  }

  # Domain match
  domains <- scope[["domains"]]
  if (!is.null(domains) && length(domains) > 0L) {
    dom_up <- toupper(as.character(unlist(domains)))
    if ("ALL" %in% dom_up) {
      # Fall through to class check (ALL means "all domains in class scope")
    } else {
      domain_ok <- ds_up %in% dom_up
      class_ok  <- !is.null(ds_class) && !is.na(ds_class) &&
        toupper(ds_class) %in% dom_up
      if (!domain_ok && !class_ok) return(FALSE)
    }
  }

  # Class match (with ADaM long <-> short form normalisation)
  classes <- scope[["classes"]]
  if (!is.null(classes) && length(classes) > 0L) {
    # If the rule requires specific classes but we don't know this dataset's
    # class (no spec supplied), fail-safe: do NOT apply the rule. Prevents
    # SDTM EVENTS-class rules from firing against every dataset.
    if (is.null(ds_class) || is.na(ds_class) || !nzchar(ds_class)) {
      cls_up <- toupper(as.character(unlist(classes)))
      if ("ALL" %in% cls_up) return(TRUE)
      return(FALSE)
    }
    adam_long <- c(
      "ADSL"  = "SUBJECT LEVEL ANALYSIS DATASET",
      "BDS"   = "BASIC DATA STRUCTURE",
      "OCCDS" = "OCCURRENCE DATA STRUCTURE",
      "TTE"   = "TIME-TO-EVENT"
    )
    norm <- function(x) {
      up  <- toupper(trimws(x))
      exp <- adam_long[up]
      ifelse(is.na(exp), up, exp)
    }
    ds_norm  <- norm(ds_class)
    cls_norm <- norm(as.character(unlist(classes)))
    if ("ALL" %in% cls_norm) return(TRUE)
    if (!any(ds_norm == cls_norm)) return(FALSE)
  }

  TRUE
}
