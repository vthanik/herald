# adsl-index-var-exists

## Intent

*"For every unique `xx` value of `<NAME>`, ADSL must carry an
index-templated variable `<TEMPLATE>`"*. Fires once per (rule x
dataset) when any unique integer value observed in the index column
does not resolve to a concrete ADSL column name under the template.

Used for ADaMIG cross-references where ADaM analysis datasets carry
a period / phase integer column and ADSL is expected to hold a set
of integer-suffixed variables that document each period/phase.

Canonical message form:
`For every unique xx value of <NAME>, there is not an ADSL variable
<TEMPLATE>`

## CDISC source

ADaMIG v1.0 Section 3.2.3 + 3.2.7. For each distinct value of
APERIOD in a BDS / OCCDS dataset, ADSL must carry the matching
`TRTxxP`, `TRxxSDT`, and `TRxxEDT` variables that define the
planned treatment, start date, and end date for that analysis
period.

- ADaM-102: APERIOD -> TRTxxP
- ADaM-103: APERIOD -> TRxxSDT
- ADaM-104: APERIOD -> TRxxEDT

## P21 conceptual parallel (reference only)

P21's SDTM-IG 3.3 config does NOT encode CDISC 102/103/104 directly.
The conceptual cousin is `val:Find Variable = "%Current.TRTxxP%"
Target = "Metadata" MatchExact = "No"` where the magic variable
expands against the DM / ADSL side. herald authors the rule from
the ADaMIG narrative.

## P21 edge-case audit (general Find conventions)

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Index value format: 2-digit zero padded | `MagicVariable.padLeft` | `sprintf("%02d", xx)`. Matches. |
| Index value format: 1-9 without padding for y/w | n/a | `sprintf("%d", y)`. Per ADaMIG convention. |
| ADSL missing -> rule-disable | `DataEntryFactory.lookupDataset` | herald returns NA mask for the rule -> advisory. More transparent. |
| Non-integer `xx` value -> skipped | `Integer.parseInt` NumberFormatException | `suppressWarnings(as.integer())` + `!is.na()` filter. Matches. |
| Case-insensitive metadata lookup | `DataEntryFactory.uppercased` | `toupper()` both sides before membership. Matches. |

## herald check_tree template

```yaml check_tree
operator: any_index_missing_ref_var
name: %name%
reference_dataset: %ref_ds%
name_template: %template%
placeholder: %placeholder%
```

Slots:
- `name`         -- the indexed column on the current dataset (e.g. `APERIOD`)
- `ref_ds`       -- the reference dataset (e.g. `ADSL`)
- `template`     -- the templated variable name with placeholder (e.g. `TRTxxP`)
- `placeholder`  -- `xx` (2-digit) or `y`/`w` (1-9)

## Expected outcome

- Positive: at least one unique `name` value has no matching
  templated column in `ref_ds` -> fires once.
- Negative: every unique value resolves to an existing column -> no
  fire.
- `name` column absent or all NA OR `ref_ds` absent -> NA -> advisory.

## Batch scope

3 rules: ADaM-102 (TRTxxP), ADaM-103 (TRxxSDT), ADaM-104 (TRxxEDT).
