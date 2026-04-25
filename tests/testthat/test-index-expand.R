# -----------------------------------------------------------------------------
# test-fast-index-expand.R -- xx / y / zz placeholder expansion
# -----------------------------------------------------------------------------
# ADaMIG index conventions:
#   xx -- 01-99 zero-padded
#   y  -- 1-9 single digit
#   zz -- 01-99 zero-padded (second slot)
#
# A check_tree carrying `expand: xx` (etc.) gets rewritten against the
# dataset's columns before the walker sees it; each matching concrete value
# instantiates a copy of the subtree under an implicit {any}.

test_that(".index_values_in_cols finds concrete xx values", {
  cols <- c("USUBJID", "TRT01PN", "TRT02PN", "TRT04PN", "AGE")
  vals <- herald:::.index_values_in_cols("TRTxxPN", cols, "xx")
  expect_setequal(vals, c("01", "02", "04"))
})

test_that(".index_values_in_cols returns empty when template doesn't match", {
  cols <- c("USUBJID", "AGE")
  expect_equal(
    herald:::.index_values_in_cols("TRTxxPN", cols, "xx"),
    character()
  )
})

test_that("y (single digit) extraction", {
  cols <- c("USUBJID", "TRTPG1N", "TRTPG3N")
  expect_setequal(
    herald:::.index_values_in_cols("TRTPGyN", cols, "y"),
    c("1", "3")
  )
})

test_that(".substitute_index rewrites leaf names", {
  tree <- list(
    all = list(
      list(name = "TRTxxPN", operator = "exists"),
      list(name = "TRTxxP", operator = "not_exists")
    )
  )
  out <- herald:::.substitute_index(tree, "xx", "01")
  expect_equal(out$all[[1L]]$name, "TRT01PN")
  expect_equal(out$all[[2L]]$name, "TRT01P")
})

test_that(".expand_indexed returns per-instance tree map for indexed rules", {
  ct <- list(
    expand = "xx",
    all = list(
      list(name = "TRTxxPN", operator = "exists"),
      list(name = "TRTxxP", operator = "not_exists")
    )
  )
  data <- data.frame(
    TRT01PN = 1,
    TRT02PN = 2,
    TRT02P = "x",
    stringsAsFactors = FALSE
  )
  xp <- herald:::.expand_indexed(ct, data)
  expect_true(isTRUE(xp$indexed))
  expect_equal(xp$placeholder, "xx")
  expect_setequal(names(xp$instances), c("01", "02"))
  # Each instance carries the substituted name in its leaves.
  expect_equal(xp$instances[["01"]]$all[[1L]]$name, "TRT01PN")
  expect_equal(xp$instances[["02"]]$all[[1L]]$name, "TRT02PN")
  # Legacy `$tree` still holds the `{any}` combinator for a single walk.
  expect_named(xp$tree, "any")
  expect_equal(length(xp$tree$any), 2L)
})

test_that(".expand_indexed returns empty instances + narrative when no cols match", {
  ct <- list(
    expand = "xx",
    all = list(
      list(name = "TRTxxPN", operator = "exists"),
      list(name = "TRTxxP", operator = "not_exists")
    )
  )
  data <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  xp <- herald:::.expand_indexed(ct, data)
  expect_true(isTRUE(xp$indexed))
  expect_equal(length(xp$instances), 0L)
  expect_true(is.list(xp$tree) && !is.null(xp$tree$narrative))
})

test_that("non-indexed check_tree passes through unchanged", {
  ct <- list(
    all = list(
      list(name = "AETERM", operator = "exists")
    )
  )
  xp <- herald:::.expand_indexed(ct, data.frame(AETERM = "x"))
  expect_false(xp$indexed)
  expect_equal(length(xp$instances), 0L)
  expect_identical(xp$tree, ct)
})

