# value-conditional-null-crossref

## Intent

*"When a reference dataset's column is null (for the same subject),
a target column in this dataset must also be null."* Cross-dataset
null-guard. The reference dataset is joined on a shared key (usually
`USUBJID`).

Canonical message form:   `<TARGET_VAR> = null`
Canonical condition form: `<REF_DS>.<REF_COL> = null`

## CDISC source

SDTMIG v3.2+ Section 2.2.5: Start/End Relative to Reference Period
(`--STRF`, `--ENRF`) depend on DM's `RFSTDTC` / `RFENDTC`. When DM
doesn't record a reference period for a subject, the relative-period
qualifier on events/interventions loses its anchor and must be null.

## P21 conceptual parallel (reference only)

P21's `val:Lookup` primitive (see XML rule `SD1030` for CG0226):

```
val:Lookup ID="SD1030" PublisherID="CG0226"
  Variable="USUBJID == USUBJID"
  When="%Domain%STRF != ''"
  Where="RFSTDTC  != ''"
  From="DM"
```

Translation of the DSL attributes:
- `Variable="USUBJID == USUBJID"` -- join condition; `USUBJID` from the
  current record equals `USUBJID` in DM.
- `When="%Domain%STRF != ''"` -- only check rows where STRF is
  populated.
- `Where="RFSTDTC != ''"` -- restrict candidate DM rows to those
  where RFSTDTC is populated.
- `From="DM"` -- lookup target.

Fires when: for a record with STRF populated, DM has NO row with
matching USUBJID AND RFSTDTC populated. I.e., the subject's DM row
lacks an anchor.

`SD1031` (CG0227) uses an alternate attribute form with `Search=` and
`WhereFailure="Ignore"` but the outcome is equivalent for RFENDTC.

herald re-expresses the concept via a new `op_ref_col_empty` op that
joins the current dataset to a reference dataset by key and returns
TRUE when the reference's column is null or the match is missing.

## P21 edge-case audit (LookupValidationRule.java inferred)

| P21 behaviour | Source | herald decision |
|---|---|---|
| `Variable="USUBJID == USUBJID"` -- exact key match on join column | XML attribute parse | `.parse_ref_arg` defaults `by` to the name arg (`USUBJID`). Lookup is indexed by this column. |
| `Where="RFSTDTC != ''"` -- restrict ref rows | XML attribute | `op_ref_col_empty` tests rtrim-null on the reference column; a ref row with `"   "` or `""` or NA counts as EMPTY (no anchor). Matches. |
| `From="DM"` | XML attribute | `.parse_ref_arg` extracts `DM` from dotted `"DM.RFSTDTC"` or from `value$reference_dataset`. |
| No matching ref row -> rule fires (Lookup fails) | Lookup semantic | `op_ref_col_empty` returns TRUE when the key doesn't appear in the ref at all. Matches. |
| rtrim-null applied on the ref column | `DataEntryFactory.java:313-328` on load | herald's op rtrims before nzchar-testing. Matches. |
| `WhereFailure="Ignore"` (SD1031) | XML attribute variant | herald's op has no equivalent; treating a missing ref as "null" (fires) is the default. Functionally identical for these rules. |
| `Search="RFENDTC != ''"` (SD1031) | alternate form for Where | Same semantics as Where; herald uses one mechanism for both. |
| Missing ref dataset entirely (e.g. no DM loaded) | P21 throws or skips | herald returns NA mask on missing ref dataset -> advisory. More transparent. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %target_var%
- operator: ref_col_empty
  name: USUBJID
  value:
    reference_dataset: %ref_ds%
    reference_column: %ref_col%
```

Slots:
- `target_var` -- the current-dataset column that must be null when
  the ref is null; violation when populated.
- `ref_ds`     -- reference dataset name (e.g. `DM`).
- `ref_col`    -- reference column name (e.g. `RFSTDTC`).

The structured `value: {reference_dataset, reference_column}` form
is used rather than the dotted `"DM.RFSTDTC"` short form because
the dotted form gets eagerly resolved by `substitute_crossrefs`
(rules-crossrefs.R) into a vector of unique values, which is the
right semantic for `is_contained_by` but wrong for a join-by-key
op that needs the ref-dataset and ref-column names.

Violation fires on rows where the target is populated AND the
reference's column is null (or the matching ref row doesn't exist).

## Expected outcome

- Positive: current row has target populated, DM has no matching
  USUBJID row (or RFSTDTC null there) -> fires.
- Negative: current row's target empty OR DM has matching USUBJID
  with RFSTDTC populated -> no fire.

## Batch scope

2 rules: CG0226 (`--STRF = null when DM.RFSTDTC = null`),
CG0227 (`--ENRF = null when DM.RFENDTC = null`). Both SDTMIG v3.2+.
