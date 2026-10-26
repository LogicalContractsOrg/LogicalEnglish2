# Migration ledger: awb_completeness_check

Source: DMN — awb-completeness-check.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Awb Admissibility Check | decision table | encoded | decision table | Awb Admissibility Check |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_awb_article_of_the_awb_admissibility_check | pass |  |
| g001 | q_d_is_complete_of_the_awb_admissibility_check | pass |  |
| g001 | q_d_missing_fields_of_the_awb_admissibility_check | pass |  |
| g002 | q_d_awb_article_of_the_awb_admissibility_check | pass |  |
| g002 | q_d_is_complete_of_the_awb_admissibility_check | pass |  |
| g002 | q_d_missing_fields_of_the_awb_admissibility_check | pass |  |
| g003 | q_d_awb_article_of_the_awb_admissibility_check | pass |  |
| g003 | q_d_is_complete_of_the_awb_admissibility_check | pass |  |
| g003 | q_d_missing_fields_of_the_awb_admissibility_check | pass |  |
| g004 | q_d_awb_article_of_the_awb_admissibility_check | pass |  |
| g004 | q_d_is_complete_of_the_awb_admissibility_check | pass |  |
| g004 | q_d_missing_fields_of_the_awb_admissibility_check | pass |  |
| g005 | q_d_awb_article_of_the_awb_admissibility_check | pass |  |
| g005 | q_d_is_complete_of_the_awb_admissibility_check | pass |  |
| g005 | q_d_missing_fields_of_the_awb_admissibility_check | pass |  |

