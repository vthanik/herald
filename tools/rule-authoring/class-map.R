# tools/rule-authoring/class-map.R
# ----------------------------------------------------------------------------
# CDISC class taxonomy used by rule-authoring pattern tools to decide which
# dataset(s) a class-scoped rule applies to and how to synthesize a fixture
# that the engine will accept as a member of that class.
#
# The canonical class is determined by the DATASET, not the other way around.
# Two lookups exist, mirroring how Pinnacle 21 Community's 2204.0 XML config
# handles this:
#
# 1. Known-dataset -> class map (DATASET_CLASS): from P21's
#    ItemGroupDef `def:Class` entries. Authoritative for every named SDTM
#    domain and ADaM structure.
# 2. Topic-variable prototypes (CLASS_TOPIC_VAR): from P21's
#    <val:Prototype KeyVariables="..."/> entries. Used to infer class when
#    the dataset name is not in the static map (custom domains), and to
#    instantiate a valid topic column in a synthetic fixture.
#
# Reference: /Users/vignesh/projects/p21-community/configs/2204.0/*.xml.
# We reference the taxonomy (public CDISC structure), not P21's rule
# expressions.

# --- DATASET -> CLASS ------------------------------------------------------
#
# Extracted from P21 SDTM-IG 3.2 (FDA).xml + SDTM-IG 3.3 (FDA).xml +
# ADaM-IG 1.1 (FDA).xml ItemGroupDef entries. Covers every SDTM 3.x domain
# P21 recognises plus the ADaM structural classes. SUPP-- / RELREC domains
# are handled by prefix matching in `class_of_dataset()` below, not by
# enumerated entries (supp-- domains multiply across parent domains).

DATASET_CLASS <- c(
  # --- ADaM structures ---
  ADSL      = "SUBJECT LEVEL ANALYSIS DATASET",
  BDS       = "BASIC DATA STRUCTURE",
  ADAE      = "OCCURRENCE DATA STRUCTURE",
  OCCDS     = "OCCURRENCE DATA STRUCTURE",
  ADAMOTHER = "ADAM OTHER",

  # --- SDTM EVENTS ---
  AE   = "EVENTS", APAE = "EVENTS", APMH = "EVENTS", CE = "EVENTS",
  DE   = "EVENTS", DS   = "EVENTS", DT   = "EVENTS", DV = "EVENTS",
  HO   = "EVENTS", MH   = "EVENTS",

  # --- SDTM INTERVENTIONS ---
  AG = "INTERVENTIONS", CM = "INTERVENTIONS", DX = "INTERVENTIONS",
  EC = "INTERVENTIONS", EX = "INTERVENTIONS", ML = "INTERVENTIONS",
  PR = "INTERVENTIONS", SU = "INTERVENTIONS",

  # --- SDTM FINDINGS ---
  CV = "FINDINGS", DA = "FINDINGS", DD = "FINDINGS", DO = "FINDINGS",
  DU = "FINDINGS", EG = "FINDINGS", FT = "FINDINGS", IE = "FINDINGS",
  IS = "FINDINGS", LB = "FINDINGS", MB = "FINDINGS", MI = "FINDINGS",
  MK = "FINDINGS", MO = "FINDINGS", MS = "FINDINGS", NV = "FINDINGS",
  OE = "FINDINGS", PC = "FINDINGS", PE = "FINDINGS", PP = "FINDINGS",
  QS = "FINDINGS", RE = "FINDINGS", RP = "FINDINGS", RS = "FINDINGS",
  SC = "FINDINGS", SS = "FINDINGS", TR = "FINDINGS", TU = "FINDINGS",
  UR = "FINDINGS", VS = "FINDINGS",

  # --- SDTM FINDINGS ABOUT ---
  FA = "FINDINGS ABOUT", SR = "FINDINGS ABOUT",

  # --- SDTM SPECIAL PURPOSE ---
  APDM = "SPECIAL PURPOSE", CO = "SPECIAL PURPOSE", DI = "SPECIAL PURPOSE",
  DM   = "SPECIAL PURPOSE", DR = "SPECIAL PURPOSE", SE = "SPECIAL PURPOSE",
  SM   = "SPECIAL PURPOSE", SV = "SPECIAL PURPOSE",

  # --- SDTM TRIAL DESIGN ---
  TA = "TRIAL DESIGN", TD = "TRIAL DESIGN", TE = "TRIAL DESIGN",
  TI = "TRIAL DESIGN", TM = "TRIAL DESIGN", TS = "TRIAL DESIGN",
  TV = "TRIAL DESIGN",

  # --- SDTM RELATIONSHIP (RELREC by name; SUPP-- handled by prefix) ---
  RELREC = "RELATIONSHIP",

  # --- SDTM 3.3 STUDY REFERENCE ---
  OI = "STUDY REFERENCE"
)

