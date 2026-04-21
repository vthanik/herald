# tools/rule-authoring/class-map.R
# ----------------------------------------------------------------------------
# CDISC class / domain map used by smoke-check.R (and any other pattern tool)
# to synthesize per-rule fixtures that match each rule's declared scope.
#
# Derived from Pinnacle 21's def:Class taxonomy in the v2204.0 XML configs --
# /Users/vignesh/projects/p21-community/configs/2204.0/{ADaM,SDTM}-IG *.xml.
# This is a *taxonomy map* (publicly documented CDISC structure), not a copy
# of P21's rule expressions.
#
# For each CDISC class, we pick one representative dataset name that a
# synthetic fixture can use. Rules scoped to a class can be exercised against
# that representative dataset; the fixture runner's spec.class_map flag tells
# the engine the class without the fixture having to match any specific real
# dataset.
#
# The map intentionally biases toward datasets already seen in the pilot so
# that downstream real-data tests can reuse the same fixtures.

# --- ADaM-IG ---------------------------------------------------------------
#
# ADaM classes from ADaM-IG 1.0/1.1/1.2/1.3 via P21 config:
#   SUBJECT LEVEL ANALYSIS DATASET -- ADSL (the one authoritative instance)
#   BASIC DATA STRUCTURE           -- BDS (generic); pick ADVS as concrete
#   OCCURRENCE DATA STRUCTURE      -- OCCDS (generic); pick ADAE as concrete
#   ADAM OTHER                     -- ADAMOTHER (generic, free-form)
#   SYSTEM                         -- metadata only (no dataset)

ADAM_CLASS_MAP <- list(
  "SUBJECT LEVEL ANALYSIS DATASET" = "ADSL",
  "BASIC DATA STRUCTURE"           = "ADVS",
  "OCCURRENCE DATA STRUCTURE"      = "ADAE",
  "ADAM OTHER"                     = "ADAMOTHER",
  "SYSTEM"                         = NA_character_
)

# --- SDTM-IG ---------------------------------------------------------------
#
# SDTM classes from SDTM-IG 3.1.2 / 3.1.3 / 3.2 / 3.3 via P21 config:
#   EVENTS                  -- AE (CE, DS, DV, HO, MH, SE are other members)
#   INTERVENTIONS           -- CM (DX, EC, EX, PR, SU, AG, ML)
#   FINDINGS                -- LB (VS, EG, QS, PC, PE, SC, ...)
#   FINDINGS ABOUT          -- FA (SR)
#   SPECIAL PURPOSE         -- DM (CO, SV, SE, DI, DR, APDM)
#   TRIAL DESIGN            -- TA (TE, TI, TM, TS, TV, TD)
#   RELATIONSHIP            -- SUPPAE (SUPPDM, RELREC, ...)
#   SYSTEM                  -- metadata only (no dataset)

SDTM_CLASS_MAP <- list(
  "EVENTS"          = "AE",
  "INTERVENTIONS"   = "CM",
  "FINDINGS"        = "LB",
  "FINDINGS ABOUT"  = "FA",
  "SPECIAL PURPOSE" = "DM",
  "TRIAL DESIGN"    = "TA",
  "RELATIONSHIP"    = "SUPPAE",
  "SYSTEM"          = NA_character_
)

# Combined lookup. Upper-cased keys for case-insensitive matching.
CLASS_TO_DATASET <- c(
  stats::setNames(unlist(ADAM_CLASS_MAP), toupper(names(ADAM_CLASS_MAP))),
  stats::setNames(unlist(SDTM_CLASS_MAP), toupper(names(SDTM_CLASS_MAP)))
)

# --- resolver ---------------------------------------------------------------

#' Given a rule's scope.classes vector, pick the first concrete dataset name
#' from CLASS_TO_DATASET. Returns NA when no class is recognised.
pick_dataset_for_classes <- function(classes) {
  if (length(classes) == 0L) return(NA_character_)
  u <- toupper(as.character(unlist(classes)))
  u <- u[nzchar(u) & u != "ALL"]
  for (cls in u) {
    ds <- CLASS_TO_DATASET[[cls]]
    if (!is.na(ds)) return(list(dataset = ds, class = cls))
  }
  NA_character_
}

#' Resolve a concrete dataset name from either an explicit scope.domains
#' (if populated) or scope.classes via the class map.
#' Returns list(dataset = <name>, class = <class>, via = "domain"|"class").
pick_dataset_for_scope <- function(scope) {
  # Explicit domain wins.
  doms <- toupper(as.character(unlist(scope$domains %||% character())))
  doms <- doms[nzchar(doms) & doms != "ALL" & !grepl("^SUPP", doms) &
               nchar(doms) >= 2L & nchar(doms) <= 8L]
  if (length(doms) > 0L) {
    return(list(dataset = doms[[1L]], class = NA_character_, via = "domain"))
  }
  # Class-based fallback.
  classes <- as.character(unlist(scope$classes %||% character()))
  classes <- classes[nzchar(classes) & toupper(classes) != "ALL"]
  if (length(classes) > 0L) {
    cls <- classes[[1L]]
    ds  <- CLASS_TO_DATASET[[toupper(cls)]]
    if (!is.na(ds)) {
      return(list(dataset = ds, class = cls, via = "class"))
    }
  }
  list(dataset = NA_character_, class = NA_character_, via = "none")
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
