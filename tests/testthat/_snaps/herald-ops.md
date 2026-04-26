# .get_op() error message lists registered operators

    Code
      herald:::.get_op("totally_unknown_op_xyz")
    Condition
      Error in `herald:::.get_op()`:
      ! Unknown operator "totally_unknown_op_xyz".
      i Registered operators: "any_index_missing_ref_var", "any_value_exceeds_length", "any_var_label_exceeds_length", "any_var_name_exceeds_length", "any_var_name_not_matching_regex", "arm_absent_in_non_adam_define", "arm_analysisresult_oid_unique", "arm_description_required", "arm_name_unique", "arm_oid_unique", "assigned_value_length_le_var_length", "assigned_value_matches_data_type", "attr_mismatch", "base_not_equal_abl_row", "contains", "contains_all", "dataset_label_not", "dataset_name_length_not_in_range", ..., "var_present_in_any_other_dataset", and "where_clause_value_in_codelist"