# Inverse: class -> character vector of member datasets.
DATASETS_IN_CLASS <- split(names(DATASET_CLASS), unname(DATASET_CLASS))

# --- TOPIC-VARIABLE PROTOTYPES --------------------------------------------
#
# From P21 val:Prototype KeyVariables. The `--` placeholder is P21's
# convention for "any two-char domain prefix"; we expand it when
# synthesising concrete column names (`AETERM`, `MHTERM`, `LBTESTCD`).

CLASS_TOPIC_VAR <- list(
  "EVENTS"         = "--TERM",
  "INTERVENTIONS"  = "--TRT",
  "FINDINGS"       = "--TESTCD",
  "FINDINGS ABOUT" = "--OBJ",
  "RELATIONSHIP"   = "QNAM"
)

# --- resolvers --------------------------------------------------------------

#' Look up the canonical class of a named dataset.
#' Returns NA_character_ when the name is unknown and no prefix rule applies.
class_of_dataset <- function(ds_name) {
  if (length(ds_name) != 1L) return(NA_character_)
  u <- toupper(as.character(ds_name))
  if (!nzchar(u) || is.na(u)) return(NA_character_)
  # SUPP-- : any split-dataset domain belongs to RELATIONSHIP.
  if (grepl("^SUPP[A-Z0-9]{2,}$", u)) return("RELATIONSHIP")
  val <- DATASET_CLASS[[u]]
  if (is.null(val)) return(NA_character_)
  val
}

#' Infer class from a column vector (e.g. names of a data frame) using the
#' SDTM `--<TOPIC>` convention. Returns NA_character_ when no prototype
#' matches. Checks classes in a deterministic order so a dataset with both
#' `--TERM` and `--TESTCD` (unlikely) resolves to EVENTS first.
class_from_topic <- function(colnames) {
  u <- toupper(as.character(colnames))
  for (cls in names(CLASS_TOPIC_VAR)) {
    topic <- CLASS_TOPIC_VAR[[cls]]
    if (startsWith(topic, "--")) {
      stem <- sub("^--", "", topic)
      pat  <- sprintf("^[A-Z][A-Z0-9]?%s$", stem)
      if (any(grepl(pat, u))) return(cls)
    } else if (any(u == toupper(topic))) {
      return(cls)
    }
  }
  NA_character_
}

#' Return the concrete topic column name for a given class + dataset-name
#' context. Expands `--<STEM>` to `<DOM2><STEM>` using the first two chars
#' of the dataset name.
topic_col_for_class <- function(class, ds_name) {
  topic <- CLASS_TOPIC_VAR[[toupper(as.character(class %||% ""))]]
  if (is.null(topic)) return(NA_character_)
  if (startsWith(topic, "--")) {
    stem <- sub("^--", "", topic)
    return(paste0(substring(toupper(as.character(ds_name)), 1, 2), stem))
  }
  topic
}

#' Given a rule's scope (list with $domains, $classes), pick a concrete
#' dataset name + its class + (optional) topic column for fixture synthesis.
#' Preference order:
#'   1. explicit scope.domains -- use the first concrete domain name.
#'   2. explicit scope.classes -- pick the canonical member dataset for
#'      that class via DATASETS_IN_CLASS (first alphabetically, which is a
#'      stable, reviewer-friendly choice).
#'   3. none -- return all-NA (caller falls back to default fixture).
pick_dataset_for_scope <- function(scope) {
  # 1. Explicit domain.
  doms <- toupper(as.character(unlist(scope$domains %||% character())))
  doms <- doms[nzchar(doms) & doms != "ALL" & nchar(doms) >= 2L &
               nchar(doms) <= 8L & !grepl("^SUPP", doms)]
  if (length(doms) > 0L) {
    ds <- doms[[1L]]
    return(list(dataset = ds, class = class_of_dataset(ds),
                topic_col = topic_col_for_class(class_of_dataset(ds), ds),
                via = "domain"))
  }
  # 2. Class-based.
  classes <- as.character(unlist(scope$classes %||% character()))
  classes <- classes[nzchar(classes) & toupper(classes) != "ALL"]
  if (length(classes) > 0L) {
    cls <- classes[[1L]]
    cand <- DATASETS_IN_CLASS[[toupper(cls)]]
    if (length(cand) > 0L) {
      ds <- sort(cand)[[1L]]
      return(list(dataset = ds, class = cls,
                  topic_col = topic_col_for_class(cls, ds),
                  via = "class"))
    }
  }
  list(dataset = NA_character_, class = NA_character_,
       topic_col = NA_character_, via = "none")
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
