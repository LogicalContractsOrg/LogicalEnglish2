# Migration ledger: us_statutes_7_2015_d_2_b

Source: Axiom RuleSpec — sources/us/statutes/7/2015/d/2/B.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 0 |
| **total** | 6 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/d/2/B#dependent_child_age_exemption_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_dependent_child_age_exemption_threshold_years |  |
| us:statutes/7/2015/d/2/B#care_responsibility_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_care_responsibility_exemption_applies |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input person_is_parent_or_other_household_member_with_responsibility_for_care_of_dependent_child | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_parent_or_other_household_member_with_responsibility_for_care_of_dependent_child |  |
| input dependent_child_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_dependent_child_age_years |  |
| input person_is_parent_or_other_household_member_with_responsibility_for_care_of_incapacitated_person | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_parent_or_other_household_member_with_responsibility_for_care_of_incapacitated_person |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| dependent_child_under_age_six_care_responsibility_exempts_person | q_care_responsibility_exemption_applies | pass |  |
| incapacitated_person_care_responsibility_exempts_person | q_care_responsibility_exemption_applies | pass |  |
| dependent_child_age_six_or_older_and_no_incapacitated_person_no_exemption | q_care_responsibility_exemption_applies | pass |  |
| person_not_otherwise_required_has_no_exemption_under_this_branch | q_care_responsibility_exemption_applies | pass |  |

