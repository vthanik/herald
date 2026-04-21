# -----------------------------------------------------------------------------
# class-detect.R -- CDISC class auto-detection for loaded datasets
# -----------------------------------------------------------------------------
# Mirrors Pinnacle 21 Community's two-stage class determination (see
# ConfigurationManager.prepare / Template.matches in P21's Java source):
#
# Stage 1 -- named-dataset lookup. For every SDTM 3.x domain and the ADaM
#            structural datasets, P21 keeps an ItemGroupDef config that
#            maps the dataset name to a class. We encode the same lookup
#            in DATASET_CLASS below.
#
# Stage 2 -- topic-variable prototype. For UNRECOGNIZED custom domains
#            P21 iterates val:Prototype entries, each declaring required
#            KeyVariables with "__" as the dataset-prefix placeholder
#            (the Java code's replace("__", name) is our `--<STEM>`
#            convention with first-two-char expansion). We encode the
#            topic map in CLASS_TOPIC_VAR below.
#
# This file exports package-internal helpers used by R/rules-scope.R to
# fill in the class of a dataset when the caller did NOT supply a spec
# via `spec$ds_spec`. A user-supplied spec always wins.

# --- DATASET -> CLASS (Stage 1) ---------------------------------------------

.DATASET_CLASS <- c(
  # ADaM structures
  ADSL      = "SUBJECT LEVEL ANALYSIS DATASET",
  BDS       = "BASIC DATA STRUCTURE",
  ADAE      = "OCCURRENCE DATA STRUCTURE",
  OCCDS     = "OCCURRENCE DATA STRUCTURE",
  ADAMOTHER = "ADAM OTHER",

  # SDTM EVENTS
  AE = "EVENTS", APAE = "EVENTS", APMH = "EVENTS", CE = "EVENTS",
  DE = "EVENTS", DS   = "EVENTS", DT   = "EVENTS", DV = "EVENTS",
  HO = "EVENTS", MH   = "EVENTS",

  # SDTM INTERVENTIONS
  AG = "INTERVENTIONS", CM = "INTERVENTIONS", DX = "INTERVENTIONS",
  EC = "INTERVENTIONS", EX = "INTERVENTIONS", ML = "INTERVENTIONS",
  PR = "INTERVENTIONS", SU = "INTERVENTIONS",

  # SDTM FINDINGS
  CV = "FINDINGS", DA = "FINDINGS", DD = "FINDINGS", DO = "FINDINGS",
  DU = "FINDINGS", EG = "FINDINGS", FT = "FINDINGS", IE = "FINDINGS",
  IS = "FINDINGS", LB = "FINDINGS", MB = "FINDINGS", MI = "FINDINGS",
  MK = "FINDINGS", MO = "FINDINGS", MS = "FINDINGS", NV = "FINDINGS",
  OE = "FINDINGS", PC = "FINDINGS", PE = "FINDINGS", PP = "FINDINGS",
  QS = "FINDINGS", RE = "FINDINGS", RP = "FINDINGS", RS = "FINDINGS",
  SC = "FINDINGS", SS = "FINDINGS", TR = "FINDINGS", TU = "FINDINGS",
  UR = "FINDINGS", VS = "FINDINGS",

  # SDTM FINDINGS ABOUT
  FA = "FINDINGS ABOUT", SR = "FINDINGS ABOUT",

  # SDTM SPECIAL PURPOSE
  APDM = "SPECIAL PURPOSE", CO = "SPECIAL PURPOSE", DI = "SPECIAL PURPOSE",
  DM   = "SPECIAL PURPOSE", DR = "SPECIAL PURPOSE", SE = "SPECIAL PURPOSE",
  SM   = "SPECIAL PURPOSE", SV = "SPECIAL PURPOSE",

  # SDTM TRIAL DESIGN
  TA = "TRIAL DESIGN", TD = "TRIAL DESIGN", TE = "TRIAL DESIGN",
  TI = "TRIAL DESIGN", TM = "TRIAL DESIGN", TS = "TRIAL DESIGN",
  TV = "TRIAL DESIGN",

  # SDTM RELATIONSHIP (SUPP-- handled by prefix; RELREC by name)
  RELREC = "RELATIONSHIP",

  # SDTM 3.3
  OI = "STUDY REFERENCE"
)

