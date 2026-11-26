# Migration ledger: finishedby

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — finishedBy.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 0 |
| **total** | 6 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Deadline_SubmitReport | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | deadline submit report |  |
| http://example.org/FiscalYear2025 | *a thing* is a temporal specification | encoded | 3 statements(3), one fact each | fiscal year 2025 |  |
| http://example.org/Action_SubmitReport | action | encoded | 4 statements(4), one fact each | action submit report |  |
| http://example.org/Action_ReviewReport | action | encoded | 4 statements(4), one fact each | action review report |  |
| http://example.org/Action_ReviewReport | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_ReviewReport has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_SubmitReport | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_SubmitReport has no hasAgentRole (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| the_links | times_within | pass |  |
| the_links | broken_links | pass |  |

