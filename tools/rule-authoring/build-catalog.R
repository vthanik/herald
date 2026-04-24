#!/usr/bin/env Rscript
# tools/rule-authoring/build-catalog.R
# ---------------------------------------------------------------------------
# Generate tools/rule-authoring/catalog.csv -- the single source of truth
# for every rule across all buckets (sdtm-ig-v2.0, adam-v5.0,
# sdtm-library-api, define-xml-v2.1).
#
# Sources merged:
#   1. tools/handauthored/**/*.yaml    -- all authored rules
#   2. core-vs-conformance.csv         -- CORE <-> CG crosswalk
#   3. progress.csv                    -- pattern, check_tree_preview,
#                                         p21_primitive, converted_at,
#                                         blocker notes (carried forward)
#
# Idempotent: re-running overwrites catalog.csv deterministically.
# Run from the package root: Rscript tools/rule-authoring/build-catalog.R

suppressPackageStartupMessages(library(yaml))

project_root   <- getwd()
auth_root      <- file.path(project_root, "tools", "handauthored", "cdisc")
authoring_root <- file.path(project_root, "tools", "rule-authoring")
xwalk_csv      <- file.path(authoring_root, "core-vs-conformance.csv")
progress_csv   <- file.path(authoring_root, "progress.csv")
out_csv        <- file.path(authoring_root, "catalog.csv")

stopifnot(dir.exists(auth_root))

# ---- helpers ----------------------------------------------------------------

normalize_severity <- function(x) {
  if (is.null(x) || length(x) == 0L || !nzchar(as.character(x))) return("Medium")
  x <- tolower(as.character(x)[[1L]])
  if (x %in% c("reject", "fatal")) "Reject"
  else if (x %in% c("error", "high")) "High"
  else if (x %in% c("warning", "medium")) "Medium"
  else if (x %in% c("info", "low", "notice")) "Low"
  else "Medium"
}

na_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)[[1L]]
}

normalize_executability <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return("narrative")
  x <- trimws(tolower(as.character(x)[[1L]]))
  if (x %in% c("predicate", "fully executable")) "predicate"
  else if (x %in% c("narrative")) "narrative"
  else if (x %in% c("reference", "partially executable", "not executable")) "reference"
  else "narrative"
}

is_core_schema <- function(yml) !is.null(yml$Core) || !is.null(yml$Authorities)

bucket_from_path <- function(path) {
  # last component of the directory that sits under tools/handauthored/cdisc/
  rel <- sub(paste0(auth_root, "/"), "", path, fixed = TRUE)
  strsplit(rel, .Platform$file.sep, fixed = TRUE)[[1L]][[1L]]
}

core_executability <- function(yml) {
  chk <- yml$Check
  if (!is.null(chk) && length(chk) > 0L) "predicate" else "narrative"
}

# ---- load crosswalk + progress ----------------------------------------------

xwalk <- if (file.exists(xwalk_csv)) {
  read.csv(xwalk_csv, stringsAsFactors = FALSE)
} else {
  data.frame(
    core_id = character(0), cg_ids = character(0),
    tig_ids = character(0), fb_ids = character(0),
    overlap_type = character(0), stringsAsFactors = FALSE
  )
}

# Build reverse map: CG id -> core_id (one-to-one; take first if multi)
cg_to_core <- list()
for (i in seq_len(nrow(xwalk))) {
  cg_raw <- xwalk$cg_ids[[i]]
  if (!is.na(cg_raw) && nzchar(cg_raw)) {
    parts <- trimws(strsplit(cg_raw, ";\\s*")[[1L]])
    for (cg in parts) {
      if (nzchar(cg) && is.null(cg_to_core[[cg]])) {
        cg_to_core[[cg]] <- xwalk$core_id[[i]]
      }
    }
  }
}