# --- PROTOTYPE MATCHING (Stage 2) -------------------------------------------
#
# Mirrors Pinnacle 21's <val:Prototype> table. Each prototype declares:
#   class          -- the CDISC class it identifies
#   name_prefix    -- optional dataset-name prefix filter (e.g. "AD" for
#                     ADaM OCCDS / ADAM OTHER). NULL = no name filter.
#   require_any    -- at least one of these columns must be present.
#                     `--<STEM>` expands to `<DOM2><STEM>` where <DOM2> is
#                     the first two chars of the dataset name.
#   require_none   -- none of these columns may be present (P21's `-VAR`
#                     syntax).
#   score          -- priority when multiple prototypes match (higher
#                     wins). Mirrors P21's match-score ranking.
#
# Ordering matters: first higher-score prototypes are checked first so a
# dataset that could match more than one prototype gets the most specific
# classification.

.PROTOTYPES <- list(
  # --- ADaM --------------------------------------------------------------
  list(class = "BASIC DATA STRUCTURE",
       name_prefix = "AD",
       require_any = c("PARAMCD", "PARAM", "AVAL", "AVALC"),
       require_none = character(),
       score = 40),
  list(class = "OCCURRENCE DATA STRUCTURE",
       name_prefix = "AD",
       require_any = c("--TRT", "--TERM"),
       require_none = c("PARAMCD"),
       score = 30),
  list(class = "ADAM OTHER",
       name_prefix = "AD",
       require_any = character(),   # catch-all for AD* without BDS/OCCDS cues
       require_none = character(),
       score = 10),

  # --- SDTM --------------------------------------------------------------
  list(class = "EVENTS",
       name_prefix = NULL,
       require_any = c("--TERM"),
       require_none = character(),
       score = 25),
  list(class = "INTERVENTIONS",
       name_prefix = NULL,
       require_any = c("--TRT"),
       require_none = character(),
       score = 25),
  list(class = "FINDINGS",
       name_prefix = NULL,
       require_any = c("--TESTCD"),
       require_none = character(),
       score = 25),
  list(class = "FINDINGS ABOUT",
       name_prefix = NULL,
       require_any = c("--OBJ"),
       require_none = character(),
       score = 35),          # more specific than FINDINGS/EVENTS
  list(class = "RELATIONSHIP",
       name_prefix = NULL,
       require_any = c("QNAM"),
       require_none = character(),
       score = 20)
)

# --- resolvers --------------------------------------------------------------

#' Stage 1: class of a dataset by NAME.
#' @noRd
.class_of_dataset_name <- function(ds_name) {
  if (length(ds_name) != 1L) return(NA_character_)
  u <- toupper(as.character(ds_name))
  if (!nzchar(u) || is.na(u)) return(NA_character_)
  # Prefix rules first so SUPPAE etc. don't require enumeration.
  if (grepl("^SUPP[A-Z0-9]{2,}$", u)) return("RELATIONSHIP")
  # Explicit map (named character vector; use [u] to get NA on miss rather
  # than [[u]] which would throw subscriptOutOfBounds).
  val <- unname(.DATASET_CLASS[u])
  if (!is.na(val) && nzchar(val)) return(val)
  # Unknown dataset name -- defer to Stage 2 prototype matching in
  # .class_from_topic which inspects columns to distinguish
  # ADLB/ADQS (BDS via PARAMCD) from ADXX custom (OCCDS via --TRT /
  # --TERM, or ADAM OTHER fallback).
  NA_character_
}

