#!/usr/bin/env Rscript
# tools/rule-authoring/discover-patterns.R
# ----------------------------------------------------------------------------
# Scan tools/handauthored/cdisc/*/*.yaml, cluster narrative rules by their
# outcome.message skeleton, write tools/rule-authoring/progress.csv, and print
# the top-N unclaimed pattern clusters.
#
# Run:
#   Rscript tools/rule-authoring/discover-patterns.R [--top N]
#
# Output:
#   tools/rule-authoring/progress.csv    (full rule-by-rule status)
#   tools/rule-authoring/coverage.md     (human summary)
#   stdout                               (top unclaimed patterns)

suppressPackageStartupMessages({
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
arg_top_idx <- which(args == "--top")
TOP_N <- if (length(arg_top_idx) > 0L) as.integer(args[[arg_top_idx + 1L]]) else 20L

project_root   <- getwd()
handauth_root  <- file.path(project_root, "tools", "handauthored", "cdisc")
authoring_root <- file.path(project_root, "tools", "rule-authoring")
progress_csv   <- file.path(authoring_root, "progress.csv")
coverage_md    <- file.path(authoring_root, "coverage.md")

stopifnot(dir.exists(handauth_root))

# ---- message skeletonisation -----------------------------------------------
# Normalise a CDISC message into a stable "skeleton" for clustering:
#   - lowercase
#   - collapse all runs of whitespace
#   - replace concrete SDTM/ADaM variable names and values with placeholders
#     so semantically-similar messages cluster together.
#
# Example:
#   "ARELTM is present and ARELTMU is not present"
#   -> "VAR is present and VAR is not present"
#
#   "AVAL is null and AVALC is not null"
#   -> "VAR is null and VAR is not null"

.skeleton <- function(msg) {
  if (is.null(msg) || is.na(msg) || !nzchar(msg)) return(NA_character_)
  s <- tolower(as.character(msg))
  # Wildcard var patterns like "*DT", "--VAR"
  s <- gsub("\\*[a-z0-9]+\\b",      "VAR", s)
  s <- gsub("--[a-z0-9]+\\b",       "VAR", s)
  # TRTxxPN / TRxxPGyN style
  s <- gsub("\\btrt[a-z0-9]{2,}\\b",  "VAR", s)
  s <- gsub("\\btr[a-z0-9]{2,}\\b",   "VAR", s)
  # Bare upper var names of length 2-8 (AVAL, AVALC, USUBJID, VISIT, etc.)
  # -- but only when looked at the ORIGINAL case before lowercasing.
  s_upper <- as.character(msg)
  # find standalone uppercase tokens of length 2-8 in the original
  toks <- regmatches(s_upper, gregexpr("\\b[A-Z][A-Z0-9_]{1,7}\\b", s_upper))[[1L]]
  for (tok in unique(toks)) {
    pat <- paste0("\\b", tolower(tok), "\\b")
    s <- gsub(pat, "VAR", s)
  }
  # Quoted string literals ("Y", "N", 'MULTIPLE') -> LIT
  s <- gsub('"[^"]*"|\u2018[^\u2019]*\u2019|\'[^\']*\'', "LIT", s)
  # Numeric literals
  s <- gsub("\\b[-+]?[0-9]+(\\.[0-9]+)?\\b", "NUM", s)
  # Collapse whitespace
  s <- gsub("\\s+", " ", trimws(s))
  s
}

# ---- YAML loader -----------------------------------------------------------

.load_rule_files <- function() {
  std_dirs <- list.dirs(handauth_root, recursive = FALSE)
  std_dirs <- std_dirs[grepl("(adam|sdtm|send)", basename(std_dirs),
                              ignore.case = TRUE)]
  files <- unlist(lapply(std_dirs, function(d) {
    list.files(d, pattern = "\\.yaml$", full.names = TRUE, recursive = FALSE)
  }))
  files
}

.parse_one <- function(path) {
  y <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
  if (is.null(y)) return(NULL)
  check     <- y$check %||% list()
  has_ops   <- any(c("all","any","not","operator") %in% names(check))
  has_narr  <- !is.null(check$narrative) && nzchar(as.character(check$narrative))
  ex        <- y$provenance$executability %||% (if (has_ops) "predicate" else "narrative")

  list(
    path              = path,
    rule_id           = as.character(y$id %||% NA),
    authority         = as.character(y$authority %||% NA),
    standard          = as.character(y$standard %||% NA),
    ig_version        = paste(as.character(y$standard_versions %||% NA), collapse = ","),
    severity          = as.character(y$severity %||% NA),
    message           = as.character(y$outcome$message %||% NA),
    condition_failure = as.character(y$check$condition_failure %||% NA),
    narrative         = as.character(y$check$narrative %||% NA),
    cited_guidance    = as.character(y$provenance$cited_guidance %||% NA),
    executability     = ex,
    has_predicate     = has_ops,
    check_tree_preview = .preview(check)
  )
}

.preview <- function(check) {
  if (is.null(check) || length(check) == 0L) return(NA_character_)
  leaves <- .extract_leaves(check)
  if (length(leaves) == 0L) return(NA_character_)
  bits <- vapply(leaves, function(l) {
    args <- c(l$name, unlist(l[setdiff(names(l), c("name","operator"))]))
    args <- args[!is.na(args) & nzchar(args)]
    sprintf("%s(%s)", l$operator %||% "?",
            paste(as.character(args), collapse = ","))
  }, character(1L))
  paste(bits, collapse = " & ")
}

.extract_leaves <- function(node, acc = list()) {
  if (!is.list(node) || length(node) == 0L) return(acc)
  if (!is.null(node$operator)) return(c(acc, list(node)))
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) for (c in ch) acc <- .extract_leaves(c, acc)
  }
  if (!is.null(node$not)) acc <- .extract_leaves(node$not, acc)
  acc
}

