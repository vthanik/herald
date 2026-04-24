# -----------------------------------------------------------------------------
# test-q4-ae-ds-dm.R -- Q4 rules: AE severity compound guards, AE/SUPPAE row
# lookup, DS disposition-event, DM/DD subject-level death flag.
# Covers CG0041, CG0042, CG0043, CG0071, CG0133.
# -----------------------------------------------------------------------------

.ae_frame <- function(aeser, flags = list()) {
  cols <- list(
    STUDYID  = rep("S", length(aeser)),
    USUBJID  = paste0("S-", seq_along(aeser)),
    AESEQ    = seq_along(aeser),
    AETERM   = rep("X", length(aeser)),
    AEDECOD  = rep("X", length(aeser)),
    AESTDTC  = rep("2024-01-01", length(aeser)),
    AESER    = aeser
  )
  for (nm in c("AESCAN", "AESCONG", "AESDISAB", "AESDTH",
               "AESHOSP", "AESLIFE", "AESOD", "AESMIE")) {
    cols[[nm]] <- if (!is.null(flags[[nm]])) flags[[nm]] else rep("", length(aeser))
  }
  as.data.frame(cols, stringsAsFactors = FALSE)
}

.count_fired <- function(res, rule_id) {
  f <- res$findings[res$findings$rule_id == rule_id &
                      res$findings$status == "fired", , drop = FALSE]
  nrow(f)
}

# ---- CG0041 -- AESER must be 'Y' when any sub-flag is 'Y' -------------------

test_that("CG0041 fires when any sub-flag is 'Y' AND AESER != 'Y'", {
  ae <- .ae_frame(
    aeser = c("N", "Y", "N", ""),
    flags = list(AESCAN = c("Y", "Y", "", ""),
                 AESHOSP = c("",  "", "", "Y"))
  )
  r <- validate(files = list(AE = ae), rules = "CG0041", quiet = TRUE)
  # Row 1: AESCAN='Y', AESER='N'  -> fire
  # Row 2: AESCAN='Y', AESER='Y'  -> no fire (assertion FALSE)
  # Row 3: no sub-flag Y          -> no fire (guard FALSE)
  # Row 4: AESHOSP='Y', AESER=''  -> fire
  expect_equal(.count_fired(r, "CG0041"), 2L)
})

test_that("CG0041 does not fire when every sub-flag is null", {
  ae <- .ae_frame(aeser = c("N", "N"))
  r <- validate(files = list(AE = ae), rules = "CG0041", quiet = TRUE)
  expect_equal(.count_fired(r, "CG0041"), 0L)
})

# ---- CG0042 -- AESER must be 'N' when every sub-flag != 'Y' -----------------

test_that("CG0042 fires when all seven sub-flags not 'Y' AND AESER != 'N'", {
  ae <- .ae_frame(
    aeser = c("Y", "N", "Y"),
    flags = list(AESCAN = c("",  "",  "Y"))
  )
  r <- validate(files = list(AE = ae), rules = "CG0042", quiet = TRUE)
  # Row 1: all flags null, AESER='Y' -> fire
  # Row 2: all flags null, AESER='N' -> no fire (assertion FALSE)
  # Row 3: AESCAN='Y', AESER='Y'     -> no fire (guard FALSE)
  expect_equal(.count_fired(r, "CG0042"), 1L)
})

# ---- CG0043 -- AESMIE must be 'Y' when SUPPAE.QNAM='AESOSP' exists ---------

test_that("CG0043 fires when SUPPAE.QNAM='AESOSP' present AND AESMIE != 'Y'", {
  ae <- data.frame(
    STUDYID = "S",
    USUBJID = c("S-1", "S-2", "S-3"),
    AESEQ   = c(1L, 1L, 1L),
    AETERM  = c("X", "Y", "Z"),
    AESTDTC = c("2024-01-01", "2024-01-02", "2024-01-03"),
    AESER   = c("Y", "Y", "N"),
    AESMIE  = c("N", "Y", "N"),
    stringsAsFactors = FALSE
  )
  suppae <- data.frame(
    STUDYID = "S",
    RDOMAIN = "AE",
    USUBJID = c("S-1", "S-2"),
    IDVAR   = "AESEQ",
    IDVARVAL = "1",
    QNAM    = c("AESOSP", "OTHER"),
    QLABEL  = c("Other", "Other"),
    QVAL    = c("desc", "foo"),
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(AE = ae, SUPPAE = suppae),
                rules = "CG0043", quiet = TRUE)
  # S-1: SUPPAE AESOSP row exists, AESMIE='N' -> fire
  # S-2: SUPPAE AESOSP NO (only OTHER), AESMIE='Y' -> no fire (guard FALSE)
  # S-3: no SUPPAE row, AESMIE='N' -> no fire (guard FALSE)
  expect_equal(.count_fired(r, "CG0043"), 1L)
})

test_that("CG0043 emits advisory when SUPPAE dataset missing", {
  ae <- data.frame(
    STUDYID = "S", USUBJID = "S-1", AESEQ = 1L,
    AETERM = "X", AESTDTC = "2024-01-01",
    AESER = "Y", AESMIE = "N",
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(AE = ae), rules = "CG0043", quiet = TRUE)
  expect_equal(.count_fired(r, "CG0043"), 0L)
})

# ---- CG0071 -- DSTERM populated when DSCAT='DISPOSITION EVENT' --------------

test_that("CG0071 fires when DSCAT='DISPOSITION EVENT' AND DSTERM empty", {
  ds <- data.frame(
    STUDYID = "S",
    USUBJID = c("S-1", "S-2", "S-3", "S-4"),
    DSSEQ   = 1:4,
    DSCAT   = c("DISPOSITION EVENT", "DISPOSITION EVENT",
                "OTHER EVENT", "DISPOSITION EVENT"),
    DSTERM  = c("", "COMPLETED", "", "ADVERSE EVENT"),
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(DS = ds), rules = "CG0071", quiet = TRUE)
  # Row 1: DSCAT match + DSTERM empty -> fire
  # Row 2: DSCAT match + DSTERM populated -> no fire
  # Row 3: DSCAT not match -> no fire (guard FALSE)
  # Row 4: DSCAT match + DSTERM populated -> no fire
  expect_equal(.count_fired(r, "CG0071"), 1L)
})

# ---- CG0133 -- DTHFL='Y' when DD record present for subject -----------------

test_that("CG0133 fires when DD has record for subject AND DTHFL != 'Y'", {
  dm <- data.frame(
    STUDYID = "S",
    USUBJID = c("S-1", "S-2", "S-3"),
    DTHFL   = c("N", "Y", ""),
    stringsAsFactors = FALSE
  )
  dd <- data.frame(
    STUDYID = "S",
    USUBJID = c("S-1", "S-2"),
    DDSEQ   = c(1L, 1L),
    DDTESTCD = c("CAUSE", "CAUSE"),
    DDORRES  = c("CARDIAC", "CARDIAC"),
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(DM = dm, DD = dd), rules = "CG0133", quiet = TRUE)
  # S-1: DD record exists + DTHFL='N' -> fire
  # S-2: DD record exists + DTHFL='Y' -> no fire (assertion FALSE)
  # S-3: no DD record                 -> no fire (guard FALSE)
  expect_equal(.count_fired(r, "CG0133"), 1L)
})

test_that("CG0133 emits no fire when DD dataset absent", {
  dm <- data.frame(
    STUDYID = "S", USUBJID = "S-1", DTHFL = "N",
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(DM = dm), rules = "CG0133", quiet = TRUE)
  expect_equal(.count_fired(r, "CG0133"), 0L)
})
