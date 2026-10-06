# Migration ledger: us_statutes_7_2015_d_2_e

Source: Axiom RuleSpec — sources/us/statutes/7/2015/d/2/E.yaml
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
| us:statutes/7/2015/d/2/E#minimum_employment_hours_per_week | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_minimum_employment_hours_per_week |  |
| us:statutes/7/2015/d/2/E#employment_or_earnings_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_employment_or_earnings_exemption_applies |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input employed_hours_per_week | input | encoded | a name no rule defines -> a fact the scenario states | rs_employed_hours_per_week |  |
| input weekly_earnings | input | encoded | a name no rule defines -> a fact the scenario states | rs_weekly_earnings |  |
| input minimum_hourly_rate_under_fair_labor_standards_act | input | encoded | a name no rule defines -> a fact the scenario states | rs_minimum_hourly_rate_under_fair_labor_standards_act |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| employed_minimum_thirty_hours_per_week_exemption_applies | q_employment_or_earnings_exemption_applies | pass |  |
| weekly_earnings_equal_flsa_rate_times_thirty_hours_exemption_applies | q_employment_or_earnings_exemption_applies | pass |  |
| insufficient_hours_and_earnings_no_exemption | q_employment_or_earnings_exemption_applies | pass |  |
| person_not_otherwise_required_has_no_exemption_under_this_branch | q_employment_or_earnings_exemption_applies | pass |  |

