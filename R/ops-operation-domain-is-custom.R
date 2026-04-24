# ops-operation-domain-is-custom.R -- domain_is_custom operation
# Returns "yes" when the current dataset name is a custom (non-standard) SDTM
# domain, "no" otherwise. A domain is custom when its 2-char prefix does not
# appear in the fixed set of CDISC-defined SDTM/SEND domain codes.
# Unlocks: CG0349 (2-char prefix of custom-domain variable must match DOMAIN).

.SDTM_STANDARD_DOMAINS <- c(
  "AE","AG","AP","APTE","CE","CM","CO","CV","DA","DD","DM","DO","DS","DV",
  "EC","EG","EX","FA","FT","GF","HO","IE","IS","LB","MB","MH","MI","MK",
  "ML","MO","MS","NV","OE","PC","PE","PF","PG","PK","PP","PR","QS","RE",
  "RP","RS","SC","SE","SK","SL","SM","SR","SS","SU","SV","TA","TD","TE",
  "TI","TM","TP","TS","TV","TX","UR","VS","XB","RELREC","RELSUB","SUPPQUAL",
  "DX","OI","OT"
)

.op_operation_domain_is_custom <- function(data, ctx, params) {
  ds <- toupper(ctx$current_dataset %||% "")
  prefix <- substr(ds, 1L, 2L)
  nzchar(prefix) && !prefix %in% .SDTM_STANDARD_DOMAINS
}

.register_operation(
  "domain_is_custom",
  .op_operation_domain_is_custom,
  meta = list(
    kind      = "cross",
    summary   = "\"yes\" when current dataset is a custom (non-standard) SDTM domain.",
    returns   = "scalar",
    cost_hint = "O(1)"
  )
)
