# Migration ledger: thuisbatterij_completeness_check

Source: DMN — thuisbatterij-completeness-check.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **18 of 18** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Thuisbatterij: aanvraag volledig (Awb 4:5) | decision table | encoded | decision table | Thuisbatterij: aanvraag volledig (Awb 4:5) | a rule per row |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g001 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g001 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g002 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g002 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g002 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g003 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g003 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g003 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g004 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g004 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g004 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g005 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g005 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g005 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g006 | q_d_awb_article_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g006 | q_d_is_complete_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |
| g006 | q_d_missing_fields_of_the_thuisbatterij_aanvraag_volledig_awb_4_5 | pass |  |

