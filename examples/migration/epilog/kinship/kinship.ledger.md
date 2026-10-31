# Migration ledger: kinship

Source: an Epilog ruleset — kinship.rules, kinship.data
Translator: lpsPlus/migration/epilog (epilog_twin.pl)
Date: 2026-10-31

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: **5 of 5** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| anc/2 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | anc |  |
| childless/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | childless |  |
| gp/2 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | gp |  |
| isparent/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | isparent |  |
| person/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | person |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| dataset | anc | pass |  |
| dataset | childless | pass |  |
| dataset | gp | pass |  |
| dataset | isparent | pass |  |
| dataset | person | pass |  |

