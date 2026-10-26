# Migration ledger: loop_income

Source: DMN — loop-income.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **29 of 29** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checkResult | literal expression | encoded | literal expression | checkResult |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Fail | q_d_check_result | pass |  |
| Invalid_income | q_d_check_result | pass |  |
| Null | q_d_check_result | pass |  |
| Pass | q_d_check_result | pass |  |
| Size_1_at_cap | q_d_check_result | pass |  |
| Size_1_below_cap | q_d_check_result | pass |  |
| Size_10_at_cap | q_d_check_result | pass |  |
| Size_10_below_cap | q_d_check_result | pass |  |
| Size_2_at_cap | q_d_check_result | pass |  |
| Size_2_below_cap | q_d_check_result | pass |  |
| Size_3_at_cap | q_d_check_result | pass |  |
| Size_3_below_cap | q_d_check_result | pass |  |
| Size_4_at_cap | q_d_check_result | pass |  |
| Size_4_below_cap | q_d_check_result | pass |  |
| Size_5_at_cap | q_d_check_result | pass |  |
| Size_5_below_cap | q_d_check_result | pass |  |
| Size_6_at_cap | q_d_check_result | pass |  |
| Size_6_below_cap | q_d_check_result | pass |  |
| Size_7_at_cap | q_d_check_result | pass |  |
| Size_7_below_cap | q_d_check_result | pass |  |
| Size_8_at_cap | q_d_check_result | pass |  |
| Size_8_below_cap | q_d_check_result | pass |  |
| Size_9_at_cap | q_d_check_result | pass |  |
| Size_9_below_cap | q_d_check_result | pass |  |
| Unknown_or_unsupported_size__1 | q_d_check_result | pass |  |
| Unknown_or_unsupported_size_0 | q_d_check_result | pass |  |
| Unknown_or_unsupported_size_1_5 | q_d_check_result | pass |  |
| Unknown_or_unsupported_size_11 | q_d_check_result | pass |  |
| Unknown_or_unsupported_size_None | q_d_check_result | pass |  |

