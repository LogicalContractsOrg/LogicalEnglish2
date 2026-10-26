# Migration ledger: loop

Source: DMN — loop.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: **22 of 22** source test expectation(s) reproduced (100%).

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
| Eligible_while_on_Homestead | q_d_is_eligible | pass |  |
| Eligible_with_five_year_increase | q_d_is_eligible | pass |  |
| Eligible_with_five_year_increase | q_d_assessment_increase_of_the_checks | pass |  |
| Eligible_with_payment_plan | q_d_is_eligible | pass |  |
| Eligible_with_payment_plan | q_d_taxes_current_or_payment_plan_of_the_checks | pass |  |
| Eligible | q_d_is_eligible | pass |  |
| Fails_AssessmentIncrease | q_d_is_eligible | pass |  |
| Fails_AssessmentIncrease | q_d_assessment_increase_of_the_checks | pass |  |
| Fails_MeetsIncomeRequirement | q_d_is_eligible | pass |  |
| Fails_MeetsIncomeRequirement | q_d_meets_income_requirement_of_the_checks | pass |  |
| Fails_NoDisqualifyingTaxAbatement | q_d_is_eligible | pass |  |
| Fails_NoDisqualifyingTaxAbatement | q_d_no_disqualifying_tax_abatement_of_the_checks | pass |  |
| Fails_TaxesCurrentOrPaymentPlan | q_d_is_eligible | pass |  |
| Fails_TaxesCurrentOrPaymentPlan | q_d_taxes_current_or_payment_plan_of_the_checks | pass |  |
| Fails_TenYearsOwnerOccupant | q_d_is_eligible | pass |  |
| Fails_TenYearsOwnerOccupant | q_d_ten_years_owner_occupant_of_the_checks | pass |  |
| Ineligible | q_d_is_eligible | pass |  |
| Ineligible | q_d_owner_occupant_of_the_checks | pass |  |
| Next_steps | q_d_is_eligible | pass |  |
| Smoke_Test | q_d_is_eligible | pass |  |

