# Migration ledger: blocks

Source: an Epilog ruleset — blocks.rules, blocks.data
Translator: lpsPlus/migration/epilog (epilog_twin.pl)
Date: 2026-10-31

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 0 |
| **total** | 6 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| above/2 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | above |  |
| clear/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | clear |  |
| cluttered/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | cluttered |  |
| stack/3 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | stack |  |
| supported/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | supported |  |
| table/1 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | table |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| dataset | above | pass |  |
| dataset | clear | pass |  |
| dataset | cluttered | pass |  |
| dataset | stack | pass |  |
| dataset | supported | pass |  |
| dataset | table | pass |  |

