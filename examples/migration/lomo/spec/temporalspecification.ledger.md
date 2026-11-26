# Migration ledger: temporalspecification

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — TemporalSpecification.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 1 |
| residue | 0 |
| **total** | 5 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Deadline_BreachNotification | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | deadline breach notification |  |
| http://example.org/BreachEvent | *a thing* is a temporal specification | encoded | 2 statements(2), one fact each | breach event |  |
| http://example.org/Deadline_Submission | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | deadline submission |  |
| http://example.org/CompletionOfLanding | *a thing* is a temporal specification | encoded | 2 statements(2), one fact each | completion of landing |  |
| P24H | a length of time | approximated | kept as text; no date is calculated from it | deadline submission | "P24H" is not a length of time in the standard form of ISO 8601 (P1Y, P12M, PT72H): a calendar cannot count with it |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| breach_on_1_march_2026 | first_dates | pass |  |
| breach_on_1_march_2026 | hours_as_days | pass |  |

