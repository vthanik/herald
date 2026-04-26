# --------------------------------------------------------------------------
# dict-provider.R -- the herald Dictionary Provider Protocol
# --------------------------------------------------------------------------
# A Dictionary Provider is any plug-in that answers "does this value
# exist in this codelist / registry / hierarchy?". CDISC CT, FDA SRS,
# MedDRA, WhoDrug, LOINC, SNOMED, and sponsor-private codelists all
# surface through the same interface so rule ops don't need to know
# (or care) about provenance.
#
# Plan file: /Users/vignesh/.claude/plans/cached-nibbling-penguin.md
#
# Minimum provider contract:
#
#   provider$name                   chr  canonical short name
#   provider$version                chr  provider-reported version
#   provider$source                 chr  bundled|cache|user-file|remote|sponsor
#   provider$license                chr  informational only
#   provider$license_note           chr  human-readable license summary
#   provider$size_rows              int  number of term rows
#   provider$fields                 chr  supported query-field names
#   provider$contains(value, field, ignore_case)  -> logical vector
#   provider$info()                 -> named list of the fields above
#
# Optional:
#   provider$lookup(value, field)   -> one-row-per-value list / tibble
#
# Providers are INSTANTIATED by factory functions in:
#   R/dict-providers-ct.R   ct_provider(package, version)
#   R/dict-providers-srs.R  srs_provider(version)
#   R/dict-providers-ext.R  meddra_provider, whodrug_provider, ...
#
# REGISTRATION + RESOLUTION
#
# Per-validate() registry lives on `ctx$dict` (rules-validate.R).
# A global session-level registry (.HERALD_DICT_REGISTRY) allows
# sponsors to install once per session and have every validate() call
# pick up their dictionaries automatically.
#
# Resolution precedence at validate() entry:
#   1. dictionaries = list(...) arg on validate()       (explicit)
#   2. .HERALD_DICT_REGISTRY                            (session)
#   3. auto-discovered from tools::R_user_dir cache     (e.g. srs,
#                                                        cache-tagged CT)
#   4. auto-discovered from inst/rules/ct/ bundle       (CDISC CT)
#   5. Missing -> op records ctx$missing_refs entry, returns NA mask.

# --------------------------------------------------------------------------
# Session-level registry
# --------------------------------------------------------------------------

#' @noRd
.HERALD_DICT_REGISTRY <- new.env(parent = emptyenv())

#' Install a dictionary provider in the session registry
#'
#' @description
#' After this call every subsequent `validate()` picks up `provider`
#' automatically under `name` unless explicitly overridden by the
#' `dictionaries=` argument.
#'
#' @param name Character scalar -- canonical short name (e.g. `"meddra"`,
#'   `"whodrug"`, `"srs"`, `"sponsor-race"`).
#' @param provider A `herald_dict_provider` (from one of the factories:
#'   [ct_provider()], [srs_provider()], [meddra_provider()], ...).
#' @return `invisible(provider)`.
#'
#' @examples
#' # Register bundled SDTM CT and inspect the registry
#' p <- ct_provider("sdtm")
#' register_dictionary("sdtm", p)
#' list_dictionaries()
#'
#' # Register a custom sponsor-private dictionary
#' codes <- data.frame(site = c("S01", "S02", "S03"), stringsAsFactors = FALSE)
#' sponsor_p <- custom_provider(codes, name = "site-codes", fields = "site")
#' register_dictionary("site-codes", sponsor_p)
#' list_dictionaries()
#'
#' # Clean up
#' unregister_dictionary("sdtm")
#' unregister_dictionary("site-codes")
#'
#' @family dict
#' @export
register_dictionary <- function(name, provider) {
  call <- rlang::caller_env()
  check_scalar_chr(name, call = call)
  if (!inherits(provider, "herald_dict_provider")) {
    herald_error(
      "{.arg provider} must be a {.cls herald_dict_provider} \\
       (use ct_provider(), srs_provider(), meddra_provider(), etc.).",
      class = "herald_error_input",
      call = call
    )
  }
  assign(name, provider, envir = .HERALD_DICT_REGISTRY)
  invisible(provider)
}

