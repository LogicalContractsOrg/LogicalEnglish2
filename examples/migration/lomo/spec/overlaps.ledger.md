# Migration ledger: overlaps

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — overlaps.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 0 |
| residue | 0 |
| **total** | 7 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Action_ProjectA | action | encoded | 5 statements(5), one fact each | action project a |  |
| http://example.org/Action_ProjectB | action | encoded | 5 statements(5), one fact each | action project b |  |
| http://example.org/TemporalSpec_ProjectA | thing | encoded | 1 statements(1), one fact each | temporal spec project a |  |
| http://example.org/TemporalSpec_EventA | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | temporal spec event a |  |
| http://example.org/TemporalSpec_EventB | *a thing* is a temporal specification | encoded | 3 statements(3), one fact each | temporal spec event b |  |
| http://example.org/Action_ProjectA | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_ProjectA has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_ProjectB | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_ProjectB has no hasAgentRole (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| the_periods | first_dates | pass |  |
| the_periods | last_dates | pass |  |
| the_periods | broken_links | pass |  |

