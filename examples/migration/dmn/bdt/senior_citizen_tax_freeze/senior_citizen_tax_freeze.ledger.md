# Migration ledger: senior_citizen_tax_freeze

Source: DMN — senior-citizen-tax-freeze.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checks | context | encoded | context | checks |  |
| isEligible | context | encoded | context | isEligible |  |
| nextSteps | literal expression | encoded | literal expression | nextSteps |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Age_Req_Fail_with_no_spouse | q_d_is_eligible | pass |  |
| Age_Req_Fail_with_no_spouse | q_d_meets_age_requirement_of_the_checks | pass |  |
| Age_Req_null_with_only_client_DOB | q_d_is_eligible | pass |  |
| Age_Req_null_with_only_client_DOB | q_d_meets_age_requirement_of_the_checks | pass |  |
| Age_Req_true_with_only_client_DOB___65 | q_d_is_eligible | pass |  |
| Age_Req_true_with_only_client_DOB___65 | q_d_meets_age_requirement_of_the_checks | pass |  |
| Eligible__late_spouse_was_65__ | q_d_is_eligible | pass |  |
| Eligible | q_d_is_eligible | pass |  |
| Ineligible__late_spouse_was_65__ | q_d_is_eligible | pass |  |
| Ineligible | q_d_is_eligible | pass |  |
| Next_steps | q_d_is_eligible | pass |  |
| Smoke_Test | q_d_is_eligible | pass |  |

