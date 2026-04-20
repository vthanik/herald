#!/usr/bin/env Rscript
# =============================================================================
# tools/harvest-cdisc-library.R
#
# Fetches CDISC conformance rules from the CDISC Library REST API and writes
# them as YAML under tools/handauthored/cdisc/<standard>-library-api/.
#
# These YAMLs are the MACHINE-EXECUTABLE form of CDISC conformance rules
# (operator trees in the Check block) and complement the narrative-only
# XLSX harvest in tools/parse-conformance-xlsx.R.
#
# Usage:
#   Rscript tools/harvest-cdisc-library.R                 # All catalogs
#   Rscript tools/harvest-cdisc-library.R --dry-run
#   Rscript tools/harvest-cdisc-library.R --catalog sdtmig/3-4
#   Rscript tools/harvest-cdisc-library.R --force         # Overwrite YAMLs
#   Rscript tools/harvest-cdisc-library.R --verbose
#
# API key:
#   CDISC_LIBRARY_KEY env var
#   or  .local/.env  containing  CDISC_LIBRARY_KEY=...
#   or  --api-key <key>
#
# Outputs:
#   tools/handauthored/cdisc/sdtm-library-api/<CORE-ID>.yaml
#   tools/handauthored/cdisc/adam-library-api/<CORE-ID>.yaml
#   tools/harvest-cache/<catalog>.json   (raw API response, gitignored)
# =============================================================================

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0L || all(is.na(a))) b else a
}

args     <- commandArgs(trailingOnly = TRUE)
dry_run  <- "--dry-run" %in% args
force    <- "--force"   %in% args
verbose  <- "--verbose" %in% args

catalog_filter <- NULL
if ("--catalog" %in% args) {
  idx <- match("--catalog", args)
  if (!is.na(idx) && idx < length(args)) catalog_filter <- args[idx + 1L]
}

api_key_arg <- NULL
if ("--api-key" %in% args) {
  idx <- match("--api-key", args)
  if (!is.na(idx) && idx < length(args)) api_key_arg <- args[idx + 1L]
}

# ---- repository layout ----------------------------------------------------

repo_root <- getwd()
if (!dir.exists(file.path(repo_root, "tools", "handauthored"))) {
  stop(
    "Run this from the package root (where tools/handauthored/ exists). ",
    "getwd() = ", repo_root,
    call. = FALSE
  )
}

sdtm_out <- file.path(repo_root, "tools", "handauthored", "cdisc", "sdtm-library-api")
adam_out <- file.path(repo_root, "tools", "handauthored", "cdisc", "adam-library-api")
cache    <- file.path(repo_root, "tools", "harvest-cache")
env_file <- file.path(repo_root, ".local", ".env")

dir.create(sdtm_out, showWarnings = FALSE, recursive = TRUE)
dir.create(adam_out, showWarnings = FALSE, recursive = TRUE)
dir.create(cache,    showWarnings = FALSE, recursive = TRUE)

for (pkg in c("jsonlite", "yaml")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' required: install.packages('%s')", pkg, pkg),
         call. = FALSE)
  }
}

# ---- API key resolution ---------------------------------------------------

get_api_key <- function() {
  if (!is.null(api_key_arg) && nzchar(api_key_arg)) return(api_key_arg)
  key <- Sys.getenv("CDISC_LIBRARY_KEY", unset = "")
  if (nzchar(key)) return(key)
  # Legacy var name support
  key <- Sys.getenv("CDISC_API_KEY", unset = "")
  if (nzchar(key)) return(key)
  if (file.exists(env_file)) {
    lines <- readLines(env_file, warn = FALSE)
    for (pattern in c("^CDISC_LIBRARY_KEY=", "^CDISC_API_KEY=")) {
      hit <- grep(pattern, lines, value = TRUE)
      if (length(hit) > 0L) return(sub(pattern, "", trimws(hit[1])))
    }
  }
  stop(
    "CDISC Library API key not found.\n",
    "  Set env:  export CDISC_LIBRARY_KEY=...\n",
    "  Or put it in .local/.env as  CDISC_LIBRARY_KEY=...\n",
    "  Or pass --api-key <KEY>.\n",
    "Request a free non-commercial key at:\n",
    "  https://api.developer.library.cdisc.org/",
    call. = FALSE
  )
}

# ---- catalog configuration ------------------------------------------------

CATALOGS <- list(
  list(path = "/mdr/rules/sdtmig/3-2", name = "SDTMIG 3.2", standard = "SDTM", version = "3.2"),
  list(path = "/mdr/rules/sdtmig/3-3", name = "SDTMIG 3.3", standard = "SDTM", version = "3.3"),
  list(path = "/mdr/rules/sdtmig/3-4", name = "SDTMIG 3.4", standard = "SDTM", version = "3.4"),
  list(path = "/mdr/rules/adam/adamig-1-1", name = "ADaMIG 1.1", standard = "ADaM", version = "1.1"),
  list(path = "/mdr/rules/adam/adamig-1-2", name = "ADaMIG 1.2", standard = "ADaM", version = "1.2"),
  list(path = "/mdr/rules/adam/adamig-1-3", name = "ADaMIG 1.3", standard = "ADaM", version = "1.3")
)

