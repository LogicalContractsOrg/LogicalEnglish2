# Migration ledger: action

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — Action.ttl
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

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Action_PublishReport | action | encoded | 4 statements(4), one fact each | action publish report |  |
| http://example.org/AgentRole_Commission_Publisher | agent role | encoded | 3 statements(3), one fact each | agent role commission publisher |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | actions_of_agents | pass |  |

