# DfE 16-19 funding calculation 2026/27: Python reference implementation notes

This is an independent reading of the technical specification v1.00 (the PDF). It was built from
the page images of pages 13-89, with the text extraction used only for exact wording.

Files:
- `dfe_ref.py`: `calculate(case) -> dict` (Learner outputs of pages 34-36, plus `_intermediate`).
- `run_ref.py`: `python3 run_ref.py cases/*.json [--no-intermediate]`, one JSON line per case.
- `make_cases.py`: regenerates `cases/` (96 cases).
- `cases/`: the test cases, each named after what it tests.

## 1. How the OPA semantics were modelled (pages 13-19)

| OPA idea | Decision |
|---|---|
| unknown vs uncertain | Two distinct sentinels, `UNKNOWN` and `UNCERTAIN`. Both are output as `null`. In `_intermediate` they show as `"<unknown>"` and `"<uncertain>"`. |
| and / or (p18) | False wins in `and`, true wins in `or`. Otherwise the result is unknown if any operand is unknown, else uncertain. Page 18 does not cover unknown; I treated it like uncertain, but it takes precedence over uncertain. |
| "is currently known" / "is known" | True for a value **and for UNCERTAIN**, false only for UNKNOWN. Evidence: the rulebase pairs "is currently known and ... is certain" on pages 59, 62, 81, 82 and 87. That pairing only makes sense if an uncertain value counts as known. |
| "is certain" | True for a value, false for UNCERTAIN, UNKNOWN for UNKNOWN. |
| "is unknown" / "is currently unknown" | The negation of "known". In a run driven by data, the two are the same. |
| rule tables (p17) | Rows are read top down and the first true row wins. A row whose condition is UNKNOWN or UNCERTAIN ends the table with that state; it does not fall through. |
| boolean rules | The value of the condition; the alternative conclusion is false (p16). |
| "for at least one" / "for all" | `or` / `and` over the members (an empty set gives false / true). |
| InstanceCount ("the number of") | Count of members. An unknown or uncertain membership makes the count that state. |
| InstanceMaximum / InstanceMinimum ("the latest of all", "which is the greatest for all ... for which") | An empty set gives UNCERTAIN, and any UNKNOWN member value gives UNKNOWN. |
| InstanceValueIf | Exactly one matching instance gives its value. No match, or more than one, gives **UNCERTAIN** (the Oracle function reference). See ambiguity A10 for the consequences. |
| TemporalFromRange / ValueAt | The end date is exclusive, which is why the rulebase adds one day to "effective to" (p62, p81). A record with an unknown "from" date never covers the date. No covering record gives UNCERTAIN. Where records overlap, the one with the latest "from" date wins (my choice). |
| MonthDifference | Whole months: drop one month when the end day-of-month is before the start day-of-month. |
| "number of years between" | Whole years (age at 31 August 2026). |
| DayDifferenceInclusive / "number of days (inclusive)" | `(b - a).days + 1`. |
| contains | Case-sensitive. The psychology rule (p55) tests both "Psychology" and "psychology", which shows the authors expected case-sensitive matching. |
| Input | An absent key or JSON `null` is UNKNOWN. FAM codes are compared as text ("107", "320", "331"). LrnFAM_* values and CompStatus are compared as numbers. |
| LARS categories | Both the `LARSCategories` list and the flat `LearnDelCatRef` form on the delivery are accepted. The list is preferred. |
| PFProgrammeCode | Page 25 makes it an attribute of the LARS programme funding. It is read from each `LARSProgrammeFunding` record when present, otherwise from the delivery (the schema puts it there). |

## 2. Elements implemented (section 4 contents, pages 2-3)

