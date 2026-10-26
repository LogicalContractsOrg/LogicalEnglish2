# Migration ledger: 0003_input_data_string_allowed_values

Source: DMN — 0003-input-data-string-allowed-values.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Employment Status Statement | literal expression | encoded | literal expression | Employment Status Statement |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_employment_status_statement | pass |  |

