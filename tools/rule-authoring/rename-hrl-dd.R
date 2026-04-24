#!/usr/bin/env Rscript
# rename-hrl-dd.R -- Rename HRL-DD-NNN rules to snake_case IDs
# Updates: id field, outcome.message (→ short error code), filename
# Run from project root: Rscript tools/rule-authoring/rename-hrl-dd.R

RULES_DIR <- "tools/handauthored/cdisc/define-xml-v2.1"

RENAME_MAP <- c(
  "HRL-DD-001" = "define_attribute_length_le_1000",
  "HRL-DD-002" = "define_assigned_value_type_match",
  "HRL-DD-003" = "define_assigned_value_length_le_var",
  "HRL-DD-004" = "define_assigned_value_in_codelist",
  "HRL-DD-005" = "define_iso8601_data_type_for_dtc_dur",
  "HRL-DD-006" = "define_where_clause_value_in_codelist",
  "HRL-DD-007" = "define_paired_terms_same_c_code",
  "HRL-DD-008" = "define_arm_not_in_non_adam",
  "HRL-DD-009" = "define_arm_display_oid_unique",
  "HRL-DD-010" = "define_arm_display_name_unique",
  "HRL-DD-011" = "define_arm_display_description_required",
  "HRL-DD-012" = "define_arm_result_oid_unique",
  "HRL-DD-013" = "define_arm_parameter_oid_required_bds",
  "HRL-DD-014" = "define_arm_parameter_oid_references_paramcd",
  "HRL-DD-015" = "define_suppqual_qnam_has_vlm",
  "HRL-DD-016" = "define_derived_var_has_method_ref",
  "HRL-DD-017" = "define_where_clause_soft_hard_is_soft",
  "HRL-DD-018" = "define_suppqual_ct_codelist_consistency",
  "HRL-DD-019" = "define_predecessor_origin_source_empty",
  "HRL-DD-020" = "define_predecessor_origin_method_empty",
  "HRL-DD-021" = "define_derived_origin_predecessor_empty",
  "HRL-DD-022" = "define_assigned_origin_predecessor_empty",
  "HRL-DD-023" = "define_assigned_origin_method_empty",
  "HRL-DD-024" = "define_study_name_required",
  "HRL-DD-025" = "define_study_description_required",
  "HRL-DD-026" = "define_protocol_name_required",
  "HRL-DD-027" = "define_version_is_2_1",
  "HRL-DD-028" = "define_context_valid_value",
  "HRL-DD-029" = "define_dataset_name_required",
  "HRL-DD-030" = "define_dataset_label_required",
  "HRL-DD-031" = "define_dataset_class_required",
  "HRL-DD-032" = "define_dataset_class_valid_ct",
  "HRL-DD-033" = "define_dataset_subclass_valid_ct",
  "HRL-DD-034" = "define_dataset_structure_required",
  "HRL-DD-035" = "define_dataset_standard_format_valid",
  "HRL-DD-036" = "define_standard_name_valid",
  "HRL-DD-037" = "define_sdtmig_version_valid",
  "HRL-DD-038" = "define_adamig_version_valid",
  "HRL-DD-039" = "define_sendig_version_valid",
  "HRL-DD-040" = "define_dataset_key_vars_required",
  "HRL-DD-041" = "define_dataset_repeating_valid",
  "HRL-DD-042" = "define_reference_data_not_repeating",
  "HRL-DD-043" = "define_dataset_purpose_valid",
  "HRL-DD-044" = "define_variable_name_required",
  "HRL-DD-045" = "define_variable_label_required",
  "HRL-DD-046" = "define_variable_data_type_valid",
  "HRL-DD-047" = "define_variable_length_required",
  "HRL-DD-048" = "define_variable_length_empty_non_scalar",
  "HRL-DD-049" = "define_variable_sig_digits_required",
  "HRL-DD-050" = "define_variable_length_positive_int",
  "HRL-DD-051" = "define_variable_text_length_le_200",
  "HRL-DD-052" = "define_variable_mandatory_valid",
  "HRL-DD-053" = "define_variable_origin_required",
  "HRL-DD-054" = "define_variable_origin_type_valid",
  "HRL-DD-055" = "define_adam_origin_not_available_invalid",
  "HRL-DD-056" = "define_variable_source_required",
  "HRL-DD-057" = "define_adam_derived_source_sponsor",
  "HRL-DD-058" = "define_sdtm_origin_source_valid",
  "HRL-DD-059" = "define_variable_method_required_derived",
  "HRL-DD-060" = "define_variable_pages_required_collected",
  "HRL-DD-061" = "define_variable_predecessor_required",
  "HRL-DD-062" = "define_variable_order_positive_int",
  "HRL-DD-063" = "define_variable_dataset_ref_exists",
  "HRL-DD-064" = "define_vlm_where_clause_required",
  "HRL-DD-065" = "define_vlm_comparator_valid",
  "HRL-DD-066" = "define_vlm_data_type_valid",
  "HRL-DD-067" = "define_vlm_length_le_parent",
  "HRL-DD-068" = "define_vlm_origin_required",
  "HRL-DD-069" = "define_vlm_variable_ref_exists",
  "HRL-DD-070" = "define_vlm_method_required_derived",
  "HRL-DD-071" = "define_codelist_id_required",
  "HRL-DD-072" = "define_codelist_name_unique",
  "HRL-DD-073" = "define_codelist_data_type_valid",
  "HRL-DD-074" = "define_codelist_term_required",
  "HRL-DD-075" = "define_codelist_nci_code_required",
  "HRL-DD-076" = "define_codelist_nci_term_code_required",
  "HRL-DD-077" = "define_codelist_decoded_value_required",
  "HRL-DD-078" = "define_variable_codelist_ref_exists",
  "HRL-DD-079" = "define_method_id_unique",
  "HRL-DD-080" = "define_method_type_valid",
  "HRL-DD-081" = "define_method_description_required",
  "HRL-DD-082" = "define_variable_method_ref_exists",
  "HRL-DD-083" = "define_comment_id_unique",
  "HRL-DD-084" = "define_comment_description_required",
  "HRL-DD-085" = "define_entity_comment_ref_exists",
  "HRL-DD-086" = "define_document_ref_exists",
  "HRL-DD-087" = "define_variable_codelist_oid_exists",
  "HRL-DD-088" = "define_variable_method_oid_exists",
  "HRL-DD-089" = "define_variable_comment_oid_exists",
  "HRL-DD-090" = "define_vlm_codelist_oid_exists",
  "HRL-DD-091" = "define_vlm_method_oid_exists",
  "HRL-DD-092" = "define_vlm_comment_oid_exists",
  "HRL-DD-093" = "define_method_document_oid_exists",
  "HRL-DD-094" = "define_comment_document_oid_exists",
  "HRL-DD-095" = "define_arm_display_ref_exists",
  "HRL-DD-096" = "define_dataset_comment_oid_exists",
  "HRL-DD-097" = "define_method_unreferenced",
  "HRL-DD-098" = "define_comment_unreferenced",
  "HRL-DD-099" = "define_document_unreferenced",
  "HRL-DD-100" = "define_codelist_unreferenced",
  "HRL-DD-101" = "define_arm_analysis_var_unique",
  "HRL-DD-102" = "define_arm_analysis_var_required",
  "HRL-DD-103" = "define_arm_analysis_reason_valid_ct",
  "HRL-DD-104" = "define_arm_analysis_purpose_valid_ct",
  "HRL-DD-105" = "define_variable_origin_consistent",
  "HRL-DD-106" = "define_variable_data_type_matches_codelist",
  "HRL-DD-107" = "define_codelist_extended_value_flagged",
  "HRL-DD-108" = "define_metadata_matches_standard",
  "HRL-DD-109" = "define_version_valid"
)

