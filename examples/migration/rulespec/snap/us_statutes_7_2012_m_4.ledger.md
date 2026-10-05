# Migration ledger: us_statutes_7_2012_m_4

Source: Axiom RuleSpec — sources/us/statutes/7/2012/m/4.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
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
| us:statutes/7/2012/m/4#individual_or_group_shall_not_constitute_household | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_individual_or_group_shall_not_constitute_household |  |
| us:statutes/7/2012/m/4#individual_or_group_shall_not_constitute_household | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_individual_or_group_shall_not_constitute_household |  |
| input individual_or_group_resides_in_institution | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_group_resides_in_institution |  |
| input individual_or_group_resides_in_boarding_house | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_group_resides_in_boarding_house |  |
| input individual_or_group_lives_with_others | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_group_lives_with_others |  |
| input individual_or_group_pays_compensation_to_others_for_meals | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_group_pays_compensation_to_others_for_meals |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| institution_resident_cannot_constitute_household | q_individual_or_group_shall_not_constitute_household | pass |  |
| boarding_house_resident_cannot_constitute_household | q_individual_or_group_shall_not_constitute_household | pass |  |
| lives_with_others_without_meal_compensation_not_barred | q_individual_or_group_shall_not_constitute_household | pass |  |
| lives_with_others_and_pays_for_meals_cannot_constitute_household | q_individual_or_group_shall_not_constitute_household | pass |  |