| Element | Page(s) | Function / attribute in `dfe_ref.py` |
|---|---|---|
| Scope of calculations (FM25; CoF looks at all aims) | 37 | `Learner.esfa`, CoF uses `all_lds` |
| Source of funding | 37 | `source_of_funding` |
| Funding line type, Direct Funded | 37-38 | `funding_line`, `LD.is_direct_funded` |
| On-programme funding, base programme funding | 38 | `on_programme_funding`, `base_programme_funding` |
| Grade C or above English/Maths | 39 | `has_eng_c`, `has_maths_c` |
| King's Trust TEAM | 40 | `LD.is_kings_trust_team` |
| Grade D, below grade D | 40-41 | `has_eng_d`, `has_maths_d`, `has_eng_below_d`, `has_maths_below_d` |
| Recognised GCSE English/Maths qualification | 41-44 | `LD._recognised` |
| Exemptions, FSL2, CoF minimum hours, CoF not required | 44 | `eng_exemption` ... `cof_not_required` |
| English / Maths CoF status tables | 45-48 | `_cof_status` |
| LARS validity upper category, number of LARS validity records, uppercase grades | 48 | `Validity.upper_category`, `LD.n_lars_validity`, `upper_eng/upper_math` |
| National rate: rate band, HNS, EHC, national rate | 49-52 | `rate_band`, `is_hns`, `is_ehc`, `national_rate` |
| Total planned hours, FTE | 53 | `total_planned_hours`, `fte` |
| Learning delivery academic flag, upper awarding organisation | 54 | `LD.is_academic`, `LD.upper_award_org` |
| General studies / critical thinking, psychology | 55 | `LD.is_gs_or_ct`, `LD.is_psychology` |
| Studying an academic programme | 55 | `is_academic_programme` |
| New retention status (RetentNew) | 55-57 | `retent_new` |
| Historic retention | 58 | `hist_retention` |
| New programme weighting stage 1 / final | 58-59 | `new_pw_stage1`, `new_pw` |
| A level aims attracting uplift, count, low PCW criteria | 59 | `LD.is_a_level_uplift`, `count_a_level_uplift`, `low_pcw_criteria` |
| Learning delivery's programme weighting (SSA table) | 60 | `LD.programme_weighting` |
| Historic programme weighting, area cost, large programme proportion | 61 | `hist_pw`, `hist_acf`, `large_prog_prop` |
| Postcode specialist resources (applicable to date, temporal flag, membership, counts) | 62 | `PostcodeSR.*`, `LD.pc_sr_*` |
| Latest learning delivery start date | 63 | `latest_ld_start` (intermediate only; not used by any rule) |
| Block 1, block 2 disadvantage | 64 | `block1`, `no_*_by_y11`, `block2` |
| Historic disadvantage proportion | 64-65 | `hist_disadv` |
| English and maths elements, instances | 66-67 | `eng_d_or_below` ... `em_instances` |
| Historic English and maths proportion | 67 | `hist_em_prop` |
| Parameters | 68-69 | module constants |
| Summer school, learner is a start | 69 | `is_summer_school`, `is_start` |
| Qualifying period, planned days, actual days | 70 | `qualifying_period`, `planned_days`, `actual_days` |
| Start / planned end / actual end dates (and "this year") | 70-72 | `start_date`, `start_this_year`, `plan_end_date`, `plan_end_this_year`, `LD.adjusted_act_end`, `act_end_date`, `act_end_this_year` |
| Payment period, planned duration, age | 72 | `payment_period`, `LD.planned_duration`, `age` |
| Learning delivery valid start for CoF, qualifying period, planned/actual days, planned end this year | 73-74 | `LD.is_start`, `LD.is_valid_start_cof`, `LD.qualifying_period`, `LD.planned_days`, `LD.actual_days`, `LD.plan_end_this_year` |
| Core aim selection (core aim, number, latest start, latest TQ start, sequence number), ESFA membership | 75-76 | `core_aims`, `n_core`, `latest_core_start`, `latest_tq_core_start`, `core_aim_seq`, `LD.m_esfa` |
| T level student, latest programme is a T level, T level programme aims, number, latest start/seq | 77-78 | `latest_core_is_tlevel`, `is_tlevel`, `tl_prog_aims`, `n_tl_prog`, `latest_tl_prog_start`, `latest_tl_prog_seq` |
| Year 3+, 2021-2022 starter | 79 | `tl_year3`, `tl_starter_2122` |
| Transition programme aims (number, latest start/seq), latest programme is Transition, transition student | 79-80 | `tl_transition_aims`, `n_transition`, `latest_transition_*`, `latest_prog_is_transition` |
| LARS programme funding applicable to date, T level funding bands/PCWs (temporal), T level funding band | 81 | `ProgFunding.applicable_to`, `LD.applicable_tl_*`, `tl_funding_band(_stage1)` |
| T level PCW stage 1 and final | 82 | `tl_pcw_stage1`, `tl_pcw` |
| T level additional hours, repeating up to one full final year | 83 | `tl_additional_hours`, `repeating_final_year` |
| National T level transition programme PCW | 84-86 | `national_transition_pcw` |
| T level OS aims (aims, continuing aims, number, latest seq, has continuing) | 87-88 | `os_aims`, `continuing_os_aims`, `n_os`, `has_continuing_os`, `latest_os_seq` |
| Latest T level TQ / OS learning aim reference | 88-89 | `tq_learn_aim_ref`, `os_learn_aim_ref` |
| Latest T level programme aim start / planned end / actual end | 89 | `tl_prog_start`, `tl_prog_plan_end`, `tl_prog_act_end` |
| HRS record uppercase type, T level delivery hours, T level hours amount | 89 | `HRS.*`, `LD.tl_hours_amount` |
| Annex A (programme cost weightings by SSA) | 60 / 89 | `SSA_WEIGHTS` (see section 3) |
| T Level and Transition programme cost weightings | 68-69, 81-86 | `NATIONAL_PCW_ZTPR`, LARS `PFTlevelPCW` |
| Annex B (area cost uplift by region) | 89 | Not needed: the provider's area cost factor is an input (`AreaCostFactor1618`, p21). |

