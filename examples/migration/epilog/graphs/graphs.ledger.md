# Migration ledger: graphs

Source: an Epilog ruleset — graphs.rules, graphs.data
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
| nonreflexive/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | nonreflexive |  |
| nonsymmetric/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | nonsymmetric |  |
| nontransitive/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | nontransitive |  |
| reflexive/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | reflexive |  |
| symmetric/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | symmetric |  |
| transitive/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | transitive |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| dataset | nonreflexive | pass |  |
| dataset | nonsymmetric | pass |  |
| dataset | nontransitive | pass |  |
| dataset | reflexive | pass |  |
| dataset | symmetric | pass |  |
| dataset | transitive | pass |  |