test_that("fired finding carries RESOLVED message, not the template", {
  # Dataset has TRT01PN and TRT04PN (no pair) -> two separate violations
  # with distinct resolved messages.
  ds <- data.frame(
    USUBJID = "S1",
    TRT01PN = 1L,
    TRT04PN = 4L,
    TRT02PN = 2L,
    TRT02P = "Placebo", # 02 is complete -> no fire for 02
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(
      ds_spec = data.frame(
        dataset = "ADSL",
        class = "SUBJECT LEVEL ANALYSIS DATASET",
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  r <- herald::validate(
    files = list(ADSL = ds),
    spec = spec,
    rules = "75",
    quiet = TRUE
  )
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  expect_equal(nrow(fired), 2L)
  # Messages must carry the concrete index values, not "xx".
  msgs <- sort(fired$message)
  expect_equal(msgs[[1L]], "TRT01PN is present and TRT01P is not present")
  expect_equal(msgs[[2L]], "TRT04PN is present and TRT04P is not present")
  # Template placeholder must NOT leak into any finding message.
  expect_false(any(grepl("xx", fired$message)))
})

test_that("end-to-end: ADaM-75 fires on TRT01PN-present / TRT01P-missing", {
  ds <- data.frame(
    USUBJID = c("S1", "S2"),
    TRT01PN = c(1L, 1L),
    TRT02PN = c(2L, 2L),
    TRT02P = c("Placebo", "Placebo"),
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(
      ds_spec = data.frame(
        dataset = "ADSL",
        class = "SUBJECT LEVEL ANALYSIS DATASET",
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  r <- herald::validate(
    files = list(ADSL = ds),
    spec = spec,
    rules = "75",
    quiet = TRUE
  )
  fired <- r$findings[r$findings$status == "fired", ]
  expect_equal(nrow(fired), 1L)
})

test_that("end-to-end: ADaM-75 does NOT fire when all pairs are complete", {
  ds <- data.frame(
    USUBJID = "S1",
    TRT01PN = 1L,
    TRT01P = "Placebo",
    TRT02PN = 2L,
    TRT02P = "Drug",
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(
      ds_spec = data.frame(
        dataset = "ADSL",
        class = "SUBJECT LEVEL ANALYSIS DATASET",
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  r <- herald::validate(
    files = list(ADSL = ds),
    spec = spec,
    rules = "75",
    quiet = TRUE
  )
  expect_equal(nrow(r$findings[r$findings$status == "fired", ]), 0L)
})

# -- .index_values_in_cols edge cases -----------------------------------------

test_that(".index_values_in_cols returns empty when ph not in template", {
  # Template "USUBJID" has no 'xx' placeholder
  cols <- c("USUBJID", "TRT01PN")
  expect_equal(herald:::.index_values_in_cols("USUBJID", cols, "xx"), character())
})

test_that(".index_values_in_cols returns empty for unknown placeholder", {
  cols <- c("TRT01PN")
  # A placeholder not in .INDEX_PATTERNS -> stem is NULL
  expect_equal(herald:::.index_values_in_cols("TRTxxPN", cols, "UNKNOWN"), character())
})

# -- .collect_indexed_names ---------------------------------------------------

test_that(".collect_indexed_names traverses all/any/not branches", {
  node <- list(
    all = list(
      list(name = "TRTxxPN", operator = "exists")
    ),
    any = list(
      list(name = "TRTxxP", operator = "exists")
    ),
    not = list(name = "TRTxxPGy", operator = "exists")
  )
  names_found <- herald:::.collect_indexed_names(node, "xx")
  expect_in("TRTxxPN", names_found)
  expect_in("TRTxxP", names_found)
  expect_in("TRTxxPGy", names_found)
})

test_that(".collect_indexed_names returns acc unchanged for non-list node", {
  expect_equal(herald:::.collect_indexed_names("not a list", "xx"), character())
})

test_that(".collect_indexed_names returns acc unchanged for empty list", {
  expect_equal(herald:::.collect_indexed_names(list(), "xx"), character())
})

# -- .substitute_index_deep ---------------------------------------------------

test_that(".substitute_index_deep substitutes in character scalars", {
  expect_equal(
    herald:::.substitute_index_deep("TRTxxPN", "xx", "01"),
    "TRT01PN"
  )
})

test_that(".substitute_index_deep substitutes inside nested lists", {
  x <- list(related_name = "TRTxxP", group_by = "TRTxxGRP")
  out <- herald:::.substitute_index_deep(x, "xx", "02")
  expect_equal(out$related_name, "TRT02P")
  expect_equal(out$group_by, "TRT02GRP")
})

test_that(".substitute_index_deep leaves non-character non-list values unchanged", {
  expect_equal(herald:::.substitute_index_deep(42L, "xx", "01"), 42L)
  expect_equal(herald:::.substitute_index_deep(TRUE, "xx", "01"), TRUE)
})

# -- .substitute_index with value slot ----------------------------------------

test_that(".substitute_index rewrites value slot recursively", {
  node <- list(
    name = "TRTxxPN",
    value = list(related_name = "TRTxxP")
  )
  out <- herald:::.substitute_index(node, "xx", "03")
  expect_equal(out$name, "TRT03PN")
  expect_equal(out$value$related_name, "TRT03P")
})

test_that(".substitute_index rewrites not branch", {
  node <- list(
    name = "TRTxxPN",
    not = list(name = "TRTxxP")
  )
  out <- herald:::.substitute_index(node, "xx", "04")
  expect_equal(out$not$name, "TRT04P")
})

# -- .parse_expand_spec -------------------------------------------------------

test_that(".parse_expand_spec returns empty for NULL", {
  expect_equal(herald:::.parse_expand_spec(NULL), character())
})

test_that(".parse_expand_spec parses comma-separated string", {
  out <- herald:::.parse_expand_spec("xx,y")
  expect_equal(sort(out), sort(c("xx", "y")))
})

test_that(".parse_expand_spec parses vector input", {
  out <- herald:::.parse_expand_spec(c("xx", "y"))
  expect_equal(sort(out), sort(c("xx", "y")))
})

test_that(".parse_expand_spec drops unknown placeholders", {
  out <- herald:::.parse_expand_spec("xx,UNKNOWN")
  expect_equal(out, "xx")
})

# -- .multi_values_in_cols multi-placeholder ----------------------------------

test_that(".multi_values_in_cols extracts tuple for multi-placeholder template", {
  cols <- c("TRT01PG1", "TRT02PG3", "USUBJID")
  tuples <- herald:::.multi_values_in_cols("TRTxxPGy", cols, c("xx", "y"))
  keys <- vapply(tuples, function(t) paste(t$xx, t$y, sep = ","), character(1L))
  expect_in("01,1", keys)
  expect_in("02,3", keys)
  expect_false("USUBJID" %in% vapply(tuples, function(t) t$xx %||% "", character(1L)))
})

test_that(".multi_values_in_cols returns empty list when no phs present in template", {
  cols <- c("AGE")
  out <- herald:::.multi_values_in_cols("USUBJID", cols, c("xx", "y"))
  expect_equal(out, list())
})

# -- .expand_indexed with no expand slot --------------------------------------

test_that(".expand_indexed handles null expand in check_tree with no_expansion", {
  ct <- list(all = list(list(name = "USUBJID", operator = "exists")))
  xp <- herald:::.expand_indexed(ct, data.frame(USUBJID = "S1"))
  expect_false(xp$indexed)
  expect_identical(xp$tree, ct)
})

# -- .expand_indexed multi-placeholder ----------------------------------------

test_that(".expand_indexed handles multi-placeholder expansion", {
  ct <- list(
    expand = "xx,y",
    all = list(
      list(name = "TRTxxPGy", operator = "exists")
    )
  )
  data <- data.frame(TRT01PG1 = 1L, TRT02PG3 = 2L, stringsAsFactors = FALSE)
  xp <- herald:::.expand_indexed(ct, data)
  expect_true(xp$indexed)
  expect_equal(length(xp$instances), 2L)
  # placeholder field shows comma-joined form
  expect_true(grepl(",", xp$placeholder))
})

# -- .render_indexed_text -----------------------------------------------------

test_that(".render_indexed_text substitutes placeholder in text", {
  out <- herald:::.render_indexed_text("TRTxxPN is missing", "xx", "01")
  expect_equal(out, "TRT01PN is missing")
})

test_that(".render_indexed_text returns NULL/NA unchanged", {
  expect_null(herald:::.render_indexed_text(NULL, "xx", "01"))
  expect_true(is.na(herald:::.render_indexed_text(NA_character_, "xx", "01")))
})

test_that(".render_indexed_text returns empty string unchanged", {
  expect_equal(herald:::.render_indexed_text("", "xx", "01"), "")
})

# -- .render_domain_prefix ----------------------------------------------------

test_that(".render_domain_prefix replaces -- with 2-char domain prefix", {
  out <- herald:::.render_domain_prefix("--REASND not present", "AE")
  expect_equal(out, "AEREASND not present")
})

test_that(".render_domain_prefix is no-op when no -- in text", {
  out <- herald:::.render_domain_prefix("USUBJID not present", "AE")
  expect_equal(out, "USUBJID not present")
})

test_that(".render_domain_prefix is no-op for ADaM datasets", {
  out <- herald:::.render_domain_prefix("--REASND not present", "ADAE")
  expect_equal(out, "--REASND not present")
})

test_that(".render_domain_prefix uses parent 2 chars for SUPP domains", {
  out <- herald:::.render_domain_prefix("--REASND not present", "SUPPAE")
  expect_equal(out, "AEREASND not present")
})

test_that(".render_domain_prefix handles NULL ds_name gracefully", {
  out <- herald:::.render_domain_prefix("--REASND", NULL)
  expect_equal(out, "--REASND")
})

test_that(".render_domain_prefix handles vector txt element-wise", {
  out <- herald:::.render_domain_prefix(c("--REASND", "--TERM"), "AE")
  expect_equal(unname(out), c("AEREASND", "AETERM"))
})
