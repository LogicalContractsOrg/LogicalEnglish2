# Migration ledger: 0106_feel_ternary_logic

Source: DMN — 0106-feel-ternary-logic.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 0 |
| residue | 0 |
| **total** | 2 |

Fidelity: **18 of 18** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| DecisionAnd | literal expression | encoded | literal expression | DecisionAnd |  |
| DecisionOr | literal expression | encoded | literal expression | DecisionOr |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_decision_and | pass |  |
| t001 | q_d_decision_or | pass |  |
| t002 | q_d_decision_and | pass |  |
| t002 | q_d_decision_or | pass |  |
| t003 | q_d_decision_and | pass |  |
| t003 | q_d_decision_or | pass |  |
| t004 | q_d_decision_and | pass |  |
| t004 | q_d_decision_or | pass |  |
| t005 | q_d_decision_and | pass |  |
| t005 | q_d_decision_or | pass |  |
| t006 | q_d_decision_and | pass |  |
| t006 | q_d_decision_or | pass |  |
| t007 | q_d_decision_and | pass |  |
| t007 | q_d_decision_or | pass |  |
| t008 | q_d_decision_and | pass |  |
| t008 | q_d_decision_or | pass |  |
| t009 | q_d_decision_and | pass |  |
| t009 | q_d_decision_or | pass |  |

