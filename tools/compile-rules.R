# tools/compile-rules.R
# Compile tools/handauthored/**/*.yaml into inst/rules/rules.rds + rules.jsonl
# + MANIFEST.json. The ONLY path rule content gets into the installed package.
#
# Run:  Rscript tools/compile-rules.R
#
# Never runs in R CMD check (network-free but also slow-ish; keep for manual).

library(yaml)
library(jsonlite)
library(digest)

project_root <- getwd()
if (!dir.exists(file.path(project_root, "tools", "handauthored"))) {
  stop(
    "Run tools/compile-rules.R from the package root ",
    "(where tools/handauthored/ exists). getwd() = ",
    project_root
  )
}

author_root <- file.path(project_root, "tools", "handauthored")
out_dir     <- file.path(project_root, "inst", "rules")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- canonical row builder -------------------------------------------------

normalize_standard <- function(raw) {
  raw <- toupper(raw %||% "")
  switch(
    raw,
    "SDTMIG"   = "SDTM-IG",
    "SDTM"     = "SDTM-IG",
    "ADAMIG"   = "ADaM-IG",
    "ADAM"     = "ADaM-IG",
    "SENDIG"   = "SEND-IG",
    "SEND"     = "SEND-IG",
    "DEFINE-XML" = "Define-XML",
    "CT"       = "CT",
    raw
  )
}

normalize_severity <- function(x) {
  if (is.null(x) || !nzchar(x)) return("Medium")
  x <- tolower(x)
  if (x %in% c("reject", "fatal")) "Reject"
  else if (x %in% c("error", "high")) "High"
  else if (x %in% c("warning", "medium")) "Medium"
  else if (x %in% c("info", "low", "notice")) "Low"
  else "Medium"
}

hash_tree <- function(tree) {
  digest::digest(tree, algo = "sha256", serialize = TRUE)
}

row_from_core_yaml <- function(yml, path) {
  # CORE schema: PascalCase
  auth_block <- yml$Authorities[[1]] %||% list()
  std_block  <- auth_block$Standards[[1]] %||% list()
  ref_block  <- std_block$References[[1]] %||% list()
  cite_block <- ref_block$Citations[[1]] %||% list()

  id        <- yml$Core$Id %||% tools::file_path_sans_ext(basename(path))
  authority <- auth_block$Organization %||% "CDISC"
  standard  <- normalize_standard(std_block$Name)
  std_ver   <- std_block$Version %||% NA_character_
  severity  <- normalize_severity(yml$Sensitivity)
  message   <- yml$Outcome$Message %||% yml$Description %||% ""
  scope <- list(
    classes = yml$Scope$Classes$Include %||% character(0),
    domains = yml$Scope$Domains$Include %||% character(0),
    exclude_domains = yml$Scope$Domains$Exclude %||% character(0)
  )
  check_tree <- yml$Check

  fetched <- yml$herald$fetched %||% NA_character_
  fetched_at <- suppressWarnings(as.POSIXct(fetched, tz = "UTC"))

  list(
    id             = as.character(id),
    authority      = as.character(authority),
    standard       = as.character(standard),
    standard_ver   = as.character(std_ver),
    severity       = as.character(severity),
    scope          = scope,
    check_tree     = check_tree,
    message        = as.character(message),
    source_document = paste0(cite_block$Document %||% "", " ",
                             cite_block$Section %||% ""),
    source_url     = yml$herald$source %||% "CDISC Library API",
    source_version = as.character(yml$Core$Version %||% NA),
    fetched_at     = fetched_at,
    content_hash   = hash_tree(check_tree),
    license        = "CC-BY-4.0",
    p21_id_equivalent = NA_character_
  )
}

