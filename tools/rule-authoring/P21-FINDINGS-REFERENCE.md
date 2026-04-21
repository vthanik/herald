# Pinnacle 21 / Certara findings reference

External reference material on P21 validation findings, scraped from
Certara's public knowledge base (search: `certara.com/?s=findings`).
Used to inform herald's rule-authoring decisions without copying P21
DSL/XML -- cross-reference only, concepts not expressions.

**Source search:** https://www.certara.com/?s=findings (146 items, 15 pages)

## Key articles and webinars

### Exploring Common CDISC ADaM Conformance Findings
https://www.certara.com/blog/exploring-common-cdisc-adam-conformance-findings/

Findings summary from the blog (for herald traceability):

| P21 ID | Variable(s) | Finding summary | Dataset class | herald status |
|---|---|---|---|---|
| AD0124 | PARAM, PARCATy | "Inconsistent value for PARCATy within a unique PARAMCD" — PARCATy must hold a many-to-one relationship with PARAM | BDS | CDISC-124 converted (uniqueness-grouped-scoped family) |
| CT2002 | RACE | Variable value not found in extensible codelist; RACE='OTHER' triggers a warning | ADSL | not in herald scope (CT rule, not IG rule) |
| CT2002 | DTYPE | Extensible codelist — WOCF and custom imputation values | BDS | same |
| AD0047 | multi | "Required variable is not present" — stale P21 Community versions may falsely fire | OCCDS/BDS | N/A (P21 version quirk) |

**Tips from Certara's article:**
- RACE='OTHER' is valid per SDTM-IG — agencies treat CT2002 as warning, not error. ADRG must explain.
- DTYPE only required when imputed analysis values are present.
- AD0047 false-positives resolved by upgrading P21 Community; version-drift issue.

### On-Demand Webinar: Exploring Common CDISC ADaM Dataset Conformance Findings
https://www.certara.com/on-demand-webinar/exploring-common-cdisc-adam-dataset-conformance-findings/

Trevor Mankus, Certara (P21 product lead). Topics cited:
- Common ADaM findings and their causes
- How to interpret warnings vs errors
- Best-practice submission checklist

(Full video transcript not scraped — cross-reference only.)

### Understanding the Duplicate Records Validation Rules
https://www.certara.com/blog/understanding-the-duplicate-records-validation-rules/

Three P21 rules cited:

| P21 ID | Applied-to | Purpose |
|---|---|---|
| SD1117 | Findings domains | Detect multiple observations/events/interventions for the same subject at the same time |
| SD1201 | Events domains | Duplicate records in events |
| SD1352 | Interventions domains | Duplicate records in interventions |

**Notes:**
- Rules check semantic duplicates (not byte-identical rows)
- Result variables (e.g. `--ORRES`) are excluded from the key-variable set
- "GroupBy" keys have been revised over time to include location/timing variables
- Rule efficacy depends on define.xml's key-variable documentation — often
  the most overlooked/misconfigured submission artifact.

### Other Certara articles referenced

| URL | Topic |
|---|---|
| /blog/send-v4-0-what-to-expect-and-when-to-expect-it/ | SEND v4.0 changes |
| /on-demand-webinar/exploring-changes-in-sdtmig-3-4-adamig-1-3/ | SDTMIG 3.4 / ADaMIG 1.3 changes |
| /blog/everything-you-need-to-know-about-sdtm/ | SDTM primer |
| /blog/how-does-pinnacle-21-enterprise-differ-from-the-community-version/ | P21 Enterprise vs Community |
| /blog/the-send-2023-updates-nonclinical-drug-developers-need-to-know/ | SEND 2023 |
| /blog/gain-nonclinical-drug-safety-insights-with-real-time-data-analysis/ | SEND analytics |

## How herald uses this reference

Clean-room rule: herald never copies P21's DSL / XML / rule expressions.
We consult this reference ONLY to:

1. **Confirm CDISC rule_id -> P21 primitive mapping** (e.g. AD0124 → val:Unique).
2. **Understand edge-case handling** (e.g. RACE='OTHER' warning tolerance).
3. **Prioritize rule authoring** (which rules generate the most real-world
   findings so we convert them first).

When adding a new herald pattern, check whether P21 has documented
findings for the same rule family; fold any non-obvious edge cases
into the pattern's MD audit table.

## Update policy

Re-scrape this reference every ADaMIG/SDTMIG major version bump
(new IG release typically publishes new findings articles). Add
new entries here before authoring new patterns.

**Last updated:** 2026-04-21 (from `certara.com/?s=findings` page 1 + 2).
Further pages not yet scraped; 136 additional search results remain.
