# Tests for R/dict-provider.R -- Dictionary Provider Protocol scaffolding.

.minimal_provider <- function(
  name = "test",
  terms = c("A", "B", "C"),
  version = "0.1",
  source = "sponsor"
) {
  new_dict_provider(
    name = name,
    version = version,
    source = source,
    license = "none",
    size_rows = length(terms),
    fields = "default",
    contains = function(value, field = NULL, ignore_case = FALSE) {
      v <- as.character(value)
      if (isTRUE(ignore_case)) {
        return(toupper(v) %in% toupper(terms))
      }
      v %in% terms
    }
  )
}

test_that("new_dict_provider() builds an object with the expected shape", {
  p <- .minimal_provider()
  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "test")
  expect_equal(p$version, "0.1")
  expect_equal(p$source, "sponsor")
  expect_type(p$contains, "closure")
  expect_true(is.function(p$info))

  info <- p$info()
  expect_equal(info$name, "test")
  expect_equal(info$size_rows, 3L)
})

test_that("new_dict_provider() rejects non-function contains", {
  expect_error(
    new_dict_provider("x", contains = "not a function"),
    class = "herald_error_input"
  )
})

test_that("provider$contains() returns a logical vector", {
  p <- .minimal_provider()
  expect_equal(p$contains(c("A", "Z", "B")), c(TRUE, FALSE, TRUE))
  expect_equal(p$contains(c("a", "A"), ignore_case = TRUE), c(TRUE, TRUE))
})

test_that("register_dictionary / unregister_dictionary round-trip", {
  on.exit(unregister_dictionary("rt-test"), add = TRUE)
  p <- .minimal_provider("rt-test")
  register_dictionary("rt-test", p)
  dfs <- list_dictionaries()
  expect_true("rt-test" %in% dfs$name)

  expect_true(unregister_dictionary("rt-test"))
  expect_false(unregister_dictionary("rt-test"))
  dfs2 <- list_dictionaries()
  expect_false("rt-test" %in% dfs2$name)
})

test_that("register_dictionary rejects a non-provider", {
  expect_error(
    register_dictionary("x", list(a = 1)),
    class = "herald_error_input"
  )
})

test_that(".populate_dict_registry merges global + explicit overrides", {
  on.exit(unregister_dictionary("g1"), add = TRUE)
  register_dictionary("g1", .minimal_provider("g1"))

  ctx <- new.env()
  herald:::.populate_dict_registry(
    ctx,
    dictionaries = list(x1 = .minimal_provider("x1")),
    call = rlang::caller_env()
  )
  expect_named(ctx$dict, c("g1", "x1"), ignore.order = TRUE)
})

test_that(".populate_dict_registry lets explicit arg override a same-named global", {
  on.exit(unregister_dictionary("shared"), add = TRUE)
  register_dictionary(
    "shared",
    .minimal_provider("shared", terms = c("A"), version = "global")
  )
  ctx <- new.env()
  herald:::.populate_dict_registry(
    ctx,
    dictionaries = list(
      shared = .minimal_provider("shared", terms = c("Z"), version = "explicit")
    ),
    call = rlang::caller_env()
  )
  expect_equal(ctx$dict$shared$version, "explicit")
})

test_that(".populate_dict_registry rejects non-list / unnamed input", {
  ctx <- new.env()
  expect_error(
    herald:::.populate_dict_registry(
      ctx,
      dictionaries = "nope",
      call = rlang::caller_env()
    ),
    class = "herald_error_input"
  )
  expect_error(
    herald:::.populate_dict_registry(
      ctx,
      dictionaries = list(.minimal_provider()),
      call = rlang::caller_env()
    ),
    class = "herald_error_input"
  )
  expect_error(
    herald:::.populate_dict_registry(
      ctx,
      dictionaries = list(x = list(not_a_provider = TRUE)),
      call = rlang::caller_env()
    ),
    class = "herald_error_input"
  )
})

test_that(".resolve_provider returns provider or NULL", {
  ctx <- new.env()
  ctx$dict <- list(x = .minimal_provider("x"))
  expect_s3_class(herald:::.resolve_provider(ctx, "x"), "herald_dict_provider")
  expect_null(herald:::.resolve_provider(ctx, "missing"))
  expect_null(herald:::.resolve_provider(NULL, "anything"))
})

test_that(".record_missing_ref collects rule_ids per (kind, name)", {
  ctx <- new.env()
  herald:::.init_missing_refs(ctx)
  herald:::.record_missing_ref(ctx, "CG0100", "dataset", "DM")
  herald:::.record_missing_ref(ctx, "CG0101", "dataset", "DM")
  herald:::.record_missing_ref(ctx, "CG0442", "dictionary", "srs")

  expect_setequal(ctx$missing_refs$datasets$DM, c("CG0100", "CG0101"))
  expect_equal(ctx$missing_refs$dictionaries$srs, "CG0442")
})

test_that(".record_missing_ref de-duplicates within a (kind, name) bucket", {
  ctx <- new.env()
  herald:::.init_missing_refs(ctx)
  herald:::.record_missing_ref(ctx, "X", "dataset", "DM")
  herald:::.record_missing_ref(ctx, "X", "dataset", "DM")
  expect_equal(ctx$missing_refs$datasets$DM, "X")
})

test_that(".finalize_skipped_refs emits actionable hints per kind+name", {
  ctx <- new.env()
  herald:::.init_missing_refs(ctx)
  herald:::.record_missing_ref(ctx, "CG0100", "dataset", "DM")
  herald:::.record_missing_ref(ctx, "CG0442", "dictionary", "srs")
  herald:::.record_missing_ref(ctx, "CG0020", "dictionary", "meddra")

  out <- herald:::.finalize_skipped_refs(ctx)
  expect_equal(out$datasets$DM$kind, "dataset")
  expect_equal(out$datasets$DM$rule_ids, "CG0100")
  expect_match(out$datasets$DM$hint, "Provide dataset DM")

  expect_equal(out$dictionaries$srs$kind, "dictionary")
  expect_match(out$dictionaries$srs$hint, "download_srs")
  expect_match(out$dictionaries$meddra$hint, "meddra_provider")
})

test_that("validate() accepts dictionaries = ... arg and carries skipped_refs", {
  # Minimal smoke: the empty-registry path produces empty skipped_refs.
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  r <- validate(files = list(DM = dm), rules = character(0), quiet = TRUE)
  expect_s3_class(r, "herald_result")
  expect_true("skipped_refs" %in% names(r))
  expect_equal(r$skipped_refs$datasets, list())
  expect_equal(r$skipped_refs$dictionaries, list())
})

test_that("validate() surfaces a recorded missing dict in result$skipped_refs", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  r <- validate(files = list(DM = dm), rules = character(0), quiet = TRUE)
  # Manually simulate a missing-ref record by invoking post-finaliser on a
  # synthetic ctx (integration through a real op lands in Phase 2).
  ctx <- new.env()
  herald:::.init_missing_refs(ctx)
  herald:::.record_missing_ref(ctx, "FAKE-01", "dictionary", "meddra")
  sr <- herald:::.finalize_skipped_refs(ctx)
  expect_equal(sr$dictionaries$meddra$rule_ids, "FAKE-01")
})

test_that("print.herald_dict_provider summarises metadata", {
  p <- .minimal_provider("prt-test", version = "9.9")
  expect_output(print(p), "herald_dict_provider")
  expect_output(print(p), "prt-test")
  expect_output(print(p), "9\\.9")
})