prog <- if (file.exists(progress_csv)) {
  read.csv(progress_csv, stringsAsFactors = FALSE)
} else {
  data.frame(rule_id = character(0), pattern = character(0),
             check_tree_preview = character(0), p21_primitive = character(0),
             converted_at = character(0), notes = character(0),
             status = character(0), stringsAsFactors = FALSE)
}
# Only keep non-NA rule_id rows for the join
prog <- prog[!is.na(prog$rule_id), ]

# ---- walk YAMLs -------------------------------------------------------------

yaml_paths <- list.files(auth_root, pattern = "\\.ya?ml$",
                         recursive = TRUE, full.names = TRUE)
cat("Found", length(yaml_paths), "YAML files under", auth_root, "\n")

rows <- vector("list", length(yaml_paths))
n_ok <- 0L

for (i in seq_along(yaml_paths)) {
  path <- yaml_paths[[i]]
  yml  <- tryCatch(yaml::read_yaml(path),
                   error = function(e) {
                     warning("YAML parse failed: ", path, " -- ", conditionMessage(e))
                     NULL
                   })
  if (is.null(yml)) next

  bucket <- bucket_from_path(path)

  if (is_core_schema(yml)) {
    rule_id       <- na_chr(yml$Core$Id)
    auth_block    <- yml$Authorities[[1L]] %||% list()
    std_block     <- auth_block$Standards[[1L]] %||% list()
    authority     <- na_chr(auth_block$Organization) %||% "CDISC"
    standard      <- na_chr(std_block$Name)
    std_versions  <- na_chr(std_block$Version)
    severity      <- normalize_severity(yml$Sensitivity)
    executability <- normalize_executability(core_executability(yml))
    message_txt   <- na_chr(yml$Outcome$Message %||% yml$Description)
    status_yml    <- na_chr(yml$status)  # may have "superseded" after dedup pass

    # Crosswalk from core-vs-conformance.csv
    xi <- match(rule_id, xwalk$core_id)
    core_id      <- rule_id
    cg_ids_val   <- if (!is.na(xi)) na_chr(xwalk$cg_ids[[xi]]) else NA_character_
    tig_ids_val  <- if (!is.na(xi)) na_chr(xwalk$tig_ids[[xi]]) else NA_character_
    fb_ids_val   <- if (!is.na(xi)) na_chr(xwalk$fb_ids[[xi]]) else NA_character_
    overlap_type <- if (!is.na(xi)) na_chr(xwalk$overlap_type[[xi]]) else NA_character_
  } else {
    rule_id       <- na_chr(yml$id)
    authority     <- na_chr(yml$authority %||% yml$provenance$authority) %||% "CDISC"
    standard      <- na_chr(yml$standard)
    std_versions  <- if (!is.null(yml$standard_versions)) {
                       paste(as.character(yml$standard_versions), collapse = ";")
                     } else {
                       na_chr(yml$standard_version)
                     }
    severity      <- normalize_severity(yml$outcome$severity)
    executability <- normalize_executability(yml$provenance$executability)
    message_txt   <- na_chr(yml$outcome$message %||% yml$description)
    status_yml    <- NA_character_

    # Crosswalk: look up this CG id in the reverse map
    core_id      <- if (!is.na(rule_id)) {
                     cg_to_core[[rule_id]] %||% NA_character_
                   } else {
                     NA_character_
                   }
    xi <- if (!is.na(core_id)) match(core_id, xwalk$core_id) else NA_integer_
    cg_ids_val   <- NA_character_
    tig_ids_val  <- if (!is.na(xi)) na_chr(xwalk$tig_ids[[xi]]) else NA_character_
    fb_ids_val   <- if (!is.na(xi)) na_chr(xwalk$fb_ids[[xi]]) else NA_character_
    overlap_type <- if (!is.na(xi)) na_chr(xwalk$overlap_type[[xi]]) else NA_character_
  }

  # Merge progress.csv columns for this rule_id
  pi <- if (!is.na(rule_id)) match(rule_id, prog$rule_id) else NA_integer_
  pattern            <- if (!is.na(pi)) na_chr(prog$pattern[[pi]])            else NA_character_
  check_tree_preview <- if (!is.na(pi)) na_chr(prog$check_tree_preview[[pi]]) else NA_character_
  p21_primitive      <- if (!is.na(pi)) na_chr(prog$p21_primitive[[pi]])      else NA_character_
  converted_at       <- if (!is.na(pi)) na_chr(prog$converted_at[[pi]])       else NA_character_
  prog_notes         <- if (!is.na(pi)) na_chr(prog$notes[[pi]])               else NA_character_
  prog_status        <- if (!is.na(pi)) na_chr(prog$status[[pi]])              else NA_character_

  # Resolve final status: YAML status_yml > progress blocker > executability
  status_final <- if (!is.na(status_yml) && nzchar(status_yml)) {
    status_yml
  } else if (!is.na(prog_status) && grepl("^blocker:", prog_status)) {
    prog_status
  } else {
    executability
  }

  p21_id_equiv <- na_chr(yml$provenance$p21_id_equivalent %||%
                          yml$provenance$p21_reference)

  n_ok <- n_ok + 1L
  rows[[i]] <- list(
    rule_id            = rule_id,
    bucket             = bucket,
    authority          = authority,
    standard           = standard,
    standard_versions  = std_versions,
    severity           = severity,
    executability      = executability,
    pattern            = pattern,
    status             = status_final,
    core_id            = core_id,
    cg_ids             = cg_ids_val,
    tig_ids            = tig_ids_val,
    fb_ids             = fb_ids_val,
    p21_id_equivalent  = p21_id_equiv,
    p21_primitive      = p21_primitive,
    overlap_type       = overlap_type,
    message            = if (!is.na(message_txt)) substr(message_txt, 1L, 160L) else NA_character_,
    check_tree_preview = check_tree_preview,
    converted_at       = converted_at,
    notes              = prog_notes
  )
}

