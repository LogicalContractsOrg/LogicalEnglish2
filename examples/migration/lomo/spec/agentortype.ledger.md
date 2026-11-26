# Migration ledger: agentortype

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — AgentOrType.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Report | action | encoded | 9 statements(9), one fact each | report 2 |  |
| http://example.org/MemberStates | agent type | encoded | 2 statements(2), one fact each | member states |  |
| http://example.org/Commission | agent | encoded | 2 statements(2), one fact each | commission |  |
| http://example.org/Report | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Report has hasAgentRole '_:', which is not a web address |
| http://example.org/Report | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Report has hasAgentRole '_:', which is not a web address |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | actions_of_agents | pass |  |

