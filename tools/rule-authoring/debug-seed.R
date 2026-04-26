# tools/debug-seed.R -- diagnostic version of seed-fixtures.R that records
# why each rule is skipped. Outputs a CSV at tools/seed-debug.csv that can
# be read back to triage neither-fires, leaf-not-seedable, both-fire bugs.

suppressPackageStartupMessages({
  library(jsonlite)
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(herald)
  }
})

# Source the seeder functions only (not the main loop)
seeder_lines <- readLines("tools/seed-fixtures.R")
end_idx <- which(grepl("^# -- main loop", seeder_lines))[[1L]] - 1L
seeder_src <- paste(seeder_lines[seq_len(end_idx)], collapse = "\n")
eval(parse(text = seeder_src))

cat_rds <- system.file("rules", "rules.rds", package = "herald")
if (!nzchar(cat_rds)) cat_rds <- file.path("inst", "rules", "rules.rds")
catalog <- readRDS(cat_rds)
n_total <- nrow(catalog)

records <- list()
for (i in seq_len(n_total)) {
  rule <- as.list(catalog[i, , drop = FALSE])
  rule$scope      <- rule$scope[[1L]]
  rule$check_tree <- rule$check_tree[[1L]]
  rule_id <- rule$id

  leaves_info <- .extract_leaves(rule$check_tree)
  if (is.null(leaves_info) || length(leaves_info) == 0L) next

  ops <- vapply(leaves_info, function(l) as.character(l$leaf$operator %||% ""),
                character(1))
  if (!all(ops %in% WHITELIST_OPS)) next

  ds_info <- .pick_dataset_and_spec(rule)
  if (is.na(ds_info$name)) next

  seed_tuple <- .seed_expand_tuple(rule$check_tree$expand)
  if (length(seed_tuple) > 0L) {
    leaves_info <- lapply(leaves_info, function(x) {
      leaf_name <- as.character(unlist(x$leaf$name %||% character()))
      name_has_placeholder <- any(vapply(names(seed_tuple), function(ph) {
        any(grepl(ph, leaf_name, fixed = TRUE))
      }, logical(1L)))
      if (name_has_placeholder) {
        x$leaf <- .substitute_seed_tuple(x$leaf, seed_tuple)
      }
      x
    })
  }

  dollar_targets <- character()
  for (lf in leaves_info) {
    v1 <- .val_first(lf$leaf$value)
    if (!is.na(v1) && startsWith(v1, "$")) {
      ref <- .parse_dollar_ref(v1)
      if (!is.null(ref)) dollar_targets <- c(dollar_targets, ref$dataset)
    }
  }
  if (length(dollar_targets) > 0L &&
      toupper(ds_info$name) %in% toupper(dollar_targets)) {
    scope_doms <- rule$scope$domains
    explicit_scope <- length(scope_doms) > 0L &&
      any(nzchar(as.character(unlist(scope_doms))) &
          toupper(as.character(unlist(scope_doms))) != "ALL")
    if (!explicit_scope) {
      alt_candidates <- c("AE", "DS", "EX", "LB", "CM", "VS")
      alt <- alt_candidates[!alt_candidates %in% toupper(dollar_targets)]
      if (length(alt) > 0L) {
        ds_info$name  <- alt[[1L]]
        ds_info$class <- NA_character_
        ds_info$spec  <- NULL
      }
    }
  }

  is_adam <- grepl("^AD[A-Z]", ds_info$name)
  wildcard_domain <- if (is_adam) NA_character_ else ds_info$name

  variants_A <- vector("list", length(leaves_info))
  variants_B <- vector("list", length(leaves_info))
  seed_fail <- FALSE
  fail_op <- NA_character_
  for (j in seq_along(leaves_info)) {
    v <- .leaf_variants(ops[[j]], leaves_info[[j]]$leaf,
                        wildcard_domain, main_dataset = ds_info$name)
    if (is.null(v)) {
      seed_fail <- TRUE
      fail_op <- ops[[j]]
      break
    }
    v <- .normalize_variant(v)
    if (isTRUE(leaves_info[[j]]$inverted)) {
      variants_A[[j]] <- v$B
      variants_B[[j]] <- v$A
    } else {
      variants_A[[j]] <- v$A
      variants_B[[j]] <- v$B
    }
  }
  if (seed_fail) {
    records[[length(records) + 1L]] <- list(
      rule_id = rule_id, reason = "leaf-not-seedable",
      ds = ds_info$name, ops = paste(ops, collapse = ","),
      detail = sprintf("op=%s", fail_op)
    )
    next
  }

  paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
  if ((.is_manual(paths$positive) || .is_manual(paths$negative))) next

  .dataset_map_from_sides <- function(sides) {
    cols <- .merge_cols(lapply(sides, function(v) v$main))
    if (is.null(cols)) return(NULL)
    extras <- .merge_extras(lapply(sides, function(v) v$extras))
    if (is.null(extras)) return(NULL)
    c(stats::setNames(list(cols), ds_info$name), extras)
  }

  dataset_map_neg <- .dataset_map_from_sides(variants_B)
  if (is.null(dataset_map_neg)) {
    records[[length(records) + 1L]] <- list(
      rule_id = rule_id, reason = "leaf-col-conflict",
      ds = ds_info$name, ops = paste(ops, collapse = ","),
      detail = ""
    )
    next
  }

  pos_side_candidates <- list(variants_A)
  n_leaf <- length(variants_A)
  if (n_leaf > 1L) {
    for (j in seq_len(n_leaf)) {
      sides <- variants_B
      sides[[j]] <- variants_A[[j]]
      pos_side_candidates[[length(pos_side_candidates) + 1L]] <- sides
    }
    if (n_leaf <= 8L) {
      pairs <- utils::combn(seq_len(n_leaf), 2L, simplify = FALSE)
      for (pair in pairs) {
        sides <- variants_B
        sides[pair] <- variants_A[pair]
        pos_side_candidates[[length(pos_side_candidates) + 1L]] <- sides
      }
    }
  }

  out_neg <- .run_rule(rule_id, dataset_map_neg, spec = ds_info$spec)
  dataset_map_pos <- NULL
  out_pos <- list(fires = FALSE, rows = integer())
  for (sides in pos_side_candidates) {
    cand <- .dataset_map_from_sides(sides)
    if (is.null(cand)) next
    got <- .run_rule(rule_id, cand, spec = ds_info$spec)
    if (isTRUE(got$fires)) {
      dataset_map_pos <- cand
      out_pos <- got
      break
    }
  }

  if (!isTRUE(out_pos$fires) || isTRUE(out_neg$fires)) {
    reason <- if (!out_pos$fires && !out_neg$fires) "neither-fires"
              else if (out_pos$fires && out_neg$fires) "both-fire"
              else "positive-no-fire"
    detail <- sprintf("ds=%s class=%s firstcols=%s",
                      ds_info$name,
                      ds_info$class %||% "NA",
                      paste(names(dataset_map_neg[[1L]]), collapse = ","))
    records[[length(records) + 1L]] <- list(
      rule_id = rule_id, reason = reason,
      ds = ds_info$name, ops = paste(ops, collapse = ","),
      detail = detail
    )
    next
  }
}

df <- do.call(rbind, lapply(records, as.data.frame, stringsAsFactors = FALSE))
write.csv(df, "tools/seed-debug.csv", row.names = FALSE)
cat("seed-debug: wrote", nrow(df), "skip records\n")
cat("breakdown:\n")
print(table(df$reason))
cat("\nfirst 30 neither-fires:\n")
print(head(df[df$reason == "neither-fires", ], 30))
cat("\nfirst 30 both-fire:\n")
print(head(df[df$reason == "both-fire", ], 30))
cat("\nfirst 30 leaf-not-seedable:\n")
print(head(df[df$reason == "leaf-not-seedable", ], 30))
