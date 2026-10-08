# Migration ledger: us_policies_usda_snap_fy_2026_cola_income_eligibility_standards

Source: Axiom RuleSpec — sources/us/policies/usda/snap/fy-2026-cola/income-eligibility-standards.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **9 of 9** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_net_income_limit_100_percent_fpl_48_states_dc_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_net_income_limit_100_percent_fpl_48_states_dc_table |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_net_income_limit_100_percent_fpl_48_states_dc_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_net_income_limit_100_percent_fpl_48_states_dc_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_net_income_limit_100_percent_fpl_48_states_dc | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income_limit_100_percent_fpl_48_states_dc |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_130_percent_fpl_48_states_dc_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_130_percent_fpl_48_states_dc_table |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_130_percent_fpl_48_states_dc_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_130_percent_fpl_48_states_dc_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_130_percent_fpl_48_states_dc | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_130_percent_fpl_48_states_dc |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_165_percent_fpl_48_states_dc_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_165_percent_fpl_48_states_dc_table |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_165_percent_fpl_48_states_dc_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_165_percent_fpl_48_states_dc_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/income-eligibility-standards#snap_gross_income_limit_165_percent_fpl_48_states_dc | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_gross_income_limit_165_percent_fpl_48_states_dc |  |
| input household_size | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_size |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| income_standards_for_one_person_household | q_snap_gross_income_limit_130_percent_fpl_48_states_dc | pass |  |
| income_standards_for_one_person_household | q_snap_gross_income_limit_165_percent_fpl_48_states_dc | pass |  |
| income_standards_for_one_person_household | q_snap_net_income_limit_100_percent_fpl_48_states_dc | pass |  |
| income_standards_for_eight_person_household | q_snap_gross_income_limit_130_percent_fpl_48_states_dc | pass |  |
| income_standards_for_eight_person_household | q_snap_gross_income_limit_165_percent_fpl_48_states_dc | pass |  |
| income_standards_for_eight_person_household | q_snap_net_income_limit_100_percent_fpl_48_states_dc | pass |  |
| income_standards_add_each_additional_person | q_snap_gross_income_limit_130_percent_fpl_48_states_dc | pass |  |
| income_standards_add_each_additional_person | q_snap_gross_income_limit_165_percent_fpl_48_states_dc | pass |  |
| income_standards_add_each_additional_person | q_snap_net_income_limit_100_percent_fpl_48_states_dc | pass |  |

