# Pilot datasets and specs shipped for examples, tests, and vignettes.
# Source: CDISC SDTM/ADaM Pilot Submission Package (public domain).
# Variable metadata below matches the bundled `sdtm_spec` / `adam_spec`
# objects exactly. To regenerate the variable tables programmatically,
# run e.g. `sdtm_spec$var_spec[sdtm_spec$var_spec$dataset == "DM", ]`.

#' Pilot DM (Demographics) domain
#'
#' @description
#' A 50-subject Demographics (DM) domain from the CDISC SDTM pilot submission.
#' Contains exactly one row per subject with screening / enrolment dates,
#' baseline characteristics, treatment arm assignment, and country of
#' enrolment. DM is the SDTM "spine": every clinical-data domain joins back
#' to DM via `STUDYID`/`USUBJID`. Useful for demonstrating SDTM validation,
#' [apply_spec()] metadata stamping, and cross-domain rule checking.
#'
#' All 25 variables shipped here are listed below with the labels drawn
#' from the bundled [`sdtm_spec`].
#'
#' @format A data frame with **50 rows** and **25 columns**. Required
#' (mandatory) variables per SDTM-IG v2.0 are flagged below.
#' \describe{
#'   \item{`STUDYID`}{*Study Identifier* (text, len 12, **required**) --
#'     unique study code (`"CDISCPILOT01"` for all rows).}
#'   \item{`DOMAIN`}{*Domain Abbreviation* (text, len 2, **required**) --
#'     constant `"DM"`.}
#'   \item{`USUBJID`}{*Unique Subject Identifier* (text, len 11,
#'     **required**) -- study-unique subject ID; primary join key.}
#'   \item{`SUBJID`}{*Subject Identifier for the Study* (text, len 4,
#'     **required**) -- subject ID within the study.}
#'   \item{`RFSTDTC`}{*Subject Reference Start Date/Time* (ISO 8601 date,
#'     len 10) -- typically date of first study treatment.}
#'   \item{`RFENDTC`}{*Subject Reference End Date/Time* (ISO 8601 date,
#'     len 10) -- typically date of last study treatment.}
#'   \item{`RFXSTDTC`}{*Date/Time of First Study Treatment* (ISO 8601
#'     datetime, len 20).}
#'   \item{`RFXENDTC`}{*Date/Time of Last Study Treatment* (ISO 8601
#'     datetime, len 20).}
#'   \item{`RFICDTC`}{*Date/Time of Informed Consent* (ISO 8601 datetime,
#'     len 20).}
#'   \item{`RFPENDTC`}{*Date/Time of End of Participation* (ISO 8601
#'     datetime, len 20).}
#'   \item{`DTHDTC`}{*Date/Time of Death* (ISO 8601 datetime, len 20) --
#'     `NA` for surviving subjects.}
#'   \item{`DTHFL`}{*Subject Death Flag* (text, len 1, codelist
#'     `CL.Y_BLANK`) -- `"Y"` if subject died, blank otherwise.}
#'   \item{`SITEID`}{*Study Site Identifier* (text, len 3, **required**).}
#'   \item{`AGE`}{*Age* (integer, len 8) -- numeric age at consent in
#'     `AGEU` units.}
#'   \item{`AGEU`}{*Age Units* (text, len 6, codelist `CL.AGEU`) --
#'     typically `"YEARS"`.}
#'   \item{`SEX`}{*Sex* (text, len 1, **required**, codelist `CL.SEX`) --
#'     `"M"` or `"F"`.}
#'   \item{`RACE`}{*Race* (text, len 78, codelist `CL.RACE`) -- e.g.
#'     `"WHITE"`, `"BLACK OR AFRICAN AMERICAN"`.}
#'   \item{`ETHNIC`}{*Ethnicity* (text, len 25, codelist `CL.ETHNIC`).}
#'   \item{`ARMCD`}{*Planned Arm Code* (text, len 8, **required**, codelist
#'     `CL.ARMCD`) -- short code for the planned arm.}
#'   \item{`ARM`}{*Description of Planned Arm* (text, len 20, **required**,
#'     codelist `CL.ARM`).}
#'   \item{`ACTARMCD`}{*Actual Arm Code* (text, len 8, **required**,
#'     codelist `CL.ARMCD`) -- actual arm received; may differ from
#'     `ARMCD` for protocol violators.}
#'   \item{`ACTARM`}{*Description of Actual Arm* (text, len 20,
#'     **required**, codelist `CL.ARM`).}
#'   \item{`COUNTRY`}{*Country* (text, len 3, **required**, codelist
#'     `CL.COUNTRY`) -- ISO 3166 alpha-3 code (e.g. `"USA"`).}
#'   \item{`DMDTC`}{*Date/Time of Collection* (ISO 8601 date, len 10) --
#'     date demographic data was collected.}
#'   \item{`DMDY`}{*Study Day of Collection* (integer, len 8) -- study
#'     day of `DMDTC` relative to `RFSTDTC`.}
#' }
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain),
#'   restricted to the 50 ITT subjects sampled from the 254-subject
#'   pilot ADSL. Labels and lengths are sourced verbatim from the pilot
#'   `define.xml` via [read_define_xml()].
#'
#' @family pilot-data
#' @seealso [adsl], [adae], [advs] (analysis-ready ADaM derivations of the
#'   same 50 subjects); [sdtm_spec] (variable metadata as a `herald_spec`).
#'
#' @examples
#' nrow(dm)
#' names(dm)
#'
#' # Subject counts by sex and arm
#' table(dm$SEX, dm$ARM)
#'
#' \donttest{
#' # Stamp SDTM attributes from spec, then validate
#' dm_stamped <- apply_spec(dm, sdtm_spec)
#' attr(dm_stamped$USUBJID, "label")
#'
#' r <- validate(files = dm_stamped, quiet = TRUE)
#' r$datasets_checked
#' }
"dm"