if (!is.null(catalog_filter)) {
  CATALOGS <- Filter(
    function(c) grepl(catalog_filter, c$path, ignore.case = TRUE),
    CATALOGS
  )
  if (length(CATALOGS) == 0L) {
    stop(sprintf("No catalog matches '%s'", catalog_filter), call. = FALSE)
  }
}

# ---- HTTP fetch -----------------------------------------------------------

BASE_URL <- "https://library.cdisc.org/api"

fetch_json <- function(path, api_key) {
  url <- paste0(BASE_URL, path)
  if (verbose) cat(sprintf("  GET %s\n", path))
  con <- url(url, headers = c("api-key" = api_key, "Accept" = "application/json"))
  on.exit(close(con))
  raw <- readLines(con, warn = FALSE)
  jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = FALSE)
}

# ---- harvest pipeline -----------------------------------------------------

cat("===== CDISC Library Conformance Rules harvest =====\n\n")
api_key <- get_api_key()

all_rules     <- list()   # keyed by CORE Id
rule_catalogs <- list()   # CORE Id -> list of catalog names it appeared in
rule_standards <- list()  # CORE Id -> "SDTM" or "ADaM"

for (cc in CATALOGS) {
  cat(sprintf("Fetching %s ...", cc$name))

  cache_file <- file.path(
    cache,
    sprintf("%s-%s.json", cc$standard, cc$version)
  )

  if (file.exists(cache_file) && !force) {
    cat(" (cached)")
    data <- jsonlite::fromJSON(
      readLines(cache_file, warn = FALSE),
      simplifyVector = FALSE
    )
  } else {
    data <- tryCatch(
      fetch_json(cc$path, api_key),
      error = function(e) {
        cat(sprintf(" ERROR: %s\n", conditionMessage(e)))
        NULL
      }
    )
    if (is.null(data)) next
    if (!dry_run) {
      writeLines(
        jsonlite::toJSON(data, auto_unbox = TRUE, pretty = TRUE),
        cache_file
      )
    }
  }

  rules <- data$rules %||% list()
  if (identical(rules, list())) {
    cat(sprintf(" 0 rules (API returned empty; use tools/parse-conformance-xlsx.R for %s)\n",
                cc$standard))
  } else {
    cat(sprintf(" %d rules\n", length(rules)))
  }

  for (rule in rules) {
    core_id <- rule$Core$Id %||% ""
    if (!nzchar(core_id)) next

    rule_catalogs[[core_id]]  <- c(rule_catalogs[[core_id]], cc$name)
    rule_standards[[core_id]] <- cc$standard

    existing <- all_rules[[core_id]]
    if (is.null(existing)) {
      all_rules[[core_id]] <- rule
    } else {
      n_new <- length(rule$Authorities[[1]]$Standards %||% list())
      n_old <- length(existing$Authorities[[1]]$Standards %||% list())
      if (n_new > n_old) all_rules[[core_id]] <- rule
    }
  }
}

cat(sprintf("\nUnique rules after catalog-dedup: %d\n\n", length(all_rules)))

# ---- write YAMLs ----------------------------------------------------------

cat("Writing YAMLs ...\n")

written <- 0L
skipped <- 0L

for (core_id in names(all_rules)) {
  rule <- all_rules[[core_id]]
  rule[["_links"]] <- NULL
  rule[["id"]]     <- NULL

  rule[["herald"]] <- list(
    source   = "CDISC Library API",
    catalogs = as.list(rule_catalogs[[core_id]]),
    fetched  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )

  std <- rule_standards[[core_id]]
  out_dir <- if (identical(std, "ADaM")) adam_out else sdtm_out
  fpath <- file.path(out_dir, paste0(core_id, ".yaml"))

  if (file.exists(fpath) && !force) {
    skipped <- skipped + 1L
    next
  }

  if (dry_run) {
    cat(sprintf("  [DRY RUN] %s (%s): %s\n",
                core_id, std,
                substr(rule$Description %||% "", 1, 60)))
    written <- written + 1L
    next
  }

  yaml_str <- yaml::as.yaml(rule, indent.mapping.sequence = TRUE)
  writeLines(yaml_str, fpath, useBytes = TRUE)
  written <- written + 1L
}

# ---- summary --------------------------------------------------------------

cat("\n===== summary =====\n")
cat(sprintf("  catalogs fetched: %d\n", length(CATALOGS)))
cat(sprintf("  unique rules:     %d\n", length(all_rules)))
cat(sprintf("  YAMLs written:    %d\n", written))
cat(sprintf("  YAMLs skipped:    %d  (use --force to overwrite)\n", skipped))
cat(sprintf("  SDTM rules:       %d\n",
            sum(vapply(rule_standards, function(s) identical(s, "SDTM"), logical(1)))))
cat(sprintf("  ADaM rules:       %d\n",
            sum(vapply(rule_standards, function(s) identical(s, "ADaM"), logical(1)))))
cat(sprintf("  outputs:          tools/handauthored/cdisc/{sdtm,adam}-library-api/\n"))
cat(sprintf("  cache:            tools/harvest-cache/  (gitignored)\n"))

if (dry_run) cat("\n  [DRY RUN] no YAMLs were actually written.\n")
cat("\nDone.\n")