`%||%` <- function(a, b) if (is.null(a) || all(is.na(a)) || (length(a) == 1L && !nzchar(as.character(a)))) b else a

# ---- main ------------------------------------------------------------------

cat("scanning handauthored YAMLs ...\n")
files <- .load_rule_files()
cat(sprintf("  found %d YAML files\n", length(files)))

rows <- lapply(files, .parse_one)
rows <- rows[!vapply(rows, is.null, logical(1L))]

df <- do.call(rbind, lapply(rows, function(r) {
  data.frame(
    rule_id            = r$rule_id,
    authority          = r$authority,
    standard           = r$standard,
    ig_version         = r$ig_version,
    severity           = r$severity,
    message            = r$message,
    pattern            = NA_character_,
    check_tree_preview = r$check_tree_preview,
    status             = r$executability,
    converted_at       = NA_character_,
    p21_primitive      = NA_character_,
    notes              = NA_character_,
    stringsAsFactors   = FALSE
  )
}))

# Load existing progress.csv if present, to preserve `pattern`, `converted_at`,
# `p21_primitive`, `notes` for rules we've already classified.
if (file.exists(progress_csv)) {
  prev <- read.csv(progress_csv, stringsAsFactors = FALSE)
  keep_cols <- intersect(c("rule_id","pattern","converted_at",
                           "p21_primitive","notes"), names(prev))
  if (length(keep_cols) >= 2L) {
    merged <- merge(df[, setdiff(names(df), keep_cols[-1L])],
                    prev[, keep_cols],
                    by = "rule_id", all.x = TRUE)
    df <- merged[match(df$rule_id, merged$rule_id), names(df)]
  }
}

# Order: narrative first, then predicate.
df <- df[order(df$status != "narrative", df$standard, df$rule_id), ]
rownames(df) <- NULL

write.csv(df, progress_csv, row.names = FALSE)
cat(sprintf("  wrote %s (%d rows)\n", progress_csv, nrow(df)))

# ---- top unclaimed patterns (for Batch authoring) --------------------------

narr <- df[df$status == "narrative", , drop = FALSE]
cat(sprintf("\nnarrative (needs authoring): %d rules\n", nrow(narr)))
cat(sprintf("predicate (already converted): %d rules\n",
            sum(df$status == "predicate")))

if (nrow(narr) > 0L) {
  narr$skel <- vapply(narr$message, .skeleton, character(1L))
  tab <- sort(table(narr$skel[!is.na(narr$skel)]), decreasing = TRUE)
  top <- utils::head(tab, TOP_N)

  cat(sprintf("\ntop %d message skeletons (unclaimed):\n", TOP_N))
  width <- min(90L, max(nchar(names(top))) + 2L)
  for (i in seq_along(top)) {
    msg <- names(top)[[i]]
    if (nchar(msg) > width) msg <- paste0(substr(msg, 1, width - 3L), "...")
    cat(sprintf("  %4d  %s\n", top[[i]], msg))
  }
}

# ---- coverage.md -----------------------------------------------------------

lines <- c(
  sprintf("# Rule authoring coverage -- %s",
          format(Sys.Date(), "%Y-%m-%d")),
  "",
  sprintf("Scanned %d handauthored rules.", nrow(df)),
  "",
  "| status | count |",
  "|---|---:|",
  sprintf("| narrative (needs authoring) | %d |", sum(df$status == "narrative")),
  sprintf("| predicate (converted) | %d |", sum(df$status == "predicate")),
  sprintf("| skipped / blocked | %d |",
          sum(!df$status %in% c("narrative","predicate"))),
  sprintf("| **total** | %d |", nrow(df)),
  ""
)

# By standard.
by_std <- aggregate(rule_id ~ standard + status, df, length)
by_std <- by_std[order(by_std$standard, by_std$status), ]
lines <- c(lines, "## By standard", "",
           "| standard | status | count |",
           "|---|---|---:|",
           sprintf("| %s | %s | %d |", by_std$standard, by_std$status,
                   by_std$rule_id),
           "")

# By pattern (if any assigned).
if (any(!is.na(df$pattern))) {
  by_pat <- aggregate(rule_id ~ pattern, df[!is.na(df$pattern), ], length)
  by_pat <- by_pat[order(-by_pat$rule_id), ]
  lines <- c(lines, "## By pattern (converted)", "",
             "| pattern | count |",
             "|---|---:|",
             sprintf("| %s | %d |", by_pat$pattern, by_pat$rule_id),
             "")
}

writeLines(lines, coverage_md)
cat(sprintf("\nwrote %s\n", coverage_md))