All 39 Learner outputs of pages 34-36 are produced, including `LearnRefNumber`, which is passed through. The Global
outputs (RulebaseVersion, UKPRN, LARSVersion, OrgVersion, PostcodeDisadvantageVersion) only pass input through.
They were not asked for and are not produced.

**Not implemented / not implementable:** nothing in section 4 was left out. The "Postcode disadvantage uplift"
lookup on page 27 (the postcode table) is outside the rulebase: the input is the uplift value itself.

## 3. Annex A: programme cost weightings

Page 60 does not refer to an outside table. Its rule table holds the whole SSA-to-weighting mapping:
- 1.15 for the low PCW criteria;
- 2.09 for SSA 3.1, 3.2 or 3.3 with specialist resources;
- 1.73 for 4.1, 4.2, 4.3 and 5.2;
- 1.58 for 3.1-3.4;
- 1.44 for 7.4 and 6.1;
- 1.29 for 5.1, 5.3, 7.1, 7.3, 9.1, 9.2, 13.1 and 13.2;
- 1 otherwise.

I implemented that table (`SSA_WEIGHTS`) and cross-checked it against the DfE's published Annex A, table A1. They are identical.
- Source: https://www.gov.uk/government/publications/funding-rates-and-formula/16-to-19-funding-2025-to-2026-rates-and-formula
  (2025 to 2026 is the latest year that publishes the table).
- https://www.gov.uk/guidance/16-to-19-funding-information-for-2026-to-2027 states that there are no planned
  changes to programme cost weightings for 2026 to 2027.

So `provider["SSAWeightings"]` is not needed.

## 4. Ambiguities, scrambled passages and inconsistencies (with my decisions)

**A1. Page 41, recognised GCSE English: missing "or" between the first two groups.** The English rule reads
"both [ECF known and ECF = 4] / all [valid start ...] / or / all [...] / or / all [... King's Trust TEAM]". There is no
"or" between the "both" group and the first "all" group. The Maths rule on page 42 has it ("both ... or all ...").
Read literally, English would be "(ECF = 4 and branch B) or C or D".
**Decision:** treat it as "or", the same as Maths. ECF code 4 means "studying GCSE English elsewhere", so it should
make the qualification recognised on its own.

**A2. Pages 62 and 60, postcode specialist resource count has no postcode test.** The rule
"...member of the learning delivery's postcode specialist resource reference data for applicable start date" tests only
the dates. Its sibling "...for delivery location postcode" also tests the postcode. Page 60 (and pages 82 and 84) use
the count of the first set (`> 0` / `= 0`) and the "Y" flag from the second.
**Decision:** read it literally. The count is the number of global postcode records effective on 1 August 2026,
whatever their postcode.
- Consequence: if reference data exists only for other postcodes, the count is > 0, so the "count = 0 and provider has
  specialist resources" row cannot fire. SSA 3.x then falls to 1.58.
- Case: `sp_ssa_3_3_postcode_data_other_postcode_only`.
- If the other implementation scopes the count to the delivery's postcode, it gets 2.09 here.

**A3. Page 62, the "+1 day" makes the effective-to date inclusive at both ends.** Membership tests "first day of the
current funding year is on or earlier than the applicable effective to date", and that date is effective-to + 1.
A record ending 31 July 2026 therefore still counts on 1 August 2026.
**Decision:** literal (case `sp_ssa_3_1_postcode_record_ended_31_july_2026` gives 2.09). The ValueAt/TemporalFromRange
uses of the same date (exclusive end) would give the opposite answer. That only affects the unused
`applicable_postcode_sr_flag`.

