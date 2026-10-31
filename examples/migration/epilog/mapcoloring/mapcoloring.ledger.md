# Migration ledger: mapcoloring

Source: an Epilog ruleset — mapcoloring.rules, mapcoloring.data
Translator: lpsPlus/migration/epilog (epilog_twin.pl)
Date: 2026-10-31

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 0 |
| residue | 1 |
| **total** | 3 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (waits for residue functional_term_1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| goal/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | goal |  |
| illegal/0 | view | encoded | a view definition -> an LE rule (naive wording); its query expects EpilogJS's answers | illegal |  |
| base/1: a sentence with the functional term color(R,H) | functional_term | residue | a Logical English place holds a constant, not a term (such as not(X), and(P,Q) or cell(a,1)): restate the term as a relation, or write it in an included Prolog resource | functional_term_1 |  |

## Residue

- **base/1: a sentence with the functional term color(R,H)** (functional_term) — a Logical English place holds a constant, not a term (such as not(X), and(P,Q) or cell(a,1)): restate the term as a relation, or write it in an included Prolog resource; in the program: functional_term_1. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| dataset | goal | pass |  |
| dataset | illegal | pass |  |

