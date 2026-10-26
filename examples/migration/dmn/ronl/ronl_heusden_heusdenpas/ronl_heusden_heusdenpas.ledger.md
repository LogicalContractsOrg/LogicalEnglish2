# Migration ledger: ronl_heusden_heusdenpas

Source: DMN — RONL_Heusden_Heusdenpas.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 1 |
| residue | 0 |
| **total** | 5 |

Fidelity: **9 of 9** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| RONL Heusdenpas Eindresultaat | decision table | encoded | decision table | RONL Heusdenpas Eindresultaat | a rule per row |
| RONL Heusdenpas Hoofd Aanvraag | decision table | encoded | decision table | RONL Heusdenpas Hoofd Aanvraag | a rule per row |
| RONL Heusdenpas Kindpakket | decision table | encoded | decision table | RONL Heusdenpas Kindpakket | a rule per row |
| RONL Heusdenpas Automatisch | decision table | approximated | decision table | RONL Heusdenpas Automatisch | ANY: the first matching row answers; DMN also reports an error when the matching rows disagree |
| RONL Heusdenpas Knockoffs | decision table | encoded | decision table | RONL Heusdenpas Knockoffs | a rule per row |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g003 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g005 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g006 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g007 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g008 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g009 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g011 | q_d_ronl_heusdenpas_automatisch | pass |  |
| g013 | q_d_ronl_heusdenpas_automatisch | pass |  |