row_from_herald_yaml <- function(yml, path) {
  # herald-own schema: lowercase
  id <- yml$id %||% tools::file_path_sans_ext(basename(path))

  severity <- normalize_severity(yml$outcome$severity)
  message  <- yml$outcome$message %||% yml$description %||% ""

  scope <- list(
    classes = yml$scope$classes %||% character(0),
    domains = yml$scope$domains %||% character(0),
    exclude_domains = yml$scope$exclude_domains %||% character(0)
  )
  check_tree <- yml$check

  # Provenance: HRL-* rules are all self-authored by the herald team.
  # If the YAML cites P21 as `provenance.source_doc` or p21_reference,
  # treat that as a CROSSWALK identifier (factual ID reference) rather
  # than a source claim. The source_document is normalised to herald-own.
  p21_id <- yml$provenance$p21_reference %||% NA_character_

  raw_source_doc <- yml$provenance$source_doc %||% ""
  raw_source_url <- yml$provenance$reference_url %||% ""

  is_p21_ref <- function(s) {
    grepl("pinnacle|p21|opencdisc", tolower(s), fixed = FALSE)
  }

  # Strip P21 identity from source_document / source_url (it belongs in p21_id_equivalent)
  source_doc <- if (is_p21_ref(raw_source_doc)) "" else raw_source_doc
  source_url <- if (is_p21_ref(raw_source_url)) "" else raw_source_url
  if (!nzchar(source_url)) source_url <- "herald-own"
  if (!nzchar(source_doc)) source_doc <- "Self-authored by herald team"
  # Crosswalk ID lives only in p21_id_equivalent column; no mention in source_document.

  list(
    id             = as.character(id),
    authority      = "HERALD",
    standard       = normalize_standard(yml$standard),
    standard_ver   = NA_character_,
    severity       = severity,
    scope          = scope,
    check_tree     = check_tree,
    message        = as.character(message),
    source_document = as.character(source_doc),
    source_url     = as.character(source_url),
    source_version = as.character(yml$version %||% "1"),
    fetched_at     = as.POSIXct(NA),
    content_hash   = hash_tree(check_tree),
    license        = "MIT",
    p21_id_equivalent = as.character(p21_id)
  )
}

is_core_schema <- function(yml) {
  !is.null(yml$Core) || !is.null(yml$Authorities)
}

parse_one <- function(path) {
  yml <- tryCatch(
    yaml::read_yaml(path),
    error = function(e) {
      warning("YAML parse failed: ", path, " (", conditionMessage(e), ")")
      NULL
    }
  )
  if (is.null(yml)) return(NULL)
  if (is_core_schema(yml)) row_from_core_yaml(yml, path)
  else                      row_from_herald_yaml(yml, path)
}

# ---- collect + compile -----------------------------------------------------

yaml_paths <- list.files(
  author_root, pattern = "\\.ya?ml$", recursive = TRUE, full.names = TRUE
)

cat("Found ", length(yaml_paths), " YAML files under ",
    author_root, "\n", sep = "")

yaml_rows <- lapply(yaml_paths, parse_one)
yaml_rows <- yaml_rows[!vapply(yaml_rows, is.null, logical(1))]

# R-DSL: load helpers, then source every *.R under tools/handauthored/
dsl_path <- file.path(project_root, "tools", "rule-dsl.R")
if (file.exists(dsl_path)) {
  source(dsl_path, local = FALSE)
  .reset_rule_registry()

  r_paths <- list.files(
    author_root, pattern = "\\.R$", recursive = TRUE, full.names = TRUE
  )
  for (p in r_paths) {
    source(p, local = FALSE)
  }
  r_rows <- .collect_rules()

  # Canonicalize R-DSL rows into the same shape parse_one returns
  r_rows <- lapply(r_rows, function(r) {
    r$content_hash <- hash_tree(r$check_tree)
    r$.origin <- NULL
    r
  })

  cat("Found ", length(r_paths), " R files, ",
      length(r_rows), " rule() calls\n", sep = "")
} else {
  r_rows <- list()
}

rows <- c(yaml_rows, r_rows)

