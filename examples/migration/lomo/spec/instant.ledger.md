# Migration ledger: instant

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — instant.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 0 |
| residue | 0 |
| **total** | 12 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/R1 | *a thing* is a prescriptive rule | encoded | 8 statements(8), one fact each | r 1 |  |
| http://example.org/Action_Meeting | action | encoded | 4 statements(4), one fact each | action meeting |  |
| http://example.org/Action_SeasonalReport | action | encoded | 4 statements(4), one fact each | action seasonal report |  |
| _: | a validity rule of LOMO | encoded | kept as the description has it | - | _: has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_Meeting | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_Meeting has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_SeasonalReport | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_SeasonalReport has no hasAgentRole (LOMO asks for one) |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has no establishedIn (LOMO asks for one) |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has no establishedIn (LOMO asks for one) |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has no hasDeonticModality (LOMO asks for one) |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has produces '_:', which is not a web address |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has no label (LOMO asks for one) |
| http://example.org/R1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/R1 has no label (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| the_instants | first_dates | pass |  |
| the_instants | last_dates | pass |  |