# Replace multi-line YAML message value with a single-line short code.
# Handles both single-line and folded/continuation forms.
replace_message <- function(txt, new_msg) {
  # Match:  "  message: <anything>" followed by zero or more
  #         "    <continuation>" lines (indented deeper than message:).
  # Replace with single-line form.
  gsub(
    "( {2}message:)[^\n]*(\n    [^\n]*)*",
    paste0("\\1 ", new_msg),
    txt,
    perl = TRUE
  )
}

renamed <- 0L
for (old_id in names(RENAME_MAP)) {
  new_id  <- RENAME_MAP[[old_id]]
  old_file <- file.path(RULES_DIR, paste0(old_id, ".yaml"))
  new_file <- file.path(RULES_DIR, paste0(new_id, ".yaml"))

  if (!file.exists(old_file)) {
    message("SKIP (not found): ", old_file)
    next
  }

  txt <- readLines(old_file, warn = FALSE)
  txt <- paste(txt, collapse = "\n")

  # 1. Replace id: line
  txt <- sub(paste0("^id: ", old_id), paste0("id: ", new_id), txt)

  # 2. Replace outcome.message with short error code (uppercase of new_id)
  error_code <- toupper(new_id)
  txt <- replace_message(txt, error_code)

  writeLines(txt, new_file)
  file.remove(old_file)
  renamed <- renamed + 1L
  message("  ", old_id, " -> ", new_id)
}

cat(sprintf("\nDone: %d rules renamed.\n", renamed))