#' Remove a dictionary from the session registry
#'
#' @param name Character scalar.
#' @return `invisible(TRUE)` if removed, `FALSE` if not registered.
#'
#' @examples
#' p <- ct_provider("sdtm")
#' register_dictionary("sdtm", p)
#' unregister_dictionary("sdtm")    # returns TRUE
#' unregister_dictionary("sdtm")    # already gone -- returns FALSE
#'
#' @family dict
#' @export
unregister_dictionary <- function(name) {
  call <- rlang::caller_env()
  check_scalar_chr(name, call = call)
  if (!exists(name, envir = .HERALD_DICT_REGISTRY, inherits = FALSE)) {
    return(invisible(FALSE))
  }
  rm(list = name, envir = .HERALD_DICT_REGISTRY)
  invisible(TRUE)
}

#' List known dictionaries
#'
#' @description
#' Enumerates everything herald can see: session-registered
#' dictionaries, cache-discoverable dictionaries, and the bundled
#' CDISC CT. Used for reporting and debugging.
#'
#' @param include_global Include the session registry. Default TRUE.
#' @param include_cache Scan the user cache. Default TRUE.
#' @return A tibble with columns `name`, `version`, `source`,
#'   `license`, `size_rows`.
#'
#' @examples
#' # No providers registered yet -- returns empty tibble
#' list_dictionaries()
#'
#' # Register SDTM CT, then list
#' p <- ct_provider("sdtm")
#' register_dictionary("sdtm", p)
#' list_dictionaries()
#' unregister_dictionary("sdtm")
#'
#' # Session registry only (skip cache scan)
#' list_dictionaries(include_global = TRUE, include_cache = FALSE)
#'
#' @family dict
#' @export
list_dictionaries <- function(include_global = TRUE, include_cache = TRUE) {
  rows <- list()
  if (isTRUE(include_global)) {
    for (nm in ls(envir = .HERALD_DICT_REGISTRY)) {
      p <- get(nm, envir = .HERALD_DICT_REGISTRY, inherits = FALSE)
      rows[[length(rows) + 1L]] <- .provider_info_row(nm, p)
    }
  }
  if (isTRUE(include_cache)) {
    # Cache scanning is deferred to per-source helpers; bundled CT is
    # always addressable via ct_provider() at resolve time. Each
    # provider factory can auto-register a cache hit when called.
    # For now the registry is the source of truth for `list`.
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      name = character(),
      version = character(),
      source = character(),
      license = character(),
      size_rows = integer()
    ))
  }
  tibble::as_tibble(do.call(rbind, rows))
}