#' Expand a column pattern: `--<STEM>` becomes `<DOM2><STEM>` using the
#' first two chars of `ds_name`; otherwise the pattern is returned as-is.
.expand_col_pattern <- function(pat, ds_name) {
  if (startsWith(pat, "--")) {
    stem <- sub("^--", "", pat)
    return(paste0(substring(toupper(as.character(ds_name)), 1, 2), stem))
  }
  toupper(pat)
}

#' Stage 2: iterate prototypes (ordered by score desc). Return the class
#' of the first prototype whose name_prefix, require_any, and require_none
#' criteria all match. Mirrors Pinnacle 21's val:Prototype table.
#' @noRd
.class_from_topic <- function(ds_name, cols) {
  u_cols  <- toupper(as.character(cols))
  u_dsname <- toupper(as.character(ds_name))

  protos_by_score <- .PROTOTYPES[order(-vapply(.PROTOTYPES,
                                               function(p) as.numeric(p$score),
                                               numeric(1L)))]
  # Check one pattern against the column list. `--<STEM>` matches both the
  # strict 2-char-prefix form (<DOM2><STEM>, P21's `__` convention) and any
  # reasonable prefix (1-7 uppercase chars, for custom domains with longer
  # names). Literal patterns require exact match.
  .matches_any_col <- function(pat, cols, ds_name) {
    if (startsWith(pat, "--")) {
      stem <- sub("^--", "", pat)
      dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
      specific <- paste0(dom2, stem)
      if (specific %in% cols) return(TRUE)
      # Relaxed: any uppercase prefix of 1-7 chars ending in STEM.
      return(any(grepl(sprintf("^[A-Z][A-Z0-9]{0,6}%s$", stem), cols)))
    }
    toupper(pat) %in% cols
  }

  for (p in protos_by_score) {
    if (!is.null(p$name_prefix) &&
        !startsWith(u_dsname, toupper(p$name_prefix))) next
    any_ok <- if (length(p$require_any) == 0L) TRUE else {
      any(vapply(p$require_any, .matches_any_col, logical(1L),
                 cols = u_cols, ds_name = ds_name))
    }
    if (!any_ok) next
    none_ok <- if (length(p$require_none) == 0L) TRUE else {
      !any(vapply(p$require_none, .matches_any_col, logical(1L),
                  cols = u_cols, ds_name = ds_name))
    }
    if (!none_ok) next
    return(p$class)
  }
  NA_character_
}

#' Cascading class resolver: spec -> name lookup -> topic prototype -> NA.
#'
#' @param ds_name dataset name (character scalar)
#' @param cols character vector of column names for `ds_name`
#' @param spec optional herald_spec carrying `$ds_spec` with (dataset, class)
#'   columns. When a row matches `ds_name`, the spec's class wins.
#' @return character(1), possibly NA.
#' @noRd
infer_class <- function(ds_name, cols = character(), spec = NULL) {
  # Caller-supplied spec always wins.
  if (!is.null(spec) && !is.null(spec$ds_spec)) {
    ds_col  <- spec$ds_spec[["dataset"]] %||% spec$ds_spec[["Dataset"]]
    cls_col <- spec$ds_spec[["class"]]   %||% spec$ds_spec[["Class"]]
    if (!is.null(ds_col) && !is.null(cls_col)) {
      hit <- which(toupper(as.character(ds_col)) == toupper(ds_name))
      if (length(hit) > 0L) {
        cls <- as.character(cls_col[hit[[1L]]])
        if (!is.na(cls) && nzchar(cls)) return(cls)
      }
    }
  }
  # Stage 1.
  by_name <- .class_of_dataset_name(ds_name)
  if (!is.na(by_name)) return(by_name)
  # Stage 2.
  by_topic <- .class_from_topic(ds_name, cols)
  if (!is.na(by_topic)) return(by_topic)
  NA_character_
}
