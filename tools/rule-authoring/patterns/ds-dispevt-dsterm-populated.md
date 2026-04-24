# ds-dispevt-dsterm-populated

## Intent

*"When `DSCAT = 'DISPOSITION EVENT'`, `DSTERM` must be populated."*

Canonical message form: `DSTERM = 'COMPLETED' or the reason for discontinuation`
Canonical condition: `DSCAT = 'DISPOSITION EVENT'`.

Fires per row when DSCAT is the literal `'DISPOSITION EVENT'`
AND DSTERM is null/empty.

## CDISC source

SDTMIG v3.2+ DS domain guidance:

> When DSCAT='DISPOSITION EVENT', DSTERM contains either
> 'COMPLETED' or, if the subject did not complete, specific
> verbatim information about the disposition event.

The narrative "`DSTERM = 'COMPLETED' or the reason for
discontinuation`" enumerates the acceptable values; any populated
DSTERM satisfies the rule. The machine-checkable form is
therefore "DSTERM must be non-null" under the DSCAT guard.

## P21 conceptual parallel (reference only)

P21 SD0099 (`PublisherID="CG0071"`): `val:Condition` with
`When="DSCAT == 'DISPOSITION EVENT'"` and `Test="DSTERM != ''"`.
herald re-expresses as
`{all: [is_contained_by(DSCAT,['DISPOSITION EVENT']), empty(DSTERM)]}`
-- `{all}` fires when guard holds AND DSTERM is empty.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `DSCAT == 'DISPOSITION EVENT'` with NULL lhs -> false | `Comparison.java:160-207` | `is_contained_by` on NA returns NA; under `{all}` NA -> advisory. Functional equivalent (never fires on null guard). |
| `DSTERM != ''` post-rtrim null-check | `DataEntryFactory.java:313-328` | `op_empty` rtrims + `nzchar`-tests. Matches. |
| Missing DSCAT / DSTERM column -> `Optional` skip | `RuleDefinition.Optional` | op returns NA mask; under `{all}` NA -> one advisory per (rule x dataset). Functional equivalent. |
| Case-sensitive literal match default | `Comparison.java:194-205` | R's `==` is case-sensitive. `'Disposition Event'` would NOT satisfy guard. Matches P21. |

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: DSCAT
  value:
  - 'DISPOSITION EVENT'
- operator: empty
  name: DSTERM
```

## Expected outcome

- Positive: DSCAT='DISPOSITION EVENT' AND DSTERM='' -> fires.
- Negative #1: DSCAT='DISPOSITION EVENT' AND DSTERM='COMPLETED'
  -> no fire (assertion FALSE).
- Negative #2: DSCAT='OTHER EVENT' (guard FALSE) -> no fire.

## Batch scope

1 rule: CG0071 (DSTERM populated when DSCAT='DISPOSITION EVENT').