rows <- rows[!vapply(rows, is.null, logical(1))]
cat("Parsed", length(rows), "rules (", length(yaml_paths) - n_ok, "failed)\n")

# ---- assemble data.frame ----------------------------------------------------

col_names <- c(
  "rule_id", "bucket", "authority", "standard", "standard_versions",
  "severity", "executability", "pattern", "status",
  "core_id", "cg_ids", "tig_ids", "fb_ids",
  "p21_id_equivalent", "p21_primitive", "overlap_type",
  "message", "check_tree_preview", "converted_at", "notes"
)

catalog <- as.data.frame(
  lapply(col_names, function(cn) vapply(rows, function(r) {
    v <- r[[cn]]
    if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)[[1L]]
  }, character(1))),
  stringsAsFactors = FALSE
)
names(catalog) <- col_names

# Sort: bucket order, then rule_id lexicographic
bucket_order <- c("sdtm-ig-v2.0", "adam-v5.0", "sdtm-library-api",
                  "define-xml-v2.1")
catalog$bucket_rank <- match(catalog$bucket, bucket_order)
catalog$bucket_rank[is.na(catalog$bucket_rank)] <- 99L
catalog <- catalog[order(catalog$bucket_rank, catalog$rule_id, na.last = TRUE), ]
catalog$bucket_rank <- NULL

# ---- summary ----------------------------------------------------------------

cat("\n===== catalog.csv summary =====\n")
cat("  total rules  :", nrow(catalog), "\n")
tbl_bucket <- table(catalog$bucket, useNA = "always")
for (nm in names(tbl_bucket)) cat("  bucket", nm, ":", as.integer(tbl_bucket[nm]), "\n")
cat("\n  status counts:\n")
print(table(catalog$status, useNA = "always"))

# ---- write ------------------------------------------------------------------

write.csv(catalog, out_csv, row.names = FALSE)
cat("\nWrote", out_csv, "\n")