#' Pilot ADSL (Subject-Level Analysis Dataset)
#'
#' @description
#' A 50-subject ADaM ADSL dataset from the CDISC pilot submission. ADSL
#' is the cornerstone analysis dataset: one row per subject, carrying
#' every population-level analysis variable (treatment assignment,
#' population flags, baseline measurements, disposition). All BDS and
#' OCCDS analysis datasets in the same study merge population flags from
#' ADSL.
#'
#' All 49 variables shipped here are documented below using labels from
#' the bundled [`adam_spec`].
#'
#' @format A data frame with **50 rows** and **49 columns**.
#' \describe{
#'   \item{`STUDYID`}{*Study Identifier* (text, len 12).}
#'   \item{`USUBJID`}{*Unique Subject Identifier* (text, len 11) -- join
#'     key used by every BDS / OCCDS analysis dataset.}
#'   \item{`SUBJID`}{*Subject Identifier for the Study* (text, len 4).}
#'   \item{`SITEID`}{*Study Site Identifier* (text, len 3).}
#'   \item{`SITEGR1`}{*Pooled Site Group 1* (text, len 3) -- analysis
#'     pooling of small sites.}
#'   \item{`ARM`}{*Description of Planned Arm* (text, len 20).}
#'   \item{`TRT01P`}{*Planned Treatment for Period 01* (text, len 20).}
#'   \item{`TRT01PN`}{*Planned Treatment for Period 01 (N)* (integer, len 8) --
#'     numeric companion to `TRT01P`.}
#'   \item{`TRT01A`}{*Actual Treatment for Period 01* (text, len 20).}
#'   \item{`TRT01AN`}{*Actual Treatment for Period 01 (N)* (integer, len 8).}
#'   \item{`TRTSDT`}{*Date of First Exposure to Treatment* (numeric SAS
#'     date, len 8).}
#'   \item{`TRTEDT`}{*Date of Last Exposure to Treatment* (numeric SAS
#'     date, len 8).}
#'   \item{`TRTDURD`}{*Total Treatment Duration (Days)* (integer, len 8) --
#'     `TRTEDT - TRTSDT + 1`.}
#'   \item{`AVGDD`}{*Avg Daily Dose (as planned)* (float, len 8).}
#'   \item{`CUMDOSE`}{*Cumulative Dose (as planned)* (float, len 8).}
#'   \item{`AGE`}{*Age* (integer, len 8).}
#'   \item{`AGEGR1`}{*Pooled Age Group 1* (text, len 5) -- e.g.
#'     `"<65"`, `"65-80"`, `">80"`.}
#'   \item{`AGEGR1N`}{*Pooled Age Group 1 (N)* (integer, len 8).}
#'   \item{`AGEU`}{*Age Units* (text, len 5).}
#'   \item{`RACE`}{*Race* (text, len 32).}
#'   \item{`RACEN`}{*Race (N)* (integer, len 8).}
#'   \item{`SEX`}{*Sex* (text, len 1).}
#'   \item{`ETHNIC`}{*Ethnicity* (text, len 22).}
#'   \item{`SAFFL`}{*Safety Population Flag* (text, len 1) -- `"Y"`/`""`.}
#'   \item{`ITTFL`}{*Intent-To-Treat Population Flag* (text, len 1).}
#'   \item{`EFFFL`}{*Efficacy Population Flag* (text, len 1).}
#'   \item{`COMP8FL`}{*Completers of Week 8 Population Flag* (text, len 1).}
#'   \item{`COMP16FL`}{*Completers of Week 16 Population Flag* (text, len 1).}
#'   \item{`COMP24FL`}{*Completers of Week 24 Population Flag* (text, len 1).}
#'   \item{`DISCONFL`}{*Did the Subject Discontinue the Study?* (text, len 1).}
#'   \item{`DSRAEFL`}{*Discontinued due to AE?* (text, len 1).}
#'   \item{`DTHFL`}{*Subject Died?* (text, len 1).}
#'   \item{`BMIBL`}{*Baseline BMI (kg/m^2)* (float, len 8).}
#'   \item{`BMIBLGR1`}{*Pooled Baseline BMI Group 1* (text, len 6).}
#'   \item{`HEIGHTBL`}{*Baseline Height (cm)* (float, len 8).}
#'   \item{`WEIGHTBL`}{*Baseline Weight (kg)* (float, len 8).}
#'   \item{`EDUCLVL`}{*Years of Education* (integer, len 8).}
#'   \item{`DISONSDT`}{*Date of Onset of Disease* (numeric SAS date, len 8).}
#'   \item{`DURDIS`}{*Duration of Disease (Months)* (float, len 8).}
#'   \item{`DURDSGR1`}{*Pooled Disease Duration Group 1* (text, len 4).}
#'   \item{`VISIT1DT`}{*Date of Visit 1* (numeric SAS date, len 8).}
#'   \item{`RFSTDTC`}{*Subject Reference Start Date/Time* (ISO 8601
#'     datetime, len 20).}
#'   \item{`RFENDTC`}{*Subject Reference End Date/Time* (ISO 8601
#'     datetime, len 20).}
#'   \item{`VISNUMEN`}{*End of Trt Visit (Vis 12 or Early Term.)*
#'     (integer, len 8).}
#'   \item{`RFENDT`}{*Date of Discontinuation/Completion* (numeric SAS
#'     date, len 8).}
#'   \item{`DCDECOD`}{*Standardized Disposition Term* (text, len 27) --
#'     `"COMPLETED"`, `"ADVERSE EVENT"`, `"WITHDRAWAL BY SUBJECT"`, etc.}
#'   \item{`EOSSTT`}{*End of Study Status* (text, len 12) --
#'     `"COMPLETED"` / `"DISCONTINUED"`.}
#'   \item{`DCSREAS`}{*Reason for Discontinuation from Study* (text, len 18).}
#'   \item{`MMSETOT`}{*MMSE Total* (integer, len 8) -- baseline
#'     Mini-Mental State Examination total.}
#' }
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain).
#'   Trimmed to 50 subjects from the full 254-subject pilot ADSL.
#'
#' @family pilot-data
#' @seealso [dm] (corresponding SDTM source); [adae], [advs] (downstream
#'   ADaM analyses); [adam_spec] (variable metadata).
#'
#' @examples
#' nrow(adsl)
#' names(adsl)[1:10]
#'
#' # Population subsets
#' table(adsl$SAFFL)             # Safety population
#' table(adsl$ITTFL, adsl$EFFFL) # ITT vs Efficacy
#'
#' # Treatment-arm summary
#' table(adsl$TRT01P)
#'
#' # Baseline characteristics (numeric)
#' summary(adsl[, c("AGE", "BMIBL", "HEIGHTBL", "WEIGHTBL")])
#'
#' \donttest{
#' adsl_stamped <- apply_spec(adsl, adam_spec)
#' r <- validate(files = adsl_stamped, quiet = TRUE)
#' r$profile
#' }
"adsl"

