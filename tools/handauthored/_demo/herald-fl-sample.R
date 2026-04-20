# tools/handauthored/_demo/herald-fl-sample.R
# DEMO: authoring rules as R code via tools/rule-dsl.R
# Shows how the hybrid pipeline handles R-authored rules alongside YAMLs.
# Remove this file once real authoring begins in its own .R modules.

# Every ADaM "*FL" flag column must be Y, N, or blank.
# Example: emit ten rules with one loop instead of ten YAML files.
for (var in c("AEFL", "ONTRTFL", "SAFFL", "TRT01FL", "ENRLFL",
              "SCRNFL", "COMPLFL", "ANLFL", "FASFL", "PPROTFL")) {
  rule(
    id             = paste0("HRL-R-FL-", var),
    standard       = "ADaM-IG",
    severity       = "High",
    domains        = "ALL",
    check          = in_set(var, c("Y", "N", NA)),
    message        = sprintf("%s must be 'Y', 'N', or blank", var),
    source_url     = "herald-own (R-DSL demo)",
    source_document = "Demonstration rule authored via tools/rule-dsl.R"
  )
}
