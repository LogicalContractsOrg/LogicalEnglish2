# Migration ledger: duration

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — duration.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 0 |
| residue | 0 |
| **total** | 2 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/A1 | action | encoded | 8 statements(8), one fact each | item a 1 |  |
| http://example.org/A1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/A1 has no hasAgentRole (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| approved_on_15_may_2026 | first_dates | pass |  |

