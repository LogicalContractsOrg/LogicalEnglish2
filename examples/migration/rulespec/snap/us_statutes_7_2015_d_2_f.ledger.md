# Migration ledger: us_statutes_7_2015_d_2_f

Source: Axiom RuleSpec — sources/us/statutes/7/2015/d/2/F.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 8 |
| approximated | 0 |
| residue | 0 |
| **total** | 8 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/d/2/F#youth_exemption_lower_age_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_youth_exemption_lower_age_years |  |
| us:statutes/7/2015/d/2/F#youth_exemption_upper_age_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_youth_exemption_upper_age_years |  |
| us:statutes/7/2015/d/2/F#youth_work_requirement_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_youth_work_requirement_exemption_applies |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input person_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_age_years |  |
| input person_is_snap_household_head | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_snap_household_head |  |
| input person_is_attending_school_at_least_half_time | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_attending_school_at_least_half_time |  |
| input person_is_enrolled_in_employment_training_program_at_least_half_time | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_enrolled_in_employment_training_program_at_least_half_time |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| youth_between_sixteen_and_eighteen_not_head_of_household_exempt | q_youth_work_requirement_exemption_applies | pass |  |
| youth_head_of_household_attending_school_at_least_half_time_exempt | q_youth_work_requirement_exemption_applies | pass |  |
| youth_head_of_household_enrolled_in_employment_training_at_least_half_time_exempt | q_youth_work_requirement_exemption_applies | pass |  |
| age_eighteen_not_within_youth_exemption_no_exemption | q_youth_work_requirement_exemption_applies | pass |  |