**A4. Page 55, general studies: no connector between the two groups.** The "either (title contains ...)" group is
followed by "the learning delivery's learning aim reference type is currently known and any (...)" with no "and"/"or".
**Decision:** "and". This flags A-level (0001/0002) General Studies or Critical Thinking.

**A5. Page 86, last row of the transition PCW (ZTPR0012).** The condition "the learning delivery's learning aim
reference = 'ZTPR0012'" is drawn at level 1, outside the "for at least one of the learner's ESFA 16-19 learning
deliveries" scope, where no learning delivery is in context.
**Decision:** treat it as inside the scope, like every other row.

**A6. Page 58 commentary versus the rules.**
- The commentary says science A levels attract a 1.1 weighting. The rule (p60) gives 1.15.
- The commentary says King's Trust TEAM carries 1.3. The rule (p59) gives 1.44.

**Decision:** the rules (both agree with gov.uk Annex A).

**A7. Page 59, "the learner's low PCW criteria" is the first row of every delivery's programme weighting (p60).**
A learner who meets the low criteria therefore has 1.15 on every delivery. That includes the academic case, because
the low row comes before "academic → 1". This is consistent with the commentary (2+ science A levels → 1.15).
Implemented literally.

**A8. Page 69, learner is a start.** "the T level learner is not a year 3+ student or both (year 3+ and repeating)".
Implemented literally; the second alternative is redundant.

**A9. Page 44 commentary versus the rule.** The text says "For 2025/26 the logic will remain unchanged ... Review again
for 2026/27". The rule still tests "latest ESFA 16-19 T level programme aim start date < 2022-08-01" and
"2021-2022 year or earlier starter (<= 2022-07-31)". Implemented as written.

**A10. Page 53 / 89, T level hours from HRS records.** "the learning delivery's T level hours amount" is an
InstanceValueIf over the HRS records.
- With Oracle's documented semantics, no matching HRS record gives UNCERTAIN, and "is currently known" is then
  **true**.
- So a T level learner whose latest programme aim has no HRS/2 record has total planned hours UNCERTAIN. Rate band,
  national rate, FTE, start and on-programme funding are then all `null`.

**Decision:** implemented this way; case `tlevel_programme_aim_without_hrs_record`. If the other implementation
treats "no match" as unknown, it falls through to PlanLearnHours + PlanEEPHours instead. This is the most likely point
of disagreement on T levels.

**A11. Uncertain values propagate as "known".** The same rule ("currently known" includes uncertain) is used for
"it is known whether or not the T level learner is a 2021-2022 year or earlier starter" (p83). For a T level student
with no T level programme aim, that value is uncertain, so TLevelAdditionalHours is `null`.

**A12. Scope of "ESFA 16-19" names (pages 77, 79).** Membership of "the learner's ESFA 16-19 T level programme aims"
(p77) and "...transition programme aims" (p79) is defined over "the learner's learning deliveries", with no FundModel
test, despite the name. T level OS aims (p87) do require ESFA membership.
**Decision:** literal. It only matters if a non-FM25 aim with ProgType 31 / 30 and AimType 1 is present.

**A13. Pages 37 / 45-47, the condition of funding looks at all aims.** The status tables use "the learner's learning
deliveries", not the ESFA 16-19 subset. Page 37 says the condition of funding element "will look across all aims".
**Decision:** all deliveries in the case, whatever the FundModel. Case `cof_gcse_in_other_funding_model_counts`
(an FM35 GCSE maths).

**A14. Page 41, the "valid start for CoF" uses the delivery's own dates.**
- Planned days run from the delivery's real start date, which is not moved forward to 1 August. Only the planned end
  is capped at 31 July 2027.
- Actual days use the adjusted actual end, which is not capped.
- So an aim that started and ended in an earlier year can still be a "valid start" (the pages 73-74 rules are
  literal). Implemented as written.

**A15. Page 66, the instance rules require the CoF exemption.** "the learner has an English instance if ... the learner
is exempt from GCSE English condition of funding due to a learning difficulty or prior attainment". That attribute is
true when ECF is unknown or ECF ∈ {1, 4, 5}. Its name suggests the opposite of the commentary, but it is implemented
exactly as written. Together with "Grade D or below" (ECF not 2/3), a learner with ECF 1 gets an instance even
though they are exempt (case `cof_exempt_ecf1_mcf2` → 1 instance, from English).

