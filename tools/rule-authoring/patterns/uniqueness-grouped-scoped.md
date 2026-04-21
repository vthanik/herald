# uniqueness-grouped-scoped

## Intent

*"Within a given value of `<SCOPE_VAR>` (e.g. PARAMCD), there is
more than one value of `<VAR_A>` for a given value of `<VAR_B>`"*.
Same shape as `uniqueness-grouped` but nested inside an outer
grouping variable (PARAMCD in BDS, or STUDYID+PARAMCD in some
rules). Fires when, within each SCOPE_VAR tuple, the A↔B
relationship is not 1:1.

Canonical message form:
`Within a given value of <SCOPE_VAR>, there is more than one value of <VAR_A> for a given value of <VAR_B>`

## CDISC source

ADaM-IG v1.1 Section 3.3 (Basic Data Structure). Paired variable
rules inside BDS datasets operate per-parameter (PARAMCD scope)
because one dataset holds multiple parameters; the 1:1 relationship
must hold within each parameter family, not across them. Examples
(ADaM rule_id): 109/110 AVISIT↔AVISITN, 117/118 ATPT↔ATPTN,
129/130 BASE↔BASEC, 135/136 SHIFTy↔SHIFTyN, 149/150 AVAL↔AVALC.

## P21 conceptual parallel (reference only)

P21 uses `val:Unique` with composite `GroupBy=STUDYID,PARAMCD,<VAR>`
and `Matching=Yes`:

```
val:Unique PublisherID="AD0129"
  Variable = BASE
  GroupBy  = STUDYID,PARAMCD,BASEC
  Matching = Yes
  When     = PARAMCD != '' @and BASE != '' @and BASEC != ''
```

P21's Matching=Yes semantic: within each (STUDYID, PARAMCD, BASEC)
tuple, Variable (BASE) must have exactly one distinct value.

herald extends `op_is_not_unique_relationship` with a `group_by`
sub-arg that nests the X↔Y check inside an outer grouping key.
For ADaM-129: name=BASEC, value.related_name=BASE,
value.group_by=[PARAMCD] (STUDYID is usually invariant within one
dataset so we scope to PARAMCD only; author can add STUDYID if
multi-study).

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Composite GroupBy joined with non-printable separator | `UniqueValueValidationRule.java` + `DataGrouping` hash | `op_is_not_unique_relationship` extended builds `outer_key = paste(group_by cols, sep="\x1f")` then `composite_x = paste(outer_key, x, sep="\x1f")`. Matches. |
| When clause filters records before uniqueness counting | `AbstractScriptableValidationRule.checkExpression` | herald's op applies rtrim-null exclusion on x, y, and group_by cols implicitly (rows with any NA in the composite key are excluded from counting). Matches "considering only those rows on which both variables are populated" clause. |
| Matching=Yes asserts exactly-one; Matching=No omits the assertion (pure duplicate count) | `UniqueValueValidationRule.performValidation` | herald fires when >1 distinct Y per (group, X) -- matches Matching=Yes. Matching=No variant not supported in this op. |
| rtrim-null on variable AND group_by values | `DataEntryFactory.java:313-328` | `.rtrim_na` applied to x, y, and each group_by col. Matches. |
| P21 fires only the 2nd+ duplicate row; herald fires EVERY row in the violating group | `UniqueValueValidationRule` | Documented deviation (CONVENTIONS.md sec 4): more complete context for reviewers. |
| Missing group_by column -> rule disabled | `CorruptRuleException` | `op_is_not_unique_relationship` returns NA mask -> advisory. More transparent. |

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- name: %var_b%
  operator: is_not_unique_relationship
  value:
    related_name: %var_a%
    group_by:
    - %scope_var%
```

Slots:
- `var_b`     -- the "given value of" variable (P21 `Variable`, the
  one with possibly non-unique values within a group)
- `var_a`     -- the "more than one value of" dependent variable
  (appears in P21 GroupBy alongside scope_var)
- `scope_var` -- the outer scope column (typically `PARAMCD`)
- `expand`    -- empty for concrete names; `y`/`xx`/`zz`/`w` for
  indexed ones

## Expected outcome

- Positive: within a PARAMCD value, one VAR_B value maps to two
  distinct VAR_A values -> both rows fire.
- Negative: within each PARAMCD, VAR_B↔VAR_A is 1:1 -> no fire.

## Batch scope

Initial batch (10 rules):

- ADaM-109/110: AVISIT↔AVISITN
- ADaM-117/118: ATPT↔ATPTN
- ADaM-129/130: BASE↔BASEC
- ADaM-135/136: SHIFTy↔SHIFTyN (y expanded)
- ADaM-149/150: AVAL↔AVALC

All scope class BDS (BASIC DATA STRUCTURE). SHIFTy rules use
`expand: y`; others are concrete.
