# Migration ledger: us_statutes_7_2015_d_2_d

Source: Axiom RuleSpec — sources/us/statutes/7/2015/d/2/D.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 0 |
| residue | 0 |
| **total** | 4 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/d/2/D#treatment_and_rehabilitation_program_participation_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_treatment_and_rehabilitation_program_participation_exemption_applies |  |
| us:statutes/7/2015/d/2/D#treatment_and_rehabilitation_program_participation_exemption_applies | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_treatment_and_rehabilitation_program_participation_exemption_applies |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input person_is_regular_participant_in_drug_addiction_or_alcoholic_treatment_and_rehabilitation_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_regular_participant_in_drug_addiction_or_alcoholic_treatment_and_rehabilitation_program |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| regular_participant_in_treatment_and_rehabilitation_program_exemption_applies | q_treatment_and_rehabilitation_program_participation_exemption_applies | pass |  |
| not_regular_participant_in_treatment_and_rehabilitation_program_no_exemption | q_treatment_and_rehabilitation_program_participation_exemption_applies | pass |  |
| person_not_otherwise_required_has_no_exemption_under_this_branch | q_treatment_and_rehabilitation_program_participation_exemption_applies | pass |  |