#' Pilot ADAE (Adverse Events Analysis Dataset, OCCDS)
#'
#' @description
#' An ADAE dataset from the CDISC ADaM pilot submission containing 254
#' adverse-event records across the 50 pilot subjects. ADAE is an OCCDS
#' (Occurrence Data Structure) following ADaM IG: each row is one occurrence
#' of an adverse event, joined to ADSL by `USUBJID` and carrying the full
#' MedDRA hierarchy plus serious-criteria, severity, and treatment-emergent
#' analysis flags. Useful for testing dictionary-provider integration and
#' cross-domain validation.
#'
#' All 55 variables shipped here are documented below using labels from
#' the bundled [`adam_spec`].
#'
#' @format A data frame with **254 rows** and **55 columns**.
#' \describe{
#'   \item{`STUDYID`}{*Study Identifier* (text, len 12).}
#'   \item{`SITEID`}{*Study Site Identifier* (text, len 3).}
#'   \item{`USUBJID`}{*Unique Subject Identifier* (text, len 11).}
#'   \item{`TRTA`}{*Actual Treatment* (text, len 20).}
#'   \item{`TRTAN`}{*Actual Treatment (N)* (integer, len 8).}
#'   \item{`AGE`}{*Age* (integer, len 8).}
#'   \item{`AGEGR1`}{*Pooled Age Group 1* (text, len 5).}
#'   \item{`AGEGR1N`}{*Pooled Age Group 1 (N)* (integer, len 8).}
#'   \item{`RACE`}{*Race* (text, len 32).}
#'   \item{`RACEN`}{*Race (N)* (integer, len 8).}
#'   \item{`SEX`}{*Sex* (text, len 1).}
#'   \item{`SAFFL`}{*Safety Population Flag* (text, len 1).}
#'   \item{`TRTSDT`}{*Date of First Exposure to Treatment* (numeric date,
#'     len 8).}
#'   \item{`TRTEDT`}{*Date of Last Exposure to Treatment* (numeric date,
#'     len 8).}
#'   \item{`ASTDT`}{*Analysis Start Date* (numeric date, len 8) -- AE
#'     onset for analysis.}
#'   \item{`ASTDTF`}{*Analysis Start Date Imputation Flag* (text, len 1).}
#'   \item{`ASTDY`}{*Analysis Start Relative Day* (integer, len 8) --
#'     study day of onset relative to `TRTSDT`.}
#'   \item{`AENDT`}{*Analysis End Date* (numeric date, len 8).}
#'   \item{`AENDY`}{*Analysis End Relative Day* (integer, len 8).}
#'   \item{`ADURN`}{*AE Duration (N)* (integer, len 8).}
#'   \item{`ADURU`}{*AE Duration Units* (text, len 3) -- e.g. `"DAY"`.}
#'   \item{`AETERM`}{*Reported Term for the Adverse Event* (text, len 46)
#'     -- verbatim CRF term.}
#'   \item{`AELLT`}{*Lowest Level Term* (text, len 46) -- MedDRA LLT.}
#'   \item{`AELLTCD`}{*Lowest Level Term Code* (integer, len 8).}
#'   \item{`AEDECOD`}{*Dictionary-Derived Term* (text, len 46) -- MedDRA PT.}
#'   \item{`AEPTCD`}{*Preferred Term Code* (integer, len 8).}
#'   \item{`AEHLT`}{*High Level Term* (text, len 8).}
#'   \item{`AEHLTCD`}{*High Level Term Code* (integer, len 8).}
#'   \item{`AEHLGT`}{*High Level Group Term* (text, len 9).}
#'   \item{`AEHLGTCD`}{*High Level Group Term Code* (integer, len 8).}
#'   \item{`AEBODSYS`}{*Body System or Organ Class* (text, len 67) --
#'     MedDRA SOC.}
#'   \item{`AESOC`}{*Primary System Organ Class* (text, len 67).}
#'   \item{`AESOCCD`}{*Primary System Organ Class Code* (integer, len 8).}
#'   \item{`AESEV`}{*Severity/Intensity* (text, len 8) -- `"MILD"`,
#'     `"MODERATE"`, `"SEVERE"`.}
#'   \item{`AESER`}{*Serious Event* (text, len 1) -- `"Y"`/`""`.}
#'   \item{`AESCAN`}{*Involves Cancer* (text, len 1).}
#'   \item{`AESCONG`}{*Congenital Anomaly or Birth Defect* (text, len 1).}
#'   \item{`AESDISAB`}{*Persist or Signif Disability/Incapacity* (text,
#'     len 1).}
#'   \item{`AESDTH`}{*Results in Death* (text, len 1).}
#'   \item{`AESHOSP`}{*Requires or Prolongs Hospitalization* (text, len 1).}
#'   \item{`AESLIFE`}{*Is Life Threatening* (text, len 1).}
#'   \item{`AESOD`}{*Occurred with Overdose* (text, len 1).}
#'   \item{`AEREL`}{*Causality* (text, len 8) -- relationship to study
#'     drug.}
#'   \item{`AEACN`}{*Action Taken with Study Treatment* (text, len 1).}
#'   \item{`AEOUT`}{*Outcome of Adverse Event* (text, len 26).}
#'   \item{`AESEQ`}{*Sequence Number* (integer, len 8) -- AE sequence
#'     within subject.}
#'   \item{`TRTEMFL`}{*Treatment Emergent Analysis Flag* (text, len 1) --
#'     `"Y"` if AE began after first dose.}
#'   \item{`AOCCFL`}{*1st Occurrence of Any AE Flag* (text, len 1).}
#'   \item{`AOCCSFL`}{*1st Occurrence of SOC Flag* (text, len 1).}
#'   \item{`AOCCPFL`}{*1st Occurrence of Preferred Term Flag* (text, len 1).}
#'   \item{`AOCC02FL`}{*1st Occurrence 02 Flag for Serious* (text, len 1).}
#'   \item{`AOCC03FL`}{*1st Occurrence 03 Flag for Serious SOC* (text,
#'     len 1).}
#'   \item{`AOCC04FL`}{*1st Occurrence 04 Flag for Serious PT* (text,
#'     len 1).}
#'   \item{`CQ01NAM`}{*Customized Query 01 Name* (text, len 19) -- sponsor
#'     custom MedDRA query.}
#'   \item{`AOCC01FL`}{*1st Occurrence 01 Flag for CQ01* (text, len 1).}
#' }
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain).
#'   254 AE records spanning the 50 pilot subjects.
#'
#' @family pilot-data
#' @seealso [adsl] (population denominator); [dm]; [adam_spec].
#'
#' @examples
#' nrow(adae)
#' table(adae$AESEV)
#' table(adae$TRTEMFL)
#'
#' # MedDRA SOC distribution
#' sort(table(adae$AEBODSYS), decreasing = TRUE)[1:5]
#'
#' # Serious AE summary
#' adae[adae$AESER == "Y", c("USUBJID", "AEDECOD", "AESEV", "AEOUT")]
#'
#' # Treatment-emergent first-occurrence subset
#' tefoc <- adae[adae$TRTEMFL == "Y" & adae$AOCCPFL == "Y", ]
#' nrow(tefoc)
"adae"

