# Operator catalog

An **operator** (or “op”) is the executable kernel of a herald rule.
Each op is a function `op_<name>(data, ctx, ...)` that returns a logical
vector the same length as `nrow(data)`: `TRUE` means the record fires
the rule (a finding is emitted), `FALSE` means the record passes, and
`NA` means the check is indeterminate (recorded as advisory). Rules in
the YAML corpus refer to ops by name; the validation engine looks them
up in the operator registry at run time.

The catalog below is generated at build time from the live registry. For
the broader picture of how ops fit into the layer stack, see the
[Architecture](https://vthanik.github.io/herald/architecture.md)
article. For guidance on writing new ops, see the operator pattern notes
in `.claude/rules/r-code.md`.

Ops are grouped by `kind`:

- **set** – membership / codelist / domain checks.
- **compare** – value comparisons against a literal or expression.
- **existence** – presence, absence, completeness, uniqueness.
- **temporal** – date / datetime ordering and ISO 8601 conformance.
- **cross** – references another dataset via `.ref_ds(ctx, name)`.
- **string** – regex, length, casing, whitespace.

Total registered operators: **119**.

## set (16)

| name                                 | summary                                                                                  | args                                                                                       | cost | NA ok |
|:-------------------------------------|:-----------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------|:-----|:------|
| contains_all                         | Column value tokenises to a superset of `value` (all needed tokens present)              | name:string*, value:list*                                                                  | O(n) | yes   |
| is_contained_by                      | Column value is in set                                                                   | name:string*, value:list*                                                                  | O(n) | yes   |
| is_contained_by_case_insensitive     | Column value is in set (case-insensitive)                                                | name:string*, value:list*                                                                  | O(n) | yes   |
| is_not_contained_by                  | Column value is not in set                                                               | name:string*, value:list*                                                                  | O(n) | yes   |
| is_not_contained_by_case_insensitive | Column value is not in set (case-insensitive)                                            | name:string*, value:list*                                                                  | O(n) | yes   |
| is_not_ordered_subset_of             | Column value breaks the ordered-subset invariant (out of order or unknown value)         | name:string*, value:list*                                                                  | O(n) | yes   |
| is_not_unique_set                    | Row’s column value is duplicated within dataset                                          | name:list\*                                                                                | O(n) | yes   |
| is_ordered_subset_of                 | Column value is in the ordered universe AND follows row-order (monotonic within dataset) | name:string*, value:list*                                                                  | O(n) | yes   |
| is_unique_set                        | Row’s column (or composite key) value is unique within dataset                           | name:list\*                                                                                | O(n) | yes   |
| not_contains_all                     | Column value is missing at least one required token                                      | name:string*, value:list*                                                                  | O(n) | yes   |
| prefix_is_not_contained_by           | First N characters of the column value are not in the allowed set.                       | name:string*, prefix:integer, value:array*                                                 | O(n) | no    |
| shares_no_elements_with              | Column value shares no tokens with the banned set                                        | name:string*, value:list*                                                                  | O(n) | yes   |
| suffix_is_not_contained_by           | Last N characters of the column value are not in the allowed set.                        | name:string*, suffix:integer, value:array*                                                 | O(n) | no    |
| value_in_codelist                    | Row value is in the named CDISC CT codelist                                              | name:string*, codelist:string*, extensible:boolean, match_synonyms:boolean, package:string | O(n) | yes   |
| value_in_dictionary                  | Row value is in the named external dictionary (fires when not found)                     | name:string\*, dict_name:string, field:string                                              | O(n) | yes   |
| value_in_srs_table                   | Row value is in the FDA SRS / UNII registry (fires when not found)                       | name:string\*, field:string                                                                | O(n) | yes   |

## compare (19)

| name                                | summary                                                                 | args                                               | cost       | NA ok |
|:------------------------------------|:------------------------------------------------------------------------|:---------------------------------------------------|:-----------|:------|
| arm_analysisresult_oid_unique       | arm:AnalysisResult OID must be unique within its ResultDisplay          |                                                    | O(n)       | no    |
| arm_name_unique                     | arm:ResultDisplay Name must be unique                                   |                                                    | O(n)       | no    |
| arm_oid_unique                      | arm:ResultDisplay OID must be unique                                    |                                                    | O(n)       | no    |
| assigned_value_length_le_var_length | Assigned value length must not exceed variable Length                   |                                                    | O(n)       | no    |
| assigned_value_matches_data_type    | Assigned value type must match variable DataType                        |                                                    | O(n)       | no    |
| define_version_matches_schema       | def:DefineVersion must be 2.0.0 or 2.1.0                                |                                                    | O(n)       | no    |
| does_not_equal_string_part          | TRUE when column value != the specified chars of the dataset name.      | name:string\*, start:integer, end:integer          | O(n)       | yes   |
| equal_to                            | Column value equals a literal or another column                         | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| equal_to_case_insensitive           | Case-insensitive equality                                               | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| equal_to_ci                         | Case-insensitive equality (short alias)                                 | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| greater_than                        | Column numeric value is strictly greater than threshold                 | name:string*, value:numeric*                       | O(n)       | yes   |
| greater_than_or_equal_to            | Column numeric value \>= threshold                                      | name:string*, value:numeric*                       | O(n)       | yes   |
| iso8601_data_type_match             | –DTC/–DUR variables must not have DataType ‘text’                       |                                                    | O(n)       | no    |
| less_than                           | Column numeric value \< threshold                                       | name:string*, value:numeric*                       | O(n)       | yes   |
| less_than_or_equal_to               | Column numeric value \<= threshold                                      | name:string*, value:numeric*                       | O(n)       | yes   |
| not_equal_to                        | Column value does not equal literal / column                            | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| not_equal_to_case_insensitive       | Case-insensitive inequality                                             | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| not_equal_to_ci                     | Case-insensitive inequality (short alias)                               | name:string*, value:any*, value_is_literal:logical | O(n)       | yes   |
| target_is_not_sorted_by             | TRUE on rows where the column breaks ascending order within each group. | name:string\*, order_by:string                     | O(n log n) | yes   |

## existence (20)

| name                                | summary                                                                                       | args                                           | cost    | NA ok |
|:------------------------------------|:----------------------------------------------------------------------------------------------|:-----------------------------------------------|:--------|:------|
| any_value_exceeds_length            | Per row: at least one character column has a value longer than the byte-length cap            | value:integer\*                                | O(n\*m) | no    |
| any_var_label_exceeds_length        | Fires when any variable label exceeds the byte-length cap                                     | value:integer\*                                | O(1)    | no    |
| any_var_name_exceeds_length         | Fires when any variable name exceeds the byte-length cap                                      | value:integer\*                                | O(1)    | no    |
| any_var_name_not_matching_regex     | Fires when any variable name does not match the required regex                                | value:string\*                                 | O(1)    | no    |
| arm_description_required            | arm:ResultDisplay must have a Description                                                     |                                                | O(n)    | no    |
| dataset_label_not                   | Dataset label (attr ‘label’) does not equal the expected string                               | expected:string\*                              | O(1)    | yes   |
| dataset_name_length_not_in_range    | Dataset name length is outside the required \[min_len, max_len\] range                        | min_len:integer, max_len:integer               | O(1)    | no    |
| dataset_name_prefix_not             | Dataset name prefix vs class check (ADaM-496 / ADaM-497 pattern)                              | prefix:string\*, when_class_is_missing:boolean | O(1)    | no    |
| empty                               | Column value is NA or empty string                                                            | name:string\*                                  | O(n)    | yes   |
| exists                              | Column is present in dataset (dataset-wide assertion)                                         | name:string\*                                  | O(1)    | no    |
| has_same_values                     | TRUE when all non-NA rows share the same value (over-grouping check).                         | name:string\*                                  | O(n)    | yes   |
| inconsistent_enumerated_columns     | TRUE when an enumerated column gap exists (n+1 non-null while n null).                        | name:string\*                                  | O(n\*m) | no    |
| is_missing                          | Synonym of empty: value is NA or empty string                                                 | name:string\*                                  | O(n)    | yes   |
| is_present                          | Synonym of non_empty: value is not NA and not empty                                           | name:string\*                                  | O(n)    | yes   |
| label_by_suffix_missing             | Fires when any variable whose name ends in `suffix` has a label that does not contain `value` | suffix:string*, value:string*                  | O(1)    | no    |
| no_var_with_suffix                  | No column in the dataset has a name ending with the given suffix                              | suffix:string\*                                | O(n)    | no    |
| non_empty                           | Column value is not NA and not empty string                                                   | name:string\*                                  | O(n)    | yes   |
| not_exists                          | Column is absent from dataset                                                                 | name:string\*                                  | O(1)    | no    |
| not_present_on_multiple_rows_within | TRUE when the value appears on fewer than 2 rows within each group.                           | name:string\*, within:string                   | O(n)    | yes   |
| var_by_suffix_not_numeric           | Column resolved by suffix wildcard is not a numeric variable                                  | name:string\*, exclude_prefix:string           | O(1)    | yes   |

## temporal (11)

| name                          | summary                                                           | args                       | cost | NA ok |
|:------------------------------|:------------------------------------------------------------------|:---------------------------|:-----|:------|
| date_equal_to                 | Date column == literal / other date column                        | name:string*, value:any*   | O(n) | yes   |
| date_greater_than             | Date column \> literal / other date column                        | name:string*, value:any*   | O(n) | yes   |
| date_greater_than_or_equal_to | Date column \>= literal / other date column                       | name:string*, value:any*   | O(n) | yes   |
| date_less_than                | Date column \< literal / other date column                        | name:string*, value:any*   | O(n) | yes   |
| date_less_than_or_equal_to    | Date column \<= literal / other date column                       | name:string*, value:any*   | O(n) | yes   |
| date_not_equal_to             | Date column != literal / other date column                        | name:string*, value:any*   | O(n) | yes   |
| invalid_date                  | Date value is not valid SDTM ISO 8601 format                      | name:string\*              | O(n) | yes   |
| invalid_duration              | Duration value is not valid ISO 8601 duration                     | name:string\*              | O(n) | yes   |
| is_complete_date              | SDTM –DTC date portion is YYYY-MM-DD (no dash-substitutions)      | name:string\*              | O(n) | yes   |
| is_incomplete_date            | SDTM –DTC date portion is partial (dash-substituted or truncated) | name:string\*              | O(n) | yes   |
| value_not_iso8601             | Value does not conform to ISO 8601 date or duration format        | name:string\*, kind:string | O(n) | yes   |

## cross (39)

| name                                    | summary                                                                                                 | args                                                                                                                            | cost       | NA ok |
|:----------------------------------------|:--------------------------------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------|:-----------|:------|
| any_index_missing_ref_var               | For each unique value of the index column, the reference dataset is missing the templated variable      | name:string*, reference_dataset:string*, name_template:string\*, placeholder:string                                             | O(n)       | yes   |
| arm_absent_in_non_adam_define           | ARM metadata must not appear in non-ADaM defines                                                        |                                                                                                                                 | O(n)       | no    |
| attr_mismatch                           | Column attribute differs between current and reference dataset                                          | name:string*, attribute:string*, reference_dataset:string\*                                                                     | O(1)       | yes   |
| base_not_equal_abl_row                  | b_var is populated and not equal to a_var on the anchor row (abl_col==abl_value) within each group      | b_var:string*, a_var:string*, group_by:array\*, abl_col:string, abl_value:string, basetype_gate:string                          | O(n)       | yes   |
| differs_by_key                          | Value differs from joined reference-dataset value (join by key)                                         | name:string*, reference_dataset:string*, reference_column:string\*, key:any, reference_key:any                                  | O(n)       | yes   |
| does_not_have_next_corresponding_record | Key has no matching record in a reference dataset                                                       | name:string*, value:any*                                                                                                        | O(n)       | yes   |
| greater_than_by_key                     | Row value is strictly greater than the joined reference value                                           | name:string*, reference_dataset:string*, reference_column:string\*, key:string, reference_key:string                            | O(n)       | yes   |
| greater_than_or_equal_by_key            | Row value is greater than or equal to the joined reference value                                        | name:string*, reference_dataset:string*, reference_column:string\*, key:string, reference_key:string                            | O(n)       | yes   |
| has_next_corresponding_record           | Key has matching record in a reference dataset                                                          | name:string*, value:any*                                                                                                        | O(n)       | yes   |
| is_inconsistent_across_dataset          | Value differs from same subject/key’s value in a reference dataset                                      | name:string*, value:any*                                                                                                        | O(n)       | yes   |
| is_not_constant_per_group               | Within each group_by bucket, `name` has more than one distinct non-NA value                             | name:string*, group_by:array*                                                                                                   | O(n log n) | yes   |
| is_not_diff                             | Stored `name` value does not equal (minuend - subtrahend) within epsilon                                | name:string*, minuend:string*, subtrahend:string\*, epsilon:numeric                                                             | O(n)       | yes   |
| is_not_pct_diff                         | Stored `name` value does not equal ((minuend - subtrahend) / denominator \* 100) within epsilon         | name:string*, minuend:string*, subtrahend:string\*, denominator:string, epsilon:numeric                                         | O(n)       | yes   |
| is_not_unique_relationship              | Column X maps to more than one value of related column Y                                                | name:string*, value:any*                                                                                                        | O(n log n) | yes   |
| is_unique_relationship                  | Column X maps to exactly one value of related column Y (1:1)                                            | name:string*, value:any*                                                                                                        | O(n log n) | yes   |
| key_not_unique_per_define               | Record not unique per sponsor-defined key variables from define.xml                                     |                                                                                                                                 | O(n)       | yes   |
| less_than_by_key                        | Row value is strictly less than the joined reference value                                              | name:string*, reference_dataset:string*, reference_column:string\*, key:string, reference_key:string                            | O(n)       | yes   |
| less_than_or_equal_by_key               | Row value is less than or equal to the joined reference value                                           | name:string*, reference_dataset:string*, reference_column:string\*, key:string, reference_key:string                            | O(n)       | yes   |
| matches_by_key                          | Value matches joined reference-dataset value (join by key)                                              | name:string*, reference_dataset:string*, reference_column:string\*, key:string, reference_key:string                            | O(n)       | yes   |
| max_n_records_per_group_matching        | fires when more than max_n rows per group match a value                                                 | name:string*, value:string*, group_keys:array\*, max_n:integer                                                                  | O(n)       | yes   |
| missing_in_ref                          | Row’s key has no matching record in the reference dataset                                               | name:string*, reference_dataset:string*, key:string, reference_key:string                                                       | O(n)       | yes   |
| next_row_not_equal                      | Current row `name` does not equal next row `prev_name` (within group ordered by order_by)               | name:string*, value:object*                                                                                                     | O(n log n) | yes   |
| no_baseline_record                      | Group has `name` populated on at least one row but no row with flag_var equal to flag_value             | name:string*, flag_var:string*, flag_value:string*, group_by:array*                                                             | O(n)       | yes   |
| not_equal_subject_templated_ref         | Row value differs from the reference-dataset value in a template-resolved column, joined by subject key | name:string*, reference_dataset:string*, reference_template:string*, index_cols:object*, key:string, reference_key:string       | O(n\*m)    | yes   |
| ref_col_empty                           | Reference dataset’s column is null/empty (or no matching ref row) for this row’s key                    | name:string*, value:any*                                                                                                        | O(n)       | yes   |
| ref_col_populated                       | Reference dataset has a matching ref row and its column is populated                                    | name:string*, value:any*                                                                                                        | O(n)       | yes   |
| ref_column_domains_exist                | Fires per row when the domain code in reference_column is not a loaded dataset                          | reference_column:string\*                                                                                                       | O(n)       | yes   |
| shared_attr_mismatch                    | Any column shared with the reference dataset has a differing attribute                                  | attribute:string*, reference_dataset:string*, exclude:array                                                                     | O(n\*m)    | yes   |
| shared_values_mismatch_by_key           | Any shared column value differs from the reference dataset value joined by subject key                  | reference_dataset:string\*, key:string, reference_key:string, exclude:array                                                     | O(n\*m)    | yes   |
| study_day_mismatch                      | SDTM –STDY/–ENDY stored value differs from CDISC-computed day offset from subject’s anchor date         | name:string*, reference_dataset:string*, reference_column:string*, target_date_column:string*, key:string, reference_key:string | O(n)       | yes   |
| study_metadata_is                       | TRUE when study_metadata\[\[key\]\] contains value; NA when study_metadata not supplied                 | key:string*, value:string*                                                                                                      | O(1)       | yes   |
| subject_has_matching_row                | Reference dataset has at least one row with matching key AND reference_column equal to expected_value   | name:string*, reference_dataset:string*, reference_column:string*, expected_value:any*, key:string, reference_key:string        | O(n)       | yes   |
| supp_row_count_exceeds                  | Supplemental dataset has more than `threshold` rows whose QNAM matches `qnam_pattern` for the row’s key | ref_dataset:string*, qnam_pattern:string*, threshold:integer, name:string, key:string                                           | O(n)       | yes   |
| treatment_var_absent_across_datasets    | None of the current-dataset treatment vars present AND none of the ADSL treatment vars present          | current_vars:array*, reference_vars:array*, reference_dataset:string                                                            | O(n\*m)    | yes   |
| valid_codelist_term                     | Assigned value must be a valid codelist term                                                            |                                                                                                                                 | O(n\*m)    | yes   |
| value_not_in_subject_indexed_set        | Row value is not in the set of subject-keyed values drawn from templated reference columns              | name:string*, reference_dataset:string*, reference_template:string\*, key:string, reference_key:string                          | O(n\*m)    | yes   |
| value_not_var_in_ref_dataset            | Value in `name` column is not a variable in `reference_dataset` (optionally with required suffix)       | name:string*, reference_dataset:string*, name_suffix:string                                                                     | O(n)       | yes   |
| var_present_in_any_other_dataset        | TRUE when the named column exists in at least one other dataset in the submission (metadata-level)      | name:string\*, exclude_current:boolean, required_dataset_classes:array                                                          | O(1)       | yes   |
| where_clause_value_in_codelist          | Where clause check value must be in the variable’s codelist                                             |                                                                                                                                 | O(n\*m)    | yes   |

## string (14)

| name                     | summary                                                                     | args                                               | cost | NA ok |
|:-------------------------|:----------------------------------------------------------------------------|:---------------------------------------------------|:-----|:------|
| contains                 | Fixed substring containment on column values                                | name:string*, value:string*, ignore_case:logical   | O(n) | no    |
| does_not_contain         | Column value does NOT contain substring                                     | name:string*, value:string*, ignore_case:logical   | O(n) | no    |
| ends_with                | Column value ends with suffix                                               | name:string*, value:string*, ignore_case:logical   | O(n) | yes   |
| iso8601                  | SDTM ISO 8601 extended format with dash-substitution for missing components | name:string\*, allow_missing:logical               | O(n) | yes   |
| length_le                | Character byte-length \<= max (matches SAS column width semantics)          | name:string*, value:integer*                       | O(n) | yes   |
| longer_than              | Column character length (bytes) is greater than value                       | name:string*, value:integer*                       | O(n) | yes   |
| matches_regex            | PCRE regex match on column values                                           | name:string*, value:string*, allow_missing:logical | O(n) | yes   |
| not_matches_regex        | Column value does not match regex pattern                                   | name:string*, value:string*, allow_missing:logical | O(n) | yes   |
| not_prefix_matches_regex | First N chars of value do not match PCRE pattern                            | name:string*, value:string*, prefix_length:integer | O(n) | yes   |
| prefix_equal_to          | First `prefix_length` chars of value equal a literal                        | name:string*, value:string*, prefix_length:integer | O(n) | yes   |
| prefix_matches_regex     | First N chars of value match PCRE pattern                                   | name:string*, value:string*, prefix_length:integer | O(n) | yes   |
| prefix_not_equal_to      | First N chars of value do not equal a literal                               | name:string*, value:string*, prefix_length:integer | O(n) | yes   |
| shorter_than             | Column character length (bytes) is less than value                          | name:string*, value:integer*                       | O(n) | yes   |
| starts_with              | Column value starts with prefix                                             | name:string*, value:string*, ignore_case:logical   | O(n) | yes   |

## Reading the table

- **name** – the registry key referenced by rule YAML under the `op:`
  field.
- **summary** – one-line description from the op’s registration block.
- **args** – argument names with type tags. A trailing `*` marks a
  required argument; argless ops show an empty cell.
- **cost** – big-O hint for the inner loop. `O(n)` ops scale linearly
  with dataset rows; `O(n*m)` ops scan a reference dataset.
- **NA ok** – whether the op emits `NA` (advisory) under indeterminate
  conditions such as a missing required argument or a partially typed
  column.

## See also

- [Architecture](https://vthanik.github.io/herald/architecture.md) –
  where operators sit in the layer stack.
- [Rule coverage](https://vthanik.github.io/herald/rule-coverage.md) –
  how compiled rules are scoped to ops and standards.
- [`vignette("validation-reporting", package = "herald")`](https://vthanik.github.io/herald/articles/validation-reporting.md)
  – end-to-end validation flow.