#' @noRd
.provider_info_row <- function(name, p) {
  info <- tryCatch(p$info(), error = function(e) list())
  data.frame(
    name = name,
    version = as.character(info$version %||% NA_character_),
    source = as.character(info$source %||% NA_character_),
    license = as.character(info$license %||% NA_character_),
    size_rows = as.integer(info$size_rows %||% NA_integer_),
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# Core constructor
# --------------------------------------------------------------------------

#' Construct a dictionary-provider object
#'
#' @description
#' Low-level constructor used by every provider factory. Validates the
#' required fields, sets the S3 class, and returns the object. Factory
#' authors should prefer this over hand-assembling a list so the
#' contract stays stable.
#'
#' @param name,version,source,license,license_note,size_rows,fields
#'   Metadata fields.
#' @param contains Function `(value, field, ignore_case) -> logical`.
#' @param info Function `() -> list`. Defaults to a closure returning
#'   the metadata fields above.
#' @param lookup Optional function `(value, field) -> list`.
#'
#' @return An object of class `c("herald_dict_provider", "list")`.
#'
#' @examples
#' # ---- Minimal provider: name + contains function ----------------------
#' p1 <- new_dict_provider(
#'   name     = "my-codes",
#'   contains = function(value, field = "code", ignore_case = FALSE) {
#'     value %in% c("A", "B", "C")
#'   },
#'   fields   = "code",
#'   size_rows = 3L
#' )
#' p1$contains(c("A", "D"))        # TRUE FALSE
#' p1$info()$name                   # "my-codes"
#'
#' # ---- With version, source, and license metadata ----------------------
#' p2 <- new_dict_provider(
#'   name     = "sponsor-sex",
#'   version  = "2026-01",
#'   source   = "sponsor",
#'   license  = "sponsor-private",
#'   contains = function(value, field = "code", ignore_case = FALSE) {
#'     value %in% c("M", "F", "U")
#'   },
#'   fields    = "code",
#'   size_rows = 3L
#' )
#' p2$info()$version
#'
#' # ---- With optional lookup function (returns matching rows) -----------
#' ref <- data.frame(
#'   code  = c("M", "F"),
#'   label = c("Male", "Female"),
#'   stringsAsFactors = FALSE
#' )
#' p3 <- new_dict_provider(
#'   name     = "sex-codes",
#'   contains = function(value, field = "code", ignore_case = FALSE) {
#'     value %in% ref$code
#'   },
#'   lookup   = function(value, field = "code") {
#'     ref[ref$code %in% value, , drop = FALSE]
#'   },
#'   fields    = "code",
#'   size_rows = nrow(ref)
#' )
#' p3$lookup("M")
#'
#' # ---- Register and use in validate() ----------------------------------
#' register_dictionary("sex-codes", p3)
#' list_dictionaries()
#' unregister_dictionary("sex-codes")
#'
#' @family dict
#' @export
new_dict_provider <- function(
  name,
  version = NA_character_,
  source = "unknown",
  license = "unknown",
  license_note = "",
  size_rows = NA_integer_,
  fields = character(),
  contains,
  info = NULL,
  lookup = NULL
) {
  call <- rlang::caller_env()
  check_scalar_chr(name, call = call)
  if (!is.function(contains)) {
    herald_error(
      "{.arg contains} must be a function.",
      class = "herald_error_input",
      call = call
    )
  }
  meta <- list(
    name = name,
    version = as.character(version),
    source = as.character(source),
    license = as.character(license),
    license_note = as.character(license_note),
    size_rows = as.integer(size_rows),
    fields = as.character(fields)
  )
  info_fn <- if (is.function(info)) info else function() meta
  structure(
    c(meta, list(contains = contains, info = info_fn, lookup = lookup)),
    class = c("herald_dict_provider", "list")
  )
}

#' Print a herald_dict_provider
#' @param x A `herald_dict_provider` object.
#' @param ... Ignored.
#' @return `x` invisibly.
#' @export
print.herald_dict_provider <- function(x, ...) {
  i <- tryCatch(x$info(), error = function(e) list())
  cat("<herald_dict_provider>\n")
  cat(sprintf("  name     : %s\n", i$name %||% "<unnamed>"))
  cat(sprintf("  version  : %s\n", i$version %||% NA))
  cat(sprintf("  source   : %s\n", i$source %||% NA))
  cat(sprintf("  license  : %s\n", i$license %||% NA))
  cat(sprintf(
    "  size     : %s rows\n",
    format(i$size_rows %||% NA, big.mark = ",")
  ))
  if (length(i$fields %||% character()) > 0L) {
    cat(sprintf("  fields   : %s\n", paste(i$fields, collapse = ", ")))
  }
  invisible(x)
}

# --------------------------------------------------------------------------
# Per-run registry population + resolution
# --------------------------------------------------------------------------

#' Populate `ctx$dict` from validate()'s `dictionaries =` arg + global
#' registry. Called once at validate() entry.
#' @noRd
.populate_dict_registry <- function(ctx, dictionaries = NULL, call) {
  ctx$dict <- list()

  # Layer 2: session registry
  for (nm in ls(envir = .HERALD_DICT_REGISTRY)) {
    ctx$dict[[nm]] <- get(nm, envir = .HERALD_DICT_REGISTRY, inherits = FALSE)
  }

  # Layer 1: explicit per-validate override (wins)
  if (!is.null(dictionaries)) {
    if (!is.list(dictionaries) || is.null(names(dictionaries))) {
      herald_error(
        "{.arg dictionaries} must be a named list of herald_dict_provider \\
         objects.",
        class = "herald_error_input",
        call = call
      )
    }
    for (nm in names(dictionaries)) {
      p <- dictionaries[[nm]]
      if (!inherits(p, "herald_dict_provider")) {
        herald_error(
          "Entry {.val {nm}} in {.arg dictionaries} must be a \\
           {.cls herald_dict_provider}.",
          class = "herald_error_input",
          call = call
        )
      }
      ctx$dict[[nm]] <- p
    }
  }

  invisible(ctx)
}

#' Resolve a dictionary by name from the per-run registry. Lazy
#' cache-discovery hook reserved for Phase 3+ when srs / other
#' factories learn to auto-register from the user cache.
#' @noRd
.resolve_provider <- function(ctx, name) {
  if (is.null(ctx) || is.null(ctx$dict)) {
    return(NULL)
  }
  p <- ctx$dict[[name]]
  if (inherits(p, "herald_dict_provider")) {
    return(p)
  }
  NULL
}

# --------------------------------------------------------------------------
# Missing-ref tracking (Q33 integration)
# --------------------------------------------------------------------------

#' Initialise the missing-ref tracker on ctx.
#' @noRd
.init_missing_refs <- function(ctx) {
  ctx$missing_refs <- list(datasets = list(), dictionaries = list())
  invisible(ctx)
}

#' Record a missing reference (dataset or dictionary) attributed to a
#' specific rule. The same (kind, name) can collect many rule_ids.
#'
#' @param ctx        Herald context env.
#' @param rule_id    Character scalar; rule that hit the missing ref.
#' @param kind       "dataset" or "dictionary".
#' @param name       Name of the missing reference.
#' @noRd
.record_missing_ref <- function(ctx, rule_id, kind, name) {
  if (is.null(ctx)) {
    return(invisible(NULL))
  }
  if (is.null(ctx$missing_refs)) {
    .init_missing_refs(ctx)
  }
  kind <- match.arg(kind, c("dataset", "dictionary", "define"))
  slot <- switch(
    kind,
    "dataset" = "datasets",
    "dictionary" = "dictionaries",
    "define" = "dictionaries"
  )
  nm <- as.character(name)
  rid <- as.character(rule_id %||% NA_character_)
  prev <- ctx$missing_refs[[slot]][[nm]]
  ctx$missing_refs[[slot]][[nm]] <- unique(c(prev, rid))
  invisible(NULL)
}

#' Post-process the missing-ref collection into the reviewer-facing
#' `result$skipped_refs` structure. Called at the end of validate().
#' Produces one entry per (kind, name) with a hint string that tells
#' the user exactly what to provide to unlock the rule(s).
#' @noRd
.finalize_skipped_refs <- function(ctx) {
  mr <- ctx$missing_refs %||% list(datasets = list(), dictionaries = list())

  hint_for <- function(kind, name) {
    switch(
      kind,
      "dataset" = sprintf(
        "Provide dataset %s to evaluate these rules.",
        name
      ),
      "dictionary" = switch(
        name,
        "srs" = "Run `herald::download_srs()` to populate the FDA SRS cache.",
        "meddra" = sprintf(
          "Register with `register_dictionary(\"meddra\", meddra_provider(\"<path>\"))`."
        ),
        "whodrug" = sprintf(
          "Register with `register_dictionary(\"whodrug\", whodrug_provider(\"<path>\"))`."
        ),
        "define.xml" = paste0(
          "Provide define.xml via `validate(..., define = read_define_xml(\"define.xml\"))`",
          " to enable sponsor key-uniqueness checks."
        ),
        sprintf(
          "Register the %s dictionary via `register_dictionary(\"%s\", <provider>)`.",
          name,
          name
        )
      )
    )
  }

  build <- function(slot_name, kind) {
    entries <- mr[[slot_name]]
    if (length(entries) == 0L) {
      return(list())
    }
    out <- list()
    for (nm in names(entries)) {
      out[[nm]] <- list(
        kind = kind,
        rule_ids = sort(unique(entries[[nm]])),
        hint = hint_for(kind, nm)
      )
    }
    out
  }

  list(
    datasets = build("datasets", "dataset"),
    dictionaries = build("dictionaries", "dictionary")
  )
}