**A16. Page 39, the ECF = 3 / MCF = 3 path still needs a known grade.** "Grade C or above" is "grade currently known
and either (grade in list) or (ECF known and = 3)". With ECF = 3 and no grade, the result is false. Literal.

**A17. Page 50, T level bands.**
- "1580 hours (T level Band 8 uplifted)" accepts only funding band "8 uplifted". A band-9 learner with 1,580-1,729 hours
  gets "Band 8" (not uplifted).
- The T level Band 5 row needs only "T level student and hours >= 580", whatever the funding band.
- A T level student under 580 hours falls past the "not a T level student" rows into "485 to 579 hours (Band 4b)" or
  lower (case `tlevel_500_hours_falls_to_band4b`).

**A18. Page 51, the rate band row "None" can never be reached.** The Band 1 threshold is 0, so 0 hours gives Band 1 with
a national rate of 0 (case `sp_no_hours_at_all_zero_hours_band1`). "None" appears only when the hours are uncertain
(the table then returns uncertain, not "None").

**A19. Page 63, "the learner's latest learning delivery start date".** Defined but not used by any other rule. Output
as an intermediate.

**A20. Page 62, "applicable postcode specialist resource flag" (TemporalFromRange / ValueAt).** Also defined but
unused. It is an intermediate.

**A21. Page 81, overlapping LARS programme funding records.** The spec does not say what TemporalFromRange does with
overlapping ranges. The latest-starting record wins.

**A22. Page 88, InstanceValueIf with several matches.** TQ / OS learn-aim-ref and T level programme aim dates look up
the delivery by AimSeqNumber, which is unique in the ILR. If it were duplicated the result would be uncertain.

**A23. Page 70, the qualifying period ignores the actual end.** Row 1 (42 days) needs only hours >= 485 and planned
days >= 14. That agrees with page 7, table 2.

**A24. Page 72, payment period.** The ExtractMonth(...) + 5 / - 7 arithmetic maps August → 1 ... July → 12. It is based
on the start date *this year*, so a learner continuing from an earlier year gets period 1.

**A25. Page 37, the funding line uses `<` / `<=` on the age.** The "19-24 EHCP" line requires EHC = 1 (p51). A learner
aged 25 or over with an EHCP is "19+ Continuing Students (excluding EHCP)" (case `sp_age25_ehc_19plus_continuing_line`).
Literal.

**A26. Section 1 (pages 6-7) versus the rulebase.** Table 1 says T level Band 5 is "580 hours"; the rulebase rate band
text is "580 to 1179 hours (T level Band 5)". The rates themselves agree with the parameters on page 68. The
rulebase is authoritative.

## 5. Test cases (96)

The names say what each case tests. The groups are:
- **study programmes:** vocational and academic, A level, IB, core maths, AAQ, general studies, unknown aim type, King's
  Trust TEAM, every SSA weighting row including the three specialist-resource variants and an unknown provider flag;
- **bands:** 5, 4a, 4b, 3, 2, 1, zero hours, and only one of the two hour fields known;
- **ages 14-25:** high needs, EHCP 19-24 and 25+, direct-funded 14-16, summer school;
- **dates and retention:** early leaver below the qualifying period, short programme (14 days), withdrawals (reason 40,
  reason 2, and the two-year after-30-June rule on both sides), academic retention through a non-core aim, continuing
  from an earlier year, January start, ended last year, starts after the year, unknown planned end;
- **core aim selection:** latest start and a tie on start date;
- **missing data:** no core aim, missing SOF, missing date of birth, missing provider factors;
- **condition of funding:** every status in the page 12 table for English and Maths (plus ECF/MCF 3 and 4, a GCSE in
  another funding model, early-leaver GCSE aims, lower-case grades, a LARS validity whose last new start date has
  passed, missing grades, does-not-apply by hours / age / pre-2022 T level);
- **disadvantage:** block 2 = 0/1/2, no postcode uplift;
- **instances:** 0/1/2 with ECF 2/4/5;
- **T levels:** bands 9, 8 uplifted, 8, 7 uplifted, 7, 6 uplifted, band 5 default with no LARS funding, under 580 hours,
  year 3+ with and without NLM 22, 2021-22 starter +40 hours, programme aim without an HRS record, OS programme code 52
  with postcode Y → 2.09, two OS aims (one continuing / both closed), second year, withdrawn;
- **transition programmes:** ZTPR0005, ZTPR0001 with and without specialist resources, an unlisted ZTPR.

Run: `python3 run_ref.py cases/*.json` (all 96 run without error).
