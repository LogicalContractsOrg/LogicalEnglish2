# Migration ledger: low_income_tax_freeze

Source: DMN — low-income-tax-freeze.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| nextSteps | literal expression | encoded | literal expression | nextSteps |  |
| checks | context | encoded | context | checks |  |
| isEligible | context | encoded | context | isEligible |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Already_enrolled | q_d_is_eligible | pass |  |
| Already_enrolled | q_d_not_already_enrolled_of_the_checks | pass |  |
| Eligible | q_d_is_eligible | pass |  |
| Fails_MeetsIncomeRequirement | q_d_is_eligible | pass |  |
| Fails_MeetsIncomeRequirement | q_d_meets_income_requirement_of_the_checks | pass |  |
| Ineligible | q_d_is_eligible | pass |  |
| Ineligible | q_d_owner_occupant_of_the_checks | pass |  |
| Married_at_limit | q_d_is_eligible | pass |  |
| Next_steps | q_d_is_eligible | pass |  |
| Smoke_Test | q_d_is_eligible | pass |  |