#' Pilot ADVS (Vital Signs Analysis Dataset, BDS)
#'
#' @description
#' An ADVS dataset from the CDISC ADaM pilot submission with 6,138 records
#' across all scheduled vital-sign assessments for the 50 pilot subjects.
#' ADVS follows the ADaM Basic Data Structure (BDS): one row per
#' (subject, parameter, visit, timepoint), with `AVAL` carrying the
#' analysis value, `BASE` the baseline, and `CHG`/`PCHG` the absolute /
#' percent change from baseline. The largest of the pilot datasets --
#' useful for performance benchmarking and BDS-rule coverage testing.
#'
#' All 35 variables shipped here are documented below using labels from
#' the bundled [`adam_spec`].
#'
#' @format A data frame with **6,138 rows** and **35 columns**.
#' \describe{
#'   \item{`STUDYID`}{*Study Identifier* (text, len 12).}
#'   \item{`SITEID`}{*Study Site Identifier* (text, len 3).}
#'   \item{`USUBJID`}{*Unique Subject Identifier* (text, len 11).}
#'   \item{`AGE`}{*Age* (integer, len 8).}
#'   \item{`AGEGR1`}{*Pooled Age Group 1* (text, len 5).}
#'   \item{`AGEGR1N`}{*Pooled Age Group 1 (N)* (integer, len 8).}
#'   \item{`RACE`}{*Race* (text, len 32).}
#'   \item{`RACEN`}{*Race (N)* (integer, len 8).}
#'   \item{`SEX`}{*Sex* (text, len 1).}
#'   \item{`SAFFL`}{*Safety Population Flag* (text, len 1).}
#'   \item{`TRTSDT`}{*Date of First Exposure to Treatment* (numeric date,
#'     len 8).}
#'   \item{`TRTEDT`}{*Date of Last Exposure to Treatment* (numeric date,
#'     len 8).}
#'   \item{`TRTP`}{*Planned Treatment* (text, len 20).}
#'   \item{`TRTPN`}{*Planned Treatment (N)* (integer, len 8).}
#'   \item{`TRTA`}{*Actual Treatment* (text, len 20).}
#'   \item{`TRTAN`}{*Actual Treatment (N)* (integer, len 8).}
#'   \item{`PARAMCD`}{*Parameter Code* (text, len 8) -- short code (e.g.
#'     `"DIABP"`, `"SYSBP"`, `"PULSE"`, `"TEMP"`, `"WEIGHT"`).}
#'   \item{`PARAM`}{*Parameter* (text, len 100) -- human-readable name
#'     (e.g. `"Diastolic Blood Pressure (mmHg)"`).}
#'   \item{`PARAMN`}{*Parameter (N)* (integer, len 8) -- numeric companion
#'     to `PARAMCD`.}
#'   \item{`ADT`}{*Analysis Date* (numeric date, len 8).}
#'   \item{`ADY`}{*Analysis Relative Day* (integer, len 8) -- study day
#'     of `ADT` relative to `TRTSDT`.}
#'   \item{`ATPTN`}{*Analysis Timepoint (N)* (integer, len 8).}
#'   \item{`ATPT`}{*Analysis Timepoint* (text, len 30) -- e.g. `"PRE-DOSE"`.}
#'   \item{`AVISIT`}{*Analysis Visit* (text, len 16) -- normalised visit
#'     name (`"BASELINE"`, `"WEEK 8"`, etc.).}
#'   \item{`AVISITN`}{*Analysis Visit (N)* (integer, len 8).}
#'   \item{`AVAL`}{*Analysis Value* (float, len 8) -- the value used in
#'     analyses.}
#'   \item{`BASE`}{*Baseline Value* (float, len 8).}
#'   \item{`BASETYPE`}{*Baseline Type* (text, len 30) -- baseline
#'     definition flag for analyses with multiple baselines.}
#'   \item{`CHG`}{*Change from Baseline* (float, len 8) -- `AVAL - BASE`.}
#'   \item{`PCHG`}{*Percent Change from Baseline* (float, len 8) --
#'     `100 * CHG / BASE`.}
#'   \item{`VISITNUM`}{*Visit Number* (float, len 8) -- numeric visit
#'     order from SDTM.}
#'   \item{`VISIT`}{*Visit Name* (text, len 19) -- visit label from SDTM.}
#'   \item{`VSSEQ`}{*Sequence Number* (integer, len 8) -- record sequence
#'     within (`USUBJID`, `VSTESTCD`).}
#'   \item{`ANL01FL`}{*Analysis Flag 01* (text, len 1) -- primary-analysis
#'     record flag.}
#'   \item{`ABLFL`}{*Baseline Record Flag* (text, len 1) -- `"Y"` on the
#'     row used to derive `BASE`.}
#' }
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain).
#'   6,138 vital-sign assessments across the 50 pilot subjects.
#'
#' @family pilot-data
#' @seealso [adsl] (population denominator); [adam_spec].
#'
#' @examples
#' nrow(advs)
#' unique(advs$PARAMCD)
#'
#' # Records per parameter
#' table(advs$PARAMCD)
#'
#' # Baseline records only
#' bl <- advs[advs$ABLFL == "Y", ]
#' nrow(bl)
#'
#' # Mean change from baseline by parameter and visit (analysis subset)
#' anl <- advs[advs$ANL01FL == "Y" & !is.na(advs$CHG), ]
#' aggregate(CHG ~ PARAMCD + AVISIT, data = anl, mean)
"advs"

