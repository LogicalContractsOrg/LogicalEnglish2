# Migration ledger: us_statutes_42_1382_a_3

Source: Axiom RuleSpec — sources/us/statutes/42/1382/a/3.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 8 |
| approximated | 0 |
| residue | 0 |
| **total** | 8 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B | parameter | encoded | parameter -> a fact, cited, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B |  |
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B | parameter | encoded | rule, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B |  |
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_ii | parameter | encoded | parameter -> a fact, cited, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_ii |  |
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_ii | parameter | encoded | rule, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_ii |  |
| us:statutes/42/1382/a/3#couple_or_living_with_spouse_resource_limit | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_couple_or_living_with_spouse_resource_limit |  |
| us:statutes/42/1382/a/3#couple_or_living_with_spouse_resource_limit | derived | encoded | rule | rs_couple_or_living_with_spouse_resource_limit |  |
| us:statutes/42/1382/a/3#individual_no_spouse_resource_limit | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_individual_no_spouse_resource_limit |  |
| us:statutes/42/1382/a/3#individual_no_spouse_resource_limit | derived | encoded | rule | rs_individual_no_spouse_resource_limit |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| resource_limits_prior_to_january_1985 | q_couple_or_living_with_spouse_resource_limit | pass |  |
| resource_limits_prior_to_january_1985 | q_individual_no_spouse_resource_limit | pass |  |
| resource_limits_on_january_1985 | q_couple_or_living_with_spouse_resource_limit | pass |  |
| resource_limits_on_january_1985 | q_individual_no_spouse_resource_limit | pass |  |
| resource_limits_on_january_1989 | q_couple_or_living_with_spouse_resource_limit | pass |  |
| resource_limits_on_january_1989 | q_individual_no_spouse_resource_limit | pass |  |