# Build tibble-like data frame (keep list-columns as-is)
if (length(rows) == 0L) {
  stop("No rules parsed from ", author_root, ". Aborting compile.")
}

scalar_cols <- c(
  "id", "authority", "standard", "standard_ver", "severity",
  "message", "source_document", "source_url", "source_version",
  "content_hash", "license", "p21_id_equivalent"
)

cols <- list()
for (col in scalar_cols) {
  cols[[col]] <- vapply(
    rows,
    function(r) {
      v <- r[[col]]
      if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)[1]
    },
    character(1)
  )
}
cols$fetched_at <- .POSIXct(
  vapply(rows, function(r) {
    v <- r$fetched_at
    if (is.null(v) || length(v) == 0L) NA_real_ else as.numeric(v)[1]
  }, numeric(1)),
  tz = "UTC"
)
cols$scope <- lapply(rows, function(r) r$scope %||% list())
cols$check_tree <- lapply(rows, function(r) r$check_tree %||% list())

# tibble handles list-columns cleanly
rules <- tibble::tibble(!!!cols)

# Dedupe by content_hash
n_before <- nrow(rules)
rules <- rules[!duplicated(rules$content_hash), , drop = FALSE]
n_after <- nrow(rules)
if (n_before != n_after) {
  cat("Deduplicated ", n_before - n_after, " rules by content_hash\n",
      sep = "")
}

# ---- integrity checks ------------------------------------------------------

if (anyDuplicated(rules$id)) {
  dupe_ids <- rules$id[duplicated(rules$id)]
  warning("Duplicate rule ids: ", paste(head(dupe_ids, 5), collapse = ", "))
}

missing_msg <- !nzchar(rules$message)
if (any(missing_msg)) {
  warning(sum(missing_msg), " rules have empty message")
}

invalid_sev <- !rules$severity %in% c("Reject", "High", "Medium", "Low")
if (any(invalid_sev)) {
  warning(sum(invalid_sev), " rules have invalid severity")
}

# ---- write outputs ---------------------------------------------------------

saveRDS(rules, file.path(out_dir, "rules.rds"), version = 3)

jsonl_path <- file.path(out_dir, "rules.jsonl")
con <- file(jsonl_path, "w", encoding = "UTF-8")
for (i in seq_len(nrow(rules))) {
  row <- as.list(rules[i, ])
  row$scope <- rules$scope[[i]]
  row$check_tree <- rules$check_tree[[i]]
  row$fetched_at <- format(rules$fetched_at[i], "%Y-%m-%dT%H:%M:%SZ")
  writeLines(jsonlite::toJSON(row, auto_unbox = TRUE, null = "null"), con)
}
close(con)

by_authority <- table(rules$authority)
by_standard  <- table(rules$standard)

manifest <- list(
  compiled_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  herald_version = as.character(
    read.dcf(file.path(project_root, "DESCRIPTION"), "Version")[1, 1]
  ),
  rule_counts = list(
    total       = nrow(rules),
    by_authority = as.list(by_authority),
    by_standard  = as.list(by_standard)
  ),
  integrity = list(
    duplicate_ids    = anyDuplicated(rules$id) > 0,
    empty_messages   = sum(missing_msg),
    invalid_severity = sum(invalid_sev)
  )
)
writeLines(
  jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
  file.path(out_dir, "MANIFEST.json")
)

cat("\n")
cat("===== compile-rules.R done =====\n")
cat("  total rules      : ", nrow(rules), "\n", sep = "")
cat("  by authority     : ",
    paste(sprintf("%s=%d", names(by_authority), by_authority),
          collapse = ", "),
    "\n", sep = "")
cat("  by standard      : ",
    paste(sprintf("%s=%d", names(by_standard), by_standard),
          collapse = ", "),
    "\n", sep = "")
cat("  output           : ", out_dir, "/\n", sep = "")