#' Pilot SDTM specification (herald_spec)
#'
#' @description
#' A `herald_spec` object covering **31 SDTM datasets** and **747 variable
#' definitions** from the CDISC pilot study, derived from the pilot
#' `define.xml` via [read_define_xml()] + [as_herald_spec()]. Pass to
#' [apply_spec()] before validating SDTM datasets to activate
#' label-, length-, and codelist-dependent rules.
#'
#' @details
#' ## Object structure
#'
#' A `herald_spec` is a length-2 list with class `c("herald_spec", "list")`:
#'
#' * `$ds_spec` -- 31 rows x 2 columns (`dataset`, `label`).
#' * `$var_spec` -- 747 rows x 10 columns. Every variable across every
#'   dataset.
#'
#' ## Datasets covered (`ds_spec`)
#'
#' All 31 SDTM datasets from the pilot:
#'
#' | Group | Datasets |
#' |-------|----------|
#' | Trial design | `TA`, `TE`, `TI`, `TS`, `TV` |
#' | Demographics / disposition | `DM`, `DS`, `MH`, `SC`, `SE`, `SV` |
#' | Interventions | `CM`, `EX` |
#' | Events | `AE` |
#' | Findings | `LBCH`, `LBHE`, `LBUR` (split lab), `VS`, `QSCO`, `QSDA`, `QSGI`, `QSHI`, `QSMM`, `QSNI` (split questionnaires) |
#' | Special-purpose | `RELREC` |
#' | Supplemental qualifiers | `SUPPAE`, `SUPPDM`, `SUPPDS`, `SUPPLBCH`, `SUPPLBHE`, `SUPPLBUR` |
#'
#' ## Variable metadata columns (`var_spec`)
#'
#' All 10 columns shipped on `var_spec`:
#'
#' \describe{
#'   \item{`dataset`}{Dataset name the variable belongs to (e.g. `"DM"`).}
#'   \item{`variable`}{Variable name (e.g. `"USUBJID"`).}
#'   \item{`label`}{CDISC SDTM variable label (e.g. `"Unique Subject Identifier"`).}
#'   \item{`data_type`}{One of `"text"`, `"integer"`, `"float"`, `"date"`,
#'     `"datetime"`, `"time"`, `"partial_date"`.}
#'   \item{`length`}{Storage length as a string (numeric for `text`,
#'     `"8"` for numerics).}
#'   \item{`origin`}{Variable origin -- `"CRF"`, `"Assigned"`, `"Derived"`,
#'     `"Protocol"`, `"eDT"`, etc.}
#'   \item{`codelist`}{Codelist OID when the variable is controlled
#'     (e.g. `"CL.SEX"`, `"CL.AGEU"`); empty string otherwise.}
#'   \item{`mandatory`}{`"Yes"` / `"No"` -- whether the variable is
#'     required by SDTM-IG.}
#'   \item{`order`}{Variable order as a string -- position within the
#'     dataset.}
#'   \item{`format`}{Display format (e.g. `"$8."`, `"DATE9."`); empty
#'     string when unset.}
#' }
#'
#' @format A `herald_spec` (S3 list, length 2) with elements `ds_spec`
#'   (31 rows, 2 columns) and `var_spec` (747 rows, 10 columns).
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain),
#'   loaded with [read_define_xml()].
#'
#' @family pilot-data
#' @seealso [as_herald_spec()], [apply_spec()], [validate()], [adam_spec].
#'
#' @examples
#' is_herald_spec(sdtm_spec)
#'
#' # Datasets covered
#' sdtm_spec$ds_spec
#'
#' # Total variable definitions
#' nrow(sdtm_spec$var_spec)
#'
#' # All metadata columns shipped on var_spec
#' names(sdtm_spec$var_spec)
#'
#' # Variables in DM, with their controlled-terminology codelists
#' dm_vars <- sdtm_spec$var_spec[sdtm_spec$var_spec$dataset == "DM", ]
#' dm_vars[, c("variable", "label", "codelist", "mandatory")]
#'
#' # Mandatory variable count per dataset
#' mand <- sdtm_spec$var_spec[sdtm_spec$var_spec$mandatory == "Yes", ]
#' table(mand$dataset)
#'
#' \donttest{
#' # Stamp DM with spec attributes, then validate
#' dm_stamped <- apply_spec(dm, sdtm_spec)
#' attr(dm_stamped$USUBJID, "label")
#'
#' r <- validate(files = dm_stamped, quiet = TRUE)
#' }
"sdtm_spec"

