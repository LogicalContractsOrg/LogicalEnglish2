# Migration ledger: dvtpdelegationcheck

Source: DMN — DvtpDelegationCheck.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| DvTP Machtiging- en delegatiecheck (FR-02) | decision table | encoded | decision table | DvTP Machtiging- en delegatiecheck (FR-02) |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_delegatie_geblokkeerd_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |
| g001 | q_d_delegatie_reden_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |
| g002 | q_d_delegatie_geblokkeerd_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |
| g002 | q_d_delegatie_reden_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |
| g003 | q_d_delegatie_geblokkeerd_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |
| g003 | q_d_delegatie_reden_of_the_dv_tp_machtiging_en_delegatiecheck_fr_02 | pass |  |

