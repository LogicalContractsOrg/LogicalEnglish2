# Migration ledger: cat_section_132

Source: Catala (catala-examples) — sources/cat/section_132.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-06
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 2 |
| residue | 0 |
| **total** | 9 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:section_132#aggregate_cost | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aggregate_cost |  |
| cat:section_132#customer_price | input | encoded | input -> a fact the scenario states | rs_customer_price |  |
| cat:section_132#discount_type | input | encoded | input -> a fact the scenario states | rs_discount_type |  |
| cat:section_132#employee_discount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_employee_discount |  |
| cat:section_132#employee_price | input | encoded | input -> a fact the scenario states | rs_employee_price |  |
| cat:section_132#gross_profit_percentage | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_gross_profit_percentage | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:section_132#is_property | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_property |  |
| cat:section_132#is_services | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_services |  |
| cat:section_132#qualified_employee_discount | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_qualified_employee_discount | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| TestSection132_1 | q_employee_discount | pass |  |
| TestSection132_1 | q_gross_profit_percentage | pass |  |
| TestSection132_1 | q_qualified_employee_discount | pass |  |
| TestSection132_2 | q_employee_discount | pass |  |
| TestSection132_2 | q_gross_profit_percentage | pass |  |
| TestSection132_2 | q_qualified_employee_discount | pass |  |
| TestSection132_3 | q_employee_discount | pass |  |
| TestSection132_3 | q_qualified_employee_discount | pass |  |