#' Pilot ADaM specification (herald_spec)
#'
#' @description
#' A `herald_spec` object covering **12 ADaM datasets** and **509 variable
#' definitions** from the CDISC pilot study, derived from the ADaM
#' `define.xml` via [read_define_xml()] + [as_herald_spec()]. Pass to
#' [apply_spec()] before running ADaM-IG validation to enable label-,
#' length-, and codelist-dependent rules.
#'
#' @details
#' ## Object structure
#'
#' A `herald_spec` is a length-2 list with class `c("herald_spec", "list")`:
#'
#' * `$ds_spec` -- 12 rows x 2 columns (`dataset`, `label`).
#' * `$var_spec` -- 509 rows x 10 columns.
#'
#' ## Datasets covered (`ds_spec`)
#'
#' All 12 ADaM datasets from the pilot:
#'
#' | Dataset | Class | n vars | Label |
#' |---------|-------|-------:|-------|
#' | `ADADAS`  | BDS | 40 | ADAS-Cog Analysis |
#' | `ADAE`    | OCCDS | 55 | Adverse Events Analysis Dataset |
#' | `ADCIBC`  | BDS | 36 | CIBIC+ Analysis |
#' | `ADLBC`   | BDS | 46 | Analysis Dataset Lab Blood Chemistry |
#' | `ADLBCPV` | BDS | 46 | Analysis Dataset Lab Blood Chemistry (Previous Visit) |
#' | `ADLBH`   | BDS | 46 | Analysis Dataset Lab Hematology |
#' | `ADLBHPV` | BDS | 46 | Analysis Dataset Lab Hematology (Previous Visit) |
#' | `ADLBHY`  | BDS | 43 | Analysis Dataset Lab Hy's Law |
#' | `ADNPIX`  | BDS | 41 | NPI-X Item Analysis Data |
#' | `ADSL`    | ADSL | 49 | Subject-Level Analysis |
#' | `ADTTE`   | TTE | 26 | AE Time To 1st Derm. Event Analysis |
#' | `ADVS`    | BDS | 35 | Vital Signs Analysis Dataset |
#'
#' (Class column reflects ADaM IG structure; assigned by herald via
#' [detect_adam_class()].)
#'
#' ## Variable metadata columns (`var_spec`)
#'
#' All 10 columns shipped on `var_spec`:
#'
#' \describe{
#'   \item{`dataset`}{ADaM dataset name (e.g. `"ADSL"`).}
#'   \item{`variable`}{Variable name (e.g. `"TRT01P"`).}
#'   \item{`label`}{ADaM variable label (e.g.
#'     `"Planned Treatment for Period 01"`).}
#'   \item{`data_type`}{One of `"text"`, `"integer"`, `"float"`, `"date"`,
#'     `"datetime"`.}
#'   \item{`length`}{Storage length as a string.}
#'   \item{`origin`}{`"Derived"` for most ADaM variables; `"Predecessor"`
#'     for variables sourced from SDTM (with the source variable in
#'     `format`).}
#'   \item{`codelist`}{Codelist OID when controlled.}
#'   \item{`mandatory`}{`"Yes"` / `"No"` -- ADaM IG required flag.}
#'   \item{`order`}{Variable order as a string.}
#'   \item{`format`}{Display format or predecessor reference.}
#' }
#'
#' @format A `herald_spec` (S3 list, length 2) with elements `ds_spec`
#'   (12 rows, 2 columns) and `var_spec` (509 rows, 10 columns).
#'
#' @source CDISC SDTM/ADaM Pilot Submission Package (public domain),
#'   loaded with [read_define_xml()].
#'
#' @family pilot-data
#' @seealso [as_herald_spec()], [apply_spec()], [validate()],
#'   [detect_adam_class()], [sdtm_spec].
#'
#' @examples
#' is_herald_spec(adam_spec)
#'
#' # Datasets covered
#' adam_spec$ds_spec
#'
#' # Total variable definitions
#' nrow(adam_spec$var_spec)
#'
#' # All metadata columns shipped on var_spec
#' names(adam_spec$var_spec)
#'
#' # Variable count per dataset
#' table(adam_spec$var_spec$dataset)
#'
#' # ADSL variables that are population flags
#' adsl_vars <- adam_spec$var_spec[adam_spec$var_spec$dataset == "ADSL", ]
#' adsl_vars[grepl("FL$", adsl_vars$variable), c("variable", "label")]
#'
#' \donttest{
#' adsl_stamped <- apply_spec(adsl, adam_spec)
#' r <- validate(files = adsl_stamped, quiet = TRUE)
#' }
"adam_spec"
